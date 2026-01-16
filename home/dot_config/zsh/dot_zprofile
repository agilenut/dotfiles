# .zprofile
# =============================================================================
# Executed by zsh on each login shell.
# See https://zsh.sourceforge.io/Guide/zshguide02.html


# Homebrew
# -----------------------------------------------------------------------------
# Homebrew must be configured in .zprofile instead of .zshenv.
# See https://gist.github.com/Linerre/f11ad4a6a934dcf01ee8415c9457e7b2

# Set path and exports
if [ -x "/opt/homebrew/bin/brew" ]; then
  # Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
  # Intel
  eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v brew >/dev/null; then
  # Opt out of analytics
  # Learn more about what you are opting in to at
  # https://docs.brew.sh/Analytics
  export HOMEBREW_NO_ANALYTICS=1
fi

# Path
# -----------------------------------------------------------------------------

typeset -U path PATH   # No dupes
path=(
  "$XDG_BIN_HOME"
  $path
)
