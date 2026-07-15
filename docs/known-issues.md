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

## lazygit silently drops unknown color tokens

**Symptom:** A lazygit color set to an unrecognized token renders wrong, not
ignored: borders/frames turn bright **white** and branch/author text turns
**black** (near-invisible on a dark background). This bit us when the theme
centralization used `brightblack`, which is not a lazygit color.

**Root cause:** lazygit's color tokens are only the base-8 names (`black`,
`red`, …, `white`), `default`, the modifiers
(`bold`/`underline`/`reverse`/`strikethrough`), and `#rrggbb` hex - there is no
`brightblack` or any `bright*` name. An unrecognized token is not an error; it
is silently dropped, and the two code paths fall back differently: gocui
attributes (borders, `activeBorderColor`, …) default to **white**, while text
colors (`authorColors`, `branchColorPatterns`) go through gookit's `color.HEX`,
which returns **black** for an invalid hex string.

**The rule:** a lazygit color must be a base-8 name, a modifier, or `#rrggbb`.
For a muted grey use the palette hex (`{{ $t.ui.muted }}`), never a `bright*`
name. The `test_theme_palette` check in dotfiles-test now fails on any invalid
lazygit token, so this can't silently regress.

_Diagnosed 2026-07-10 (fixed in #84)._

## QuickLook colors markdown links the same as headings

**Symptom:** In the QuickLook markdown preview (sbarex Syntax Highlight, the
`highlight` engine), links render in the same color as headings, unlike the
nvim (render-markdown) and bat views where links are cyan.

**Root cause:** `highlight`'s `markdown.lang` puts headings in keyword group
`Id=1` and links in `Id=2`/`Id=3` - genuinely separate groups. But the theme's
`Keywords` color array is **global across every language**: entry N colors
keyword-group N for _all_ grammars (Python, TypeScript, JSON all use groups
2/3 for their own secondary keywords). So recoloring the link groups to cyan
would also recolor secondary keywords in every other language. `highlight` has
no per-language color in its theme model - color is keyed to the group number,
not the language.

**Why we don't fix it:** shipping a custom `markdown.lang` that reassigns links
to a different group would still share that group's global color, so it can't
isolate markdown. QL is the secondary preview engine (nvim and bat are the
primary reads), and its markdown support is coarse. Headings are correctly
`keyword_storage`; links inherit the same only because groups 1-3 are all set
to it. Not worth a custom langDef. Do NOT try to recolor `Keywords[2]`/`[3]` -
it will change syntax highlighting in every other language.

_Diagnosed 2026-07-14._

## Theme gallery: aha corrupts colored underlines into a purple background

**Symptom:** In `docs/theme-gallery/*.html`, diagnostic/spell regions rendered
by nvim show up with a faint **purple (`#646695`) background** plus italics —
e.g. the whole JSX block of `sample.tsx`, or the diagnostics showcase. No such
color exists in the editor.

**Root cause:** nvim draws colored undercurls (diagnostic underlines, spell)
with the `CSI 58;2;R;G;B m` SGR (set-underline-color). `aha` — the ANSI→HTML
converter the gallery uses — doesn't support SGR 58. It mis-parses the
parameters: the `2` reads as SGR 2 (faint → aha's `contrast/brightness` filter)
and the run ends up with a spurious `background-color:#646695`. The editor
itself is correct — the raw terminal shows the real undercurl colors
(`#d16969` error, `#d7ba7d` warn, `#569cd6` info, `#6e7681` hint), no background.

**Why it looks like a theme bug but isn't:** `#646695` is vscode.nvim's default
`vscViolet`, which our config remaps — but no highlight group actually carries
it as a background (verified: scanning every group finds none). It only appears
in aha's output. So it's a converter limitation, not a palette defect.

**What we do about it:** the gallery avoids feeding undercurls to aha rather
than trying to make aha render them. Per-file syntax cards run nvim with
`no-diagnostics.lua` (`vim.diagnostic.enable(false)`) so a project-less sample's
LSP errors don't draw underlines; the diagnostics showcase uses
`underline = false` and conveys severity via signs + inline virtual text (both
palette fg, which aha renders). Do NOT try to make aha render colored
undercurls — it can't, and a live terminal shows them correctly anyway.

_Diagnosed 2026-07-14._
