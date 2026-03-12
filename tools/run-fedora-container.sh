#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE_NAME="${KONSOLE_BUILD_IMAGE:-konsole-build-f41}"
BUILD_DIR_REL="${1:-build-fedora}"

if [[ "${BUILD_DIR_REL}" = /* ]]; then
    echo "error: build directory must be relative to the repo root" >&2
    exit 1
fi

shift || true

APP_REL="bin/konsole"
if (($# > 0)) && [[ "$1" != -* ]]; then
    APP_REL="$1"
    shift
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

if ! "${RUNTIME}" image exists "${IMAGE_NAME}" >/dev/null 2>&1; then
    "${RUNTIME}" build \
        --pull=always \
        -f "${SCRIPT_DIR}/Containerfile.fedora41" \
        -t "${IMAGE_NAME}" \
        "${SCRIPT_DIR}"
fi

RUN_ARGS=(
    --rm
    "${USER_ARGS[@]}"
    -e HOME=/tmp
    -v "${REPO_ROOT}:/src"
    -w /src
)

if [[ -n "${DISPLAY:-}" ]]; then
    RUN_ARGS+=(-e DISPLAY="${DISPLAY}")
fi

if [[ -d /tmp/.X11-unix ]]; then
    RUN_ARGS+=(-v /tmp/.X11-unix:/tmp/.X11-unix)
fi

if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]]; then
    RUN_ARGS+=(
        -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"
        -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
        -v "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}"
    )
fi

if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    RUN_ARGS+=(-e DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}")
fi

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && -z "${QT_QPA_PLATFORM:-}" ]]; then
    RUN_ARGS+=(-e QT_QPA_PLATFORM=minimal)
fi

"${RUNTIME}" run \
    "${RUN_ARGS[@]}" \
    "${IMAGE_NAME}" \
    "/src/${BUILD_DIR_REL}/${APP_REL}" \
    "$@"
