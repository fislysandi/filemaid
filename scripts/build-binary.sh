#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${1:-${REPO_ROOT}/build}"
OUT_BIN="${2:-${OUT_DIR}/filemaid}"

mkdir -p "${OUT_DIR}"

sbcl --non-interactive \
  --eval '(require :asdf)' \
  --eval "(asdf:load-asd #P\"${REPO_ROOT}/filemaid.asd\")" \
  --eval '(asdf:load-system "filemaid")' \
  --eval "(sb-ext:save-lisp-and-die #P\"${OUT_BIN}\" :toplevel #'filemaid:main :executable t :compression t)"

chmod +x "${OUT_BIN}"
printf 'Built binary: %s\n' "${OUT_BIN}"
