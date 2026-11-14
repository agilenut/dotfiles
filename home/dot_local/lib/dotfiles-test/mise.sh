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

  # Assert the file's contents, not `mise current node`: the resolved
  # version moves with every release.
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
  # mise is the only .NET, so a repo's global.json pin works only if mise reads it.
  if [[ "$idiomatic" == *dotnet* ]]; then
    pass "mise reads global.json for dotnet"
  else
    fail "mise ignores global.json (settings.idiomatic_version_file_enable_tools lacks dotnet)"
  fi

  if [[ -n "$(mise config get -f "$config" tools.pnpm 2>/dev/null || true)" ]]; then
    pass "global pnpm is set"
  else
    fail "global pnpm is unset (pnpm is missing outside repos that pin it)"
  fi

  if [[ -n "$(mise config get -f "$config" tools.dotnet 2>/dev/null || true)" ]]; then
    pass "global dotnet is set"
  else
    fail "global dotnet is unset (no dotnet for global tools outside repos that pin one)"
  fi
  # `command -v dotnet` alone also passes on a CI runner's own .NET.
  if (cd "$HOME" && mise which dotnet >/dev/null 2>&1); then
    pass "mise installed its global dotnet"
  else
    fail "mise's global dotnet isn't installed (run \`mise install\` from \$HOME)"
  fi
}
