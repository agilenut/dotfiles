# shellcheck shell=bash
# dotfiles-lock.sh
# =============================================================================
# Locks shared by the scheduled jobs and `update`. A lock is a directory
# holding its owner's PID in `pid`; it counts as held only while that process
# runs, so a lock left by a killed run or a reboot clears on the next try.
#
# Sourced by bash (recap-daily) and zsh (topgrade-daily, `update`), so it
# sticks to syntax both run. $$ is the sourcing shell, which is the owner.
# macOS only (`stat -f`, `kern.boottime`), like the jobs that use it. sysctl
# is called by path: the launchd jobs' PATH leaves out /usr/sbin.

# Succeed when lock <dir> is held by a running process. A lock with no PID yet
# is being taken (between mkdir and the PID write) unless it's over a minute
# old. A lock from before the last boot is never held: PIDs restart at boot,
# so its PID may now belong to an unrelated process.
lock_held() {
  [ -d "$1" ] || return 1
  local boot
  boot=$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null | sed -n 's/^{ sec = \([0-9]*\),.*/\1/p')
  if [ -n "$boot" ] && [ "$(stat -f %m "$1")" -lt "$boot" ]; then
    return 1
  fi
  local pid
  pid=$(cat "$1/pid" 2>/dev/null) || pid=""
  if [ -z "$pid" ]; then
    [ -n "$(find "$1" -maxdepth 0 -mmin -1 2>/dev/null)" ]
    return
  fi
  kill -0 "$pid" 2>/dev/null
}

# Take lock <dir>, clearing it first if its owner is gone. Fails while another
# running process holds it. Two callers clearing the same stale lock at the
# same moment could both end up holding it; the window is milliseconds after
# a crash, and only topgrade-daily and `update` share a lock.
lock_acquire() {
  if ! mkdir "$1" 2>/dev/null; then
    if lock_held "$1"; then
      return 1
    fi
    echo "Clearing $1, left by pid $(cat "$1/pid" 2>/dev/null || echo unknown)" >&2
    rm -rf "$1"
    mkdir "$1" 2>/dev/null || return 1
  fi
  printf '%s\n' "$$" >"$1/pid"
}

# Release lock <dir> if this shell owns it; a lock taken over by another
# process is left alone.
lock_release() {
  [ "$(cat "$1/pid" 2>/dev/null)" = "$$" ] || return 0
  rm -rf "$1"
}
