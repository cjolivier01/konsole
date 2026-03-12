# Konsole Build Guide

`v24.12.0` is a Qt6/KF6 release. It needs:
- Qt `>= 6.5`
- KF6 `>= 6.0`
- Extra CMake Modules (ECM) `>= 6.0`

## 1) Native build (distros with KF6 packages)

Example for Fedora 41+:

```bash
sudo dnf install -y dnf-plugins-core ninja-build
sudo dnf builddep -y konsole

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

## 2) Containerized build (works on older host distros)

If your host distro does not ship KF6/ECM6 packages (for example Ubuntu 24.04),
build with the helper script:

```bash
./tools/build-fedora-container.sh
```

This script:
- builds a Fedora 41 image with the required build dependencies
- mounts this repository into the container
- runs CMake configure + compile in `build-fedora/`

To run the resulting build against the same Fedora Qt6/KF6 runtime, use:

```bash
./tools/run-fedora-container.sh build-fedora --version
```

`v24.12.0` is not a realistic fully-static target in this environment. The
Fedora toolchain used here provides Qt6/KF6 as shared libraries, so a
container-built binary must either be run inside that container or packaged in
a self-contained format such as Flatpak.

## 3) Self-contained Flatpak build

The repo keeps the upstream nightly manifest in
`/home/colivier-local/src/konsole/.flatpak-manifest.json`.
For this `v24.12.0` checkout, use the stable manifest and helper script:

```bash
sudo apt-get install -y flatpak-builder
./tools/build-flatpak.sh
```

This uses:
- [org.kde.konsole.stable.flatpak.json](/home/colivier-local/src/konsole/org.kde.konsole.stable.flatpak.json)
- runtime `org.kde.Platform//6.9`
- sdk `org.kde.Sdk//6.9`

Outputs:
- local Flatpak repo in `flatpak-repo/`
- bundle at `konsole-24.12.flatpak`

Run the installed Flatpak with:

```bash
./tools/run-flatpak.sh --version
```

If `org.kde.konsole//24.12` is not installed yet, the runner installs it from
`konsole-24.12.flatpak` automatically.
