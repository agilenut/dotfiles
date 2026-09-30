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
# on the bare prefix). Patterns with interior wildcards are intentionally NOT
# loosened — the hook stays strict, mirroring Claude Code's own matcher.
# Interior wildcards are the shape to avoid entirely: Step 9 peels git's global
# options so `git -C <path> <subcmd>` matches the plain `Bash(git <subcmd> *)`
# rule, which is why no `-C` variant of any rule needs to exist.
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

# Patch (Step 4): peel_xargs function + add to normalize_command flow.
# Strips leading `xargs [FLAGS] CMD ...` so the inner command is what gets
# matched against allow patterns. Initial-args after CMD pass through as
# CMD's positional args (semantically same as `CMD initial-args`).
#
# Refuses to peel when:
#   - the inner command is an unsafe executor (sh -c, bash -c, python -c,
#     awk, etc.) — those still prompt because the executor is what's checked
#   - an unknown long flag is encountered — better to fall through than
#     guess flag-vs-value semantics on novel/typo flags
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# --- Patch 1: insert peel_xargs above the sentinel ---
fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''def peel_xargs(cmd):
    """Strip leading `xargs [FLAGS] CMD [INITIAL-ARGS]` and return the inner CMD.

    xargs runs CMD with stdin args, so CMD is the security-relevant part to
    match against allow patterns. The initial-args after CMD are passed to
    CMD as positional args, semantically identical to `CMD initial-args`.

    Returns the original cmd unchanged when:
      - first token isn't `xargs`
      - the inner command is an unsafe executor (sh, bash, zsh, dash, ksh,
        python, python3, node, perl, ruby, awk) — peeling would let those
        auto-allow despite still being a hidden-executor escape hatch
      - an unknown long flag is encountered (--frobnicate) — refuses to
        guess flag-vs-value semantics
      - xargs has no inner command (just `xargs --help`)
    """
    BOOLEAN_SHORT = {"-0", "-r", "-t", "-p", "-x"}
    VALUE_SHORT_PREFIXES = ("-n", "-L", "-P", "-I", "-J", "-d", "-E", "-a", "-s")
    BOOLEAN_LONG = {"--null", "--no-run-if-empty", "--verbose", "--interactive",
                    "--show-limits", "--no-quote", "--exit", "--help", "--version"}
    VALUE_LONG = {"--max-args", "--max-procs", "--max-chars", "--max-lines",
                  "--replace", "--delimiter", "--eof", "--arg-file",
                  "--process-slot-var"}
    # Inner-command interpreters that take their program as an arg — peeling
    # would let `xargs <interpreter> -c '...'` auto-allow despite still being
    # the same hidden-executor escape hatch as bare `<interpreter> -c '...'`.
    # Match against the basename with any trailing version digits/dots
    # stripped, so `/bin/sh`, `python3.11`, `lua5.4`, `pwsh.exe` all hit.
    UNSAFE_INNER = {"sh", "bash", "zsh", "dash", "ksh", "fish", "nu",
                    "python", "node", "perl", "ruby", "awk",
                    "osascript", "pwsh", "php", "lua", "tclsh"}

    toks = cmd.strip().split()
    if not toks or toks[0] != "xargs":
        return cmd

    original = cmd
    i = 1
    while i < len(toks) and toks[i].startswith("-"):
        tok = toks[i]
        if tok == "--":
            i += 1
            break
        if tok.startswith("--"):
            if "=" in tok:
                key = tok.split("=", 1)[0]
                if key in VALUE_LONG or key in BOOLEAN_LONG:
                    i += 1
                    continue
                return original
            if tok in BOOLEAN_LONG:
                i += 1
                continue
            if tok in VALUE_LONG and i + 1 < len(toks):
                i += 2
                continue
            return original
        if tok in BOOLEAN_SHORT:
            i += 1
            continue
        consumed = False
        for prefix in VALUE_SHORT_PREFIXES:
            if tok == prefix:
                if i + 1 < len(toks):
                    i += 2
                    consumed = True
                    break
                return original
            if tok.startswith(prefix) and len(tok) > len(prefix):
                i += 1
                consumed = True
                break
        if consumed:
            continue
        # Unknown short flag — bail rather than guess. If the flag actually
        # took a value (-Z VAL CMD), assuming boolean would let VAL slide in
        # as the inner command. Safer to fall through to native prompt.
        return original

    if i >= len(toks):
        return original

    # Normalize the inner token: strip path (basename) and trailing version
    # digits/dots so `/bin/sh`, `python3.11`, `lua5.4` all match the
    # canonical interpreter name in UNSAFE_INNER.
    inner_base = os.path.basename(toks[i])
    m = re.match(r"^([a-zA-Z]+)[\\d.]*$", inner_base)
    inner_normalized = m.group(1) if m else inner_base
    if inner_normalized in UNSAFE_INNER or inner_base in UNSAFE_INNER:
        return original

    return " ".join(toks[i:])


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 4 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 4 fn patch did not apply to {path}")
src = new_src

# --- Patch 2: add peel_xargs call to normalize_command flow ---
# Sequential after peel_command_wrappers: `time xargs CMD` → peel `time` →
# `xargs CMD` → peel `xargs` → `CMD`. The reverse order (`xargs time CMD`)
# is rare and falls through to native prompt — acceptable trade-off vs.
# adding a fixed-point loop.
call_old = "    cmd = peel_command_wrappers(cmd)\n    cmd = strip_env_vars(cmd)"
call_new = "    cmd = peel_command_wrappers(cmd)\n    cmd = peel_xargs(cmd)\n    cmd = strip_env_vars(cmd)"

if call_old not in src:
    sys.exit(f"smart-approve Step 4 call-site patch: anchor not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 4 call-site patch did not apply to {path}")
src = new_src

with open(path, "w") as f:
    f.write(src)
PY

# Patch (Step 5): is_awk_program_safe + command_passes_allow + decide() wire-in.
# Lets safe awk programs auto-allow without putting Bash(awk *) on the
# allow list (which would also pass dangerous shapes like
# `awk 'BEGIN{system("rm")}'`). Safety scan:
#   - Reject -f / -i / -e / -E and their long-form equivalents (uninspectable
#     external program, inplace rewrite, alternate program location, gawk
#     fallback program loader)
#   - Reject any unknown flag (better to fall through than guess flag-vs-value)
#   - Scan program text for system( / getline / print(f) > / print(f) | /
#     @load / @include / backtick command-substitution
# False-positive case: a program containing one of those tokens as a string
# literal substring (e.g. `awk '{print "system( is text"}'`) gets rejected.
# Acceptable cost — falls through to native prompt rather than auto-allowing
# something whose intent we can't statically determine.
#
# decide() call-site: replace the allow-loop's command_matches_pattern with
# command_passes_allow. The DENY loop stays on command_matches_pattern —
# awk safety doesn't influence deny matching. Asymmetry is intentional: an
# unsafe awk program shouldn't be *denied*, it should fall through.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# --- Patch 1: insert is_awk_program_safe + command_passes_allow above sentinel ---
fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''def is_awk_program_safe(cmd):
    """Heuristic safety check for an `awk` invocation.

    Returns True only if `cmd` is an `awk` invocation AND:
      - no dangerous flags are present (-f / --file=, -i / --include=,
        -e / --source=, -E / --exec=, or any unknown flag)
      - the program text scans clean of shell-out, file-write, and
        external-load primitives

    False positives are accepted: a program containing one of the
    dangerous tokens as a literal-string substring (e.g.,
    `awk 'BEGIN{print "system( is text"}'`) will be rejected. Falls
    through to native prompt rather than auto-allowing programs whose
    intent we can\\'t statically verify — safer direction.
    """
    import shlex
    BOOLEAN_FLAGS = {"--lint", "--posix", "--traditional", "--csv",
                     "--non-decimal-data", "--re-interval",
                     "--gen-pot", "--no-optimize", "--bignum",
                     "--profile", "--debug", "--copyright",
                     "--help", "--version"}
    REJECT_SHORT = {"-f", "-i", "-e", "-E"}
    REJECT_LONG_PREFIXES = ("--file", "--include", "--source", "--exec")
    VALUE_SHORT_PREFIXES = ("-F", "-v")

    # shlex.split (not str.split) so the quoted awk program is one token
    # rather than being whitespace-split into pieces. Critical: a naive
    # split on `awk \\'{print > "/tmp/x"}\\' file` would scatter the
    # `print >` across tokens and miss the dangerous-token check.
    try:
        toks = shlex.split(cmd)
    except ValueError:
        return False  # malformed quoting — play it safe
    if not toks or toks[0] != "awk":
        return False

    i = 1
    while i < len(toks):
        tok = toks[i]
        if not tok.startswith("-"):
            break
        if tok == "--":
            i += 1
            break
        if tok in REJECT_SHORT:
            return False
        if any(tok == p or tok.startswith(p + "=") for p in REJECT_LONG_PREFIXES):
            return False
        if tok.startswith("--"):
            if "=" in tok:
                key = tok.split("=", 1)[0]
                if key in BOOLEAN_FLAGS:
                    i += 1
                    continue
                return False
            if tok in BOOLEAN_FLAGS:
                i += 1
                continue
            return False
        # Short value-flag: separate (-F SEP) or attached (-F: / -vx=1).
        consumed = False
        for prefix in VALUE_SHORT_PREFIXES:
            if tok == prefix:
                if i + 1 < len(toks):
                    i += 2
                    consumed = True
                    break
                return False
            if tok.startswith(prefix) and len(tok) > len(prefix):
                i += 1
                consumed = True
                break
        if consumed:
            continue
        return False  # unknown short flag — bail

    if i >= len(toks):
        return False  # awk with no program text

    program = toks[i]

    # Regex-based detection (rather than substring) so `print $0 > "/tmp/x"`
    # and `print "data" |& "sh"` (data between print and the redirect/pipe
    # operator) get caught — substring matchers required adjacency.
    # The @<ident>( pattern catches gawk indirect calls like
    # `awk 'BEGIN{a="syst"; @a("rm")}'` that build the function name at
    # runtime and bypass a literal `system(` check.
    DANGEROUS_PATTERNS = (
        re.compile(r"\\bsystem\\s*\\("),
        re.compile(r"\\bgetline\\b"),
        re.compile(r"\\bprintf?\\b[^;{}\\n]*[>|]"),
        re.compile(r"@(load|include|[A-Za-z_]+\\s*\\()"),
    )
    for pattern in DANGEROUS_PATTERNS:
        if pattern.search(program):
            return False
    if "`" in program:
        return False

    return True


def command_passes_allow(cmd, allow_patterns):
    """Allow-gate check with awk-safety special case.

    Used in place of command_matches_pattern in the allow loop of decide().
    The deny loop continues to use command_matches_pattern directly — awk
    safety only widens what allows, never what denies.
    """
    if command_matches_pattern(cmd, allow_patterns):
        return True
    if cmd.startswith("awk ") and is_awk_program_safe(cmd):
        return True
    return False


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 5 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 5 fn patch did not apply to {path}")
src = new_src

# --- Patch 2: wire command_passes_allow into decide()'s allow loop ---
call_old = "        if not command_matches_pattern(cmd, allow_patterns):"
call_new = "        if not command_passes_allow(cmd, allow_patterns):"

if call_old not in src:
    sys.exit(f"smart-approve Step 5 call-site patch: decide() allow-loop anchor not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 5 call-site patch did not apply to {path}")
src = new_src

with open(path, "w") as f:
    f.write(src)
PY

# Patch (Step 6): _log_decision audit log + main() call-site.
# Always-on (no SMART_APPROVE_VERBOSE gate). Logs every allow/deny decision
# to ~/.claude/logs/smart_approve_decisions.log so the user can review which
# commands the hook auto-decided over a trial period — particularly useful
# for evaluating whether Step 5 (awk safety) and Step 4 (xargs peel)
# heuristics fire often enough to justify the complexity.
#
# Fallthroughs are NOT logged — they're the majority of invocations on
# read-heavy workloads and would dominate the log file.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

# --- Patch 1: insert _log_decision above the sentinel ---
fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''def _log_decision(decision, command):
    """Append a single line to ~/.claude/logs/smart_approve_decisions.log per decision.

    Always-on (not gated by SMART_APPROVE_VERBOSE) so the trial-period audit
    works without env-var setup. Same hardening as _emit_verbose_to_log_file:
    O_NOFOLLOW + 0o600 + control-byte scrub. Best-effort: catches all
    exceptions so the hook's primary job (the permission decision) isn't
    affected by log-write failures or unexpected input. The function is
    called BEFORE the JSON decision is emitted to stdout — letting an
    exception escape would suppress the decision and silently fall through
    to native prompt, which for a deny decision would be a soft bypass.
    """
    if not decision:
        return
    try:
        import datetime
        # SMART_APPROVE_DECISIONS_LOG_PATH overrides the default path.
        # Tests redirect to /dev/null (or a temp file) to prevent test runs
        # from polluting the user trial's audit log.
        log_path = os.environ.get(
            "SMART_APPROVE_DECISIONS_LOG_PATH",
            os.path.expanduser("~/.claude/logs/smart_approve_decisions.log"),
        )
        log_dir = os.path.dirname(log_path)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        ts = datetime.datetime.now().isoformat(timespec="seconds")
        flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW
        fd = os.open(log_path, flags, 0o600)
        with os.fdopen(fd, "a", buffering=1) as f:
            scrubbed = "".join(c if c.isprintable() else f"\\\\x{ord(c):02x}" for c in command)[:300]
            f.write(f"{ts}\\t{str(decision).upper()}\\t{scrubbed}\\n")
    except Exception:
        pass


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 6 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 6 fn patch did not apply to {path}")
src = new_src

# --- Patch 2: call _log_decision inside main()'s decision-emit block ---
call_old = "    if decision is not None:"
call_new = "    _log_decision(decision, command)\n    if decision is not None:"

if call_old not in src:
    sys.exit(f"smart-approve Step 6 call-site patch: main() decision-emit anchor not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 6 call-site patch did not apply to {path}")
src = new_src

with open(path, "w") as f:
    f.write(src)
PY

# Patch (Step 8): refuse to strip execution-influencing env assignments.
# strip_env_vars removes any leading NAME=VALUE before matching, which is what
# lets `S=/tmp foo` match Bash(foo *). It also made every deny rule blind to
# `GIT_CONFIG_KEY_0=core.pager GIT_CONFIG_VALUE_0='sh -c evil' git log`, which
# normalized to a bare `git log`. Assignments that change what a program
# executes are left in place instead, so nothing matches and the command falls
# through to the classifier. Measured against 21 days of history: 244 allowed
# commands carry an env prefix and none of them names a variable on this list.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''# Environment variables that change which program runs, or what it runs on the
# way. Prefix entries match any variable starting with them.
UNSAFE_ENV_EXACT = frozenset({
    "BASH_ENV", "ENV", "SHELLOPTS", "PS4", "IFS", "PATH", "SHELL", "CDPATH",
    "PYTHONPATH", "PYTHONSTARTUP", "PYTHONHOME", "NODE_OPTIONS",
    "PERL5OPT", "PERL5LIB", "RUBYOPT", "RUBYLIB",
    "EDITOR", "VISUAL", "PAGER", "LESSOPEN", "MAKEFLAGS",
    # Relocating a tool's config directory is as good as editing its config:
    # a planted .gitconfig supplies core.pager, a planted gh config a pager.
    "HOME", "XDG_CONFIG_HOME", "GH_CONFIG_DIR", "GH_PAGER",
    "DOTNET_STARTUP_HOOKS", "DOCKER_HOST",
})
UNSAFE_ENV_PREFIXES = ("GIT_", "LD_", "DYLD_", "NPM_CONFIG_", "npm_config_")


def is_unsafe_env_name(name):
    """True when an assignment to this name can redirect execution."""
    return name in UNSAFE_ENV_EXACT or name.startswith(UNSAFE_ENV_PREFIXES)


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 8 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 8 fn patch did not apply to {path}")
src = new_src

strip_old = """    while True:
        m = re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', cmd)
        if not m:
            break"""
strip_new = """    while True:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=', cmd)
        if not m:
            break
        # PATCHED (dotfiles fork): stop at an assignment that can redirect
        # execution, leaving it in the command so no allow pattern matches it.
        if is_unsafe_env_name(m.group(1)):
            break"""

if strip_old not in src:
    sys.exit(f"smart-approve Step 8 strip patch: strip_env_vars body not found in {path}")
new_src = src.replace(strip_old, strip_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 8 strip patch did not apply to {path}")

with open(path, "w") as f:
    f.write(new_src)
PY

# Patch (Step 9): peel git global options so the subcommand sits next to `git`.
# Claude Code's own matcher extracts the subcommand after global options
# (2.1.0). The hook never did, which is the only reason a `-C` copy of every
# git rule had to exist. Those copies were also the absorption vector: the
# interior wildcard in `Bash(git -C * add *)` spans a whole different
# subcommand, so `git -C /r rebase -x <cmd> add HEAD~2` matched it.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''# Leading `git` options that conceal the subcommand while conferring nothing.
# -c, --config-env, --exec-path, --git-dir, --work-tree, --upload-pack and
# --receive-pack are deliberately absent: each can redirect what git executes,
# and peeling one would hide it from the deny rules that exist to catch it.
_GIT_PEELABLE_OPT = re.compile(
    r'^git\\s+(?:'
    r'-C\\s*(?:"[^"]*"|\\'[^\\']*\\'|\\S+)'
    r'|--no-pager'
    r'|--literal-pathspecs'
    r'|-P'
    r')\\s+'
)


def peel_git_global_opts(cmd):
    """Rewrite `git -C <path> <subcmd> ...` as `git <subcmd> ...` for matching.

    Bounded at 8 peels. On exhaustion the ORIGINAL command is returned, as
    peel_command_wrappers and peel_xargs do, so pathologically nested input is
    never handed to the matcher in a half-peeled form.
    """
    original = cmd
    for _ in range(8):
        if not cmd.startswith("git "):
            return cmd
        m = _GIT_PEELABLE_OPT.match(cmd)
        if not m:
            return cmd
        cmd = "git " + cmd[m.end():]
    return original


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 9 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 9 fn patch did not apply to {path}")
src = new_src

call_old = """    cmd = peel_xargs(cmd)
    cmd = strip_env_vars(cmd)"""
call_new = """    cmd = peel_xargs(cmd)
    cmd = strip_env_vars(cmd)
    cmd = peel_git_global_opts(cmd)"""

if call_old not in src:
    sys.exit(f"smart-approve Step 9 call-site patch: normalize_command flow not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 9 call-site patch did not apply to {path}")

with open(path, "w") as f:
    f.write(new_src)
PY

# Patch (Step 10): treat only a trailing ":*" as the legacy prefix separator.
# Upstream splits on the first colon anywhere, so Bash(pnpm test:run *) parsed
# as prefix "pnpm test" with glob "pnpm test run *" and could never match
# `pnpm test:run`. Claude Code splits only on a trailing ":*", so this also
# stops the two matchers disagreeing about script names that contain a colon.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

old = "        colon_idx = inner.find(':')"
new = (
    "        # PATCHED (dotfiles fork): only a trailing ':*' is the legacy\n"
    "        # prefix separator. A colon anywhere else is a literal character\n"
    "        # in a script name, as in Bash(pnpm test:run *).\n"
    "        colon_idx = len(inner) - 2 if inner.endswith(':*') else -1"
)

if old not in src:
    sys.exit(f"smart-approve Step 10 patch: colon split not found in {path}")
new_src = src.replace(old, new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 10 patch did not apply to {path}")

with open(path, "w") as f:
    f.write(new_src)
PY

# Patch (Step 11): refuse redirects into the files that grant permission.
# strip_redirections deletes `> target` before matching, so `printf x >
# ~/.claude/settings.json` matched Bash(printf *) and no deny rule could see
# the target. Anything that can rewrite settings.json or the hook itself can
# grant itself everything, so the target is checked before it is discarded.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''# A redirect whose target is one of these rewrites the permission system
# itself. Matched against the raw command, before redirections are stripped.
# `>|` is included because bash accepts it as a clobbering redirect; the
# chezmoi source spelling is included because writing `home/dot_claude/` and
# running `chezmoi apply` reaches the same files by a second step.
_PERMISSION_FILE_REDIRECT = re.compile(
    r\'(?:>\\||>>?)\\s*[\\\'"]?[^\\s\\\'";&|]*(?:[./]claude/|dot_claude/)\'
    r\'(?:settings\\.json|settings\\.local\\.json|hooks/|CLAUDE\\.md)\'
)


_HEREDOC_BODY = re.compile(
    r"<<-?\\s*[\\\'\\"]?(\\w+)[\\\'\\"]?\\n.*?\\n\\1", re.DOTALL
)


def redirects_into_permission_file(cmd):
    """True when the command writes to a file that decides what is allowed.

    Heredoc bodies are removed first. Without that, any command carrying this
    path as text — documentation about the rule, a patch to the hook, a commit
    message — denies itself, and a hook deny cannot be overridden.
    """
    return bool(_PERMISSION_FILE_REDIRECT.search(_HEREDOC_BODY.sub("", cmd)))


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 11 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 11 fn patch did not apply to {path}")
src = new_src

call_old = """    # Check if ALL match allow"""
call_new = """    # Runs after the deny scan, never before it: an early return here would let
    # a redirect suppress a deny, as in `git -c core.pager=evil log > <a
    # permission file>`. Declines rather than denies, because the scan is a
    # substring match on a command the hook never tokenizes, so it also fires
    # on one that merely quotes such a path, and a hook deny cannot be
    # overridden. Declining stops the automatic yes and lets the classifier
    # read the difference.
    if redirects_into_permission_file(command):
        log("declining to approve: writes to a file that grants permissions")
        return None, None

    # Check if ALL match allow"""

if call_old not in src:
    sys.exit(f"smart-approve Step 11 call-site patch: decide() body not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 11 call-site patch did not apply to {path}")

with open(path, "w") as f:
    f.write(new_src)
PY

# Smoke test before installing. Every patch above adds module-level code
# (re.compile, frozenset), so a bad edit can raise at import. A hook that
# raises prints nothing, and a hook that prints nothing reads as "no opinion"
# — every deny it should have returned is silently lost. Require a known deny
# to come back before the patched file replaces the working one.
# Self-contained: the hook is pointed at a settings file written here, not at
# ~/.claude/settings.json, which may not exist yet on a first apply. The test
# asserts the decision path works, not that any particular policy is installed.
SMOKE_SETTINGS="$(mktemp "$HOOK_DIR/.smoke_settings.XXXXXX")"
trap 'rm -f "$TMP" "$SMOKE_SETTINGS"' EXIT
cat >"$SMOKE_SETTINGS" <<'SMOKEJSON'
{"permissions":{"allow":["Bash(zzzsmoke-ok *)"],"deny":["Bash(zzzsmoke-bad *)"]}}
SMOKEJSON

smoke_decision() {
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" \
    | SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null \
      CLAUDE_SETTINGS_PATH="$SMOKE_SETTINGS" \
      SMART_APPROVE_EXTRA_ALLOW_PATH=/nonexistent \
      python3 "$TMP" 2>&1
}

for smoke_case in "zzzsmoke-bad x:deny" "zzzsmoke-ok x:allow"; do
  smoke_cmd=${smoke_case%:*}
  smoke_want=${smoke_case##*:}
  if ! smoke_out=$(smoke_decision "$smoke_cmd"); then
    echo "smart-approve smoke test: hook exited non-zero on '$smoke_cmd'" >&2
    printf '%s\n' "$smoke_out" >&2
    exit 1
  fi
  case "$smoke_out" in
    *"\"permissionDecision\": \"$smoke_want\""* | *"\"permissionDecision\":\"$smoke_want\""*) ;;
    *)
      echo "smart-approve smoke test: expected $smoke_want for '$smoke_cmd', got:" >&2
      printf '%s\n' "${smoke_out:-<no output>}" >&2
      exit 1
      ;;
  esac
done

# Patch (Step 12): never approve a `gh api` call carrying two method flags.
# `gh` takes the last -X / --method wins, and every gh api allow rule ends in a
# trailing wildcard, so `gh api -X GET <path> -X DELETE` matched the GET rule
# and ran as a DELETE. A deny *glob* for the shape hard-blocks a real command,
# because a nested `$(gh api -X GET ...)` supplying a path value puts two GETs
# in one segment; counting flags outside substitutions has no such false
# positive, which is why this counts rather than matches.
#
# It denies rather than declining to approve. Measured end to end: with a
# decline, the classifier went on to approve `gh api -X GET <path> -X DELETE`,
# and the DELETE was the request actually sent. Zero of 2,033 gh api commands
# across nine months carry a second method flag, so nothing real is lost.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''_GH_METHOD_FLAG = re.compile(r\'(?:^|\\s)(?:-X|--method)(?:[=\\s]|$)\')
_CMD_SUBSTITUTION = re.compile(r\'\\$\\([^()]*\\)\')


def gh_api_method_count(cmd):
    """Count top-level -X / --method flags in a `gh api` command.

    Command substitutions are removed first: a nested `$(gh api -X GET ...)`
    supplying a path value is one call, not a second method on this one.
    """
    if not cmd.startswith("gh api"):
        return 0
    stripped = cmd
    for _ in range(8):
        reduced = _CMD_SUBSTITUTION.sub(" ", stripped)
        if reduced == stripped:
            break
        stripped = reduced
    return len(_GH_METHOD_FLAG.findall(stripped))


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 12 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 12 fn patch did not apply to {path}")
src = new_src

call_old = """    # Check if ALL match allow"""
call_new = """    for cmd in sub_commands:
        if gh_api_method_count(cmd) > 1:
            return "deny", f"'{cmd}' carries two HTTP method flags; gh uses the last"

    # Check if ALL match allow"""

if call_old not in src:
    sys.exit(f"smart-approve Step 12 call-site patch: decide() allow scan not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 12 call-site patch did not apply to {path}")

with open(path, "w") as f:
    f.write(new_src)
PY

# Patch (Step 13): only approve a redirect that lands in the work area.
# strip_redirections deletes `> target` before matching, so every allow-listed
# text tool is also an arbitrary-file-write rule: `echo '[core]' >
# ~/.gitconfig` matches Bash(echo *), and that config sets core.pager, which is
# the execution vector the git deny rules exist to block. Bash(echo *) alone
# decided 22,383 invocations.
#
# Enumerating dangerous targets cannot work; the interesting ones are
# unbounded. This inverts it: a redirect is approved only when the target is
# under the working directory, the scratchpad, a temp root, or /dev. Measured
# over seven months of history, that covers the overwhelming majority of real
# redirects, and what it does not cover is the set worth a second look.
#
# A target the hook cannot resolve (a variable, a substitution) counts as out
# of scope, because `D=~/.gitconfig; echo x > $D` is otherwise a bypass.
python3 - "$TMP" <<'PY'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

fn_old = "# SMART_APPROVE_DOTFILES_PATCH_BLOCK\n"
fn_new = '''# Set from the PreToolUse payload in main(); empty until then, which makes
# every redirect out of scope rather than in.
_WRITE_SCOPE_ROOTS = []

# A redirect operator (>, >>, >|) and its target. `2>&1` and `<` are not
# writes to a path and do not match: the target must start like a path.
_REDIRECT_TARGET = re.compile(
    r\'(?:^|\\s)\\d?>>?\\|?\\s*["\\\']?([A-Za-z0-9_./~$][^\\s"\\\';&|)<>]*)\'
)

# Sinks that are always safe to write to.
_WRITE_SINKS = ("/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty")


def set_write_scope(cwd, scratchpad_dir):
    """Record the directories a redirect may land in."""
    roots = []
    for d in (cwd, scratchpad_dir, os.environ.get("TMPDIR"),
              "/tmp", "/private/tmp", "/var/folders"):
        if not d:
            continue
        try:
            roots.append(os.path.realpath(os.path.expanduser(d)))
        except OSError:
            continue
    _WRITE_SCOPE_ROOTS[:] = roots


def _target_in_scope(target, cwd):
    """True when a redirect target resolves inside the work area."""
    if target.startswith(_WRITE_SINKS):
        return True
    # A value the hook cannot resolve is not a value it can vouch for.
    if "$" in target or "`" in target:
        return False
    expanded = os.path.expanduser(target)
    if not os.path.isabs(expanded):
        if not cwd:
            return False
        expanded = os.path.join(cwd, expanded)
    # realpath on both sides, so /tmp matching /private/tmp on macOS is not a
    # miss, and a symlink pointing out of the work area is not a way in.
    try:
        resolved = os.path.realpath(expanded)
    except OSError:
        return False
    for root in _WRITE_SCOPE_ROOTS:
        if resolved == root or resolved.startswith(root + os.sep):
            return True
    return False


def redirects_outside_write_scope(cmd, cwd=None):
    """True when the command writes somewhere outside the work area."""
    cwd = cwd or (_WRITE_SCOPE_ROOTS[0] if _WRITE_SCOPE_ROOTS else None)
    for target in _REDIRECT_TARGET.findall(cmd):
        if not _target_in_scope(target, cwd):
            return True
    return False


# SMART_APPROVE_DOTFILES_PATCH_BLOCK
'''

if fn_old not in src:
    sys.exit(f"smart-approve Step 13 fn patch: sentinel anchor not found in {path}")
new_src = src.replace(fn_old, fn_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 13 fn patch did not apply to {path}")
src = new_src

call_old = """    # Check if ALL match allow"""
call_new = """    if redirects_outside_write_scope(command):
        log("declining to approve: redirect lands outside the work area")
        return None, None

    # Check if ALL match allow"""

if call_old not in src:
    sys.exit(f"smart-approve Step 13 call-site patch: decide() allow scan not found in {path}")
new_src = src.replace(call_old, call_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 13 call-site patch did not apply to {path}")
src = new_src

main_old = """    settings_path = os.environ.get("CLAUDE_SETTINGS_PATH")"""
main_new = """    set_write_scope(input_data.get("cwd"), input_data.get("scratchpad_dir"))

    settings_path = os.environ.get("CLAUDE_SETTINGS_PATH")"""

if main_old not in src:
    sys.exit(f"smart-approve Step 13 main patch: settings load anchor not found in {path}")
new_src = src.replace(main_old, main_new, 1)
if new_src == src:
    sys.exit(f"smart-approve Step 13 main patch did not apply to {path}")

with open(path, "w") as f:
    f.write(new_src)
PY

chmod +x "$TMP"
mv "$TMP" "$HOOK"

echo "Installed smart_approve.py @ ${SHA} -> ${HOOK}"
