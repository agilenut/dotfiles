# macos.zsh
# =============================================================================
# Setup MacOs specific aliases and functions.

alias brewup='\
  brew update \
  && brew upgrade \
  && brew cleanup'

alias update='\
  sudo softwareupdate -i -a \
  && brewup \
  && oh-my-posh upgrade'

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
