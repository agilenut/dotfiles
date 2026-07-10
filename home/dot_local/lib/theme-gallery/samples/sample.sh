#!/usr/bin/env bash
# Palette sample: shell — comments, strings, vars, keywords, numbers.
set -euo pipefail

readonly MAX_RETRIES=3
greeting="hello\tworld" # escape inside double quotes

retry() {
  local -i attempt=0
  while ((attempt < MAX_RETRIES)); do
    if "$@"; then
      return 0
    fi
    ((attempt += 1))
    printf 'retry %d of %d\n' "$attempt" "$MAX_RETRIES" >&2
  done
  return 1
}

retry curl -fsSL "https://example.com/${greeting}" || echo "gave up"
