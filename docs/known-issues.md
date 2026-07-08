# Known Issues

_Diagnosed limitations we've investigated and chosen to live with. Documented so
they aren't re-investigated - if you hit a rendering or tooling oddity, check
here first. Each entry records the root cause and what NOT to try._

## delta shows PHP diffs unhighlighted

**Symptom:** In `git diff` and lazygit (both use delta as the pager), PHP code
renders plain - one foreground color, no syntax highlighting. Other languages
(Python, Lua, TS) highlight normally, and `bat` colors the same PHP file fully.

**Root cause:** delta highlights diff _hunks in isolation_. PHP's syntect syntax
is HTML-embedded (`text.html.php`): it only enters PHP-code scope after it sees
`<?php`. A normal 3-line-context hunk in the middle of a file contains no
`<?php`, so delta highlights the PHP as plain HTML body text. `bat` highlights
the whole file (sees `<?php` first), which is why it works. Verified:
`git diff -U1000 | delta` (hunk includes `<?php`) colors PHP correctly; default
context does not. Python etc. are not HTML-embedded, so they highlight from any
hunk - which is why only PHP is affected.

**Why we don't fix it:**

- It is **not the theme.** `bat` colors PHP with the same `palette` theme, and
  delta fails to highlight PHP with _any_ theme (Monokai tested too). Do NOT add
  PHP scopes to `home/dot_config/bat/themes/palette.tmTheme.tmpl` - the theme is
  not the problem (an earlier plan note wrongly suggested this).
- delta is already the latest release (0.19.2).
- Raising `diff.context` enough to always include `<?php` means near-full-file
  context on every diff in every language - not worth it.
- A source-only PHP syntax (`source.php`, no HTML wrapper) would fix it, but
  bat's set ships only the embedded syntax and delta uses its own compiled-in
  syntaxes (no `--map-syntax`, doesn't read bat's cache) - nowhere to plug it in.

Upstream delta limitation for HTML-embedded languages. _Diagnosed 2026-07-07._

## charmbracelet CLIs leak terminal-probe escapes under tmux

**Symptom:** Some charmbracelet-based tools (e.g. lefthook, gitleaks) emit stray
escape-sequence junk (garbled characters) at startup when run inside tmux.

**Root cause:** They probe the terminal for its foreground/background colors via
OSC 10/11 queries (to auto-detect a dark/light theme). Under tmux the
query/response handshake isn't consumed cleanly, so the raw sequences leak onto
the screen.

**Why we don't fix it:** `NO_COLOR` is the only lever that suppresses the probe,
but it strips color from the tools' output entirely - a worse outcome than the
occasional junk, and there's no per-tool flag to skip only the probe. Decided to
live with it. Do NOT re-investigate NO_COLOR as a fix.
