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

  local tmp shell_name lock out dead
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

  for shell_name in bash zsh; do

    rm -rf "$lock"
    out=$(in_shell "$shell_name" "lock_acquire '$lock' && echo ok") || true
    if [ "$(sed -n 2p <<<"$out")" = ok ] && [ "$(cat "$lock/pid")" = "$(sed -n 1p <<<"$out")" ]; then
      pass "$shell_name: a free lock is taken and records its owner"
    else
      fail "$shell_name: free lock not taken: $(tr '\n' '|' <<<"$out")"
    fi

    # The test runner itself is a live owner.
    rm -rf "$lock" && mkdir "$lock" && echo $$ >"$lock/pid"
    out=$(in_shell "$shell_name" "lock_acquire '$lock' && echo taken; lock_held '$lock' && echo held") || true
    if ! grep -q taken <<<"$out" && grep -q held <<<"$out" && [ "$(cat "$lock/pid")" = $$ ]; then
      pass "$shell_name: a lock whose owner runs is held and not taken"
    else
      fail "$shell_name: live lock mishandled: $(tr '\n' '|' <<<"$out")"
    fi

    # A live PID in a lock from before the last boot is a reused PID. Run
    # with the launchd jobs' PATH, which has no /usr/sbin.
    touch -t 200001010000 "$lock"
    out=$(PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin \
      in_shell "$shell_name" "lock_held '$lock' && echo held") || true
    if ! grep -q held <<<"$out"; then
      pass "$shell_name: a lock from before the last boot is not held, even if its PID runs"
    else
      fail "$shell_name: pre-boot lock treated as held"
    fi

    # The PID of a process that has already exited.
    sh -c 'exit 0' &
    dead=$!
    wait "$dead"
    rm -rf "$lock" && mkdir "$lock" && echo "$dead" >"$lock/pid"
    out=$(in_shell "$shell_name" "lock_held '$lock' && echo held; lock_acquire '$lock' && echo taken") || true
    if ! grep -q held <<<"$out" && grep -q taken <<<"$out" \
      && [ "$(cat "$lock/pid")" = "$(sed -n 1p <<<"$out")" ]; then
      pass "$shell_name: a lock whose owner is gone is cleared and taken"
    else
      fail "$shell_name: dead owner's lock mishandled: $(tr '\n' '|' <<<"$out")"
    fi

    rm -rf "$lock" && mkdir "$lock"
    out=$(in_shell "$shell_name" "lock_held '$lock' && echo held") || true
    if grep -q held <<<"$out"; then
      pass "$shell_name: a lock still being taken (no PID yet) is held"
    else
      fail "$shell_name: fresh PID-less lock not held"
    fi
    touch -A -000200 "$lock"
    out=$(in_shell "$shell_name" "lock_held '$lock' && echo held; lock_acquire '$lock' && echo taken") || true
    if ! grep -q held <<<"$out" && grep -q taken <<<"$out"; then
      pass "$shell_name: a PID-less lock over a minute old is cleared"
    else
      fail "$shell_name: old PID-less lock mishandled: $(tr '\n' '|' <<<"$out")"
    fi

    rm -rf "$lock" && mkdir "$lock" && echo $$ >"$lock/pid"
    in_shell "$shell_name" "lock_release '$lock'" >/dev/null || true
    if [ -d "$lock" ]; then
      pass "$shell_name: release leaves a lock another process owns"
    else
      fail "$shell_name: released a lock it didn't own"
    fi
    rm -rf "$lock"
    in_shell "$shell_name" "lock_acquire '$lock' && lock_release '$lock'" >/dev/null || true
    if [ ! -e "$lock" ]; then
      pass "$shell_name: release removes the owner's lock"
    else
      fail "$shell_name: owner's release left the lock"
    fi
  done

  rm -rf "$tmp"
}
