#!/usr/bin/env python3
import contextlib
import io
from pathlib import Path
import runpy
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'configure-acpi-brightness'
configure = runpy.run_path(str(HELPER))['configure']
STOCK = '''#!/bin/sh
case "$1" in
    button/lid) zzz ;;
    video/brightnessdown)
        step_backlight -
        ;;
    video/brightnessup)
        step_backlight +
        ;;
    *) logger "$1" ;;
esac
'''


class AcpiBrightness(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'handler.sh'
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))

    def test_patch_and_repeat(self):
        self.path.write_text(STOCK)
        self.path.chmod(0o755)
        configure(self.path)
        result = self.path.read_text()
        self.assertNotIn('step_backlight', result)
        self.assertIn('button/lid) zzz ;;', result)
        self.assertIn('*) logger "$1" ;;', result)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o755)
        backup = self.path.with_name('handler.sh.before-desktop-brightness')
        self.assertEqual(backup.read_text(), STOCK)
        configure(self.path)
        self.assertEqual(self.path.read_text(), result)
        self.assertEqual(backup.read_text(), STOCK)

    def test_absent(self):
        configure(self.path)
        self.assertFalse(self.path.exists())

    def test_custom_untouched(self):
        self.path.write_text(STOCK.replace('step_backlight +', 'custom_brightness'))
        original = self.path.read_text()
        with self.assertRaises(SystemExit):
            configure(self.path)
        self.assertEqual(self.path.read_text(), original)
        self.assertEqual(len(list(self.path.parent.iterdir())), 1)


if __name__ == '__main__':
    unittest.main()
