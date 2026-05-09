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

# Patch (Step 3): peel_command_wrappers function + normalize_command call site.
# Strips leading time/nice/env/command/exec/ionice/taskset wrappers so the
# inner command is what gets matched against allow patterns. The wrappers
# themselves contribute no privileges; the inner command is the security-
# relevant part. sudo/doas are intentionally NOT peeled (privilege escalation
# should always surface to the user). command -v / -V are info-only and
# stay matched via Bash(command -v *) directly without peeling.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# --- Patch 1: insert peel_command_wrappers above the sentinel ---
fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''def peel_command_wrappers(cmd):
    """Strip leading command-wrapper invocations and return the inner command.

    Wrappers handled: time, nice, ionice, taskset, env (binary form, not
    KEY=VAL prefix — that's strip_env_vars' job), exec, command. Each runs
    another command but contributes no privileges of its own, so the inner
    command is the security-relevant part to match against allow patterns.

    Recursive (handles `time nice CMD`) with a 16-level bound against
    pathological input. On normal exit (peel chain ends because the next
    token isn't a wrapper, or the wrapper has no inner command) returns
    the peeled-so-far cmd. On bound exhaustion (17+ levels of wrappers)
    returns the *original* cmd unchanged so the chain falls through to
    native prompt — refusing to auto-allow pathologically nested input.

    Special cases (do NOT peel):
      - sudo / doas — privilege escalation; always prompt
      - command -v / command -V / command --help — info-only invocations
        that allow-match Bash(command -v *) directly; peeling would yield
        an invalid `-v jq` command.
    """
    WRAPPER_NAMES = {"time", "nice", "ionice", "taskset", "env", "exec", "command"}
    VALUE_FLAGS = {
        "nice":    {"-n"},
        "ionice":  {"-c", "-n", "-p", "-P"},
        "env":     {"-u", "-C", "-S"},
        "exec":    {"-a"},
        "taskset": {"-c", "-p"},
    }

    original = cmd
    for _ in range(16):
        toks = cmd.strip().split()
        if not toks or toks[0] not in WRAPPER_NAMES:
            return cmd
        first = toks[0]

        if first == "command" and len(toks) >= 2 and toks[1] in ("-v", "-V", "--help"):
            return cmd

        i = 1
        vflags = VALUE_FLAGS.get(first, set())
        while i < len(toks) and toks[i].startswith("-"):
            tok = toks[i]
            if tok.startswith("--") and "=" in tok:
                i += 1
                continue
            if tok in vflags and i + 1 < len(toks):
                i += 2
                continue
            if first == "nice" and re.match(r"^-\\d+$", tok):
                i += 1
                continue
            if tok == "--":
                i += 1
                break
            i += 1

        # taskset MASK positional: hex (0x3, 0xff), int (0, 42), or
        # comma/dash list (0,1,2; 0-3; 1-3,5). Tightened to avoid matching
        # bare hex-like words (cafe, dad) that aren't masks.
        if first == "taskset" and i < len(toks) and re.match(r"^(0x[0-9a-fA-F]+|\\d+([-,]\\d+)*)$", toks[i]):
            i += 1

        if i >= len(toks):
            return cmd

        cmd = " ".join(toks[i:])

    return original


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 3 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 3 fn patch did not apply to {path}")
src = new_src

# --- Patch 2: wire peel into normalize_command ---
# Re-call strip_env_vars after peel so `env KEY=VAL CMD` (where strip_env_vars
# initially saw `env` as the leading word) gets its newly-exposed KEY=VAL
# stripped post-peel.
call_old = "    # Collapse multiple spaces\n    cmd = re.sub(r'\\s+', ' ', cmd)"
call_new = "    cmd = peel_command_wrappers(cmd)\n    cmd = strip_env_vars(cmd)\n    # Collapse multiple spaces\n    cmd = re.sub(r'\\s+', ' ', cmd)"

if call_old not in src:
    sys.exit(f"smart-approve Step 3 call-site patch: normalize_command anchor not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 3 call-site patch did not apply to {path}")
src = new_src

with open(path, "w") as f:
    f.write(src)
PY

chmod +x "$TMP"
mv "$TMP" "$HOOK"

echo "Installed smart_approve.py @ ${SHA} -> ${HOOK}"
