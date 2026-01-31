#!/usr/bin/env bash
# macOS defaults tests (darwin only)

# Check if sudo is available, prompting if interactive
can_sudo() {
  # If we already have a cached sudo session, use it
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  # If running interactively, prompt for sudo
  if [[ -t 0 ]]; then
    echo "Some tests require sudo. Enter password to run them, or press Ctrl+C to skip."
    sudo -v 2>/dev/null
    return $?
  fi

  # Non-interactive and no cached session - skip sudo tests
  return 1
}

test_macos_defaults() {
  if [[ "$(uname)" != "Darwin" ]]; then
    return
  fi

  section "macOS Security & Privacy"

  # Tests requiring sudo - skip if not available
  if can_sudo; then
    # Firewall enabled
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled"; then
      pass "Firewall enabled"
    else
      fail "Firewall not enabled"
    fi

    # Stealth mode (output: "Firewall stealth mode is on")
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -qi "is on"; then
      pass "Stealth mode enabled"
    else
      fail "Stealth mode not enabled"
    fi

    # Signed apps allowed (output: "Automatically allow built-in signed software ENABLED")
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null | grep -qi "ENABLED"; then
      pass "Signed apps allowed through firewall"
    else
      fail "Signed apps not allowed through firewall"
    fi

    # Automatic login disabled (key should not exist)
    if ! sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser &>/dev/null; then
      pass "Automatic login disabled"
    else
      fail "Automatic login enabled"
    fi
  else
    skip_with_followup "Firewall enabled" "Run tests interactively to enable sudo-required security checks"
    skip_with_followup "Stealth mode enabled" "Run tests interactively to enable sudo-required security checks"
    skip_with_followup "Signed apps allowed" "Run tests interactively to enable sudo-required security checks"
    skip_with_followup "Automatic login disabled" "Run tests interactively to enable sudo-required security checks"
  fi

  # Personalized ads disabled
  test_macos_default "com.apple.AdLib" "allowApplePersonalizedAdvertising" "0" "Personalized ads disabled"

  # Siri analytics disabled (value 2 = disabled)
  test_macos_default "com.apple.assistant.support" "Siri Data Sharing Opt-In Status" "2" "Siri analytics disabled"

  # Spotlight Siri suggestions disabled
  test_macos_default "com.apple.Spotlight" "SiriSuggestionsEnabled" "0" "Spotlight Siri suggestions disabled"

  # AirDrop Contacts Only
  test_macos_default "com.apple.sharingd" "DiscoverableMode" "Contacts Only" "AirDrop set to Contacts Only"

  section "macOS Finder"

  # Show all filename extensions
  test_macos_default "NSGlobalDomain" "AppleShowAllExtensions" "1" "Show all filename extensions"

  # Show path bar
  test_macos_default "com.apple.finder" "ShowPathbar" "1" "Show path bar"

  section "macOS Dock"

  # Autohide
  test_macos_default "com.apple.dock" "autohide" "1" "Dock autohide enabled"

  # Minimize to application
  test_macos_default "com.apple.dock" "minimize-to-application" "1" "Minimize to application icon"

  # Magnification
  test_macos_default "com.apple.dock" "magnification" "1" "Dock magnification enabled"

  section "macOS General"

  # Dark mode
  local interface_style
  interface_style=$(defaults read NSGlobalDomain AppleInterfaceStyle 2>/dev/null || echo "Light")
  if [[ "$interface_style" == "Dark" ]]; then
    pass "Dark mode enabled"
  else
    skip "Dark mode not enabled (current: $interface_style)"
  fi

  # Expand save panel by default
  test_macos_default "NSGlobalDomain" "NSNavPanelExpandedStateForSaveMode" "1" "Expand save panel by default"

  section "macOS Safari"

  # Safari is sandboxed, so preferences are in the container.
  # Reading this requires Full Disk Access permission for the terminal app.
  local safari_plist="$HOME/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"

  if [[ -r "$safari_plist" ]]; then
    # Show full URL
    test_macos_default "$safari_plist" "ShowFullURLInSmartSearchField" "1" "Safari shows full URL"

    # Developer menu enabled
    test_macos_default "$safari_plist" "IncludeDevelopMenu" "1" "Safari developer menu enabled"
  else
    skip_with_followup "Safari shows full URL" "Grant Full Disk Access to terminal in System Settings > Privacy & Security"
    skip_with_followup "Safari developer menu enabled" "Grant Full Disk Access to terminal in System Settings > Privacy & Security"
  fi
}
