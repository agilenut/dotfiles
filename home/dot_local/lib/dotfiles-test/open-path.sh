#!/usr/bin/env bash
# open-path resolution tests
# shellcheck shell=bash

# Unit coverage for open-path's path resolution: absolute, ~/-prefixed,
# base-relative, repo-relative (.git walk), and :line[:col] suffix parsing,
# plus the non-existent-path failure. Uses OPEN_PATH_DRY_RUN (print resolution,
# skip the nvim/tmux spawn) and OPEN_PATH_BASE (inject the relative base) so no
# tmux server or editor is needed. What stays manual: the live Ctrl+Shift+O hint
# and the in-tmux pane-cwd query.
test_open_path() {
  section "Open Path Resolution"

  # Prefer the source sibling (so source runs test source changes), else the
  # installed copy. Invoked via bash since the source file isn't chmod +x.
  local bin=""
  local cand
  for cand in "$SCRIPT_DIR/executable_open-path" "$SCRIPT_DIR/open-path" \
    "${HOME}/.local/bin/open-path"; do
    if [[ -f "$cand" ]]; then
      bin="$cand"
      break
    fi
  done

  if [[ -z "$bin" ]]; then
    skip_with_followup "open-path not found" \
      "Run 'chezmoi apply' to install open-path"
    return
  fi

  # Fixture: a throwaway repo with a file at the root and an empty subdir, so
  # the .git walk has somewhere to climb from.
  local tmp repo
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  mkdir -p "$repo/sub" "$repo/.git"
  # file.txt exists in both root and sub; rootonly.txt only at the root, so the
  # walk case can't short-circuit on a direct base join.
  touch "$repo/file.txt" "$repo/sub/file.txt" "$repo/rootonly.txt"

  # Resolve $2 against base $1 in dry-run; assert resolved path and line.
  check_resolve() {
    local desc="$1" base="$2" target="$3" want_resolved="$4" want_line="$5"
    local out resolved line
    out="$(env OPEN_PATH_DRY_RUN=1 OPEN_PATH_BASE="$base" \
      bash "$bin" "$target" 2>/dev/null)"
    resolved="$(printf '%s\n' "$out" | sed -n 's/^resolved=//p')"
    line="$(printf '%s\n' "$out" | sed -n 's/^line=//p')"
    if [[ "$resolved" == "$want_resolved" && "$line" == "$want_line" ]]; then
      pass "$desc"
    else
      fail "$desc (resolved='$resolved' line='$line'," \
        "want resolved='$want_resolved' line='$want_line')"
    fi
  }

  # Absolute inputs ignore the base entirely.
  check_resolve "absolute path resolves regardless of base" \
    "/nonexistent-base" "$repo/file.txt" "$repo/file.txt" ""

  # ~/ expands to $HOME, also base-independent.
  check_resolve "~ expands to \$HOME" \
    "/nonexistent-base" "~" "$HOME" ""

  # Relative input resolves against the injected base (the new tmux-pane path
  # in production).
  check_resolve "base-relative path resolves against base" \
    "$repo" "file.txt" "$repo/file.txt" ""

  # From a subdir the direct join misses; the .git walk climbs to the repo root.
  check_resolve "repo-relative resolves via .git walk from base" \
    "$repo/sub" "rootonly.txt" "$repo/rootonly.txt" ""

  # :line and :line:col suffixes are stripped and the line captured. Real hint
  # inputs always contain a slash (the Alacritty regex requires one), so use a
  # slashed path — a bare `name:line` would trip open-path's SCP-style guard.
  check_resolve ":line suffix parsed" \
    "$repo" "sub/file.txt:42" "$repo/sub/file.txt" "42"
  check_resolve ":line:col suffix parsed" \
    "$repo" "sub/file.txt:42:7" "$repo/sub/file.txt" "42"

  # A path that resolves nowhere exits nonzero.
  if env OPEN_PATH_DRY_RUN=1 OPEN_PATH_BASE="$repo" \
    bash "$bin" "nope.txt" >/dev/null 2>&1; then
    fail "non-existent path should exit nonzero"
  else
    pass "non-existent path exits nonzero"
  fi

  rm -rf "$tmp"
}
