#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./tools/install-deps.sh [options]

Install the Debian/Ubuntu packages needed to build Konsole from source. The
package list is read from packaging/debian/control, so it always matches what
dpkg-buildpackage enforces for `make deb`.

Options:
  -h, --help             Show this help text
  -n, --dry-run          Print what would be installed, change nothing
  -y, --yes              Do not prompt before installing (implied when non-interactive)
      --no-update        Skip `apt-get update`
      --control FILE     Read Build-Depends from FILE
                         Default: packaging/debian/control
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTROL_FILE="${REPO_ROOT}/packaging/debian/control"
DRY_RUN=0
ASSUME_YES=0
RUN_UPDATE=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -y|--yes)
            ASSUME_YES=1
            shift
            ;;
        --no-update)
            RUN_UPDATE=0
            shift
            ;;
        --control)
            CONTROL_FILE="$2"
            shift 2
            ;;
        --control=*)
            CONTROL_FILE="${1#*=}"
            shift
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ ! -r "${CONTROL_FILE}" ]]; then
    echo "error: control file not readable: ${CONTROL_FILE}" >&2
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "error: apt-get not found; this script only supports Debian-based distributions." >&2
    exit 1
fi

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" != "debian" && "${ID_LIKE:-}" != *debian* ]]; then
        echo "error: unsupported distribution: ${PRETTY_NAME:-unknown}" >&2
        exit 1
    fi
    if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" != "26.04" ]]; then
        echo "warning: this checkout targets Ubuntu 26.04; host is ${VERSION_ID:-unknown}." >&2
        echo "warning: a native build may still work; 'make deb' is unaffected either way." >&2
    fi
fi

# Collect the Build-Depends stanza using the control-file continuation rule
# (continuation lines start with whitespace), then drop version constraints
# "(>= 1.0)", architecture qualifiers "[linux-any]" and build profiles
# "<!nocheck>", and keep only the first branch of any "foo | bar" alternative.
mapfile -t PACKAGES < <(
    awk '
        /^Build-Depends(-Arch|-Indep)?:/ { collecting = 1; sub(/^[^:]*:/, ""); print; next }
        collecting && /^[ \t]/           { print; next }
        collecting                       { collecting = 0 }
    ' "${CONTROL_FILE}" \
        | tr ',' '\n' \
        | sed -e 's/([^)]*)//g' -e 's/\[[^]]*\]//g' -e 's/<[^>]*>//g' \
        | cut -d'|' -f1 \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | grep -E '^[a-z0-9][a-z0-9+.-]*$' \
        | sort -u
)

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
    echo "error: no Build-Depends parsed from ${CONTROL_FILE}" >&2
    exit 1
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "error: not running as root and sudo is not available." >&2
        exit 1
    fi
    SUDO="sudo"
fi

echo "Build dependencies from ${CONTROL_FILE} (${#PACKAGES[@]} packages):"
printf '  %s\n' "${PACKAGES[@]}"
echo

if [[ "${DRY_RUN}" -eq 1 ]]; then
    if [[ "${RUN_UPDATE}" -eq 1 ]]; then
        echo "Would run: ${SUDO} apt-get update"
    fi
    echo "Would run: ${SUDO} apt-get install -y ${PACKAGES[*]}"
    exit 0
fi

if [[ "${ASSUME_YES}" -eq 0 ]] && [[ -t 0 ]]; then
    read -r -p "Install these packages now? [y/N] " reply
    case "${reply}" in
        y|Y|yes|YES) ;;
        *)
            echo "Aborted."
            exit 1
            ;;
    esac
fi

if [[ "${RUN_UPDATE}" -eq 1 ]]; then
    echo "==> apt-get update"
    # A single unreachable third-party repository makes apt-get update exit
    # non-zero even though every Ubuntu suite refreshed fine. Warn and carry
    # on; the install below fails loudly if a package is really missing.
    if ! ${SUDO} apt-get update; then
        echo "warning: apt-get update reported errors (see above); continuing anyway." >&2
    fi
fi

echo "==> Installing build dependencies"
DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get install -y "${PACKAGES[@]}"

echo "==> Verifying with dpkg-checkbuilddeps"
if dpkg-checkbuilddeps "${CONTROL_FILE}"; then
    echo "All build dependencies are satisfied."
else
    echo "error: build dependencies are still unsatisfied (see above)." >&2
    exit 1
fi
