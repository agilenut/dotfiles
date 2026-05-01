#!/bin/sh
# Install liberzon/claude-hooks smart_approve.py at a pinned SHA, with our
# bare-command parser fix applied. Re-runs whenever this script's content
# changes (chezmoi run_onchange semantics) — bumping the SHA below or editing
# the embedded patch triggers reinstall.
#
# Upstream: https://github.com/liberzon/claude-hooks
# License: MIT

set -eu

SHA="db5713da06d31e74f48923873abd0d9ce325679d" # liberzon/claude-hooks@main, 2026-03-21
URL="https://raw.githubusercontent.com/liberzon/claude-hooks/${SHA}/smart_approve.py"
HOOK_DIR="$HOME/.claude/hooks"
HOOK="$HOOK_DIR/smart_approve.py"

mkdir -p "$HOOK_DIR"

# Same-filesystem temp file so the final mv is an atomic rename. mktemp
# defaulted to $TMPDIR (often a different filesystem) which made mv a
# non-atomic copy+unlink — interrupt mid-copy = half-written hook on disk.
TMP="$(mktemp "$HOOK_DIR/.smart_approve.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

curl -fsSL -o "$TMP" "$URL"

# Patch parse_bash_patterns so "Bash(prefix *)" form (space-asterisk suffix,
# what users actually write in settings.json) matches bare commands too —
# fnmatch("git status", "git status *") returns False because the pattern
# requires a literal space + something after it. Without this patch, bare
# `git status` inside a chain wouldn't match `Bash(git status *)`.
#
# Done in Python (string replace) rather than `patch` so the change survives
# upstream line-number drift; if the function body refactors significantly,
# the assert below fails loudly and the install aborts (review + bump SHA).
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

old = (
    '        if colon_idx == -1:\n'
    '            # Pattern like "Bash(something)" with no colon — treat as exact prefix\n'
    '            result.append((inner, inner))'
)
new = (
    '        if colon_idx == -1:\n'
    '            # PATCHED (dotfiles fork): also match "Bash(prefix *)" form so\n'
    '            # bare commands ("git status" with no args) match patterns\n'
    '            # written as "Bash(git status *)".\n'
    '            if inner.endswith(" *"):\n'
    '                bare = inner[:-2].rstrip()\n'
    '                result.append((bare, inner))\n'
    '            else:\n'
    '                result.append((inner, inner))'
)
if old not in src:
    sys.exit(f"smart-approve patch target not found in {path} — upstream may have refactored parse_bash_patterns; review the SHA pin")
with open(path, "w") as f:
    f.write(src.replace(old, new))
PY

chmod +x "$TMP"
mv "$TMP" "$HOOK"

echo "Installed smart_approve.py @ ${SHA} -> ${HOOK}" >&2
