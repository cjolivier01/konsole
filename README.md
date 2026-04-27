# Konsole - KDE's Terminal Emulator

Konsole is a terminal program for KDE.

As well as being a standalone program, it is also used by other KDE programs
such as the Kate editor and KDevelop development environment to provide easy
access to a terminal window. Konsole's features and usage are explained and
illustrated in the Konsole handbook, which can be accessed by browsing to
`help:/konsole` in Konqueror.

## Building Debian packages on Ubuntu 24.04

For the `v24.12.x` packaging branch in this repository, stock Ubuntu 24.04
packages are too old for the required Qt6, KF6, and ECM versions. Enable the
KDE neon User repository first, then install the build dependencies and run the
Debian packaging helper:

```bash
sudo install -d /etc/apt/keyrings
curl -fsSL https://archive.neon.kde.org/public.key | sudo gpg --dearmor -o /etc/apt/keyrings/neon-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/neon-archive-keyring.gpg] https://archive.neon.kde.org/user noble main" | sudo tee /etc/apt/sources.list.d/kde-neon-user.list >/dev/null

sudo apt-get update
sudo apt-get install -y curl gpg devscripts equivs rsync dpkg-dev
sudo mk-build-deps --install --remove --tool 'apt-get -y --no-install-recommends -o Dpkg::Options::=--force-overwrite' packaging/debian/control

./tools/build-deb.sh
```

Generated artifacts are copied to `build-deb/packages/`.

For native, container, and Flatpak build notes beyond this Debian packaging
flow, see `BUILD.md`.

## Directory Structure

| Directory          | Description                                                                                                                                                                        |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/doc/user`        | README files, primarily for advanced users, explaining various aspects of Konsole such as fonts and keyboard handling in-depth.                                                    |
| `/doc/developer`   | README files and resources for developers of Konsole. This includes information on the design of Konsole's internals and the VT100 terminal on which Konsole's emulation is based. |
| `/src`             | Source code for Konsole, including the embedded versions of Konsole which are used in Kate, KDevelop and others.                                                                   |
| `/desktop`         | .desktop files for Konsole, used to launch the program from KDE's various menus and other application launchers.                                                                   |
| `/data`            | Data files for use with Konsole as well as the keyboard setup and color schemes provided with Konsole.                                                                             |

## Contact

Up-to-date information about the latest releases can be found on Konsole's
website at https://konsole.kde.org. Discussions about Konsole's development are
held on the konsole-devel mailing list, which can be accessed at
https://mail.kde.org/mailman/listinfo/konsole-devel.

## Quick Links
- [KDE Release Schedule](https://community.kde.org/Schedules)
- [Official Homepage](https://konsole.kde.org)
- [Builds](https://invent.kde.org/utilities/konsole/-/pipelines)
- [Forums](https://discuss.kde.org)
- [Konsole Bug Reports per Component](https://bugs.kde.org/describecomponents.cgi?product=konsole)
