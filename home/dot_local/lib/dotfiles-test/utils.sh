#!/usr/bin/env bash
# Shared utilities for dotfiles-test

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() {
  ((TESTS_RUN++))
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${RESET} $1"
}

fail() {
  ((TESTS_RUN++))
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${RESET} $1"
}

skip() {
  ((TESTS_SKIPPED++))
  echo -e "  ${YELLOW}○${RESET} $1 (skipped)"
}

section() {
  echo ""
  echo -e "${BOLD}[$1]${RESET}"
}

header() {
  echo ""
  echo "================================================================================"
  echo -e "${BOLD}                        DOTFILES TEST SUITE${RESET}"
  echo "================================================================================"
}

# Clear zsh completion cache to ensure fresh completions during testing
clear_zcompdump() {
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local cleared=0

  # Clear zcompdump files (may include version-specific files)
  for f in "$cache_dir"/zcompdump*; do
    if [[ -f "$f" ]]; then
      rm -f "$f"
      ((cleared++))
    fi
  done

  # Clear completion cache directory
  if [[ -d "$cache_dir/zcompcache" ]]; then
    rm -rf "$cache_dir/zcompcache"
    ((cleared++))
  fi

  if [[ $cleared -gt 0 ]]; then
    echo -e "${BLUE}ℹ${RESET} Cleared zsh completion cache ($cleared items)"
  fi
}

# Check if output contains ANSI escape sequences
has_ansi_codes() {
  local output="$1"
  [[ "$output" == *$'\e['* ]] || [[ "$output" == *$'\033['* ]]
}

# Run a command in interactive zsh and return its exit code
# Uses env -i to start with minimal environment, preventing stale parent vars
# from overriding what .zshenv would set
zsh_check() {
  env -i HOME="$HOME" USER="$USER" TERM="${TERM:-xterm-256color}" PATH="$PATH" \
    zsh -i -c "$1" 2>/dev/null
}

# Test if an environment variable exists in zsh
test_env_exists() {
  if zsh_check "[[ -n \"\$$1\" ]]"; then
    local value
    value=$(zsh_check "echo \$$1")
    pass "$1=$value"
  else
    fail "$1 not set"
  fi
}

# Test if a macOS default matches expected value
test_macos_default() {
  local domain="$1"
  local key="$2"
  local expected="$3"
  local description="$4"

  local actual
  actual=$(defaults read "$domain" "$key" 2>/dev/null) || {
    fail "$description (key not found)"
    return
  }

  if [[ "$actual" == "$expected" ]]; then
    pass "$description"
  else
    fail "$description (expected: $expected, got: $actual)"
  fi
}
