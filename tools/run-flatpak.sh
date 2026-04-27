#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_ID="${FLATPAK_APP_ID:-org.kde.konsole}"
APP_BRANCH="${FLATPAK_APP_BRANCH:-24.12}"
BUNDLE_PATH="${FLATPAK_BUNDLE_PATH:-${REPO_ROOT}/konsole-24.12.flatpak}"

if ! command -v flatpak >/dev/null 2>&1; then
    echo "error: flatpak is not installed" >&2
    exit 1
fi

if ! flatpak info --user "${APP_ID}//${APP_BRANCH}" >/dev/null 2>&1; then
    if [[ ! -f "${BUNDLE_PATH}" ]]; then
        echo "error: ${APP_ID}//${APP_BRANCH} is not installed and bundle was not found at ${BUNDLE_PATH}" >&2
        echo "build it first with ./tools/build-flatpak.sh or install the bundle manually" >&2
        exit 1
    fi

    flatpak install --user --noninteractive "${BUNDLE_PATH}"
fi

exec flatpak run --user "${APP_ID}//${APP_BRANCH}" "$@"
