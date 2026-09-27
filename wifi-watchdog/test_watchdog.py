#!/usr/bin/env python3
"""Offline tests: no real service/network commands are executed."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
SOURCE = (ROOT / 'wifi-watchdog').read_text().rsplit('\nmain\n', 1)[0]
STUBS = '''
clock=100
health_input=disconnected
state_input=DISCONNECTED
date() { if [ "$1" = +%s ]; then echo "$clock"; else echo timestamp; fi; }
inspect() {
    health=$health_input; state=$state_input
    status="wpa_state=$state"; status_rc=0; link="test link"
}
command_log() { log "COMMAND $*"; }
init_state
'''


class WatchdogTests(unittest.TestCase):
    def run_script(self, script, stubs=True):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'watchdog.log'
            env = dict(os.environ, WIFI_WATCHDOG_CONFIG='/dev/null', LOG=str(log))
            result = subprocess.run(['sh', '-c', SOURCE + '\n' + (STUBS if stubs else '') + script],
                                    env=env, text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            return log.read_text() if log.exists() else ''

    def test_stages_and_verified_recovery(self):
        log = self.run_script('''
tick
clock=110; tick
clock=120; tick
clock=130; tick
clock=140; health_input=healthy; tick
''')
        commands = [line.split('COMMAND ')[1] for line in log.splitlines() if 'COMMAND ' in line]
        self.assertEqual(commands, ['wpa_cli -i wlp0s20f3 reconnect',
                                    'wpa_cli -i wlp0s20f3 reassociate',
                                    'sv -w 5 restart wpa_supplicant'])
        self.assertIn('recovered verified downtime=40s', log)

    def test_progress_grace_is_bounded(self):
        log = self.run_script('''
state_input=4WAY_HANDSHAKE
tick
clock=110; tick
clock=120; tick
clock=130; tick
clock=140; tick
''')
        self.assertEqual(log.count('granting one extra interval'), 1)
        self.assertIn('COMMAND sv -w 5 restart wpa_supplicant', log)

    def test_dhcp_only(self):
        log = self.run_script('''
health_input=no-ip; state_input=COMPLETED
tick
clock=110; tick
clock=120; tick
''')
        self.assertIn('COMMAND dhcpcd -n wlp0s20f3', log)
        self.assertIn('COMMAND sv -w 5 restart dhcpcd', log)
        self.assertNotIn('COMMAND wpa_cli', log)
        self.assertNotIn('restart wpa_supplicant', log)

    def test_unreachable_gateway_does_not_restart(self):
        log = self.run_script('''
health_input=gateway-unreachable; state_input=COMPLETED
tick
clock=110; tick
clock=1000; tick
''')
        self.assertNotIn('COMMAND', log)

    def test_restart_backoff_and_stable_reset(self):
        log = self.run_script('''
tick
clock=110; tick
clock=120; tick
clock=130; tick
clock=140; tick
clock=249; tick
clock=250; tick
clock=260; health_input=healthy; tick
clock=560; tick
[ "$backoff" -eq 120 ] && [ "$next_restart" -eq 0 ]
''')
        self.assertEqual(log.count('COMMAND sv'), 2)
        self.assertIn('next_restart_in=120s', log)
        self.assertIn('next_restart_in=240s', log)

    def test_zero_exit_fail_response_is_failure(self):
        log = self.run_script('''
if command_log sh -c 'echo FAIL'; then exit 1; fi
command_log sh -c 'echo OK'
''', stubs=False)
        self.assertIn('rc=0 response=FAIL', log)
        self.assertIn('rc=0 response=OK', log)

    def test_nonzero_exit_is_logged(self):
        log = self.run_script('''
if command_log sh -c 'echo denied >&2; exit 7'; then exit 1; fi
''', stubs=False)
        self.assertIn('rc=7 response=denied', log)

    def test_command_timeout(self):
        log = self.run_script('''
COMMAND_TIMEOUT=0.1
if command_log sh -c 'sleep 2'; then exit 1; fi
''', stubs=False)
        self.assertIn('rc=124', log)

    def test_inspect_classification(self):
        self.run_script('''
timeout() { shift; "$@"; }
wpa_cli() { echo wpa_state=COMPLETED; }
iw() { echo 'Connected to test'; }
ip() {
    case "$*" in
        *addr*) [ "$has_ip" = yes ] && echo '2: test inet 10.0.0.10/24' ;;
        *route*) [ "$has_route" = yes ] && echo 'default via 10.0.0.1 dev test' ;;
    esac
}
ping() { [ "$responds" = yes ]; }
has_ip=no; has_route=no; responds=no
inspect; [ "$health" = no-ip ] || exit 1
has_ip=yes
inspect; [ "$health" = no-route ] || exit 1
has_route=yes
inspect; [ "$health" = gateway-unreachable ] || exit 1
responds=yes
inspect; [ "$health" = healthy ] || exit 1
iw() { echo 'Not connected.'; }
inspect; [ "$health" = disconnected ] || exit 1
''', stubs=False)

    def test_rotation(self):
        self.run_script('''
LOG_MAX_BYTES=1
log one
log two
log three
[ -s "$LOG.1" ] && [ -s "$LOG.2" ]
''', stubs=False)


if __name__ == '__main__':
    unittest.main()
