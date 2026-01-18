# aliases.zsh
# =============================================================================
# Sets generic aliases.

# Terminal
# -----------------------------------------------------------------------------
alias cls='clear'                              # clear screen
alias reload="source ${ZDOTDIR:-$HOME}/.zshrc" # reload zsh
alias path='echo -e ${PATH//:/\\n}'            # display path 1 line at a time

# CD
# -----------------------------------------------------------------------------
alias ..='cd ..'          # up 1 level
alias ...='cd ../../'     # up 2 levels
alias ....='cd ../../../' # up 3 levels
alias -- -='cd -'         # previous dir

# Shortcuts
# -----------------------------------------------------------------------------
alias home='cd ~'                                   # user home
alias dt='cd ~/Desktop'                             # desktop
alias dev='cd ~/Developer'                          # dev repos
alias docs='cd ~/Documents'                         # documents
alias dl='cd ~/Downloads'                           # downloads
alias dot='cd ~/Developer/github/agilenut/dotfiles' # dotfiles repo

# LS
# -----------------------------------------------------------------------------
if command -v eza &>/dev/null; then
  # use eza if it exists
  alias l='eza --group-directories-first'             # short list
  alias ls='eza --group-directories-first'            # short list
  alias ll='eza -l --git --group-directories-first'   # long list
  alias la='eza -A --group-directories-first'         # short list with hidden files
  alias lla='eza -lA --git --group-directories-first' # long list with hidden files
else
  # fallback to ls if eza doesn't exist
  alias l='ls --color="auto"'        # short list
  alias ls='ls --color="auto"'       # short list
  alias ll='ls -lh --color="auto"'   # long list
  alias la='ls -A --color="auto"'    # short list with hidden files
  alias lla='ls -lhA --color="auto"' # long list format with hidden files
fi

# Directory operations
# -----------------------------------------------------------------------------
alias mkcd='foo() { mkdir -p "$1" && cd "$1"; }; foo'
alias rmrf='rm -rf'

# Editing
# -----------------------------------------------------------------------------
alias e=$EDITOR
alias vi='nvim'
alias vim='nvim'

# GIT
# -----------------------------------------------------------------------------
alias g='git'

alias ga='git add'
alias gaa='git add --all'

alias gb='git branch'

alias gco='git checkout'
alias gcb='git checkout -b'

alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'

alias gd='git diff'
alias gds='git diff --staged'

alias gf='git fetch'
alias gfo='git fetch origin'

alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias glp='_git_log_prettily'
alias glg='git log --stat'
alias glgp='git log --stat --patch'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias gfg='git ls-files | grep'

alias gm='git merge'
alias gms="git merge --squash"

alias gl='git pull'

alias gp='git push'
alias gpd='git push --dry-run'
alias gpsup='git push --set-upstream origin $(git_current_branch)'

alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'

alias cdgit='cd $(git rev-parse --show-toplevel)' # cd to git root

# GO
# -----------------------------------------------------------------------------
alias go-bins='for f in ~/.local/bin/*; do v=$(go version "$f" 2>/dev/null); [[ -n "$v" ]] && echo "$v"; done' # list go-installed binaries
