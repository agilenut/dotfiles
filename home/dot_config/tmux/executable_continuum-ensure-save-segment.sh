#!/usr/bin/env bash
# continuum-ensure-save-segment: re-add tmux-continuum's auto-save segment
# after a config reload wipes it.
#
# Continuum has no daemon. Auto-save exists only as a
# "#(<plugin>/scripts/continuum_save.sh)" segment prepended to status-right,
# which tmux runs on every status refresh. Sourcing tmux.conf rewrites
# status-right without that segment, and continuum's own re-add (via the TPM
# run line) is skipped whenever its "another tmux server running?" guard
# miscounts — any transient tmux process at that instant, including the
# status bar's own show-option calls, trips it. When that happens auto-save
# dies silently until the next server restart. tmux.conf runs this script
# after TPM so every reload repairs the segment.
#
# The segment must byte-match the one continuum builds from its own absolute
# path: its "already added" check is a literal substring match, so a ~ or
# $HOME spelling here would stack a second copy.

set -euo pipefail

# %/ strip: a trailing slash in XDG_CONFIG_HOME would break the byte-match.
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
save_script="${config_home%/}/tmux/plugins/tmux-continuum/scripts/continuum_save.sh"
segment="#(${save_script})"

# Plugin not installed yet (fresh machine before prefix-I): nothing to repair.
[ -x "$save_script" ] || exit 0

status_right="$(tmux show-option -gqv status-right)"
case "$status_right" in
  *"$segment"*) exit 0 ;;
esac

tmux set-option -g status-right "${segment}${status_right}"
