# Session Notes

## 2026-01-22 - Tmux Setup & Manual Testing Redesign

**Accomplished**: Added tmux to dotfiles with TPM plugin manager, redesigned manual testing to use split panes for inline testing, fixed Touch ID in tmux with pam-reattach, configured mouse/vi copy mode.

**Key Learnings**:

- Touch ID in tmux requires `pam-reattach` added to `/etc/pam.d/sudo_local` before `pam_tid.so`
- Mouse drag in tmux auto-copies to clipboard on release (stays within pane); Shift+select bypasses tmux for cross-pane selection
- Manual test results now use grouped format: `pppfs` (one char per test in group)
- Tmux plugins require first-run install: start tmux, press `C-a I`
- Use `${VAR:-}` syntax for optional env vars with bash strict mode (`set -u`)
- Vi copy mode bindings are standard across tmux (`C-a [`) and Alacritty (`Ctrl+Shift+Space`): hjkl nav, v select, y yank
- For hjkl consistency: change Karabiner to space+hjkl rather than remapping every vi-mode tool

## 2026-01-21 - README/CLAUDE.md Restructure and /retro Skill

**Accomplished**: Restructured documentation (README sections, CLAUDE.md organization), created /retro skill replacing /notes, improved test and apply output clarity, expanded local dev instructions, added VS Code tasks for source testing.

**Key Learnings**:

- `dotfiles-test` runs from installed location; use VS Code task or direct path for testing source changes
- `chezmoi state delete-bucket --bucket=scriptState` forces re-run of run_once scripts
- Git workflow: always suggest commits for approval, never commit directly without explicit user consent
