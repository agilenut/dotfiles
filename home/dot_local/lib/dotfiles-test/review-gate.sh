#!/usr/bin/env bash
# Review gate git hook tests
# shellcheck shell=bash

# Overridable so the tests can run against the source script before an apply.
REVIEW_GATE="${REVIEW_GATE:-${HOME}/.local/bin/review-gate}"

test_review_gate() {
  section "Review Gate Hook"

  if [ ! -x "$REVIEW_GATE" ]; then
    fail "review-gate not installed at $REVIEW_GATE"
    return
  fi

  # The scratch repos take each hook's event from the global config and
  # override only its command, so every other case needs these entries.
  local commit_cmd push_cmd
  commit_cmd=$(git config --global --get hook.claude-review-commit.command || true)
  push_cmd=$(git config --global --get hook.claude-review-push.command || true)
  if git config --global --get-all hook.claude-review-commit.event | grep -qx pre-commit \
    && git config --global --get-all hook.claude-review-push.event | grep -qx pre-push \
    && [[ "$commit_cmd" == '[ "$CLAUDECODE" = 1 ] || exit 0; exec '*'review-gate pre-commit' ]] \
    && [[ "$push_cmd" == '[ "$CLAUDECODE" = 1 ] || exit 0; exec '*'review-gate pre-push' ]]; then
    pass "global git config runs review-gate on pre-commit and pre-push, for Claude only"
  else
    fail "global git config doesn't register the review-gate hooks (apply ~/.config/git/config); skipping the gate tests"
    return
  fi

  local fx=""
  review_gate_cleanup() {
    [ -n "$fx" ] && rm -rf "$fx"
  }
  trap review_gate_cleanup EXIT
  fx="$(mktemp -d)"

  # A repo wired like the global git config, but pointing at $REVIEW_GATE.
  # Repo-local config is read after global, so these commands win.
  rg_repo() {
    local dir="$1"
    git init -q -b main "$dir"
    git -C "$dir" config user.name test
    git -C "$dir" config user.email test@example.com
    git -C "$dir" config commit.gpgsign false
    git -C "$dir" config hook.claude-review-commit.command "\"$REVIEW_GATE\" pre-commit"
    git -C "$dir" config hook.claude-review-push.command "\"$REVIEW_GATE\" pre-push"
  }
  rg_with_remote() {
    local dir="$1"
    rg_repo "$dir"
    git init -q --bare "$dir.remote.git"
    git -C "$dir" remote add origin "$dir.remote.git"
  }
  # Claude's commands: CLAUDECODE=1, as Claude Code sets for its Bash calls.
  rg_claude() {
    (cd "$1" && shift && CLAUDECODE=1 "$@")
  }
  # The user's own commands (lazygit, a terminal). Unset explicitly, since
  # these tests may themselves run inside a Claude Code session.
  rg_user() {
    (cd "$1" && shift && env -u CLAUDECODE "$@")
  }
  rg_stage() {
    printf '%s\n' "$3" >"$1/$2"
    git -C "$1" add "$2"
  }
  # A triage file where /review writes one for the repo's current branch.
  # Each call writes a new file, as each /review run does, since mark
  # refuses a triage file that already recorded a review.
  rg_triage() {
    local branch n file
    branch=$(git -C "$1" branch --show-current)
    mkdir -p "$1/.reviews/code"
    n=$(find "$1/.reviews/code" -name '*-triage.md' | wc -l | tr -d ' ')
    file="$1/.reviews/code/2026-01-01-$(printf '%06d' "$n")-${branch//\//-}-triage.md"
    printf -- '---\nround: 1\n---\n' >"$file"
    printf '%s' "$file"
  }
  rg_mark() {
    local dir="$1"
    shift
    rg_claude "$dir" "$REVIEW_GATE" mark "$@" "$(rg_triage "$dir")" >/dev/null
  }

  local r="$fx/repo" out

  # Git that predates config hooks ignores hook.<name>.event, so the gate
  # silently doesn't run while commits no longer prompt.
  local probe="$fx/probe"
  rg_with_remote "$probe"
  rg_stage "$probe" p.txt one
  out=$(rg_claude "$probe" git commit -qm probe 2>&1) || true
  if ! grep -q 'review-gate: no review covers this commit' <<<"$out"; then
    fail "$(git --version) didn't run the review gate on a Claude commit, so the gate is off; skipping the gate tests"
    trap - EXIT
    review_gate_cleanup
    return
  fi
  pass "git runs config hooks, so the gate is active"

  # ---- Commit gate ----
  rg_with_remote "$r"
  printf '.reviews/\n' >"$r/.gitignore"
  git -C "$r" add .gitignore
  if rg_user "$r" git commit -qm "user commit" >/dev/null 2>&1; then
    pass "commit without CLAUDECODE is not gated (the user's own commits)"
  else
    fail "commit without CLAUDECODE was refused"
  fi
  rg_stage "$r" a.txt zero
  # The global command, with its script path pointing nowhere.
  if rg_user "$r" git -c "hook.claude-review-commit.command=${commit_cmd//review-gate/missing-review-gate}" \
    commit -qm "user commit, script missing" >/dev/null 2>&1; then
    pass "the user's commits don't need the script installed"
  else
    fail "a user commit failed because the review-gate script is missing"
  fi

  rg_stage "$r" a.txt two
  if out=$(rg_claude "$r" git commit -qm unreviewed 2>&1); then
    fail "unreviewed commit by Claude was allowed"
  elif grep -q 'run /review, then commit again' <<<"$out" && ! grep -qi 'defer' <<<"$out"; then
    pass "unreviewed commit is refused, naming /review as the only way forward"
  else
    fail "refusal message doesn't name /review alone: $out"
  fi
  # Claude reads the refusal, so it must not say how to clear the variable
  # the gate depends on.
  if grep -qiE 'unset|env -u|CLAUDECODE=' <<<"$out"; then
    fail "refusal message tells the reader how to clear CLAUDECODE: $out"
  else
    pass "refusal message doesn't say how to turn the gate off"
  fi

  rg_mark "$r"
  if rg_claude "$r" git commit -qm reviewed >/dev/null 2>&1; then
    pass "commit matching a recorded review is allowed"
  else
    fail "reviewed commit was refused"
  fi

  rg_stage "$r" a.txt three
  rg_mark "$r"
  rg_stage "$r" a.txt three-edited
  if rg_claude "$r" git commit -qm edited >/dev/null 2>&1; then
    fail "commit edited after its review was allowed"
  else
    pass "editing staged changes after a review requires a new review"
  fi

  git -C "$r" reset -q --hard
  rg_stage "$r" a.txt four
  rg_mark "$r"
  printf 'unstaged\n' >"$r/a.txt"
  if rg_claude "$r" git commit -qam "commit -a" >/dev/null 2>&1; then
    fail "commit -a with unreviewed working-tree changes was allowed"
  else
    pass "commit -a checks the tree it commits, not the index"
  fi
  git -C "$r" checkout -q -- a.txt
  rg_claude "$r" git commit -qm four >/dev/null 2>&1

  if rg_claude "$r" git commit -q --amend -m "reworded" >/dev/null 2>&1; then
    pass "amend that changes only the message is allowed"
  else
    fail "message-only amend was refused"
  fi
  rg_stage "$r" a.txt amended
  if rg_claude "$r" git commit -q --amend --no-edit >/dev/null 2>&1; then
    fail "amend with unreviewed content was allowed"
  else
    pass "amend that changes content needs a review"
  fi
  git -C "$r" reset -q --hard

  # Each wrong file exists, so each refusal comes from the check it names.
  rg_mark_refused() {
    local file="$1" why="$2"
    if out=$(rg_claude "$r" "$REVIEW_GATE" mark "$file" 2>&1); then
      fail "mark accepted $file"
    elif grep -q "$why" <<<"$out"; then
      pass "mark refuses $(basename "$file") ($why)"
    else
      fail "mark refused $file for the wrong reason: $out"
    fi
  }
  rg_triage "$r" >/dev/null
  local other
  for other in 2026-01-01-000000-other-branch-triage.md 2026-01-01-000000-chore-main-triage.md notes-main-triage.md; do
    printf -- '---\nround: 1\n---\n' >"$r/.reviews/code/$other"
  done
  rg_mark_refused "$r/a.txt" "must be in the repo's .reviews/code/"
  rg_mark_refused "$r/.reviews/code/2026-01-01-000000-other-branch-triage.md" "must be this branch's"
  rg_mark_refused "$r/.reviews/code/2026-01-01-000000-chore-main-triage.md" "must be this branch's"
  rg_mark_refused "$r/.reviews/code/notes-main-triage.md" "must be this branch's"
  git -C "$r" switch -q --detach
  rg_mark_refused "$r/.reviews/code/2026-01-01-000000-main-triage.md" "HEAD is detached"
  git -C "$r" switch -q main
  # A triage file that already recorded a review can't record another tree.
  local used
  used=$(rg_triage "$r")
  rg_claude "$r" "$REVIEW_GATE" mark "$used" >/dev/null
  rg_stage "$r" a.txt after-the-review
  rg_mark_refused "$used" "already recorded a review"
  git -C "$r" reset -q --hard
  # A triage file whose round ended can't record: its frontmatter's outcome
  # says how the round ended. Only the frontmatter counts, not the body.
  rg_outcome() {
    local file
    file=$(rg_triage "$r")
    printf -- '---\nbranch: main\n%s\n---\n\n## Summary\n' "$1" >"$file"
    printf '%s' "$file"
  }
  rg_mark_refused "$(rg_outcome 'outcome: next-round')" "handed off to the next round"
  rg_mark_refused "$(rg_outcome $'outcome: not-recorded\noutcome-reason: base reviewer failed')" "ended Not recorded: base reviewer failed"
  rg_mark_refused "$(rg_outcome 'outcome: paused')" "is paused"
  rg_mark_refused "$(rg_outcome 'outcome: recorded')" "already recorded a review"
  rg_mark_refused "$(rg_outcome 'outcome: done')" "unknown outcome"
  local crlf
  crlf=$(rg_triage "$r")
  printf -- '---\r\noutcome: next-round\r\n---\r\n' >"$crlf"
  rg_mark_refused "$crlf" "handed off to the next round"
  # Without frontmatter the outcome can't be read, so the file can't record.
  local bare
  bare=$(rg_triage "$r")
  printf -- '\n---\noutcome: not-recorded\n---\n' >"$bare"
  rg_mark_refused "$bare" "has no frontmatter"
  bare=$(rg_triage "$r")
  printf -- '---\nround: 1\n' >"$bare"
  rg_mark_refused "$bare" "has no frontmatter"
  rg_mark_accepted() {
    local file
    file=$(rg_triage "$r")
    printf -- "$1" >"$file"
    if rg_claude "$r" "$REVIEW_GATE" mark "$file" >/dev/null 2>&1; then
      pass "mark accepts a triage file $2"
    else
      fail "mark refused a triage file $2"
    fi
    git -C "$r" reset -q --hard
  }
  rg_mark_accepted '---\nbranch: main\nround: 1\n---\n\noutcome: next-round is quoted here\n' "with no outcome in its frontmatter"
  rg_mark_accepted '---\noutcome:\n---\n' "with an empty outcome"
  rg_mark_accepted '---\noutcome: null\n---\n' "with outcome: null"

  # ---- No way to skip a review ----
  rg_stage "$r" a.txt five
  local cmd
  # No commit skips its review, so review-gate has no `defer` or `last`.
  for cmd in defer last; do
    if rg_claude "$r" "$REVIEW_GATE" "$cmd" "some reason" >/dev/null 2>&1; then
      fail "review-gate $cmd still exists"
    else
      pass "review-gate has no $cmd command"
    fi
  done
  # The push check matches a rebased commit by its change, so mark records
  # the staged change's patch-id beside its tree.
  rg_mark "$r"
  local log
  log="$(git -C "$r" rev-parse --path-format=absolute --git-common-dir)/claude-reviews.log"
  if tail -n 1 "$log" | cut -f8 | grep -qx '[0-9a-f]\{40\}'; then
    pass "mark records a patch-id"
  else
    fail "mark didn't record a patch-id: $(tail -n 1 "$log")"
  fi
  git -C "$r" reset -q --hard

  # ---- Repo scope ----
  local nr="$fx/no-remote"
  rg_repo "$nr"
  rg_stage "$nr" n.txt one
  if rg_claude "$nr" git commit -qm "no remote" >/dev/null 2>&1; then
    pass "repo with no remote is not gated"
  else
    fail "repo with no remote was gated"
  fi
  # A push to a URL from that repo is checked: the push proves a remote.
  git init -q --bare "$nr.url-remote.git"
  if out=$(rg_claude "$nr" git push -q "$nr.url-remote.git" HEAD:refs/heads/main 2>&1); then
    fail "a push to a URL from a repo with no configured remote wasn't checked"
  elif grep -q 'review-gate' <<<"$out"; then
    pass "a push to a URL from a repo with no configured remote is checked"
  else
    fail "push to a URL failed for another reason: $out"
  fi
  git -C "$nr" config claude.reviewHook true
  rg_stage "$nr" n.txt two
  if rg_claude "$nr" git commit -qm "opted in" >/dev/null 2>&1; then
    fail "claude.reviewHook=true didn't opt a no-remote repo in"
  else
    pass "claude.reviewHook=true opts a repo in"
  fi
  git -C "$nr" config claude.reviewHook maybe
  if out=$(rg_claude "$nr" git commit -qm "bad value" 2>&1); then
    fail "an invalid claude.reviewHook value was ignored"
  elif grep -q 'must be true or false' <<<"$out"; then
    pass "an invalid claude.reviewHook value is refused, not ignored"
  else
    fail "invalid claude.reviewHook refusal doesn't say why: $out"
  fi
  git -C "$r" config claude.reviewHook false
  rg_stage "$r" a.txt opted-out
  if rg_claude "$r" git commit -qm "opted out" >/dev/null 2>&1; then
    pass "claude.reviewHook=false opts a repo out"
  else
    fail "claude.reviewHook=false didn't opt the repo out"
  fi
  git -C "$r" config --unset claude.reviewHook

  # ---- The repo's own hooks still run, after the gate ----
  local hd="$fx/hookdir"
  rg_with_remote "$hd"
  git -C "$hd" config hook.claude-review-commit.command "echo gate >>\"$fx/order\"; \"$REVIEW_GATE\" pre-commit"
  printf '#!/bin/sh\necho repo-hook >>"%s/order"\n' "$fx" >"$hd/.git/hooks/pre-commit"
  printf '#!/bin/sh\ncat >"%s/pre-push-stdin"\n' "$fx" >"$hd/.git/hooks/pre-push"
  chmod +x "$hd/.git/hooks/pre-commit" "$hd/.git/hooks/pre-push"
  rg_stage "$hd" h.txt one
  rg_mark "$hd"
  rg_claude "$hd" git commit -qm one >/dev/null 2>&1
  if [ "$(tr '\n' ' ' <"$fx/order" 2>/dev/null)" = "gate repo-hook " ]; then
    pass "repo's own pre-commit hook still runs, after the gate"
  else
    fail "hook order was '$(tr '\n' ' ' <"$fx/order" 2>/dev/null)', expected 'gate repo-hook'"
  fi
  rg_mark "$hd" --branch
  rg_claude "$hd" git push -q origin main >/dev/null 2>&1
  if grep -q 'refs/heads/main' "$fx/pre-push-stdin" 2>/dev/null; then
    pass "repo's own pre-push hook still gets the pushed refs"
  else
    fail "repo's own pre-push hook got no refs on stdin"
  fi

  # ---- Push gate ----
  local up="$fx/user-push"
  rg_with_remote "$up"
  rg_stage "$up" u.txt one
  rg_user "$up" git commit -qm one >/dev/null 2>&1
  if rg_user "$up" git push -q origin main >/dev/null 2>&1; then
    pass "push without CLAUDECODE is not gated"
  else
    fail "push without CLAUDECODE was refused"
  fi

  # A branch with one commit: its commit review is the whole branch, so the
  # first push needs no branch review.
  local p="$fx/push"
  rg_with_remote "$p"
  rg_stage "$p" p.txt one
  rg_mark "$p"
  rg_claude "$p" git commit -qm one >/dev/null 2>&1
  if rg_claude "$p" "$REVIEW_GATE" covered >/dev/null 2>&1; then
    pass "covered accepts a one-commit branch with its commit review"
  else
    fail "covered refused a one-commit branch with its commit review"
  fi
  if rg_claude "$p" git push -q -u origin main >/dev/null 2>&1; then
    pass "first push of a one-commit branch needs only its commit review"
  else
    fail "first push of a reviewed one-commit branch was refused"
  fi
  # A one-commit branch whose commit has no review of its own (the user's,
  # or made while the gate was off) still needs a review.
  local oc="$fx/one-unreviewed"
  rg_with_remote "$oc"
  rg_stage "$oc" o.txt one
  rg_user "$oc" git commit -qm by-user >/dev/null 2>&1
  if out=$(rg_claude "$oc" "$REVIEW_GATE" covered 2>&1); then
    fail "covered accepted a one-commit branch whose commit has no review"
  elif [ "$out" = "/review branch" ]; then
    pass "covered refuses a one-commit branch whose commit has no review"
  else
    fail "covered printed '$out', expected '/review branch'"
  fi
  if out=$(rg_claude "$oc" git push -q origin main 2>&1); then
    fail "first push of an unreviewed one-commit branch was allowed"
  elif grep -q ' by-user$' <<<"$out"; then
    pass "first push of a one-commit branch with no review is refused and names the commit"
  else
    fail "push of an unreviewed one-commit branch refused for the wrong reason: $out"
  fi

  # Two commits, each reviewed: the first push also needs a review of the
  # whole branch, recorded on exactly the commit being pushed.
  local mc="$fx/multi"
  rg_with_remote "$mc"
  rg_stage "$mc" m.txt one
  rg_mark "$mc"
  rg_claude "$mc" git commit -qm one >/dev/null 2>&1
  rg_stage "$mc" m.txt two
  rg_mark "$mc"
  rg_claude "$mc" git commit -qm two >/dev/null 2>&1
  if out=$(rg_claude "$mc" git push -q origin main 2>&1); then
    fail "first push of two commits without a branch review was allowed"
  elif grep -q 'needs a review of the whole branch' <<<"$out" \
    && grep -q 'Run /review branch, commit any fixes it stages, then push again' <<<"$out"; then
    pass "first push of two commits needs a branch review, and says what to run"
  else
    fail "first-push refusal doesn't say what to run: $out"
  fi
  if out=$(rg_claude "$mc" "$REVIEW_GATE" covered 2>&1); then
    fail "covered accepted two commits with no branch review"
  elif [ "$out" = "/review branch" ]; then
    pass "covered refuses two commits with no branch review and names the review"
  else
    fail "covered printed '$out', expected '/review branch'"
  fi
  # The branch review's fixes, committed from the tree it recorded.
  rg_stage "$mc" m.txt two-fixed
  rg_mark "$mc" --branch
  rg_claude "$mc" git commit -qm "review fixes" >/dev/null 2>&1
  if rg_claude "$mc" "$REVIEW_GATE" covered >/dev/null 2>&1 \
    && rg_claude "$mc" git push -q -u origin main >/dev/null 2>&1; then
    pass "a branch review's fix commit can be pushed: its tree is the one recorded"
  else
    fail "push of a branch review's fix commit was refused"
  fi
  if rg_claude "$mc" "$REVIEW_GATE" covered >/dev/null 2>&1; then
    pass "covered accepts a HEAD that is already pushed"
  else
    fail "covered refused a HEAD that is already pushed"
  fi

  # Anything committed after the branch review, even with its own review,
  # means the branch review didn't see what is pushed.
  local ar="$fx/after-review"
  rg_with_remote "$ar"
  rg_stage "$ar" a.txt one
  rg_mark "$ar"
  rg_claude "$ar" git commit -qm one >/dev/null 2>&1
  rg_stage "$ar" a.txt two
  rg_mark "$ar" --branch
  rg_claude "$ar" git commit -qm two >/dev/null 2>&1
  rg_stage "$ar" a.txt three
  rg_mark "$ar"
  rg_claude "$ar" git commit -qm three >/dev/null 2>&1
  if out=$(rg_claude "$ar" git push -q origin main 2>&1); then
    fail "first push allowed a commit made after the branch review"
  elif grep -q 'needs a review of the whole branch' <<<"$out"; then
    pass "a commit after the branch review needs a new branch review before the first push"
  else
    fail "first push refused a commit after the branch review for the wrong reason: $out"
  fi

  # A branch cut from a pushed branch needs its own branch review: one in
  # pushed history covered the other branch's PR.
  local sb="$fx/stacked"
  rg_with_remote "$sb"
  rg_stage "$sb" s.txt one
  rg_mark "$sb"
  rg_claude "$sb" git commit -qm one >/dev/null 2>&1
  rg_stage "$sb" s.txt two
  rg_mark "$sb" --branch
  rg_claude "$sb" git commit -qm two >/dev/null 2>&1
  rg_claude "$sb" git push -q -u origin main >/dev/null 2>&1
  git -C "$sb" switch -q -c feat-b
  rg_stage "$sb" s.txt three
  rg_mark "$sb"
  rg_claude "$sb" git commit -qm three >/dev/null 2>&1
  rg_stage "$sb" s.txt four
  rg_mark "$sb"
  rg_claude "$sb" git commit -qm four >/dev/null 2>&1
  if out=$(rg_claude "$sb" git push -q origin feat-b 2>&1); then
    fail "first push of a stacked branch was allowed with no branch review of its own"
  elif grep -q 'needs a review of the whole branch' <<<"$out"; then
    pass "first push of a stacked branch needs its own branch review"
  else
    fail "stacked-branch push refused for the wrong reason: $out"
  fi

  # Later pushes: each new commit needs its own review, or a branch review
  # of a commit built on it. The user's own commits and commits made while
  # the gate was off have no review of their own.
  rg_stage "$p" p.txt two
  rg_mark "$p"
  rg_claude "$p" git commit -qm two >/dev/null 2>&1
  rg_stage "$p" p.txt three
  rg_mark "$p"
  rg_claude "$p" git commit -qm three >/dev/null 2>&1
  if rg_claude "$p" git push -q origin main >/dev/null 2>&1; then
    pass "later push of commits with their own reviews is allowed"
  else
    fail "later push of reviewed commits was refused"
  fi
  rg_stage "$p" p.txt by-user
  rg_user "$p" git commit -qm by-user >/dev/null 2>&1
  rg_stage "$p" p.txt reviewed-after
  rg_mark "$p"
  rg_claude "$p" git commit -qm reviewed-after >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin main 2>&1); then
    fail "push of a commit with no review was allowed"
  elif grep -q ' by-user$' <<<"$out" && ! grep -q ' reviewed-after$' <<<"$out" \
    && grep -q 'Run /review branch, commit any fixes it stages, then push again' <<<"$out"; then
    pass "push refuses a commit with no review, names only it, and names /review branch"
  else
    fail "push refusal doesn't name just the uncovered commit: $out"
  fi
  rg_mark "$p" --branch
  if rg_claude "$p" git push -q origin main >/dev/null 2>&1; then
    pass "a branch review of HEAD covers the commits under it"
  else
    fail "push after a branch review of HEAD was refused"
  fi

  # A rebase gives commits new trees; a commit whose change is the same is
  # matched by its patch-id, and one whose change differs needs a review.
  local rb="$fx/rebase"
  rg_with_remote "$rb"
  printf 'a\nb\nc\n' >"$rb/f.txt"
  printf 'x\n' >"$rb/g.txt"
  git -C "$rb" add f.txt g.txt
  rg_user "$rb" git commit -qm base >/dev/null 2>&1
  rg_user "$rb" git push -q -u origin main >/dev/null 2>&1
  git -C "$rb" switch -q -c feat
  printf 'a\nB\nc\n' >"$rb/f.txt"
  git -C "$rb" add f.txt
  rg_mark "$rb"
  rg_claude "$rb" git commit -qm change >/dev/null 2>&1
  git -C "$rb" switch -q main
  printf 'y\n' >"$rb/g.txt"
  git -C "$rb" add g.txt
  rg_user "$rb" git commit -qm "main moves" >/dev/null 2>&1
  rg_user "$rb" git push -q origin main >/dev/null 2>&1
  git -C "$rb" switch -q feat
  rg_user "$rb" git rebase -q main >/dev/null 2>&1
  if [ "$(git -C "$rb" show HEAD:g.txt)" != y ]; then
    fail "setup: the rebase didn't happen, so this case tests nothing"
  elif rg_claude "$rb" git push -q origin feat >/dev/null 2>&1; then
    pass "a commit rebased with no conflict keeps its review"
  else
    fail "a cleanly rebased reviewed commit was refused"
  fi
  git -C "$rb" switch -q main
  printf 'a\nZ\nc\n' >"$rb/f.txt"
  git -C "$rb" add f.txt
  rg_user "$rb" git commit -qm "main conflicts" >/dev/null 2>&1
  rg_user "$rb" git push -q origin main >/dev/null 2>&1
  git -C "$rb" switch -q -c feat-2 main~1
  printf 'a\nB\nc\n' >"$rb/f.txt"
  git -C "$rb" add f.txt
  rg_mark "$rb"
  rg_claude "$rb" git commit -qm change-2 >/dev/null 2>&1
  rg_user "$rb" git rebase -q main >/dev/null 2>&1 || true
  printf 'a\nBZ\nc\n' >"$rb/f.txt"
  git -C "$rb" add f.txt
  rg_user "$rb" env GIT_EDITOR=true git rebase --continue >/dev/null 2>&1
  if [ "$(git -C "$rb" show HEAD:f.txt | sed -n 2p)" != BZ ]; then
    fail "setup: the conflicted rebase didn't finish, so this case tests nothing"
  elif out=$(rg_claude "$rb" git push -q origin feat-2 2>&1); then
    fail "a commit whose change differs after a rebase kept its old review"
  elif grep -q ' change-2$' <<<"$out"; then
    pass "a commit whose change differs after a rebase needs a new review"
  else
    fail "push after a conflicted rebase refused for the wrong reason: $out"
  fi

  # A conflict resolved with a change that differs only in whitespace still
  # needs a review: indentation changes what Python or YAML does.
  local ws="$fx/whitespace"
  rg_with_remote "$ws"
  printf 'a\nb\nc\n' >"$ws/w.txt"
  git -C "$ws" add w.txt
  rg_user "$ws" git commit -qm base >/dev/null 2>&1
  rg_user "$ws" git push -q -u origin main >/dev/null 2>&1
  git -C "$ws" switch -q -c ws-feat
  printf 'a\n  X\nc\n' >"$ws/w.txt"
  git -C "$ws" add w.txt
  rg_mark "$ws"
  rg_claude "$ws" git commit -qm indented >/dev/null 2>&1
  local reviewed_sha
  reviewed_sha=$(git -C "$ws" rev-parse HEAD)
  git -C "$ws" switch -q main
  printf 'a\n b\nc\n' >"$ws/w.txt"
  git -C "$ws" add w.txt
  rg_user "$ws" git commit -qm "main reindents" >/dev/null 2>&1
  rg_user "$ws" git push -q origin main >/dev/null 2>&1
  git -C "$ws" switch -q ws-feat
  rg_user "$ws" git rebase -q main >/dev/null 2>&1 || true
  printf 'a\nX\nc\n' >"$ws/w.txt"
  git -C "$ws" add w.txt
  rg_user "$ws" env GIT_EDITOR=true git rebase --continue >/dev/null 2>&1
  if [ "$(git -C "$ws" diff-tree -p HEAD~1 HEAD | git patch-id --stable | cut -d' ' -f1)" \
    != "$(git -C "$ws" diff-tree -p "$reviewed_sha~1" "$reviewed_sha" | git patch-id --stable | cut -d' ' -f1)" ]; then
    fail "setup: the resolution differs in more than whitespace, so this case tests nothing"
  elif out=$(rg_claude "$ws" git push -q origin ws-feat 2>&1); then
    fail "a conflict resolution that differs only in whitespace kept the old review"
  elif grep -q ' indented$' <<<"$out"; then
    pass "a conflict resolution that differs only in whitespace needs a new review"
  else
    fail "push after a whitespace-only resolution refused for the wrong reason: $out"
  fi

  # A merge commit has no single change to match; the unpushed commits it
  # brings in are checked one by one. A merge edited by hand is finished
  # with `git commit`, which runs the commit check.
  git -C "$p" switch -q -c side
  rg_stage "$p" side.txt one
  rg_mark "$p"
  rg_claude "$p" git commit -qm side-one >/dev/null 2>&1
  git -C "$p" switch -q main
  rg_stage "$p" p.txt main-only
  rg_user "$p" git commit -qm main-only >/dev/null 2>&1
  rg_user "$p" git merge -q --no-edit side >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin main 2>&1); then
    fail "a merge pushed a commit with no review"
  elif grep -q ' main-only$' <<<"$out" && ! grep -q ' side-one$' <<<"$out" \
    && ! grep -q "Merge branch" <<<"$out"; then
    pass "a merge's commits are checked one by one, and the merge itself is skipped"
  else
    fail "push refusal after a merge named the wrong commits: $out"
  fi
  git -C "$p" reset -q --hard origin/main

  git -C "$p" tag v1 HEAD~1
  if rg_claude "$p" git push -q origin v1 >/dev/null 2>&1; then
    pass "a tag on an already-pushed commit can be pushed"
  else
    fail "a tag on an already-pushed commit was refused"
  fi
  # A tag publishes the commits under it, so a tag on an unreviewed
  # commit gets the same check as a branch push.
  rg_stage "$p" p.txt tagged
  rg_user "$p" git commit -qm tagged >/dev/null 2>&1
  git -C "$p" tag v2
  if out=$(rg_claude "$p" git push -q origin v2 2>&1); then
    fail "a tag on an unreviewed commit was pushed"
  elif grep -q ' tagged$' <<<"$out"; then
    pass "a tag on an unreviewed commit is refused and names it"
  else
    fail "tag push refusal didn't name the commit: $out"
  fi
  git -C "$p" tag -d v2 >/dev/null
  git -C "$p" reset -q --hard origin/main
  # Any other ref (not a branch, not a tag) gets the same check as a
  # later branch push, so unreviewed commits can't go out that way.
  rg_stage "$p" p.txt custom-ref
  rg_user "$p" git commit -qm custom-ref >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin HEAD:refs/review/x 2>&1); then
    fail "an unreviewed commit was pushed to a custom ref"
  elif grep -q ' custom-ref$' <<<"$out"; then
    pass "a push to a custom ref is checked like a branch push"
  else
    fail "custom-ref push refusal didn't name the commit: $out"
  fi
  git -C "$p" reset -q --hard origin/main

  # ---- A commit review covers the change from its base, not just a tree ----
  local am="$fx/amend"
  rg_with_remote "$am"
  rg_stage "$am" m.txt base
  rg_mark "$am"
  rg_claude "$am" git commit -qm base >/dev/null 2>&1
  rg_claude "$am" git push -q -u origin main >/dev/null 2>&1
  # An unreviewed commit A, then a reviewed change amended into it: the
  # review saw only A->T, so the amended commit's change from base isn't
  # covered.
  rg_stage "$am" m.txt unreviewed-a
  rg_user "$am" git commit -qm a >/dev/null 2>&1
  rg_stage "$am" n.txt reviewed-b
  rg_mark "$am"
  rg_claude "$am" git commit -q --amend -m "a and b" >/dev/null 2>&1
  if [ "$(git -C "$am" log -1 --format=%s)" != "a and b" ]; then
    fail "setup: the amend didn't happen, so this case tests nothing"
  elif rg_claude "$am" git push -q origin main >/dev/null 2>&1; then
    fail "an amend folding a reviewed change into an unreviewed commit was pushed"
  else
    pass "an amend into an unreviewed commit isn't covered by the later review"
  fi
  # A reviewed change amended into a reviewed commit: the reviews chain from
  # the commit's parent to its tree.
  git -C "$am" reset -q --hard origin/main
  rg_stage "$am" m.txt reviewed-a
  rg_mark "$am"
  rg_claude "$am" git commit -qm a >/dev/null 2>&1
  rg_stage "$am" n.txt reviewed-b
  rg_mark "$am"
  rg_claude "$am" git commit -q --amend -m "a and b" >/dev/null 2>&1
  if rg_claude "$am" git push -q origin main >/dev/null 2>&1; then
    pass "an amend of a reviewed commit with a reviewed change can be pushed"
  else
    fail "an amend of a reviewed commit with a reviewed change was refused"
  fi
  # Two commits each reviewed, squashed into one: the reviews chain from
  # the squashed commit's parent to its tree, so it's covered.
  rg_stage "$am" m.txt reviewed-c
  rg_mark "$am"
  rg_claude "$am" git commit -qm c >/dev/null 2>&1
  rg_stage "$am" n.txt reviewed-d
  rg_mark "$am"
  rg_claude "$am" git commit -qm d >/dev/null 2>&1
  git -C "$am" reset -q --soft origin/main
  rg_claude "$am" git commit -qm "c and d" >/dev/null 2>&1
  if rg_claude "$am" git push -q origin main >/dev/null 2>&1; then
    pass "a squash of commits that were each reviewed can be pushed"
  else
    fail "a squash of reviewed commits was refused"
  fi
  # A branch review covers the commit it ran on (or one that commits its
  # staged fixes), not every commit that later has the same tree: an
  # unreviewed commit followed by its revert has the reviewed tree again.
  rg_stage "$am" m.txt reviewed-tip
  rg_mark "$am" --branch
  rg_claude "$am" git commit -qm tip >/dev/null 2>&1
  rg_claude "$am" git push -q origin main >/dev/null 2>&1
  printf 'secret\n' >"$am/leak.txt"
  git -C "$am" add leak.txt
  rg_user "$am" git commit -qm "add leak" >/dev/null 2>&1
  git -C "$am" rm -q leak.txt
  rg_user "$am" git commit -qm "remove leak" >/dev/null 2>&1
  if [ "$(git -C "$am" rev-parse 'HEAD^{tree}')" != "$(git -C "$am" rev-parse 'origin/main^{tree}')" ]; then
    fail "setup: the revert didn't restore the reviewed tree, so this case tests nothing"
  elif out=$(rg_claude "$am" git push -q origin main 2>&1); then
    fail "an unreviewed commit hidden by a revert to a branch-reviewed tree was pushed"
  elif grep -q ' add leak$' <<<"$out"; then
    pass "a branch review doesn't cover a later commit that only repeats its tree"
  else
    fail "push refusal after a revert didn't name the unreviewed commit: $out"
  fi

  # A message-only amend of a branch-reviewed commit keeps its tree and
  # parent, so the branch review still covers it.
  local rw="$fx/reword"
  rg_with_remote "$rw"
  rg_stage "$rw" base.txt base
  rg_user "$rw" git commit -qm base >/dev/null 2>&1
  rg_stage "$rw" r.txt one
  rg_user "$rw" git commit -qm "first wording" >/dev/null 2>&1
  # The branch review runs on the commit already made, then it's reworded.
  rg_mark "$rw" --branch
  rg_claude "$rw" git commit -q --amend -m "second wording" >/dev/null 2>&1
  if [ "$(git -C "$rw" log -1 --format=%s)" != "second wording" ]; then
    fail "setup: the reword didn't happen, so this case tests nothing"
  elif rg_claude "$rw" git push -q -u origin main >/dev/null 2>&1; then
    pass "a reworded branch-reviewed commit can still be pushed"
  else
    fail "a message-only amend of a branch-reviewed commit was refused"
  fi
  # A branch review's staged fixes amended into the reviewed commit (not
  # committed on top) are covered too: same parent, the recorded tree.
  rg_stage "$rw" r.txt two
  rg_user "$rw" git commit -qm "needs a fix" >/dev/null 2>&1
  rg_stage "$rw" r.txt two-fixed
  rg_mark "$rw" --branch
  rg_claude "$rw" git commit -q --amend --no-edit >/dev/null 2>&1
  if [ "$(git -C "$rw" show HEAD:r.txt)" != "two-fixed" ]; then
    fail "setup: the fix wasn't amended in, so this case tests nothing"
  elif rg_claude "$rw" git push -q origin main >/dev/null 2>&1; then
    pass "a branch review's fixes amended into the reviewed commit can be pushed"
  else
    fail "a branch review's fixes amended into the reviewed commit were refused"
  fi

  # A review recorded early in a long log still covers its commit (the
  # check reads the whole log, so an early match can't break the pipe).
  local ll="$fx/long-log"
  rg_with_remote "$ll"
  rg_stage "$ll" l.txt one
  rg_mark "$ll"
  local lf
  lf="$(git -C "$ll" rev-parse --path-format=absolute --git-common-dir)/claude-reviews.log"
  local i
  for i in $(seq 4000); do
    printf '%040d\tcommit\t2026-01-01T00:00:00Z\tmain\tfiller\t%040d\tnone\n' "$i" "$i"
  done >>"$lf"
  if rg_claude "$ll" git commit -qm one >/dev/null 2>&1; then
    pass "a review early in a long log still covers its commit"
  else
    fail "a commit reviewed early in a long log was refused"
  fi

  # ---- A review recorded in a worktree ----
  local wt="$fx/push-wt"
  git -C "$p" worktree add -q -b wt-branch "$wt" >/dev/null 2>&1
  rg_stage "$wt" w.txt one
  rg_mark "$wt"
  if rg_claude "$wt" git commit -qm "in worktree" >/dev/null 2>&1; then
    pass "a review recorded in a worktree covers its commit"
  else
    fail "worktree commit after a review was refused"
  fi

  # A triage file in a sibling worktree's .reviews/code/ (neither this
  # worktree nor the main checkout) is accepted.
  local wt2="$fx/push-wt2"
  git -C "$p" worktree add -q -b wt-sibling "$wt2" >/dev/null 2>&1
  git -C "$wt" switch -q -c wt-two
  mkdir -p "$wt2/.reviews/code"
  printf -- '---\nround: 1\n---\n' >"$wt2/.reviews/code/2026-01-01-000000-wt-two-triage.md"
  rg_stage "$wt" w.txt two
  if rg_claude "$wt" "$REVIEW_GATE" mark "$wt2/.reviews/code/2026-01-01-000000-wt-two-triage.md" >/dev/null 2>&1; then
    pass "mark accepts a triage file in another worktree of the repo"
  else
    fail "mark refused a triage file in another worktree of the repo"
  fi

  # Bare-repo workspace: <container>/.bare, worktrees inside the container,
  # triage files at the container root.
  local bw="$fx/bare-ws"
  mkdir -p "$bw/.reviews/code"
  git init -q --bare "$bw/.bare"
  printf 'gitdir: ./.bare\n' >"$bw/.git"
  git -C "$bw" worktree add -q --orphan -b main "$bw/main" >/dev/null 2>&1
  git -C "$bw/main" config commit.gpgsign false
  printf -- '---\nround: 1\n---\n' >"$bw/.reviews/code/2026-01-01-000000-main-triage.md"
  rg_stage "$bw/main" b.txt one
  if rg_claude "$bw/main" "$REVIEW_GATE" mark "$bw/.reviews/code/2026-01-01-000000-main-triage.md" >/dev/null 2>&1; then
    pass "mark accepts a triage file at a bare-repo workspace's root"
  else
    fail "mark refused a triage file at a bare-repo workspace's root"
  fi

  trap - EXIT
  review_gate_cleanup
}
