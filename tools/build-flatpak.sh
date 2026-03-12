#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MANIFEST="${MANIFEST:-${REPO_ROOT}/org.kde.konsole.stable.flatpak.json}"
BUILD_DIR_REL="${1:-flatpak-build}"
REPO_DIR_REL="${2:-flatpak-repo}"
BUNDLE_PATH="${3:-${REPO_ROOT}/konsole-24.12.flatpak}"

RUNTIME_VERSION="${FLATPAK_KDE_RUNTIME_VERSION:-6.9}"
APP_ID="${FLATPAK_APP_ID:-org.kde.konsole}"
APP_BRANCH="${FLATPAK_APP_BRANCH:-24.12}"

if [[ "${BUILD_DIR_REL}" = /* || "${REPO_DIR_REL}" = /* ]]; then
    echo "error: build and repo directories must be relative to the repo root" >&2
    exit 1
fi

if ! command -v flatpak-builder >/dev/null 2>&1; then
    echo "error: flatpak-builder is not installed" >&2
    echo "ubuntu/debian: sudo apt-get install -y flatpak-builder" >&2
    exit 1
fi

if ! flatpak remotes --user --columns=name 2>/dev/null | rg -qx "flathub"; then
    flatpak remote-add --if-not-exists --user flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
fi

flatpak install --user --noninteractive flathub \
    "org.kde.Platform//${RUNTIME_VERSION}" \
    "org.kde.Sdk//${RUNTIME_VERSION}"

flatpak-builder \
    --user \
    --force-clean \
    --install-deps-from=flathub \
    --repo="${REPO_ROOT}/${REPO_DIR_REL}" \
    "${REPO_ROOT}/${BUILD_DIR_REL}" \
    "${MANIFEST}"

flatpak build-bundle \
    "${REPO_ROOT}/${REPO_DIR_REL}" \
    "${BUNDLE_PATH}" \
    "${APP_ID}" \
    "${APP_BRANCH}"

echo "Flatpak repo: ${REPO_ROOT}/${REPO_DIR_REL}"
echo "Flatpak bundle: ${BUNDLE_PATH}"
