#!/usr/bin/env bash
# Theme palette contract tests
# shellcheck shell=bash

# Guards the centralized palette (home/.chezmoidata/themes.toml) and the
# committed per-theme outputs theme-gen generates from it. Invariants that have
# bitten us:
#   1. lazygit color values must be valid tokens (a base-8 name, a modifier, or
#      #hex). An unknown token like `brightblack` is silently dropped, rendering
#      white for borders / black for text (see docs/known-issues.md).
#   2. No generated output may contain Go's "<no value>" — that means a template
#      referenced a palette key a theme doesn't define, silently blanking a color.
#   3. Every ansi/syntax/ui key the templates actually reference must be defined
#      for every theme. The key list is derived FROM the templates (not a
#      hardcoded copy that drifts), so adding a token to a template is covered.
#
# All checks read the COMMITTED source (via chezmoi source-path), so they
# validate what ships regardless of whether this machine has applied. chezmoi is
# a core package — present locally and in CI (which runs `init --apply` first);
# no check calls skip(), since the runner exits non-zero on any skip.
test_theme_palette() {
  section "Theme Palette"

  local src repo
  if ! command -v chezmoi >/dev/null 2>&1 || ! src="$(chezmoi source-path 2>/dev/null)"; then
    fail "chezmoi source-path unavailable; cannot validate theme outputs"
    return
  fi
  repo="$(dirname "$src")"

  # 1. lazygit token validity — every committed per-theme config. Leaf values
  #    only under the color blocks (theme / authorColors / branchColorPatterns),
  #    so non-color settings (widths, presets) are ignored.
  local lg valid bad="" v vals found=0
  valid='^(default|black|red|green|yellow|blue|magenta|cyan|white|bold|underline|reverse|strikethrough|#[0-9a-fA-F]{6})$'
  for lg in "$src"/dot_config/lazygit/themes/*.yml; do
    [[ -f $lg ]] || continue
    found=1
    vals="$(awk '
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
    while IFS= read -r v; do
      [[ -z $v ]] && continue
      [[ $v =~ $valid ]] || bad+=" $(basename "$lg"):$v"
    done <<<"$vals"
  done
  if [[ $found -eq 0 ]]; then
    fail "no lazygit per-theme configs found under $src/dot_config/lazygit/themes"
  elif [[ -n $bad ]]; then
    fail "lazygit has invalid color token(s):${bad} (must be a base-8 name or #hex)"
  else
    pass "lazygit color values are all valid tokens"
  fi

  # 2. No generated output carries a missing-key placeholder. Covers every tool
  #    and theme generically — no key list to maintain. Guard the empty scan so a
  #    missing/renamed output tree fails loudly instead of reading green.
  local outdirs=(
    "$src/dot_config/bat/themes" "$src/dot_config/alacritty/themes"
    "$src/dot_config/nvim/lua/themes" "$src/dot_config/lazygit/themes"
    "$src/dot_config/delta/themes" "$src/dot_config/syntax-highlight/Themes"
  )
  if ! find "${outdirs[@]}" -type f 2>/dev/null | grep -q .; then
    fail "no generated theme outputs found to scan under $src/dot_config"
  elif grep -rl '<no value>' "${outdirs[@]}" 2>/dev/null | grep -q .; then
    fail "a generated theme output contains <no value> (a template references a missing palette key)"
  else
    pass "no generated theme output has a missing-key placeholder"
  fi

  # 3. Every key the templates reference is defined for every theme. Derive the
  #    key list from the templates so it can't drift from what they consume, then
  #    render each for every theme; a missing key renders "<no value>".
  local keys tmpl out
  keys="$(grep -rhoE '\$t\.(ansi|syntax|ui)\.[a-z_]+' "$repo/themes/templates" 2>/dev/null \
    | sed -E 's/^\$t\.//' | sort -u)"
  if [[ -z $keys ]]; then
    fail "no \$t.<layer>.<key> references found in $repo/themes/templates"
  else
    tmpl='{{ range (include "../themes/palette.toml" | fromToml).themes }}'
    while IFS= read -r k; do [[ -n $k ]] && tmpl+="{{ .$k }}"; done <<<"$keys"
    tmpl+='{{ end }}'
    if ! out="$(chezmoi execute-template "$tmpl" 2>&1)"; then
      fail "palette completeness template error: ${out}"
    elif printf '%s' "$out" | grep -q '<no value>'; then
      fail "a theme is missing a key the templates reference (<no value> rendered)"
    else
      pass "every template-referenced ansi/syntax/ui key is defined for all themes"
    fi
  fi
}
