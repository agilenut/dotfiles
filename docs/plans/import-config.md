# Import More Configuration

## Goals

1. **Scan** `~/` for shell and app configs. Skip macOS folders (Documents, Downloads, etc.).
2. **XDG compliance**: Move configs to XDG locations where supported. Add required env vars. Flag unsupported tools. Reference: <https://wiki.archlinux.org/title/XDG_Base_Directory>
3. **Repo integration**: Add configs to dotfiles repo. Combine with XDG moves into unified migration plan.
4. **Package audit**: Find packages installed suboptimally (npm globals → npx, pip → pipx, downloads → Homebrew). Include migration steps.

## Known Items

- qlmarkdown, karabiner, raycast, .ssh (maybe)
- `~/npm` - misplaced
- `~/vscode` - misplaced, has good user config
- `~/.aspnet` - misplaced, unclear how to prevent recreation
- pipx already installed

## Approach

- Use `/notes` to persist progress across sessions
- Iterate in small batches: migrate → chezmoi apply → manual verification
- Don't break working setups; flag unsupported XDG moves

## Output

- Ask questions as needed
- Present incremental, testable migration steps
