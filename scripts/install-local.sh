#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
TARGET_DIR="${HOME}/.local/bin"
TARGET_BIN="${TARGET_DIR}/filemaid"

mkdir -p "${TARGET_DIR}"
"${SCRIPT_DIR}/build-binary.sh" "${BUILD_DIR}" "${BUILD_DIR}/filemaid"
cp "${BUILD_DIR}/filemaid" "${TARGET_BIN}"
chmod +x "${TARGET_BIN}"

printf 'Installed: %s\n' "${TARGET_BIN}"
printf 'Run with: filemaid --help\n'
