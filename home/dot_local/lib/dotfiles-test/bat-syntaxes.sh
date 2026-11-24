#!/usr/bin/env bash
# Custom bat syntax tests
# shellcheck shell=bash

# Custom syntaxes in ~/.config/bat/syntaxes reach bat and delta (lazygit's diff
# pager) only through bat's compiled cache, so these check the deployed cache,
# not the source files.
test_bat_syntaxes() {
  section "Custom bat Syntaxes"

  if ! command -v bat >/dev/null 2>&1; then
    skip "bat not installed"
    return
  fi

  # Applying only the syntax files (chezmoi apply <target>) skips the
  # cache-rebuild script, so the cache can lag the deployed syntax.
  local fix="chezmoi apply ~/.config/bat/syntaxes, then run bat cache --build"
  if bat --list-languages | grep -q '^Bats:bats$'; then
    pass "bat maps .bats files to the Bats syntax"
  else
    fail "bat has no Bats syntax for .bats ($fix)"
  fi

  if ! command -v delta >/dev/null 2>&1; then
    skip "delta not installed"
  elif delta --list-languages | grep -qE '^Bats[[:space:]]'; then
    pass "delta sees the Bats syntax from bat's cache"
  else
    fail "delta has no Bats syntax ($fix)"
  fi

  # The Bats syntax adds a rule for @test on top of Bash, so the same line
  # renders differently under each.
  local line='@test "adds two numbers" {'
  local as_bats as_bash
  as_bats="$(printf '%s\n' "$line" | bat --color=always --style=plain --language=bats 2>/dev/null)"
  as_bash="$(printf '%s\n' "$line" | bat --color=always --style=plain --language=bash 2>/dev/null)"
  if [[ -n $as_bats && $as_bats != "$as_bash" ]]; then
    pass "bat highlights @test differently under the Bats syntax than under Bash"
  else
    fail "bat renders @test the same as Bash does (Bats syntax missing or its @test rule broken)"
  fi
}
