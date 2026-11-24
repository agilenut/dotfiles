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
    echo triage >"$file"
    printf '%s' "$file"
  }
  rg_mark() {
    local dir="$1"
    shift
    rg_claude "$dir" "$REVIEW_GATE" mark "$@" "$(rg_triage "$dir")" >/dev/null
  }

  local r="$fx/repo" out

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
  elif grep -q '/review, then commit again' <<<"$out" && grep -q 'review-gate defer' <<<"$out"; then
    pass "unreviewed commit is refused, naming review and defer"
  else
    fail "refusal message doesn't name both ways forward: $out"
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
    echo triage >"$r/.reviews/code/$other"
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

  # ---- Defer ----
  rg_stage "$r" a.txt five
  if rg_claude "$r" "$REVIEW_GATE" defer >/dev/null 2>&1; then
    fail "defer accepted an empty reason"
  else
    pass "defer requires a reason"
  fi
  rg_claude "$r" "$REVIEW_GATE" defer $'end-of-PR\trename' >/dev/null
  if rg_claude "$r" git commit -qm deferred >/dev/null 2>&1; then
    pass "deferred commit is allowed"
  else
    fail "deferred commit was refused"
  fi
  local log
  log="$(git -C "$r" rev-parse --path-format=absolute --git-common-dir)/claude-reviews.log"
  if grep -q 'defer.*end-of-PR rename$' "$log" && ! cut -f1 "$log" | grep -qv '^[0-9a-f]\{40\}$'; then
    pass "defer logs its reason on one line"
  else
    fail "defer reason missing from the review log, or it broke a line"
  fi

  # ---- Repo scope ----
  local nr="$fx/no-remote"
  rg_repo "$nr"
  rg_stage "$nr" n.txt one
  if rg_claude "$nr" git commit -qm "no remote" >/dev/null 2>&1; then
    pass "repo with no remote is not gated"
  else
    fail "repo with no remote was gated"
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

  local p="$fx/push"
  rg_with_remote "$p"
  rg_stage "$p" p.txt one
  rg_mark "$p"
  rg_claude "$p" git commit -qm one >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin main 2>&1); then
    fail "first push without a branch review was allowed"
  elif grep -q 'Run /review branch, then push again' <<<"$out"; then
    pass "first push needs a branch review"
  else
    fail "first-push refusal doesn't say what to run: $out"
  fi
  rg_mark "$p" --branch
  if rg_claude "$p" git push -q origin main >/dev/null 2>&1; then
    pass "first push after a branch review is allowed"
  else
    fail "first push after a branch review was refused"
  fi

  rg_stage "$p" p.txt two
  rg_mark "$p"
  rg_claude "$p" git commit -qm two >/dev/null 2>&1
  if rg_claude "$p" git push -q origin main >/dev/null 2>&1; then
    pass "later push of commits with their own reviews is allowed"
  else
    fail "later push of reviewed commits was refused"
  fi

  rg_stage "$p" p.txt three
  rg_claude "$p" "$REVIEW_GATE" defer "mechanical" >/dev/null
  rg_claude "$p" git commit -qm three >/dev/null 2>&1
  rg_stage "$p" p.txt four
  rg_mark "$p"
  rg_claude "$p" git commit -qm four >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin main 2>&1); then
    fail "push of a deferred commit without a branch review was allowed"
  elif grep -q ' three$' <<<"$out" && ! grep -q ' four$' <<<"$out" \
    && grep -q 'Run /review unreviewed, then push again' <<<"$out"; then
    pass "push refuses a deferred commit below a reviewed one, names only it, and names /review unreviewed"
  else
    fail "push refusal doesn't name just the uncovered commit: $out"
  fi
  rg_mark "$p" --branch
  rg_stage "$p" p.txt five
  rg_claude "$p" "$REVIEW_GATE" defer "after the branch review" >/dev/null
  rg_claude "$p" git commit -qm five >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin main 2>&1); then
    fail "a commit made after a branch review was covered by it"
  elif grep -q ' five$' <<<"$out" && ! grep -q ' three$' <<<"$out"; then
    pass "a branch review covers earlier commits but not later ones"
  else
    fail "push refusal after a branch review named the wrong commits: $out"
  fi
  rg_mark "$p" --branch
  if rg_claude "$p" git push -q origin main >/dev/null 2>&1; then
    pass "push after a branch review of HEAD is allowed"
  else
    fail "push after a branch review of HEAD was refused"
  fi

  # A merged side branch: a branch review of the side branch doesn't cover
  # main-line commits that aren't its ancestors.
  git -C "$p" switch -q -c side
  rg_stage "$p" side.txt one
  rg_claude "$p" "$REVIEW_GATE" defer "side" >/dev/null
  rg_claude "$p" git commit -qm side-one >/dev/null 2>&1
  rg_mark "$p" --branch
  git -C "$p" switch -q main
  rg_stage "$p" p.txt main-only
  rg_claude "$p" "$REVIEW_GATE" defer "main only" >/dev/null
  rg_claude "$p" git commit -qm main-only >/dev/null 2>&1
  rg_user "$p" git merge -q --no-edit side >/dev/null 2>&1
  if out=$(rg_claude "$p" git push -q origin main 2>&1); then
    fail "a branch review of a merged side branch covered main-line commits"
  elif grep -q ' main-only$' <<<"$out" && ! grep -q ' side-one$' <<<"$out"; then
    pass "a branch review covers only the commits it is built on"
  else
    fail "push refusal after a merge named the wrong commits: $out"
  fi
  git -C "$p" reset -q --hard origin/main

  git -C "$p" tag v1 HEAD~1
  if rg_claude "$p" git push -q origin v1 >/dev/null 2>&1; then
    pass "pushing a tag is not gated"
  else
    fail "pushing a tag was refused"
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
  echo triage >"$wt2/.reviews/code/2026-01-01-000000-wt-two-triage.md"
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
  echo triage >"$bw/.reviews/code/2026-01-01-000000-main-triage.md"
  rg_stage "$bw/main" b.txt one
  if rg_claude "$bw/main" "$REVIEW_GATE" mark "$bw/.reviews/code/2026-01-01-000000-main-triage.md" >/dev/null 2>&1; then
    pass "mark accepts a triage file at a bare-repo workspace's root"
  else
    fail "mark refused a triage file at a bare-repo workspace's root"
  fi

  # ---- Branch review of staged fixes, and the last branch review ----
  local br="$fx/branch-fix"
  rg_with_remote "$br"
  rg_stage "$br" f.txt one
  rg_mark "$br" --branch
  rg_claude "$br" git commit -qm one >/dev/null 2>&1
  local branch_reviewed_sha
  branch_reviewed_sha=$(git -C "$br" rev-parse HEAD)
  rg_stage "$br" f.txt two
  rg_mark "$br"
  rg_claude "$br" git commit -qm two >/dev/null 2>&1
  rg_stage "$br" f.txt three
  rg_claude "$br" "$REVIEW_GATE" defer "later" >/dev/null
  rg_claude "$br" git commit -qm three >/dev/null 2>&1
  if [ "$(rg_claude "$br" "$REVIEW_GATE" last)" = "$branch_reviewed_sha" ]; then
    pass "last prints the newest branch-reviewed commit, skipping commit reviews and deferrals"
  else
    fail "last printed '$(rg_claude "$br" "$REVIEW_GATE" last)', expected $branch_reviewed_sha"
  fi
  # A branch review whose fixes are staged: the fix commit is the pushed tip.
  rg_stage "$br" f.txt review-fix
  rg_mark "$br" --branch
  if rg_claude "$br" git commit -qm "review fixes" >/dev/null 2>&1 \
    && rg_claude "$br" git push -q origin main >/dev/null 2>&1; then
    pass "a branch review records its staged fixes, so the fix commit can be pushed"
  else
    fail "push of a branch review's fix commit was refused"
  fi
  if [ -z "$(rg_claude "$nr" "$REVIEW_GATE" last)" ]; then
    pass "last prints nothing when no commit was reviewed"
  else
    fail "last printed a commit in a repo with no reviews"
  fi

  trap - EXIT
  review_gate_cleanup
}
