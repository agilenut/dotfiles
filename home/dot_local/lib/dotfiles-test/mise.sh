#!/usr/bin/env bash
# mise global config tests.

test_mise_config() {
  section "mise Global Config"

  # mise isn't packaged for apt/dnf (see packages.sh), so those machines have
  # nothing to check.
  if ! command -v mise &>/dev/null; then
    skip "mise not installed"
    return
  fi

  local config="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
  if [[ -f "$config" ]]; then
    pass "mise global config exists"
  else
    fail "mise global config not found at $config (run \`chezmoi apply\`)"
    return
  fi

  # Assert the file's contents, not `mise current node`: CI has no
  # mise-installed Node, and the resolved version moves with every release.
  local probe
  if ! probe="$(mise config get -f "$config" 2>&1)"; then
    fail "mise can't read $config: ${probe%%$'\n'*}"
    return
  fi

  local node
  node="$(mise config get -f "$config" tools.node 2>/dev/null || true)"
  if [[ "$node" =~ ^(lts|latest|[0-9]+)$ ]]; then
    pass "global node tracks a release line ($node), not a fixed version"
  else
    fail "global node is '${node:-<unset>}'; use lts, latest, or a bare major"
  fi

  local idiomatic
  idiomatic="$(mise config get -f "$config" settings.idiomatic_version_file_enable_tools 2>/dev/null || true)"
  if [[ "$idiomatic" == *node* ]]; then
    pass "mise reads .nvmrc for node"
  else
    fail "mise ignores .nvmrc (settings.idiomatic_version_file_enable_tools lacks node)"
  fi
  # Node 25+ no longer ships corepack, so pnpm and yarn come from mise.
  if [[ "$idiomatic" == *pnpm* && "$idiomatic" == *yarn* ]]; then
    pass "mise reads package.json packageManager for pnpm and yarn"
  else
    fail "mise ignores packageManager (settings.idiomatic_version_file_enable_tools lacks pnpm or yarn)"
  fi

  if [[ -n "$(mise config get -f "$config" tools.pnpm 2>/dev/null || true)" ]]; then
    pass "global pnpm is set"
  else
    fail "global pnpm is unset (pnpm is missing outside repos that pin it)"
  fi
}
