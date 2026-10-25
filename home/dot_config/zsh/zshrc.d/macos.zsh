# macos.zsh
# =============================================================================
# Setup MacOs specific aliases and functions.

# Upgrades everything topgrade detects (brew, mise, uv tools, App Store,
# macOS, ...); see ~/.config/topgrade.toml for the steps it skips. Holds the
# lock the scheduled run (topgrade-daily) takes, so the two never run brew at
# the same time. A clean full run (no arguments, so every step ran) clears the
# scheduled run's failure, and every run refreshes its list of waiting casks.
update() {
  local lock="$HOME/Library/Logs/topgrade.lock"
  source "$HOME/.local/lib/dotfiles-lock.sh"
  mkdir -p "${lock:h}"
  if ! lock_acquire "$lock"; then
    print -u2 "An update is already running (pid $(cat "$lock/pid" 2>/dev/null))." \
      "The scheduled run logs to ~/Library/Logs/topgrade-daily-$(date +%Y-%m-%d).log"
    return 1
  fi
  # Ctrl-C would otherwise end the function before the lock is released. A
  # nonzero return keeps Ctrl-C's usual abort.
  setopt local_options local_traps
  TRAPINT() {
    lock_release "$lock"
    return $((128 + $1))
  }
  local rc=0 state="${XDG_STATE_HOME:-$HOME/.local/state}/topgrade"
  topgrade "$@" || rc=$?
  lock_release "$lock"
  if ((rc == 0 && $# == 0)); then
    rm -f "$state/failed"
  fi
  # Casks it upgraded no longer wait; refresh the scheduled run's list.
  if [[ -f "$state/outdated-casks" ]] \
    && HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --quiet >"$state/outdated-casks.tmp" 2>/dev/null; then
    mv "$state/outdated-casks.tmp" "$state/outdated-casks"
  else
    rm -f "$state/outdated-casks.tmp"
  fi
  return $rc
}

alias dns-flush='sudo killall -HUP mDNSResponder'

# empty trash on all volumes.
# clear apple logs to improve shell startup speed.
# clear download history from quarantine. https://mths.be/bum
alias emptytrash="\
  sudo rm -rfv /Volumes/*/.Trashes; \
  sudo rm -rfv ~/.Trash/*; \
  sudo rm -rfv /private/var/log/asl/*.asl; \
  sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"

# Displays the brew formulas, casks and dependencies.
# Arguments:
#  None
# Outputs:
#  Formulas, Casks, and Dependencies.
brews() {
  local formulae, casks, blue, bold, off

  local formulae="$(brew leaves | xargs brew deps --installed --for-each)"
  local casks="$(brew list --cask 2>/dev/null)"

  local blue="$(tput setaf 4)"
  local bold="$(tput bold)"
  local off="$(tput sgr0)"

  echo "${blue}==>${off} ${bold}Formulae${off}"
  echo "${formulae}" | sed "s/^\(.*\):\(.*\)$/\1${blue}\2${off}/"
  echo "\n${blue}==>${off} ${bold}Casks${off}\n${casks}"
}
