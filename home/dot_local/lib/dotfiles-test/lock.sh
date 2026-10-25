#!/usr/bin/env bash
# Lock library tests. Each case runs under bash and zsh, since recap-daily
# sources the library from bash and topgrade-daily and `update` from zsh.

DOTFILES_LOCK="${HOME}/.local/lib/dotfiles-lock.sh"

test_dotfiles_lock() {
  section "Job locks"

  # The jobs that use the library are macOS-only, and the age cases use BSD
  # `touch -A`.
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi
  if [ ! -f "$DOTFILES_LOCK" ]; then
    fail "dotfiles-lock.sh not installed at $DOTFILES_LOCK"
    return
  fi

  local tmp sh lock out dead
  tmp=$(mktemp -d)
  lock="$tmp/job.lock"
  # Runs <code> in a fresh <shell> with the library sourced; prints the
  # shell's PID first so cases can compare it with the lock's owner.
  in_shell() {
    local shell="$1" code="$2"
    if [ "$shell" = zsh ]; then
      zsh -fc "source '$DOTFILES_LOCK'; echo \$\$; $code" 2>&1
    else
      # macOS's bash 3.2, which recap-daily runs under.
      /bin/bash -c "source '$DOTFILES_LOCK'; echo \$\$; $code" 2>&1
    fi
  }

  for sh in bash zsh; do

    rm -rf "$lock"
    out=$(in_shell "$sh" "lock_acquire '$lock' && echo ok") || true
    if [ "$(sed -n 2p <<<"$out")" = ok ] && [ "$(cat "$lock/pid")" = "$(sed -n 1p <<<"$out")" ]; then
      pass "$sh: a free lock is taken and records its owner"
    else
      fail "$sh: free lock not taken: $(tr '\n' '|' <<<"$out")"
    fi

    # The test runner itself is a live owner.
    rm -rf "$lock" && mkdir "$lock" && echo $$ >"$lock/pid"
    out=$(in_shell "$sh" "lock_acquire '$lock' && echo taken; lock_held '$lock' && echo held") || true
    if ! grep -q taken <<<"$out" && grep -q held <<<"$out" && [ "$(cat "$lock/pid")" = $$ ]; then
      pass "$sh: a lock whose owner runs is held and not taken"
    else
      fail "$sh: live lock mishandled: $(tr '\n' '|' <<<"$out")"
    fi

    # A live PID in a lock from before the last boot is a reused PID.
    touch -t 200001010000 "$lock"
    out=$(in_shell "$sh" "lock_held '$lock' && echo held") || true
    if ! grep -q held <<<"$out"; then
      pass "$sh: a lock from before the last boot is not held, even if its PID runs"
    else
      fail "$sh: pre-boot lock treated as held"
    fi

    # The PID of a process that has already exited.
    sh -c 'exit 0' &
    dead=$!
    wait "$dead"
    echo "$dead" >"$lock/pid"
    out=$(in_shell "$sh" "lock_held '$lock' && echo held; lock_acquire '$lock' && echo taken") || true
    if ! grep -q held <<<"$out" && grep -q taken <<<"$out" \
      && [ "$(cat "$lock/pid")" = "$(sed -n 1p <<<"$out")" ]; then
      pass "$sh: a lock whose owner is gone is cleared and taken"
    else
      fail "$sh: dead owner's lock mishandled: $(tr '\n' '|' <<<"$out")"
    fi

    rm -rf "$lock" && mkdir "$lock"
    out=$(in_shell "$sh" "lock_held '$lock' && echo held") || true
    if grep -q held <<<"$out"; then
      pass "$sh: a lock still being taken (no PID yet) is held"
    else
      fail "$sh: fresh PID-less lock not held"
    fi
    touch -A -000200 "$lock"
    out=$(in_shell "$sh" "lock_held '$lock' && echo held; lock_acquire '$lock' && echo taken") || true
    if ! grep -q held <<<"$out" && grep -q taken <<<"$out"; then
      pass "$sh: a PID-less lock over a minute old is cleared"
    else
      fail "$sh: old PID-less lock mishandled: $(tr '\n' '|' <<<"$out")"
    fi

    rm -rf "$lock" && mkdir "$lock" && echo $$ >"$lock/pid"
    in_shell "$sh" "lock_release '$lock'" >/dev/null || true
    if [ -d "$lock" ]; then
      pass "$sh: release leaves a lock another process owns"
    else
      fail "$sh: released a lock it didn't own"
    fi
    rm -rf "$lock"
    in_shell "$sh" "lock_acquire '$lock' && lock_release '$lock'" >/dev/null || true
    if [ ! -e "$lock" ]; then
      pass "$sh: release removes the owner's lock"
    else
      fail "$sh: owner's release left the lock"
    fi
  done

  rm -rf "$tmp"
}
