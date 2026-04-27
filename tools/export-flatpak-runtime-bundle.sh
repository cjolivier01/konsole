#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUNTIME_ID="${FLATPAK_RUNTIME_ID:-org.kde.Platform}"
RUNTIME_VERSION="${FLATPAK_KDE_RUNTIME_VERSION:-6.9}"
BUNDLE_PATH="${1:-${REPO_ROOT}/${RUNTIME_ID}-${RUNTIME_VERSION}.flatpak}"
USER_REPO="${HOME}/.local/share/flatpak/repo"

if ! command -v flatpak >/dev/null 2>&1; then
    echo "error: flatpak is not installed" >&2
    exit 1
fi

if ! flatpak remotes --user --columns=name 2>/dev/null | rg -qx "flathub"; then
    flatpak remote-add --if-not-exists --user flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
fi

if ! flatpak info --user "${RUNTIME_ID}//${RUNTIME_VERSION}" >/dev/null 2>&1; then
    flatpak install --user --noninteractive flathub "${RUNTIME_ID}//${RUNTIME_VERSION}"
fi

flatpak build-bundle \
    "${USER_REPO}" \
    "${BUNDLE_PATH}" \
    "${RUNTIME_ID}" \
    "${RUNTIME_VERSION}" \
    --runtime

echo "Runtime bundle: ${BUNDLE_PATH}"
