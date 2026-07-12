#!/usr/bin/env bash
# Theme palette contract tests
# shellcheck shell=bash

# Guards the centralized palette (home/.chezmoidata/themes.toml) and its
# consumers. Two invariants that have bitten us:
#   1. Every theme must define every key the templates reference. A missing key
#      renders as Go's "<no value>", silently blanking a color.
#   2. lazygit color values must be valid tokens (a base-8 name, a modifier, or
#      a #hex). An unknown token like `brightblack` is silently dropped —
#      rendering white for borders / black for text (see docs/known-issues.md).
test_theme_palette() {
  section "Theme Palette"

  if ! command -v chezmoi >/dev/null; then
    skip "chezmoi not found"
    return
  fi
  local src
  src="$(chezmoi source-path 2>/dev/null)"
  if [[ ! -d $src ]]; then
    skip "chezmoi source-path unavailable"
    return
  fi

  # 1. Completeness: access every key each consumer uses, for every theme. A
  #    missing key prints "<no value>" rather than erroring, so check the output.
  local keys_tmpl out
  # `range .themes` sets dot to each theme (no $-vars, so no shell-expansion
  # false positive from shellcheck on the single-quoted Go template).
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

  # 2. lazygit color-token validity for the active theme.
  local cfg
  cfg="$(chezmoi execute-template <"$src/dot_config/lazygit/config.yml.tmpl" 2>/dev/null)"
  if [[ -z $cfg ]]; then
    skip "lazygit config did not render"
    return
  fi
  # Collect leaf values only under the color blocks (theme / authorColors /
  # branchColorPatterns), so non-color settings (widths, presets) are ignored.
  local values valid bad=""
  values="$(printf '%s\n' "$cfg" | awk '
    /^  (theme|authorColors|branchColorPatterns):/ { inblock = 1; next }
    /^  [a-zA-Z]/ { inblock = 0 }
    inblock {
      line = $0
      # Strip inline comments. Hex values are always quoted ("#rrggbb"), so a
      # whitespace-preceded # is always a comment, never a bare hex value.
      sub(/[[:space:]]+#.*$/, "", line)
      if (match(line, /(- |: )"?[^"]+"?[[:space:]]*$/)) {
        v = line; sub(/.*(- |: )/, "", v); gsub(/["[:space:]]/, "", v)
        if (v != "") print v
      }
    }')"
  valid='^(default|black|red|green|yellow|blue|magenta|cyan|white|bold|underline|reverse|strikethrough|#[0-9a-fA-F]{6})$'
  local v
  while IFS= read -r v; do
    [[ -z $v ]] && continue
    [[ $v =~ $valid ]] || bad+=" $v"
  done <<<"$values"
  if [[ -n $bad ]]; then
    fail "lazygit has invalid color token(s):${bad} (must be a base-8 name or #hex)"
  else
    pass "lazygit color values are all valid tokens"
  fi
}
