# Raycast Backup Support

## Problem

Raycast settings and extensions cannot be easily managed in dotfiles:

- Cloud Sync requires Pro subscription
- Export produces compressed `.rayconfig` files (not git-friendly)
- Manual workaround exists but is clunky

## Workaround (Manual)

1. Export without password: Settings > Extensions > Raycast > Export Settings & Data > delete password
2. Run export command
3. Decompress: `gzip --decompress --keep --suffix .rayconfig FILE.rayconfig`
4. Result: JSON file suitable for git

## Desired Solution

Automate the workaround via chezmoi script that:

1. Detects if Raycast is installed
2. Exports settings (prompts for no password or handles encryption)
3. Decompresses to JSON
4. Stores in repo

Or wait for Raycast to support XDG/dotfiles-friendly export format.

## References

- [Raycast Export/Import changelog](https://www.raycast.com/changelog/1-22-0)
- [Workaround gist](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893)
- [Cloud Sync docs](https://manual.raycast.com/cloud-sync)
