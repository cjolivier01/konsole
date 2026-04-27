#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE_NAME="${KONSOLE_BUILD_IMAGE:-konsole-build-f41}"
BUILD_DIR_REL="${1:-build-fedora}"
JOBS="${JOBS:-$(nproc)}"

if [[ "${BUILD_DIR_REL}" = /* ]]; then
    echo "error: build directory must be relative to the repo root" >&2
    echo "example: ./tools/build-fedora-container.sh build-fedora-release" >&2
    exit 1
fi

if command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
    USER_ARGS=(--userns=keep-id)
elif command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
    USER_ARGS=(--user "$(id -u):$(id -g)")
else
    echo "error: neither podman nor docker was found in PATH" >&2
    exit 1
fi

mkdir -p "${REPO_ROOT}/${BUILD_DIR_REL}"

echo "==> Building container image ${IMAGE_NAME}"
"${RUNTIME}" build \
    --pull=always \
    -f "${SCRIPT_DIR}/Containerfile.fedora41" \
    -t "${IMAGE_NAME}" \
    "${SCRIPT_DIR}"

echo "==> Configuring and building Konsole in ${BUILD_DIR_REL}"
"${RUNTIME}" run --rm \
    "${USER_ARGS[@]}" \
    -e HOME=/tmp \
    -v "${REPO_ROOT}:/src" \
    -w /src \
    "${IMAGE_NAME}" \
    bash -lc "cmake -S /src -B /src/${BUILD_DIR_REL} -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build /src/${BUILD_DIR_REL} -j${JOBS}"

echo "==> Build complete: ${REPO_ROOT}/${BUILD_DIR_REL}"
