#!/usr/bin/env bash
# Install liberzon/claude-hooks smart_approve.py at a pinned SHA, with our
# bare-command parser fix applied. Re-runs whenever this script's content
# changes (chezmoi run_onchange semantics) — bumping the SHA below or editing
# the embedded patch triggers reinstall.
#
# Upstream: https://github.com/liberzon/claude-hooks
# License: MIT

set -euo pipefail

SHA="db5713da06d31e74f48923873abd0d9ce325679d" # liberzon/claude-hooks@main, 2026-03-21
# recompute EXPECTED_SHA256 when bumping SHA: curl --proto '=https' --tlsv1.2 -fsSL "$URL" | shasum -a 256
EXPECTED_SHA256="c98b27a11cb6fec1b83075d8cf43162f799b573bc8bf5d537570689e4c1cebc3"
URL="https://raw.githubusercontent.com/liberzon/claude-hooks/${SHA}/smart_approve.py"
HOOK_DIR="$HOME/.claude/hooks"
HOOK="$HOOK_DIR/smart_approve.py"

mkdir -p "$HOOK_DIR"

# Same-filesystem temp file so the final mv is an atomic rename. mktemp
# defaulted to $TMPDIR (often a different filesystem) which made mv a
# non-atomic copy+unlink — interrupt mid-copy = half-written hook on disk.
TMP="$(mktemp "$HOOK_DIR/.smart_approve.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

# --proto '=https' --tlsv1.2 belt-and-suspenders against TLS downgrade or
# protocol smuggling on the bootstrap fetch (HTTPS-only, TLS 1.2+).
curl --proto '=https' --tlsv1.2 -fsSL -o "$TMP" "$URL"

# Verify SHA-256 of the downloaded file before patching. Pinned commit SHA
# protects against tag-rewrite; this protects against a compromised CDN
# response or a silent re-point of the pin. Bump EXPECTED_SHA256 alongside
# SHA when intentionally upgrading.
#
# `shasum` is BSD/macOS canonical; some minimal Linux images only ship
# `sha256sum` (GNU coreutils, no Perl dep). Probe both. Stdout is left
# visible so the "FAILED" message is loud on mismatch.
if command -v shasum >/dev/null 2>&1; then
  echo "${EXPECTED_SHA256}  ${TMP}" | shasum -a 256 -c -
else
  echo "${EXPECTED_SHA256}  ${TMP}" | sha256sum -c -
fi

# Patch parse_bash_patterns so "Bash(prefix *)" form (space-asterisk suffix,
# what users actually write in settings.json) matches bare commands too —
# fnmatch("git status", "git status *") returns False because the pattern
# requires a literal space + something after it. Without this patch, bare
# `git status` inside a chain wouldn't match `Bash(git status *)`.
#
# IMPORTANT: this only fires for non-wildcard prefixes (uses string equality
# on the bare prefix). Patterns with interior wildcards like
# `Bash(git -C * status *)` are intentionally NOT loosened — the hook stays
# strict, mirroring Claude's native matcher. To allow bare forms of
# interior-wildcard patterns, add an explicit no-trailing-* entry to
# settings.json (e.g. `Bash(git -C * status)`). See project CLAUDE.md
# "Gotchas" for the full rule.
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

# Patch (Step 2): _emit_verbose_to_log_file + sentinel.
# Smoke test 2026-05-09 confirmed Claude Code does not surface PreToolUse hook
# stderr to the assistant tool-result context, so verbose lines instead append
# to ~/.claude/logs/smart_approve.log when SMART_APPROVE_VERBOSE=1. Registered
# via atexit so it fires regardless of how main() exits.
#
# The SMART_APPROVE_DOTFILES_PATCH_BLOCK sentinel comment is a stable anchor
# for Steps 3+ — each subsequent step's patch matches the sentinel and inserts
# its function block immediately after it, keeping per-step patches independent
# (no Step-N's `old` string referencing Step-(N-1)'s text).
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# Defense-in-depth: bail if upstream already emits the sentinel string.
# Steps 3+ rely on this anchor being unique to the dotfiles fork.
if "SMART_APPROVE_DOTFILES_PATCH_BLOCK" in src:
    sys.exit(f"smart-approve verbose patch: upstream {path} already contains the sentinel — review the SHA pin")

old = "def main():"
new = '''def _emit_verbose_to_log_file():
    """Append collected verbose log lines to ~/.claude/logs/smart_approve.log.

    Registered via atexit so it fires regardless of how the hook exits
    (sys.exit, natural return, exception). No-op when SMART_APPROVE_VERBOSE
    is unset or no log lines were collected. Best-effort: if the log can't
    be written (read-only fs, permission denied), silently swallow — the
    hook's primary job is the permission decision, not diagnostics.

    Hardened writes:
      - O_NOFOLLOW + 0o600 mode prevent symlink redirection and umask leaks.
      - Each line is scrubbed for non-printable bytes (CR, ESC, etc.) so a
        crafted command can't inject terminal escapes that spoof entries
        when the user later cat/tail/greps the log.
    """
    if not _verbose_enabled() or not _log_lines:
        return
    import datetime
    log_path = os.path.expanduser("~/.claude/logs/smart_approve.log")
    log_dir = os.path.dirname(log_path)
    try:
        os.makedirs(log_dir, exist_ok=True)
        ts = datetime.datetime.now().isoformat(timespec="seconds")
        flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW
        fd = os.open(log_path, flags, 0o600)
        with os.fdopen(fd, "a", buffering=1) as f:
            f.write(f"--- {ts} ---\\n")
            for line in _log_lines:
                scrubbed = "".join(c if c.isprintable() else f"\\\\x{ord(c):02x}" for c in line)
                f.write(f"{scrubbed}\\n")
        _log_lines.clear()
    except OSError:
        pass


import atexit
atexit.register(_emit_verbose_to_log_file)


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
# Anchor for dotfiles-fork patches (Steps 3+). Each step's patch matches the
# sentinel line above and inserts its function block immediately after it.
# Do not remove without auditing the install script.

def main():'''

if old not in src:
    sys.exit(f"smart-approve verbose patch target 'def main():' not found in {path} — upstream may have refactored; review the SHA pin")
new_src = src.replace(old, new, 1)
if new_src == src:
    sys.exit(f"smart-approve verbose patch did not apply to {path}")
with open(path, "w") as f:
    f.write(new_src)
PY

chmod +x "$TMP"
mv "$TMP" "$HOOK"

echo "Installed smart_approve.py @ ${SHA} -> ${HOOK}"
