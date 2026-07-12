#!/usr/bin/env bash
# Theme palette contract tests
# shellcheck shell=bash

# Guards the centralized palette (home/.chezmoidata/themes.toml) and its
# consumers. Two invariants that have bitten us:
#   1. lazygit color values must be valid tokens (a base-8 name, a modifier, or
#      #hex). An unknown token like `brightblack` is silently dropped, rendering
#      white for borders / black for text (see docs/known-issues.md).
#   2. Every theme must define every key the templates reference. A missing key
#      renders as Go's "<no value>", silently blanking a color.
#
# Neither check calls skip(): the runner exits non-zero on any skip, and this
# must stay green in CI (where chezmoi's source dir isn't queryable). The
# lazygit check reads the installed, already-rendered config so it always runs;
# the all-themes completeness check runs only where chezmoi can render data.
test_theme_palette() {
  section "Theme Palette"

  # 1. lazygit token validity — from the installed (rendered) config, so it
  #    needs no chezmoi source access.
  local lg="$HOME/.config/lazygit/config.yml"
  if [[ -f $lg ]]; then
    # Leaf values only under the color blocks (theme / authorColors /
    # branchColorPatterns), so non-color settings (widths, presets) are ignored.
    local values valid bad="" v
    values="$(awk '
      /^  (theme|authorColors|branchColorPatterns):/ { inblock = 1; next }
      /^  [a-zA-Z]/ { inblock = 0 }
      inblock {
        line = $0
        # Strip inline comments. Hex values are always quoted, so a
        # whitespace-preceded # is always a comment, never a bare hex value.
        sub(/[[:space:]]+#.*$/, "", line)
        if (match(line, /(- |: )"?[^"]+"?[[:space:]]*$/)) {
          v = line; sub(/.*(- |: )/, "", v); gsub(/["[:space:]]/, "", v)
          if (v != "") print v
        }
      }' "$lg")"
    valid='^(default|black|red|green|yellow|blue|magenta|cyan|white|bold|underline|reverse|strikethrough|#[0-9a-fA-F]{6})$'
    while IFS= read -r v; do
      [[ -z $v ]] && continue
      [[ $v =~ $valid ]] || bad+=" $v"
    done <<<"$values"
    if [[ -n $bad ]]; then
      fail "lazygit has invalid color token(s):${bad} (must be a base-8 name or #hex)"
    else
      pass "lazygit color values are all valid tokens"
    fi
  fi

  # 2. Completeness across all themes — needs chezmoi's palette data. Access
  #    every key each consumer uses, for every theme; a missing key prints
  #    "<no value>" rather than erroring, so check the output. Runs only where
  #    chezmoi can render templates (local dev); silently omitted elsewhere.
  if command -v chezmoi >/dev/null && chezmoi execute-template '{{ len .themes }}' >/dev/null 2>&1; then
    local keys_tmpl out
    keys_tmpl='{{ range .themes }}
{{ .ansi.background }}{{ .ansi.foreground }}{{ .ansi.black }}{{ .ansi.red }}{{ .ansi.green }}{{ .ansi.yellow }}{{ .ansi.blue }}{{ .ansi.magenta }}{{ .ansi.cyan }}{{ .ansi.white }}{{ .ansi.bright_black }}{{ .ansi.bright_blue }}{{ .ansi.bright_magenta }}{{ .ansi.bright_cyan }}
{{ .syntax.comment }}{{ .syntax.string }}{{ .syntax.escape }}{{ .syntax.regexp }}{{ .syntax.number }}{{ .syntax.keyword }}{{ .syntax.keyword_storage }}{{ .syntax.function }}{{ .syntax.type }}{{ .syntax.variable }}{{ .syntax.constant }}{{ .syntax.operator }}
{{ .ui.selection }}{{ .ui.line_highlight }}{{ .ui.muted }}{{ .ui.diff_add_bg }}{{ .ui.diff_change_bg }}{{ .ui.diff_del_bg }}{{ .ui.diff_add_emph_bg }}{{ .ui.diff_del_emph_bg }}{{ .ui.diff_text }}{{ .ui.git_add }}{{ .ui.git_change }}{{ .ui.git_delete }}{{ .ui.git_untracked }}{{ .ui.git_conflict }}{{ .ui.diag_error }}{{ .ui.diag_warn }}{{ .ui.diag_info }}{{ .ui.diag_hint }}{{ end }}'
    if ! out="$(chezmoi execute-template "$keys_tmpl" 2>&1)"; then
      fail "palette template error: ${out}"
    elif printf '%s' "$out" | grep -q '<no value>'; then
      fail "a theme is missing a key the templates use (<no value> rendered)"
    else
      pass "all themes define the required ansi/syntax/ui keys"
    fi
  fi
}
