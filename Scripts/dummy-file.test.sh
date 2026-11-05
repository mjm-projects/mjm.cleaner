#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
DUMMY_FILE="$SCRIPT_DIR/../dummy.txt"

[[ -f "$DUMMY_FILE" ]] || { printf 'FAIL: dummy.txt missing\n' >&2; exit 1; }
[[ "$(<"$DUMMY_FILE")" == "I'm Dummy!" ]] || {
  printf 'FAIL: dummy.txt has unexpected contents\n' >&2
  exit 1
}

printf 'PASS: dummy.txt exists with expected contents\n'
