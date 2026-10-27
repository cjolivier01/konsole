TOPDIR := $(shell pwd)

# Prefer the distro CMake. A conda environment earlier in PATH ships its own
# cmake, and that one drags conda prefixes into find_package(), which breaks
# Qt6/KF6 detection in confusing ways. Override with `make CMAKE=/path/to/cmake`.
CMAKE ?= $(if $(wildcard /usr/bin/cmake),/usr/bin/cmake,cmake)
CTEST ?= $(if $(wildcard /usr/bin/ctest),/usr/bin/ctest,ctest)
GENERATOR ?= Ninja
BUILD_TYPE ?= Release
BUILD_DIR ?= build
PREFIX ?= /usr/local
CMAKE_ARGS ?=

# Forward `make -j N` to the CMake build tool. GNU make normalizes -jN/-j N/
# --jobs=N into a single "-jN" word in MAKEFLAGS; a bare "-j" (unlimited) maps
# to every core. Override directly with `make CMAKE_JOBS=16 ...`; with neither,
# the generator keeps its own default.
MAKE_JOBS_FLAG := $(firstword $(filter -j%,$(MAKEFLAGS)))
CMAKE_JOBS ?= $(if $(MAKE_JOBS_FLAG),$(or $(patsubst -j%,%,$(MAKE_JOBS_FLAG)),$(shell nproc)),)
CMAKE_JOBS_FLAG := $(if $(strip $(CMAKE_JOBS)),-j $(strip $(CMAKE_JOBS)),)

TARGET_UBUNTU ?= 26.04
DEB_BASE_IMAGE ?= ubuntu:$(TARGET_UBUNTU)
DEB_OUTPUT_DIR ?= $(TOPDIR)/dist/ubuntu$(TARGET_UBUNTU)
DEB_VERSION_SUFFIX ?= 0local1
DEB_CONTROL := $(TOPDIR)/packaging/debian/control

all: print_targets

.PHONY: all print_targets configure build release debug profile asan test \
	run install uninstall deps check-deps \
	deb deb-ubuntu26 deb-image deb-shell deb-install deb-uninstall \
	clean distclean format

configure:
	$(CMAKE) -S $(TOPDIR) -B $(BUILD_DIR) -G $(GENERATOR) \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
		$(CMAKE_ARGS)

build: configure
	$(CMAKE) --build $(BUILD_DIR) $(CMAKE_JOBS_FLAG)

release:
	$(MAKE) build BUILD_TYPE=Release BUILD_DIR=build-release

debug:
	$(MAKE) build BUILD_TYPE=Debug BUILD_DIR=build

profile:
	$(MAKE) build BUILD_TYPE=RelWithDebInfo BUILD_DIR=build-profile

asan:
	$(MAKE) build BUILD_TYPE=Debug BUILD_DIR=build-asan \
		CMAKE_ARGS="-DECM_ENABLE_SANITIZERS='address;undefined' $(CMAKE_ARGS)"

test:
	$(MAKE) build CMAKE_ARGS="-DBUILD_TESTING=ON $(CMAKE_ARGS)"
	cd $(BUILD_DIR) && $(CTEST) --output-on-failure

run: build
	$(BUILD_DIR)/bin/konsole

install: build
	$(CMAKE) --install $(BUILD_DIR) --prefix $(PREFIX)

uninstall:
	@if [ ! -f "$(BUILD_DIR)/install_manifest.txt" ]; then \
		echo 'ERROR: $(BUILD_DIR)/install_manifest.txt not found; nothing was installed from this build tree.' >&2; \
		exit 2; \
	fi
	xargs -r -d '\n' rm -f -- < $(BUILD_DIR)/install_manifest.txt

deps:
	tools/install-deps.sh

check-deps:
	dpkg-checkbuilddeps $(DEB_CONTROL)

deb:
	@echo "Debian package output directory: $(DEB_OUTPUT_DIR)"
	tools/build-deb-docker.sh \
		--target-ubuntu="$(TARGET_UBUNTU)" \
		--base-image="$(DEB_BASE_IMAGE)" \
		--output-dir="$(DEB_OUTPUT_DIR)" \
		--version-suffix="$(DEB_VERSION_SUFFIX)"

deb-ubuntu26:
	$(MAKE) deb TARGET_UBUNTU=26.04

deb-image:
	tools/build-deb-docker.sh --target-ubuntu="$(TARGET_UBUNTU)" \
		--base-image="$(DEB_BASE_IMAGE)" --build-image-only

deb-shell:
	tools/build-deb-docker.sh --target-ubuntu="$(TARGET_UBUNTU)" \
		--base-image="$(DEB_BASE_IMAGE)" --shell

deb-install:
	@if [ -z "$$(find '$(DEB_OUTPUT_DIR)' -maxdepth 1 -name '*.deb' -print -quit 2>/dev/null)" ]; then \
		echo 'ERROR: no .deb found in $(DEB_OUTPUT_DIR). Run `make deb` first.' >&2; \
		exit 2; \
	fi
	sudo apt-get install -y $(DEB_OUTPUT_DIR)/konsole_*.deb $(DEB_OUTPUT_DIR)/konsole-kpart_*.deb

deb-uninstall:
	sudo apt-get remove -y konsole konsole-kpart

clean:
	@if [ -d "$(BUILD_DIR)" ]; then $(CMAKE) --build $(BUILD_DIR) --target clean; fi

distclean:
	rm -rf $(TOPDIR)/build $(TOPDIR)/build-release $(TOPDIR)/build-profile \
		$(TOPDIR)/build-asan $(TOPDIR)/build-deb $(TOPDIR)/dist \
		$(TOPDIR)/compile_commands.json

format:
	$(MAKE) configure
	$(CMAKE) --build $(BUILD_DIR) --target clang-format

print_targets:
	@printf '%s\n' \
		"Available make targets (run 'make <target>'):" \
		'' \
		"'make -j N <target>' forwards N to the CMake build tool (bare -j means all cores);" \
		'override directly with CMAKE_JOBS=N.' \
		'' \
		'Build Outputs' \
		'-------------' \
		'build          Configure and compile BUILD_TYPE=$(BUILD_TYPE) into $(BUILD_DIR).' \
		'configure      Run the CMake configure step only.' \
		'release        Build optimized (Release) into build-release.' \
		'debug          Build unoptimized with debug info (Debug) into build.' \
		'profile        Build RelWithDebInfo into build-profile.' \
		'asan           Build Debug with address+undefined sanitizers into build-asan.' \
		'' \
		'Run & Install' \
		'-------------' \
		'run            Build, then run $(BUILD_DIR)/bin/konsole.' \
		'install        cmake --install into PREFIX=$(PREFIX) (DESTDIR honored).' \
		'uninstall      Remove the files listed in $(BUILD_DIR)/install_manifest.txt.' \
		'' \
		'Dependencies' \
		'------------' \
		'deps           Install the Build-Depends from packaging/debian/control (needs sudo).' \
		'check-deps     Report which build dependencies are still missing.' \
		'' \
		'Debian Packaging' \
		'----------------' \
		'Packages are always built in a container, never against the host.' \
		'deb            Build the .deb for Ubuntu $(TARGET_UBUNTU); output under dist/ubuntu$(TARGET_UBUNTU).' \
		'deb-ubuntu26   Build the Ubuntu 26.04 package (the default target release).' \
		'deb-image      Build or refresh the builder image only.' \
		'deb-shell      Open an interactive shell in the builder image.' \
		'deb-install    apt-get install the packages from $(DEB_OUTPUT_DIR) (needs sudo).' \
		'deb-uninstall  apt-get remove konsole and konsole-kpart (needs sudo).' \
		'' \
		'Tests' \
		'-----' \
		'test           Build with BUILD_TESTING=ON and run ctest.' \
		'' \
		'Maintenance & Cleanup' \
		'---------------------' \
		'clean          cmake --build $(BUILD_DIR) --target clean.' \
		'distclean      Remove every build directory plus dist/.' \
		'format         Run the clang-format target over all sources.' \
		'' \
		'Meta' \
		'----' \
		'print_targets  Shows this help text.'
