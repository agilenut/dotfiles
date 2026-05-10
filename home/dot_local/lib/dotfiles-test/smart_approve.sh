#!/usr/bin/env bash
# smart_approve hook tests
# shellcheck shell=bash

SMART_APPROVE_HOOK="${HOME}/.claude/hooks/smart_approve.py"

test_smart_approve() {
  section "Smart Approve Hook"

  if [ ! -f "$SMART_APPROVE_HOOK" ]; then
    skip_with_followup "smart_approve.py not installed" \
      "Run 'chezmoi apply' to install the smart_approve hook"
    return
  fi

  if ! command -v python3 &>/dev/null; then
    skip "python3 not installed (required by smart_approve)"
    return
  fi

  # Hook must contain the dotfiles patch marker. If it doesn't, the install
  # script silently downloaded an unpatched copy or upstream refactored the
  # function the patch targets — both are bugs.
  if grep -q "PATCHED (dotfiles fork)" "$SMART_APPROVE_HOOK"; then
    pass "patch marker present in installed hook"
  else
    fail "patch marker missing — install script may have skipped the patch"
  fi

  # Helper: pipe a PreToolUse JSON envelope through the hook and extract
  # the permissionDecision (defaults to "fallthrough" for empty/silent output).
  # SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null prevents test invocations
  # from polluting the user's audit log at ~/.claude/logs/smart_approve_decisions.log.
  decision_for() {
    local cmd="$1"
    local out
    out=$(printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$cmd}}" \
      | env SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null python3 "$SMART_APPROVE_HOOK" 2>/dev/null)
    if [ -z "$out" ]; then
      printf 'fallthrough'
    else
      printf '%s' "$out" | python3 -c \
        "import json,sys; print(json.load(sys.stdin).get('hookSpecificOutput',{}).get('permissionDecision','fallthrough'))" \
        2>/dev/null
    fi
  }

  # Bare command matches Bash(prefix *) — proves the parser patch works.
  # Without the patch, fnmatch("git status", "git status *") is False because
  # the pattern requires a literal space + something after it.
  local d
  d=$(decision_for '"git status"')
  if [ "$d" = "allow" ]; then
    pass "bare command matches Bash(prefix *) (parser patch active)"
  else
    fail "bare 'git status' should match Bash(git status *) via patched parser (got: $d)"
  fi

  # Chained allowlisted commands — explicit allow.
  d=$(decision_for '"git status && git diff"')
  if [ "$d" = "allow" ]; then
    pass "chained allowlisted commands → allow"
  else
    fail "chained 'git status && git diff' should allow (got: $d)"
  fi

  # find -exec hits the deny pattern — explicit deny.
  d=$(decision_for '"find . -exec rm {} \\;"')
  if [ "$d" = "deny" ]; then
    pass "find -exec → deny"
  else
    fail "'find . -exec rm {} ;' should match deny pattern (got: $d)"
  fi

  # find -execdir hits the deny pattern.
  d=$(decision_for '"find . -execdir rm {} \\;"')
  if [ "$d" = "deny" ]; then
    pass "find -execdir → deny"
  else
    fail "'find . -execdir' should match deny pattern (got: $d)"
  fi

  # find -delete is intentionally NOT in deny — should still match Bash(find *)
  # allow per user policy ("ok with find remove in allowed folders").
  d=$(decision_for '"find /tmp -name foo -delete"')
  if [ "$d" = "allow" ]; then
    pass "find -delete → allow (intentional, not in deny)"
  else
    fail "'find -delete' should still allow (got: $d)"
  fi

  # Narrow uv allow wins: Bash(uv pip list *) is in allow, Bash(uv *) is in
  # ask. The hook only checks allow/deny, so the narrow allow wins for
  # non-chained read-only uv commands.
  d=$(decision_for '"uv pip list"')
  if [ "$d" = "allow" ]; then
    pass "uv pip list → allow (narrow allow wins over broader ask)"
  else
    fail "'uv pip list' should allow via narrow pattern (got: $d)"
  fi

  # Non-narrow uv (e.g. uv run, uv pip install) is not in allow → hook falls
  # through → Claude Code native sees Bash(uv *) in ask → prompts.
  d=$(decision_for '"uv run script.py"')
  if [ "$d" = "fallthrough" ]; then
    pass "uv run → fall-through (broader ask handles)"
  else
    fail "'uv run' should fall through to native matcher (got: $d)"
  fi

  # Demoted patterns (curl, rm, docker run, etc.) fall through to native ask.
  d=$(decision_for '"curl https://example.com"')
  if [ "$d" = "fallthrough" ]; then
    pass "curl → fall-through (demoted from allow)"
  else
    fail "'curl ...' should fall through (got: $d)"
  fi

  d=$(decision_for '"rm /tmp/foo"')
  if [ "$d" = "fallthrough" ]; then
    pass "rm → fall-through (demoted from allow)"
  else
    fail "'rm ...' should fall through (got: $d)"
  fi

  # Mixed chain (allow + ask) → silent fall-through (hook doesn't honor ask).
  d=$(decision_for '"git status && git config core.editor vim"')
  if [ "$d" = "fallthrough" ]; then
    pass "mixed chain (allow + ask) → silent fall-through"
  else
    fail "mixed chain should fall through to native matcher (got: $d)"
  fi

  # Chain mixing allowed + demoted command falls through.
  d=$(decision_for '"git status && curl https://example.com"')
  if [ "$d" = "fallthrough" ]; then
    pass "chain (allow + demoted) → fall-through"
  else
    fail "chain with demoted command should fall through (got: $d)"
  fi

  # Deny applies even when the rest of the chain is allowed.
  d=$(decision_for '"git status && find . -exec rm {} \\;"')
  if [ "$d" = "deny" ]; then
    pass "chain containing deny pattern → deny"
  else
    fail "chain with find -exec should deny (got: $d)"
  fi

  # ---- bare commands matched via explicit no-trailing-* allow patterns ----
  # Settings.json has BOTH Bash(git -C * <subcmd>) and Bash(git -C * <subcmd> *)
  # for status/log/diff. This is required because Claude's native pattern matcher
  # (and the hook, which mirrors it) is **strict** for patterns with interior
  # wildcards: Bash(git -C * status *) does NOT match bare `git -C /path status`
  # — the trailing * needs a real arg. So the bare form needs its own pattern.
  # See project CLAUDE.md "Gotchas" for the full permissive-vs-strict rule.

  d=$(decision_for '"git -C /Users/eric/repos/dotfiles status"')
  if [ "$d" = "allow" ]; then
    pass "git -C <path> status → allow (bare cmd, interior * in pattern)"
  else
    fail "'git -C <path> status' should match Bash(git -C * status *) (got: $d)"
  fi

  d=$(decision_for '"git -C /Users/eric/repos/dotfiles log"')
  if [ "$d" = "allow" ]; then
    pass "git -C <path> log → allow (bare cmd, interior * in pattern)"
  else
    fail "'git -C <path> log' should match Bash(git -C * log *) (got: $d)"
  fi

  d=$(decision_for '"git -C /Users/eric/repos/dotfiles diff"')
  if [ "$d" = "allow" ]; then
    pass "git -C <path> diff → allow (bare cmd, interior * in pattern)"
  else
    fail "'git -C <path> diff' should match Bash(git -C * diff *) (got: $d)"
  fi

  # Regression check: with-args case must still match the inner pattern.
  d=$(decision_for '"git -C /Users/eric/repos/dotfiles status -s"')
  if [ "$d" = "allow" ]; then
    pass "git -C <path> status -s → allow (with args, full pattern)"
  else
    fail "'git -C <path> status -s' should match Bash(git -C * status *) (got: $d)"
  fi

  # ---- git RCE deny patterns (alias-set, core.fsmonitor/sshCommand, protocol.ext) ----

  # Bang-alias attack — quoted form (the realistic shell form).
  d=$(decision_for "\"git config alias.foo '!evil'\"")
  if [ "$d" = "deny" ]; then
    pass "git config alias.foo '!evil' → deny (alias-set)"
  else
    fail "quoted bang-alias should deny (got: $d)"
  fi

  # Bang-alias with --global flag interposed.
  d=$(decision_for "\"git config --global alias.foo '!evil'\"")
  if [ "$d" = "deny" ]; then
    pass "git config --global alias.foo '!evil' → deny (flag-interposed alias-set)"
  else
    fail "--global alias.foo '!evil' should deny (got: $d)"
  fi

  # Bang-alias via -c one-shot form.
  d=$(decision_for "\"git -c alias.foo='!evil' status\"")
  if [ "$d" = "deny" ]; then
    pass "git -c alias.foo='!evil' status → deny (one-shot alias)"
  else
    fail "git -c alias.*=* should deny (got: $d)"
  fi

  # core.fsmonitor — known git-RCE config key.
  d=$(decision_for '"git -c core.fsmonitor=evil status"')
  if [ "$d" = "deny" ]; then
    pass "git -c core.fsmonitor=evil → deny"
  else
    fail "core.fsmonitor should deny (got: $d)"
  fi

  # camelCase variant — covered.
  d=$(decision_for '"git -c core.fsMonitor=evil status"')
  if [ "$d" = "deny" ]; then
    pass "git -c core.fsMonitor=evil → deny (camelCase covered)"
  else
    fail "core.fsMonitor should deny (got: $d)"
  fi

  # Documented residual gap: UPPERCASE git config keys (case-insensitive in git,
  # case-sensitive in fnmatch) bypass the deny. Asserting fall-through here
  # locks in the gap so a future fix (e.g. case-insensitive deny matching)
  # can flip this assertion intentionally.
  d=$(decision_for '"git -c CORE.fsmonitor=evil status"')
  if [ "$d" = "fallthrough" ]; then
    pass "git -c CORE.fsmonitor=evil → fall-through (documented case gap)"
  else
    fail "CORE.fsmonitor case bypass status changed (got: $d)"
  fi

  # Reads via --get must still be allowed (deny pattern's trailing ' *' should
  # not match read forms). The hook explicitly returns allow here; if Claude
  # Code's native ask layer ever overrides hook-allow, this still passes.
  d=$(decision_for '"git config --get alias.foo"')
  if [ "$d" = "allow" ]; then
    pass "git config --get alias.foo → allow (read explicitly allowed by hook)"
  else
    fail "git config --get alias.foo should explicitly allow (got: $d)"
  fi

  # Bare-key read (no value) must still pass — tests the trailing space+value
  # discriminator in the deny pattern.
  d=$(decision_for '"git config alias.foo"')
  if [ "$d" = "fallthrough" ] || [ "$d" = "allow" ]; then
    pass "git config alias.foo (bare-key read) → allow/fall-through"
  else
    fail "bare-key alias read should not deny (got: $d)"
  fi

  # ---- Step 1: read-only allow additions ----
  # Representative sample of the 21 new read-only allow entries (basename,
  # cmp, column, comm, cut, df, diff, dirname, du, hexdump, lsof, od, paste,
  # printf, ps, readlink, realpath, seq, stat, uniq, wc). Verifies bare and
  # arg'd forms — bare requires the parser patch, arg'd requires the entry.

  d=$(decision_for '"wc -l /tmp/foo"')
  if [ "$d" = "allow" ]; then
    pass "wc -l <file> → allow (new read-only entry)"
  else
    fail "'wc -l <file>' should match Bash(wc *) (got: $d)"
  fi

  d=$(decision_for '"wc"')
  if [ "$d" = "allow" ]; then
    pass "wc (bare) → allow"
  else
    fail "bare 'wc' should match Bash(wc *) via parser patch (got: $d)"
  fi

  d=$(decision_for '"cut -d: -f1 /etc/passwd"')
  if [ "$d" = "allow" ]; then
    pass "cut -d: -f1 <file> → allow"
  else
    fail "'cut -d: -f1 <file>' should match Bash(cut *) (got: $d)"
  fi

  d=$(decision_for '"diff a.txt b.txt"')
  if [ "$d" = "allow" ]; then
    pass "diff a.txt b.txt → allow"
  else
    fail "'diff a.txt b.txt' should match Bash(diff *) (got: $d)"
  fi

  d=$(decision_for '"stat /tmp/foo"')
  if [ "$d" = "allow" ]; then
    pass "stat <file> → allow"
  else
    fail "'stat <file>' should match Bash(stat *) (got: $d)"
  fi

  d=$(decision_for '"du -sh ."')
  if [ "$d" = "allow" ]; then
    pass "du -sh . → allow"
  else
    fail "'du -sh .' should match Bash(du *) (got: $d)"
  fi

  d=$(decision_for '"ps aux"')
  if [ "$d" = "allow" ]; then
    pass "ps aux → allow"
  else
    fail "'ps aux' should match Bash(ps *) (got: $d)"
  fi

  d=$(decision_for '"printf %s foo"')
  if [ "$d" = "allow" ]; then
    pass "printf %s foo → allow"
  else
    fail "'printf' should match Bash(printf *) (got: $d)"
  fi

  d=$(decision_for '"basename /tmp/foo.txt"')
  if [ "$d" = "allow" ]; then
    pass "basename → allow"
  else
    fail "'basename' should match Bash(basename *) (got: $d)"
  fi

  # Composing newly-allowed tools with existing ones in a chain — exercises
  # the segment-level allow check the new ## Bash rule lifts the chain ban for.
  d=$(decision_for '"jq . file.json | wc -l"')
  if [ "$d" = "allow" ]; then
    pass "jq | wc chain → allow (compose-freely guarantee)"
  else
    fail "'jq | wc' chain should allow when both segments are allow-listed (got: $d)"
  fi

  # ---- Step 2: verbose-on-fallthrough log-file emission ----
  # SMART_APPROVE_VERBOSE=1 appends per-invocation entries to
  # ~/.claude/logs/smart_approve.log on both decision and fallthrough paths.
  # Without the env var, the log file is not touched.

  local log_file="${HOME}/.claude/logs/smart_approve.log"
  local before_lines after_lines marker

  # Allow path with verbose on — log gets new lines containing the marker.
  # SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null prevents Step 6's audit log
  # from also being written to during these Step 2 verbose-log tests.
  marker="step2_allow_$$_$(date +%s%N 2>/dev/null || date +%s)"
  before_lines=$(wc -l <"$log_file" 2>/dev/null | tr -d ' ' || printf 0)
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ${marker}\"}}" \
    | env SMART_APPROVE_VERBOSE=1 SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  after_lines=$(wc -l <"$log_file" 2>/dev/null | tr -d ' ' || printf 0)
  if [ "$after_lines" -gt "$before_lines" ] && grep -q "$marker" "$log_file" 2>/dev/null; then
    pass "verbose=1, allow path → log file appended with command preview"
  else
    fail "verbose=1, allow path: log should grow and contain '${marker}' (lines: ${before_lines}→${after_lines})"
  fi

  # Fallthrough path with verbose on — log also grows.
  marker="step2_fallthrough_$$_$(date +%s%N 2>/dev/null || date +%s)"
  before_lines=$after_lines
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"unknownbinary ${marker}\"}}" \
    | env SMART_APPROVE_VERBOSE=1 SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  after_lines=$(wc -l <"$log_file" 2>/dev/null | tr -d ' ' || printf 0)
  if [ "$after_lines" -gt "$before_lines" ] && grep -q "$marker" "$log_file" 2>/dev/null; then
    pass "verbose=1, fallthrough path → log file appended"
  else
    fail "verbose=1, fallthrough: log should grow and contain '${marker}' (lines: ${before_lines}→${after_lines})"
  fi

  # Verbose unset — log not touched. Marker absence is sufficient; line-count
  # delta is race-prone under parallel test execution and adds nothing.
  marker="step2_off_$$_$(date +%s%N 2>/dev/null || date +%s)"
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ${marker}\"}}" \
    | env -u SMART_APPROVE_VERBOSE SMART_APPROVE_DECISIONS_LOG_PATH=/dev/null \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  if ! grep -q "$marker" "$log_file" 2>/dev/null; then
    pass "verbose unset → log file unmodified (marker absent)"
  else
    fail "verbose unset: log should not contain '${marker}'"
  fi

  # Patch survival markers — assert Step 2 patches landed in the installed hook.
  if grep -q "_emit_verbose_to_log_file" "$SMART_APPROVE_HOOK"; then
    pass "Step 2 patch marker present (_emit_verbose_to_log_file)"
  else
    fail "Step 2 _emit_verbose_to_log_file missing — install script may have skipped patch"
  fi

  if grep -q "SMART_APPROVE_DOTFILES_PATCH_BLOCK" "$SMART_APPROVE_HOOK"; then
    pass "patch sentinel present (SMART_APPROVE_DOTFILES_PATCH_BLOCK)"
  else
    fail "patch sentinel missing — Step 2 install patch may have skipped"
  fi

  # ---- Step 3: command-wrapper prefix peeling ----
  # peel_command_wrappers() strips leading time/nice/env/command/exec/ionice/
  # taskset wrappers and re-checks the inner command against allow patterns.
  # The wrapper itself contributes no privileges; the inner command is what's
  # security-relevant. command -v / -V are info-only and stay matched via the
  # Bash(command -v *) allow entry rather than being peeled.

  d=$(decision_for '"time git status"')
  if [ "$d" = "allow" ]; then
    pass "time git status → allow (wrapper peeled)"
  else
    fail "'time git status' should peel to 'git status' and allow (got: $d)"
  fi

  d=$(decision_for '"nice git status"')
  if [ "$d" = "allow" ]; then
    pass "nice git status → allow (wrapper peeled)"
  else
    fail "'nice git status' should peel to 'git status' and allow (got: $d)"
  fi

  d=$(decision_for '"nice -n 10 git status"')
  if [ "$d" = "allow" ]; then
    pass "nice -n 10 git status → allow (peel consumes flag value)"
  else
    fail "'nice -n 10 git status' should peel to 'git status' (got: $d)"
  fi

  d=$(decision_for '"env git status"')
  if [ "$d" = "allow" ]; then
    pass "env (binary) git status → allow (wrapper peeled)"
  else
    fail "'env git status' should peel to 'git status' (got: $d)"
  fi

  d=$(decision_for '"command git status"')
  if [ "$d" = "allow" ]; then
    pass "command git status → allow (wrapper peeled)"
  else
    fail "'command git status' should peel to 'git status' (got: $d)"
  fi

  # command -v is info-only — must NOT peel (otherwise '-v jq' isn't a
  # valid command). Allow comes from Bash(command -v *) directly.
  d=$(decision_for '"command -v jq"')
  if [ "$d" = "allow" ]; then
    pass "command -v jq → allow (info-only, not peeled)"
  else
    fail "'command -v jq' should match Bash(command -v *) without peel (got: $d)"
  fi

  d=$(decision_for '"exec git status"')
  if [ "$d" = "allow" ]; then
    pass "exec git status → allow (wrapper peeled)"
  else
    fail "'exec git status' should peel to 'git status' (got: $d)"
  fi

  # Recursive peel: time nice CMD → nice CMD → CMD.
  d=$(decision_for '"time nice git status"')
  if [ "$d" = "allow" ]; then
    pass "time nice git status → allow (recursive peel, 2 levels)"
  else
    fail "'time nice git status' should peel both wrappers (got: $d)"
  fi

  # Recursion bound — 10 levels of `time` should still allow without hang.
  d=$(decision_for '"time time time time time time time time time time git status"')
  if [ "$d" = "allow" ]; then
    pass "10-level time wrapper → allow (recursion bound holds)"
  else
    fail "10-level time wrapper should peel to 'git status' (got: $d)"
  fi

  # sudo is intentionally NOT peeled — privilege escalation should always
  # surface to the user via native prompt.
  d=$(decision_for '"sudo git status"')
  if [ "$d" = "fallthrough" ]; then
    pass "sudo git status → fallthrough (sudo not peeled, native handles)"
  else
    fail "'sudo git status' should NOT auto-allow via wrapper peeling (got: $d)"
  fi

  # Patch markers — Step 3 functions and call site landed.
  if grep -q "peel_command_wrappers" "$SMART_APPROVE_HOOK"; then
    pass "Step 3 patch marker present (peel_command_wrappers)"
  else
    fail "peel_command_wrappers missing — Step 3 install patch may have skipped"
  fi

  # Branch coverage for per-wrapper flag handling and corner cases.

  # nice legacy negative-int form
  d=$(decision_for '"nice -19 git status"')
  if [ "$d" = "allow" ]; then
    pass "nice -19 git status → allow (legacy negative-int)"
  else
    fail "'nice -19 git status' should peel via legacy form (got: $d)"
  fi

  # -- terminator
  d=$(decision_for '"nice -n 10 -- git status"')
  if [ "$d" = "allow" ]; then
    pass "nice -n 10 -- git status → allow (-- terminator handled)"
  else
    fail "'nice -n 10 -- git status' should peel through -- (got: $d)"
  fi

  # env -u VAR (value-flag)
  d=$(decision_for '"env -u FOO git status"')
  if [ "$d" = "allow" ]; then
    pass "env -u FOO git status → allow (-u value-flag consumed)"
  else
    fail "'env -u FOO git status' should peel (got: $d)"
  fi

  # env KEY=VAL CMD — post-peel strip_env_vars handles the asymmetry.
  d=$(decision_for '"env FOO=bar git status"')
  if [ "$d" = "allow" ]; then
    pass "env FOO=bar git status → allow (post-peel strip_env_vars)"
  else
    fail "'env FOO=bar git status' should peel + restrip env (got: $d)"
  fi

  # taskset positional MASK (hex form)
  d=$(decision_for '"taskset 0x3 git status"')
  if [ "$d" = "allow" ]; then
    pass "taskset 0x3 git status → allow (hex MASK consumed)"
  else
    fail "'taskset 0x3 git status' should peel hex MASK (got: $d)"
  fi

  # taskset -c CPU_LIST
  d=$(decision_for '"taskset -c 0,1 git status"')
  if [ "$d" = "allow" ]; then
    pass "taskset -c 0,1 git status → allow (-c value-flag)"
  else
    fail "'taskset -c 0,1 git status' should peel -c LIST (got: $d)"
  fi

  # exec -a NAME (value-flag)
  d=$(decision_for '"exec -a myname git status"')
  if [ "$d" = "allow" ]; then
    pass "exec -a myname git status → allow (-a value-flag)"
  else
    fail "'exec -a myname git status' should peel -a NAME (got: $d)"
  fi

  # ---- Step 4: xargs peel-and-inspect ----
  # peel_xargs() strips a leading `xargs` invocation and returns the inner
  # command. Returns the original cmd unchanged when the inner is an unsafe
  # executor (sh -c, bash -c, python -c, awk, etc.) or when an unknown long
  # flag is encountered (better to fall through than guess flag-vs-value).

  d=$(decision_for '"xargs grep foo"')
  if [ "$d" = "allow" ]; then
    pass "xargs grep foo → allow (canonical peel)"
  else
    fail "'xargs grep foo' should peel to 'grep foo' (got: $d)"
  fi

  d=$(decision_for '"xargs -0 grep foo"')
  if [ "$d" = "allow" ]; then
    pass "xargs -0 grep foo → allow (boolean -0 flag)"
  else
    fail "'xargs -0 grep foo' should peel through -0 (got: $d)"
  fi

  d=$(decision_for '"xargs -I {} cat {}"')
  if [ "$d" = "allow" ]; then
    pass "xargs -I {} cat {} → allow (-I value-flag)"
  else
    fail "'xargs -I {} cat {}' should peel (got: $d)"
  fi

  # -L1 attached value form (very common)
  d=$(decision_for '"xargs -L1 cat"')
  if [ "$d" = "allow" ]; then
    pass "xargs -L1 cat → allow (attached value form)"
  else
    fail "'xargs -L1 cat' should peel attached -L1 (got: $d)"
  fi

  # -n 5 separate value form
  d=$(decision_for '"xargs -n 5 cat"')
  if [ "$d" = "allow" ]; then
    pass "xargs -n 5 cat → allow (separate value form)"
  else
    fail "'xargs -n 5 cat' should peel (got: $d)"
  fi

  # -a FILE
  d=$(decision_for '"xargs -a /tmp/list cat"')
  if [ "$d" = "allow" ]; then
    pass "xargs -a /tmp/list cat → allow (-a FILE)"
  else
    fail "'xargs -a /tmp/list cat' should peel (got: $d)"
  fi

  # GNU long-form key=value
  d=$(decision_for '"xargs --max-args=1 cat"')
  if [ "$d" = "allow" ]; then
    pass "xargs --max-args=1 cat → allow (long --key=value)"
  else
    fail "'xargs --max-args=1 cat' should peel (got: $d)"
  fi

  # Unsafe inner — sh -c, bash -c, python -c
  d=$(decision_for '"xargs sh -c echo"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs sh -c echo → fallthrough (unsafe inner; sh stays unmatched)"
  else
    fail "'xargs sh -c echo' should NOT auto-allow (got: $d)"
  fi

  d=$(decision_for '"xargs bash -c true"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs bash -c true → fallthrough (unsafe inner)"
  else
    fail "'xargs bash -c true' should NOT auto-allow (got: $d)"
  fi

  d=$(decision_for '"xargs python3 -c print"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs python3 -c print → fallthrough (unsafe inner)"
  else
    fail "'xargs python3 -c print' should NOT auto-allow (got: $d)"
  fi

  # Unknown long flag — bail rather than guess flag-vs-value semantics
  d=$(decision_for '"xargs --frobnicate cat"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs --frobnicate cat → fallthrough (unknown long flag bails)"
  else
    fail "'xargs --frobnicate cat' should bail on unknown flag (got: $d)"
  fi

  # Composed with command-wrapper peel: time xargs grep foo
  d=$(decision_for '"time xargs grep foo"')
  if [ "$d" = "allow" ]; then
    pass "time xargs grep foo → allow (Step 3 + Step 4 sequential peel)"
  else
    fail "'time xargs grep foo' should peel both wrappers (got: $d)"
  fi

  # Patch marker
  if grep -q "peel_xargs" "$SMART_APPROVE_HOOK"; then
    pass "Step 4 patch marker present (peel_xargs)"
  else
    fail "peel_xargs missing — Step 4 install patch may have skipped"
  fi

  # Inner-command basename normalization — absolute path bypass closed.
  d=$(decision_for '"xargs /bin/sh -c echo"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs /bin/sh -c → fallthrough (basename normalization catches sh)"
  else
    fail "'xargs /bin/sh -c echo' should fallthrough via basename (got: $d)"
  fi

  # Version-suffix normalization (python3.11, python2.7, lua5.4).
  d=$(decision_for '"xargs python3.11 -c print"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs python3.11 -c → fallthrough (version-suffix normalized)"
  else
    fail "'xargs python3.11 -c print' should fallthrough (got: $d)"
  fi

  # macOS-specific: osascript runs AppleScript via -e.
  d=$(decision_for '"xargs osascript -e tell"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs osascript -e → fallthrough (osascript in UNSAFE_INNER)"
  else
    fail "'xargs osascript -e tell' should fallthrough (got: $d)"
  fi

  # Unknown short flag — must bail rather than mis-peel.
  d=$(decision_for '"xargs -Z somevalue git status"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs -Z VAL git → fallthrough (unknown short flag bails)"
  else
    fail "'xargs -Z VAL git status' should bail on unknown short (got: $d)"
  fi

  # -- terminator with safe inner: peels through.
  d=$(decision_for '"xargs -- cat /tmp/foo"')
  if [ "$d" = "allow" ]; then
    pass "xargs -- cat → allow (-- terminator, safe inner)"
  else
    fail "'xargs -- cat /tmp/foo' should peel through -- (got: $d)"
  fi

  # -- terminator does not unlock unsafe inner.
  d=$(decision_for '"xargs -- sh -c echo"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs -- sh -c → fallthrough (-- doesn't bypass UNSAFE_INNER)"
  else
    fail "'xargs -- sh -c echo' should still fallthrough (got: $d)"
  fi

  # xargs sudo CMD — sudo isn't peeled by either layer; falls through.
  d=$(decision_for '"xargs sudo git status"')
  if [ "$d" = "fallthrough" ]; then
    pass "xargs sudo git status → fallthrough (sudo never auto-allows)"
  else
    fail "'xargs sudo git status' should fallthrough (got: $d)"
  fi

  # ---- Step 5: awk safety heuristic ----
  # is_awk_program_safe() scans the program text + flags for shell-out, file
  # write, or external-program-load primitives. Safe programs auto-allow
  # without needing Bash(awk *) on the allow list. Unsafe programs (and any
  # use of -f/-i/-e/-E/--source/--include) fall through to native prompt.

  # Safe awk programs — common shapes auto-allow.
  d=$(decision_for "\"awk '{print \$1}' /tmp/foo\"")
  if [ "$d" = "allow" ]; then
    pass "awk '{print \$1}' file → allow (safe program scans clean)"
  else
    fail "safe awk '{print \$1}' should auto-allow (got: $d)"
  fi

  d=$(decision_for "\"awk -F: '{print \$2}' /etc/passwd\"")
  if [ "$d" = "allow" ]; then
    pass "awk -F: '{print \$2}' file → allow (-F value-flag handled)"
  else
    fail "awk -F: should auto-allow (got: $d)"
  fi

  d=$(decision_for "\"awk -v x=1 'NR==1{print x}' file\"")
  if [ "$d" = "allow" ]; then
    pass "awk -v x=1 ... → allow (-v value-flag handled)"
  else
    fail "awk -v should auto-allow (got: $d)"
  fi

  # Unsafe awk programs — must fall through.
  d=$(decision_for "\"awk 'BEGIN{system(\\\"rm\\\")}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk 'BEGIN{system(...)}' → fallthrough (system() blocked)"
  else
    fail "awk system() should fallthrough (got: $d)"
  fi

  d=$(decision_for "\"awk '{print > \\\"/tmp/x\\\"}' file\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk '{print > \"...\"}' → fallthrough (file write blocked)"
  else
    fail "awk print > should fallthrough (got: $d)"
  fi

  d=$(decision_for "\"awk '{ \\\"cmd\\\" | getline x }' file\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk getline → fallthrough (pipe-getline blocked)"
  else
    fail "awk getline should fallthrough (got: $d)"
  fi

  # Dangerous flags — -f loads external script.
  d=$(decision_for '"awk -f /tmp/script.awk file"')
  if [ "$d" = "fallthrough" ]; then
    pass "awk -f script.awk → fallthrough (external program load blocked)"
  else
    fail "awk -f should fallthrough (got: $d)"
  fi

  # -i inplace silently rewrites the input file.
  d=$(decision_for "\"awk -i inplace '{print toupper(\$0)}' /tmp/x\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk -i inplace → fallthrough (in-place rewrite blocked)"
  else
    fail "awk -i should fallthrough (got: $d)"
  fi

  # -e is alternate program location; a program-text scan would skip it.
  d=$(decision_for "\"awk -e '{system(\\\"x\\\")}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk -e → fallthrough (alternate program location blocked)"
  else
    fail "awk -e should fallthrough (got: $d)"
  fi

  # @load and @include are gawk extension/include directives.
  d=$(decision_for "\"awk '@load \\\"filefuncs\\\"; {print stat()}' file\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk @load → fallthrough (gawk extension load blocked)"
  else
    fail "awk @load should fallthrough (got: $d)"
  fi

  # Documented false-positive: 'system(' inside a string literal still
  # rejects (the heuristic doesn't parse awk syntax). Locks in the
  # accepted cost.
  d=$(decision_for "\"awk 'BEGIN{print \\\"system( is text\\\"}' file\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk with 'system(' as string literal → fallthrough (false-positive accepted)"
  else
    fail "awk false-positive case behavior changed (got: $d)"
  fi

  # Bare awk with no program — falls through (no program to scan).
  d=$(decision_for '"awk"')
  if [ "$d" = "fallthrough" ]; then
    pass "bare awk → fallthrough (no program to inspect)"
  else
    fail "bare awk should fallthrough (got: $d)"
  fi

  # Composed: cat | awk in a pipeline — both segments allow.
  d=$(decision_for "\"cat /tmp/foo | awk '{print \$1}'\"")
  if [ "$d" = "allow" ]; then
    pass "cat | awk safe-program → allow (segment-level both ok)"
  else
    fail "'cat | awk safe' chain should allow (got: $d)"
  fi

  # Patch markers
  if grep -q "is_awk_program_safe" "$SMART_APPROVE_HOOK"; then
    pass "Step 5 patch marker present (is_awk_program_safe)"
  else
    fail "is_awk_program_safe missing — Step 5 install patch may have skipped"
  fi

  if grep -q "command_passes_allow" "$SMART_APPROVE_HOOK"; then
    pass "Step 5 patch marker present (command_passes_allow)"
  else
    fail "command_passes_allow missing — Step 5 install patch may have skipped"
  fi

  # Branch coverage and bypass-attempt locks for the awk safety heuristic.

  # Bypass-attempt: data between print and >. Must fall through.
  d=$(decision_for "\"awk '{print \$0 > \\\"/tmp/x\\\"}' /tmp/foo\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk '{print \$0 > \"...\"}' → fallthrough (intervening data caught)"
  else
    fail "awk print-with-intervening-data should fallthrough (got: $d)"
  fi

  # Coprocess `|&` (gawk two-way pipe).
  d=$(decision_for "\"awk '{print \\\"x\\\" |& \\\"sh\\\"}' file\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk '{print ... |& ...}' → fallthrough (coprocess blocked)"
  else
    fail "awk |& coprocess should fallthrough (got: $d)"
  fi

  # @indirect call — runtime function name construction.
  d=$(decision_for "\"awk 'BEGIN{a=\\\"syst\\\"; @a(\\\"rm\\\")}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk @indirect call → fallthrough (gawk indirect call blocked)"
  else
    fail "awk @indirect should fallthrough (got: $d)"
  fi

  # @ inside string literal (false-positive avoidance) — should still allow.
  d=$(decision_for "\"awk 'BEGIN{print \\\"user@host\\\"}'\"")
  if [ "$d" = "allow" ]; then
    pass "awk 'BEGIN{print \"user@host\"}' → allow (@ in string literal not function call)"
  else
    fail "awk @ in string literal should allow (got: $d)"
  fi

  # -E flag (gawk fallback program loader).
  d=$(decision_for '"awk -E /tmp/script.awk file"')
  if [ "$d" = "fallthrough" ]; then
    pass "awk -E → fallthrough (-E flag rejected)"
  else
    fail "awk -E should fallthrough (got: $d)"
  fi

  # --source=PROG long form.
  d=$(decision_for "\"awk --source='{system(\\\"x\\\")}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk --source= → fallthrough (--source= rejected)"
  else
    fail "awk --source= should fallthrough (got: $d)"
  fi

  # --include=lib long form.
  d=$(decision_for "\"awk --include=foo '{print}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk --include= → fallthrough (--include= rejected)"
  else
    fail "awk --include= should fallthrough (got: $d)"
  fi

  # bare awk -- (no program after terminator).
  d=$(decision_for '"awk --"')
  if [ "$d" = "fallthrough" ]; then
    pass "awk -- (no program) → fallthrough"
  else
    fail "awk -- should fallthrough (got: $d)"
  fi

  # Unknown short flag.
  d=$(decision_for "\"awk -X '{print}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk -X → fallthrough (unknown short bails)"
  else
    fail "awk -X should fallthrough (got: $d)"
  fi

  # Unknown long flag.
  d=$(decision_for "\"awk --frobnicate '{print}'\"")
  if [ "$d" = "fallthrough" ]; then
    pass "awk --frobnicate → fallthrough (unknown long bails)"
  else
    fail "awk --frobnicate should fallthrough (got: $d)"
  fi

  # Asymmetry lock: safe awk + denied find-exec → deny precedence.
  d=$(decision_for "\"awk '{print}' && find . -exec rm {} \\\\;\"")
  if [ "$d" = "deny" ]; then
    pass "awk safe && find -exec → deny (deny loop unaffected by awk widening)"
  else
    fail "awk + find-exec chain should deny (got: $d)"
  fi

  # ---- Step 6: decisions audit log (always-on) ----
  # _log_decision() appends a line to a path controlled by
  # SMART_APPROVE_DECISIONS_LOG_PATH (defaults to
  # ~/.claude/logs/smart_approve_decisions.log) for every allow/deny decision.
  # Tests use a temp file via env override so they don't pollute the user's
  # real trial-period audit log.

  local test_log
  test_log=$(mktemp 2>/dev/null) || test_log="/tmp/smart_approve_test_$$.log"
  : >"$test_log" # truncate so before-counts start at 0
  local marker before_lines after_lines

  # Allow decision → log gets a new line containing the command.
  marker="step6_allow_$$_$(date +%s%N 2>/dev/null || date +%s)"
  before_lines=$(wc -l <"$test_log" 2>/dev/null | tr -d ' ' || printf 0)
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ${marker}\"}}" \
    | env -u SMART_APPROVE_VERBOSE SMART_APPROVE_DECISIONS_LOG_PATH="$test_log" \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  after_lines=$(wc -l <"$test_log" 2>/dev/null | tr -d ' ' || printf 0)
  if [ "$after_lines" -gt "$before_lines" ] && grep -q "$marker" "$test_log" 2>/dev/null; then
    pass "allow decision → decisions log appended (env var unset, always-on)"
  else
    fail "allow decision: log should contain '${marker}' (lines: ${before_lines}→${after_lines})"
  fi

  # Deny decision → log also gets an entry.
  marker="step6_deny_$$_$(date +%s%N 2>/dev/null || date +%s)"
  before_lines=$after_lines
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"find . -exec rm ${marker} {} \\\\;\"}}" \
    | env -u SMART_APPROVE_VERBOSE SMART_APPROVE_DECISIONS_LOG_PATH="$test_log" \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  after_lines=$(wc -l <"$test_log" 2>/dev/null | tr -d ' ' || printf 0)
  if [ "$after_lines" -gt "$before_lines" ] && grep -q "$marker" "$test_log" 2>/dev/null; then
    pass "deny decision → decisions log appended"
  else
    fail "deny decision: log should contain '${marker}' (lines: ${before_lines}→${after_lines})"
  fi

  # Fallthrough → log NOT touched (volume control).
  marker="step6_fall_$$_$(date +%s%N 2>/dev/null || date +%s)"
  before_lines=$after_lines
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"unknownbinary ${marker}\"}}" \
    | env -u SMART_APPROVE_VERBOSE SMART_APPROVE_DECISIONS_LOG_PATH="$test_log" \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  if ! grep -q "$marker" "$test_log" 2>/dev/null; then
    pass "fallthrough → decisions log unchanged (marker absent)"
  else
    fail "fallthrough: log should NOT contain '${marker}'"
  fi

  # Log file mode is 0o600 (security hardening — secrets in args concern).
  if [ -f "$test_log" ]; then
    local mode
    mode=$(stat -f '%Lp' "$test_log" 2>/dev/null || stat -c '%a' "$test_log" 2>/dev/null)
    if [ "$mode" = "600" ]; then
      pass "decisions log file mode is 0o600"
    else
      fail "decisions log mode should be 600, got: $mode"
    fi
  fi

  # Patch marker
  if grep -q "_log_decision" "$SMART_APPROVE_HOOK"; then
    pass "Step 6 patch marker present (_log_decision)"
  else
    fail "_log_decision missing — Step 6 install patch may have skipped"
  fi

  # Format validation: line is <ISO-timestamp>\t<DECISION>\t<cmd[:300]>.
  # Catches silent format breakage from future refactors.
  marker="step6_format_$$_$(date +%s%N 2>/dev/null || date +%s)"
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ${marker}\"}}" \
    | env -u SMART_APPROVE_VERBOSE SMART_APPROVE_DECISIONS_LOG_PATH="$test_log" \
      python3 "$SMART_APPROVE_HOOK" >/dev/null 2>&1
  local line
  line=$(grep -F "$marker" "$test_log" 2>/dev/null | tail -1)
  if [ -n "$line" ]; then
    # Field 1: ISO timestamp like 2026-05-09T21:30:00
    # Field 2: ALLOW or DENY
    # Field 3: scrubbed command preview
    local f1 f2
    f1=$(printf '%s' "$line" | cut -f1)
    f2=$(printf '%s' "$line" | cut -f2)
    if printf '%s' "$f1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' \
      && { [ "$f2" = "ALLOW" ] || [ "$f2" = "DENY" ]; }; then
      pass "decisions log line format: <ISO-ts>\\t<ALLOW|DENY>\\t<cmd>"
    else
      fail "decisions log format check failed (ts=${f1}, decision=${f2})"
    fi
  else
    fail "decisions log: format-validation marker '${marker}' missing from log"
  fi

  rm -f "$test_log"
}
