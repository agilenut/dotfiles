#!/usr/bin/env bash
# SSH config + git commit-signing tests
#
# Verifies the post-1Password-fetch-doc setup:
# - ~/.ssh/config is plaintext, includes 1P auto-managed config + config.d/
# - git config selects ssh signing without routing through op-ssh-sign
# - fetch-git-signing-key-personal is installed and executable
# - fetch-chezmoi-age-key is installed and executable

test_ssh_config() {
  section "SSH Config"

  local cfg="$HOME/.ssh/config"

  if [[ ! -f "$cfg" ]]; then
    fail "$cfg not found"
    return
  fi
  pass "$cfg exists"

  if grep -q "^Include ~/.ssh/1Password/config" "$cfg"; then
    pass "includes 1Password auto-managed config"
  else
    fail "missing: Include ~/.ssh/1Password/config"
  fi

  if grep -q "^Include ~/.ssh/config.d/\*\.conf" "$cfg"; then
    pass "includes config.d/*.conf overlay"
  else
    fail "missing: Include ~/.ssh/config.d/*.conf"
  fi

  if grep -q "^[[:space:]]*IdentityAgent.*1password.*agent.sock" "$cfg"; then
    pass "1Password SSH agent socket configured"
  else
    fail "1Password SSH agent socket not configured for Host *"
  fi

  # Plaintext-not-templated sanity: the old .tmpl rendered a
  # 1P document body that started with "# This is the SSH config for ..."
  # or contained literal "onepassword" tokens. The new file shouldn't.
  if grep -qi "onepasswordDocument\|chezmoi:template" "$cfg"; then
    fail "config still contains template artifacts (chezmoi apply may have failed)"
  else
    pass "no template artifacts in deployed config"
  fi
}

test_git_signing() {
  section "Git Commit Signing"

  # Read git config WITHOUT --global. Quirk: when ~/.gitconfig exists,
  # `git config --global --get` reads only ~/.gitconfig — it does NOT
  # also fall back to $XDG_CONFIG_HOME/git/config where chezmoi writes.
  # Bare `git config --get` reads the merged set (system + global + local)
  # which is what `git commit -S` actually consumes.
  local format
  format=$(git config --get gpg.format 2>/dev/null || echo "")
  if [[ "$format" == "ssh" ]]; then
    pass "gpg.format=ssh"
  else
    fail "gpg.format expected 'ssh', got '${format:-unset}'"
  fi

  # The whole point of this PR: signing must NOT route through op-ssh-sign,
  # otherwise every commit prompts 1Password (and remote sessions can't sign).
  local program
  program=$(git config --get gpg.ssh.program 2>/dev/null || echo "")
  if [[ -z "$program" ]]; then
    pass "gpg.ssh.program unset (defaults to ssh-keygen, signs with on-disk key)"
  elif [[ "$program" == *op-ssh-sign* ]]; then
    fail "gpg.ssh.program still points at op-ssh-sign — every commit will prompt 1Password"
  else
    pass "gpg.ssh.program=$program"
  fi

  local sign
  sign=$(git config --get commit.gpgsign 2>/dev/null || echo "")
  if [[ "$sign" == "true" ]]; then
    pass "commit.gpgsign=true"
  else
    fail "commit.gpgsign expected 'true', got '${sign:-unset}'"
  fi

  local signingkey
  signingkey=$(git config --get user.signingkey 2>/dev/null || echo "")
  local expected="$HOME/.ssh/id_ed25519_git_signing_key_personal.pub"
  # signingkey is stored with literal ~ — expand for comparison
  local resolved="${signingkey/#\~/$HOME}"
  if [[ "$resolved" == "$expected" ]]; then
    pass "user.signingkey points at on-disk pubkey"
  else
    fail "user.signingkey expected '$expected', got '${signingkey:-unset}'"
  fi

  # Material on disk: skip-with-followup if the user hasn't run the
  # fetch script yet on this machine (don't fail the whole suite).
  local privkey="$HOME/.ssh/id_ed25519_git_signing_key_personal"
  if [[ -f "$privkey" && -f "${privkey}.pub" ]]; then
    pass "signing key materialized on disk"
    local mode
    mode=$(stat -f "%A" "$privkey" 2>/dev/null || stat -c "%a" "$privkey" 2>/dev/null)
    if [[ "$mode" == "600" ]]; then
      pass "signing key permissions are 600"
    else
      fail "signing key permissions are $mode (expected 600)"
    fi
  else
    skip_with_followup "signing key not on disk yet" \
      "Run: fetch-git-signing-key-personal"
  fi
}

# Shared shape check for the fetch-* scripts (one entry per 1P-backed item).
# Each script is small and follows the same convention: shebang, Raycast
# headers, VAULT/ITEM constants, op call, chmod. Verifying that contract
# catches drift across siblings (renames, missing headers, wrong vault).
_check_fetch_script() {
  local name="$1"
  local raycast_title="$2"
  local item_value="$3"
  local dest_pattern="$4"
  local script="$HOME/.local/bin/$name"

  if [[ ! -x "$script" ]]; then
    fail "$script not found or not executable"
    return
  fi
  pass "$name installed and executable"

  if bash -n "$script" 2>/dev/null; then
    pass "$name is syntactically valid bash"
  else
    fail "$name has bash syntax errors"
  fi

  if grep -qF "# @raycast.title $raycast_title" "$script"; then
    pass "Raycast title: $raycast_title"
  else
    fail "Raycast title missing or wrong (expected: $raycast_title)"
  fi

  if grep -qF "VAULT=\"Private\"" "$script"; then
    pass 'VAULT="Private"'
  else
    fail "VAULT not set to Private"
  fi

  if grep -qF "ITEM=\"$item_value\"" "$script"; then
    pass "ITEM=\"$item_value\""
  else
    fail "ITEM not set to '$item_value'"
  fi

  if grep -qF "$dest_pattern" "$script"; then
    pass "DEST contains '$dest_pattern'"
  else
    fail "DEST does not match expected pattern '$dest_pattern'"
  fi
}

test_fetch_signing_script() {
  section "fetch-git-signing-key-personal"
  _check_fetch_script \
    "fetch-git-signing-key-personal" \
    "Fetch Git Signing Key (Personal)" \
    "Git Signing Key (personal)" \
    "id_ed25519_git_signing_key_personal"
}

test_fetch_age_key_script() {
  section "fetch-chezmoi-age-key"
  _check_fetch_script \
    "fetch-chezmoi-age-key" \
    "Fetch Chezmoi Age Key" \
    "Chezmoi Age Key" \
    ".config/chezmoi/key.txt"
}
