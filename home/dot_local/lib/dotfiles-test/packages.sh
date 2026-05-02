#!/usr/bin/env bash
# Package installation tests

test_commands_installed() {
  section "Command Installation"

  # Universally available in core packages on every supported OS
  # (Homebrew, apt, dnf, pacman) under the same binary name.
  # Note: on apt, `bat` installs as `batcat` and `fd-find` as `fdfind`;
  # those binary-name differences would need shell aliases or symlinks
  # on apt before the test passes there.
  local commands=(
    "age"
    "bat"
    "fzf"
    "git"
    "jq"
    "nvim"
    "rg"
    "tmux"
    "tree"
    "zoxide"
    "zsh"
  )

  # macOS extras: in darwin core packages or the personal dev/quicklook
  # profiles. Not enforced on Linux because either (a) the package isn't
  # in the distro's default repos (chezmoi, gh, eza on apt) or (b) it's
  # in a personal-profile-only list (dotnet, go, shellcheck, shfmt, etc.)
  # that may or may not be present on a Linux runner.
  if [[ "$(uname)" == "Darwin" ]]; then
    commands+=(
      "chezmoi"
      "dotnet"
      "fd"
      "git-credential-manager"
      "git-ignore"
      "go"
      "oh-my-posh"
      "pwsh"
      "shellcheck"
      "shfmt"
    )
  fi

  # eza: in darwin, dnf, and pacman core. Skipped on apt (not in default
  # repos — see chezmoidata.toml comment).
  if [[ "$(uname)" == "Darwin" ]] || command -v dnf &>/dev/null \
    || command -v pacman &>/dev/null; then
    commands+=("eza")
  fi

  # mise: in darwin and pacman core. Skipped on apt/dnf, which require
  # manual PPA/COPR setup (see chezmoidata.toml comments).
  if [[ "$(uname)" == "Darwin" ]] || command -v pacman &>/dev/null; then
    commands+=("mise")
  fi

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
