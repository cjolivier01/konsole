#!/usr/bin/env bash
# Build the Konsole Debian packages against an explicit Ubuntu ABI baseline in
# a container, so the result does not depend on whatever happens to be
# installed on the host.
#
# Usage:
#   tools/build-deb-docker.sh --target-ubuntu=26.04
#   tools/build-deb-docker.sh --target-ubuntu=26.04 --shell
#
# The container runs tools/build-deb.sh with the repository bind-mounted
# read-only, so a package build can never write into the working tree.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./tools/build-deb-docker.sh [options]

Options:
  -h, --help                 Show this help text
      --target-ubuntu VER    Ubuntu release to build against (default: 26.04)
      --base-image IMAGE     Base image (default: ubuntu:<target-ubuntu>)
      --image-name NAME      Builder image tag (default: konsole-deb-build-<target-ubuntu>)
  -o, --output-dir DIR       Where built .deb artifacts are written
                             Default: dist/ubuntu<target-ubuntu>
      --version-suffix TEXT  Debian revision suffix passed to tools/build-deb.sh
      --no-cache             Rebuild the builder image from scratch
      --build-image-only     Build or refresh the builder image, then stop
      --shell                Open an interactive shell in the builder image

Environment:
  KONSOLE_CONTAINER_RUNTIME  Force "docker" or "podman"
  DEBFULLNAME, DEBEMAIL      Forwarded into the generated debian/changelog entry
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_UBUNTU="26.04"
BASE_IMAGE=""
IMAGE_NAME=""
OUTPUT_DIR=""
VERSION_SUFFIX=""
NO_CACHE=0
BUILD_IMAGE_ONLY=0
OPEN_SHELL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --target-ubuntu) TARGET_UBUNTU="$2"; shift 2 ;;
        --target-ubuntu=*) TARGET_UBUNTU="${1#*=}"; shift ;;
        --base-image) BASE_IMAGE="$2"; shift 2 ;;
        --base-image=*) BASE_IMAGE="${1#*=}"; shift ;;
        --image-name) IMAGE_NAME="$2"; shift 2 ;;
        --image-name=*) IMAGE_NAME="${1#*=}"; shift ;;
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
        --version-suffix) VERSION_SUFFIX="$2"; shift 2 ;;
        --version-suffix=*) VERSION_SUFFIX="${1#*=}"; shift ;;
        --no-cache) NO_CACHE=1; shift ;;
        --build-image-only) BUILD_IMAGE_ONLY=1; shift ;;
        --shell) OPEN_SHELL=1; shift ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

BASE_IMAGE="${BASE_IMAGE:-ubuntu:${TARGET_UBUNTU}}"
IMAGE_NAME="${IMAGE_NAME:-konsole-deb-build-${TARGET_UBUNTU}}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/dist/ubuntu${TARGET_UBUNTU}}"

# Prefer docker: the package build runs as root inside the container and chowns
# its output back to the invoking user, which needs no uid remapping.
if [[ -n "${KONSOLE_CONTAINER_RUNTIME:-}" ]]; then
    RUNTIME="${KONSOLE_CONTAINER_RUNTIME}"
    if ! command -v "${RUNTIME}" >/dev/null 2>&1; then
        echo "error: KONSOLE_CONTAINER_RUNTIME=${RUNTIME} is not in PATH" >&2
        exit 1
    fi
elif command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
else
    echo "error: neither docker nor podman was found in PATH" >&2
    exit 1
fi

echo "==> Building container image ${IMAGE_NAME} (base: ${BASE_IMAGE})"
build_args=(
    build
    --build-arg "BASE_IMAGE=${BASE_IMAGE}"
    -f "${SCRIPT_DIR}/Containerfile.ubuntu"
    -t "${IMAGE_NAME}"
)
if [[ "${NO_CACHE}" -eq 1 ]]; then
    build_args+=(--no-cache)
fi
# The build context is packaging/debian so the image layer that installs the
# build dependencies is invalidated exactly when control changes.
build_args+=("${REPO_ROOT}/packaging/debian")
"${RUNTIME}" "${build_args[@]}"

if [[ "${BUILD_IMAGE_ONLY}" -eq 1 ]]; then
    echo "==> Image ready: ${IMAGE_NAME}"
    exit 0
fi

mkdir -p "${OUTPUT_DIR}"

run_args=(
    run --rm
    -v "${REPO_ROOT}:/src:ro"
    -v "${OUTPUT_DIR}:/out"
    -w /src
    -e "HOST_UID=$(id -u)"
    -e "HOST_GID=$(id -g)"
    -e "DEBFULLNAME=${DEBFULLNAME:-Local Konsole Build}"
    -e "DEBEMAIL=${DEBEMAIL:-local@invalid}"
    # /src is read-only and owned by a different uid inside the container;
    # these let build-deb.sh still read the git ref instead of falling back to
    # "nogit", without trying to refresh the index.
    -e GIT_OPTIONAL_LOCKS=0
    -e GIT_CONFIG_COUNT=1
    -e GIT_CONFIG_KEY_0=safe.directory
    -e GIT_CONFIG_VALUE_0=/src
)

if [[ "${OPEN_SHELL}" -eq 1 ]]; then
    echo "==> Opening a shell in ${IMAGE_NAME}"
    exec "${RUNTIME}" "${run_args[@]}" -it "${IMAGE_NAME}" bash
fi

deb_args=(--work-root /build --output-dir /out)
if [[ -n "${VERSION_SUFFIX}" ]]; then
    deb_args+=(--version-suffix "${VERSION_SUFFIX}")
fi

echo "==> Building Konsole packages for Ubuntu ${TARGET_UBUNTU}"
"${RUNTIME}" "${run_args[@]}" "${IMAGE_NAME}" bash -c '
    set -euo pipefail
    mkdir -p /build
    /src/tools/build-deb.sh "$@"
    chown -R "${HOST_UID}:${HOST_GID}" /out
' bash "${deb_args[@]}"

echo "==> Artifacts in ${OUTPUT_DIR}:"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name '*.deb' -printf '  %f\n' | sort
