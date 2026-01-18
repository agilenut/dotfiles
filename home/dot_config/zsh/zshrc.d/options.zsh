# options.zsh
# =============================================================================
# Sets zsh options
# See https://zsh.sourceforge.io/Doc/Release/Options.html

# Changing directories
# -----------------------------------------------------------------------------

setopt AUTO_CD           # Automatically cd to a directory if not cmd.
setopt CD_SILENT         # Don't print directory after cd.
setopt AUTO_NAME_DIRS    # % export h=/home/sjs; cd ~h; pwd => /home/sjs
setopt CDABLE_VARS       # blah=~/media/movies; cd blah; pwd => ~/media/movies
setopt AUTO_PUSHD        # Automatically pushd directories on dirstack.
setopt PUSHD_SILENT      # Dont' print dirstack after each cd/pushd.
setopt PUSHD_IGNORE_DUPS # Don't push dupes on stack.
setopt PUSHD_MINUS       # pushd -N goes to Nth dir in stack.

DIRSTACKSIZE=8

# Expansion and Globbing
# -----------------------------------------------------------------------------

#setopt NO_GLOB        # Turn off glob expansion.
#setopt EXTENDED_GLOB  # '#', '~', and '^' used for globbing patterns.
setopt GLOB_DOTS # Leading '.' in filename not needed for globbing.

# Setting this allows for things like 'cd D*<tab>' to trigger fzf completion.
# But you will still get old completion behavior when there are no matches.
#setopt GLOB_COMPLETE   # Don't insert words but run completion on globs.

# History
# -----------------------------------------------------------------------------

setopt EXTENDED_HISTORY     # Save command timestamps and duration.
setopt HIST_FIND_NO_DUPS    # Don't display a line previously found.
setopt HIST_IGNORE_ALL_DUPS # Delete old recorded entry if newer is a dupe.
setopt HIST_IGNORE_SPACE    # Don't record entry starting with a space.
setopt HIST_REDUCE_BLANKS   # Remove superfluous blanks from entries.
setopt SHARE_HISTORY        # Share history between all sessions.

[[ -d "$XDG_STATE_HOME/zsh" ]] \
  || mkdir -p "$XDG_STATE_HOME/zsh"
HISTFILE="$XDG_STATE_HOME/zsh/history" # Location of the history.
HISTSIZE=100000                        # Number of history entries to keep in memory.
SAVEHIST=$HISTSIZE                     # Number of history entries to save to file.

# Input/Output
# -----------------------------------------------------------------------------

setopt CORRECT # Try to correct misspelled commands.

# This got annoying.
#setopt CORRECT_ALL          # Try to correct misspelled options.

setopt INTERACTIVE_COMMENTS # Allow comments even in interactive shells.

# Job Control
# -----------------------------------------------------------------------------

setopt LONG_LIST_JOBS # Display PID when suspending processes as well.

# ZLE
# -----------------------------------------------------------------------------

setopt NO_BEEP # Don't beep on errors (in ZLE)

# Key bindings
# -----------------------------------------------------------------------------

bindkey -v # Use vi key bindings
