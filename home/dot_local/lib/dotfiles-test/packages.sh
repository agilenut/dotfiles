#!/usr/bin/env bash
# Package installation tests

test_commands_installed() {
  section "Command Installation"

  local commands=(
    "bat"
    "chezmoi"
    "dotnet"
    "eza"
    "fd"
    "fzf"
    "git"
    "git-credential-manager"
    "git-ignore"
    "go"
    "nvim"
    "oh-my-posh"
    "pwsh"
    "rg"
    "shellcheck"
    "shfmt"
    "tmux"
    "tree"
    "zoxide"
    "zsh"
  )

  for cmd in "${commands[@]}"; do
    if command -v "$cmd" &>/dev/null; then
      pass "$cmd is installed"
    else
      fail "$cmd not found"
    fi
  done
}

test_casks_installed() {
  section "GUI Applications (macOS)"

  if [[ "$(uname)" != "Darwin" ]]; then
    skip "Not on macOS"
    return
  fi

  # Helper to check if app exists
  check_app() {
    local app="$1"
    if [[ -d "/Applications/${app}.app" ]] || [[ -d "${HOME}/Applications/${app}.app" ]]; then
      pass "$app is installed"
    else
      fail "$app not found"
    fi
  }

  check_app "Visual Studio Code"
  check_app "Warp"
  check_app "Alfred 5"
  check_app "Firefox"
  check_app "Google Chrome"
  check_app "1Password"
  check_app "AppCleaner"
  check_app "Rectangle Pro"
}
