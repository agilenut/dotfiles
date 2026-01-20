# MacOS Settings

## Goal

Codify all mac settings that I setup on new installs and have them
automatically applied by chezmoi.

## Reference

This file is the extremely popular version of macos defaults that many dotfiles are based on: [mathiasbynens dotfiles](https://github.com/mathiasbynens/dotfiles/blob/master/.macos).

## Approach

Find a way to test this safely and iteratively (setting by setting). Perhaps we need to extract all existing settings and merge them with his file (comments maybe). Then iterate over each one running it separately and testing the results to determine if I like it.

Having a way to restore from a backup would also be good (e.g. Time Machine). That should be tested though.

Since this may take a while. Need to write out current progress to the script so that subsequent claude sessions can resume.

## Success

- ✅ All settings are defined, checked in, and working.
- ✅ Settings are applied by chezmoi on new installs.
- ✅ Settings are not applied to non MacOS systems.
