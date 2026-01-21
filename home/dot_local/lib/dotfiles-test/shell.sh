#!/usr/bin/env bash
# Shell configuration tests

test_environment_variables() {
  section "Environment Variables"

  # These need to be checked in zsh context
  test_env_exists "XDG_BIN_HOME"
  test_env_exists "XDG_CACHE_HOME"
  test_env_exists "XDG_CONFIG_HOME"
  test_env_exists "XDG_DATA_HOME"
  test_env_exists "XDG_STATE_HOME"
  test_env_exists "ZDOTDIR"
  test_env_exists "LS_COLORS"
  test_env_exists "LSCOLORS"
  test_env_exists "FZF_DEFAULT_OPTS"
  test_env_exists "PYTHON_HISTORY"
  test_env_exists "PYTHONPYCACHEPREFIX"
  test_env_exists "PYTHONUSERBASE"

  # shellcheck disable=SC2016 # Single quotes intentional - passed to zsh
  if zsh_check '[[ "$CLICOLOR" == "1" ]]'; then
    pass "CLICOLOR=1"
  else
    fail "CLICOLOR not set to 1"
  fi
}

test_completion_system() {
  section "Completion System"

  if zsh_check 'type compdef &>/dev/null'; then
    pass "compdef function exists (compinit loaded)"
  else
    fail "compdef not found (compinit not loaded)"
  fi

  if zsh_check 'zmodload -L 2>/dev/null | grep -q complist'; then
    pass "zsh/complist module loaded"
  else
    fail "zsh/complist module not loaded"
  fi

  if zsh_check 'zstyle -L ":fzf-tab:*" &>/dev/null'; then
    pass "fzf-tab zstyles configured"
  else
    fail "fzf-tab zstyles not found"
  fi
}

test_plugins_loaded() {
  section "Plugins"

  if zsh_check 'type _zsh_highlight &>/dev/null'; then
    pass "fast-syntax-highlighting loaded"
  else
    fail "fast-syntax-highlighting not loaded"
  fi

  # shellcheck disable=SC2016 # Single quotes intentional - passed to zsh
  if zsh_check '[[ -n "$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE" ]] || type autosuggest-accept &>/dev/null'; then
    pass "zsh-autosuggestions loaded"
  else
    fail "zsh-autosuggestions not loaded"
  fi

  if zsh_check 'type fzf-tab-complete &>/dev/null'; then
    pass "fzf-tab loaded"
  else
    fail "fzf-tab not loaded"
  fi
}

test_prompt_configured() {
  section "Prompt Configuration"

  if zsh_check 'type _omp_precmd &>/dev/null'; then
    pass "oh-my-posh precmd hook installed"
  else
    fail "oh-my-posh precmd hook not found"
  fi
}

test_color_output() {
  section "Color Output Detection"

  if command -v eza &>/dev/null; then
    local eza_output
    eza_output=$(eza --color=always / 2>/dev/null | head -1)
    if has_ansi_codes "$eza_output"; then
      pass "eza produces ANSI color codes"
    else
      fail "eza not producing color output"
    fi
  else
    skip "eza not installed"
  fi

  if command -v bat &>/dev/null; then
    local bat_output
    # Create a temp file to test bat
    local tmpfile
    tmpfile=$(mktemp)
    echo 'echo "hello"' >"$tmpfile"
    bat_output=$(bat --color=always --style=plain "$tmpfile" 2>/dev/null)
    rm -f "$tmpfile"
    if has_ansi_codes "$bat_output"; then
      pass "bat produces ANSI color codes"
    else
      fail "bat not producing color output"
    fi
  else
    skip "bat not installed"
  fi

  if command -v oh-my-posh &>/dev/null; then
    local omp_output
    omp_output=$(oh-my-posh print primary 2>/dev/null)
    if has_ansi_codes "$omp_output"; then
      pass "oh-my-posh produces ANSI color codes"
    else
      fail "oh-my-posh not producing color output"
    fi
  else
    skip "oh-my-posh not installed"
  fi
}

test_config_files() {
  section "Configuration Files"

  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

  if [[ -f "$config_home/bat/config" ]]; then
    pass "bat config exists"
  else
    fail "bat config not found"
  fi

  if [[ -f "$config_home/fd/fd.ignore" ]]; then
    pass "fd ignore exists"
  else
    fail "fd ignore not found"
  fi

  if [[ -f "$config_home/git/config" ]]; then
    pass "git config exists"
  else
    fail "git config not found"
  fi

  if [[ -f "$config_home/git/ignore" ]]; then
    pass "git ignore exists"
  else
    fail "git ignore not found"
  fi

  if [[ -f "$config_home/zsh/.zshrc" ]]; then
    pass "zshrc exists"
  else
    fail "zshrc not found"
  fi

  if [[ -d "$config_home/zsh/zshrc.d" ]]; then
    local count
    count=$(find "$config_home/zsh/zshrc.d" -name "*.zsh" 2>/dev/null | wc -l | tr -d ' ')
    pass "zshrc.d exists with $count modules"
  else
    fail "zshrc.d directory not found"
  fi

  if [[ -f "$config_home/pip/pip.conf" ]]; then
    pass "pip config exists"
  else
    fail "pip config not found"
  fi
}

test_fzf_keybindings() {
  section "FZF Keybindings"

  if zsh_check 'bindkey | grep -q fzf-file-widget'; then
    pass "CTRL-T (fzf-file-widget) bound"
  else
    fail "CTRL-T not bound to fzf-file-widget"
  fi

  if zsh_check 'bindkey | grep -q fzf-cd-widget'; then
    pass "ALT-C (fzf-cd-widget) bound"
  else
    fail "ALT-C not bound to fzf-cd-widget"
  fi

  if zsh_check 'bindkey | grep -q fzf-history-widget'; then
    pass "CTRL-R (fzf-history-widget) bound"
  else
    fail "CTRL-R not bound to fzf-history-widget"
  fi
}

test_aliases_defined() {
  section "Aliases"

  if zsh_check 'alias ls 2>/dev/null | grep -q eza'; then
    pass "ls aliased to eza"
  elif zsh_check 'alias ls &>/dev/null'; then
    pass "ls alias defined"
  else
    fail "ls alias not defined"
  fi

  if zsh_check 'alias ll &>/dev/null'; then
    pass "ll alias defined"
  else
    fail "ll alias not defined"
  fi

  if zsh_check 'alias la &>/dev/null'; then
    pass "la alias defined"
  else
    fail "la alias not defined"
  fi
}
