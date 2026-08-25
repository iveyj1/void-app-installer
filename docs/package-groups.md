# Package Groups

`install-void-package-groups` reads group files from `packages.d/`.

## Format

Each group file is plain text:

```text
# comments are ignored
package-name
another-package
```

Blank lines are ignored. Inline comments are also ignored:

```text
samba  # optional file sharing tools
```

## Groups

- `core` - command-line tools, networking basics, dwm/XLibre, audio, fonts, build dependencies, and live-image tools
- `xfce` - Xfce desktop plus Breeze/Plasma-style appearance packages
- `cad` - FreeCAD, KiCad, OpenSCAD
- `network` - CIFS and Samba packages
- `extras` - miscellaneous tools; `install-void-apps` also installs Pi when this group is selected
- `all` - expands to all groups above

## Usage

```sh
./install-void-package-groups core
./install-void-package-groups core xfce
./install-void-package-groups all
```

The main installer always installs `core` and adds optional groups according to `--xfce`, `--cad`, `--network`, `--extras`, or `--all`.

## Adding a package

For quick additions to the core list:

```sh
./add-package-void package-name
```

Or edit the group files directly.
