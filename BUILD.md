# Konsole Build Guide

`v24.12.x` is a Qt6/KF6 release. It needs:
- Qt `>= 6.5`
- KF6 `>= 6.0`
- Extra CMake Modules (ECM) `>= 6.0`

## 1) Build with `make` (Ubuntu 26.04)

The top-level `Makefile` wraps the CMake build and the Debian packaging. Run
`make` on its own to list every target.

```bash
make deps                 # install the Build-Depends from packaging/debian/control
make build -j"$(nproc)"   # configure + compile into build/
./build/bin/konsole --version
```

Useful variables: `BUILD_TYPE` (default `Release`), `BUILD_DIR` (default `build`),
`PREFIX` (default `/usr/local`), `CMAKE_ARGS`. `make -j N` is forwarded to the
build tool, and `make debug` / `profile` / `asan` build into their own
directories.

To build the Ubuntu 26.04 `.deb` installer:

```bash
make deb
```

This always builds inside a container (`ubuntu:26.04` by default), so the
packages do not depend on what happens to be installed on the host. Artifacts
land in `dist/ubuntu26.04/`:

- `konsole_<version>_amd64.deb`
- `konsole-kpart_<version>_amd64.deb`

Install them with `make deb-install`, remove them with `make deb-uninstall`.
Use `make deb-shell` to get a shell in the builder image when a package build
needs debugging. Override the baseline with
`make deb TARGET_UBUNTU=24.04`, and force podman with
`KONSOLE_CONTAINER_RUNTIME=podman`.

## 2) Native build (distros with KF6 packages)

Example for Fedora 41+:

```bash
sudo dnf install -y dnf-plugins-core ninja-build
sudo dnf builddep -y konsole

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

## 3) Containerized build (works on older host distros)

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

`v24.12.x` is not a realistic fully-static target in this environment. The
Fedora toolchain used here provides Qt6/KF6 as shared libraries, so a
container-built binary must either be run inside that container or packaged in
a self-contained format such as Flatpak.

## 4) Self-contained Flatpak build

The repo keeps the upstream nightly manifest in `.flatpak-manifest.json`.
For this `v24.12.x` checkout, use the stable manifest and helper script:

```bash
sudo apt-get install -y flatpak-builder
./tools/build-flatpak.sh
```

This uses:
- [org.kde.konsole.stable.flatpak.json](org.kde.konsole.stable.flatpak.json)
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

For another machine without `org.kde.Platform//6.9` already installed, export
the runtime bundle too:

```bash
./tools/export-flatpak-runtime-bundle.sh
```

Then copy both files:
- `org.kde.Platform-6.9.flatpak`
- `konsole-24.12.flatpak`

Install them on the target machine in this order:

```bash
flatpak install ./org.kde.Platform-6.9.flatpak
flatpak install ./konsole-24.12.flatpak
```
