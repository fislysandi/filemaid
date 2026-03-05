#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${1:-${REPO_ROOT}/build/docs}"

mkdir -p "${OUT_DIR}"
cp "${REPO_ROOT}/README.md" "${OUT_DIR}/README.md"
cp "${REPO_ROOT}/CONTEXT7.md" "${OUT_DIR}/CONTEXT7.md"

if [ -d "${REPO_ROOT}/.opencode/context/filemaid" ]; then
  rm -rf "${OUT_DIR}/context"
  mkdir -p "${OUT_DIR}/context"
  cp -r "${REPO_ROOT}/.opencode/context/filemaid" "${OUT_DIR}/context/filemaid"
fi

printf 'Docs bundle written to: %s\n' "${OUT_DIR}"
