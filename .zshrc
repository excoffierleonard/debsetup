# Check if the session is inside tmux
if [ -z "$TMUX" ]; then
  neofetch
fi

# Set up coloring
autoload -U colors && colors

# Customize the command prompt
PROMPT="%{$fg_bold[green]%}%n%{$reset_color%}@%{$fg_bold[green]%}%M %{$fg_bold[blue]%}%~ %{$reset_color%}%# "

# Aliases
alias ls="exa -alh --group-directories-first" 
alias gti="git"
alias vim="nvim"
alias cl="clear"
alias grep="rg"
alias top="btop"
alias :q="exit"
alias lg="lazygit"
alias python="python3"
alias pip="pip3"
alias system_update="~/.scripts/system_update.sh"
alias todo="~/.scripts/todo.sh"

# Set up the editor
export EDITOR=nvim

# Use modern completion system
autoload -Uz compinit
compinit

# Source zsh plugins
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Enable fzf keyboard shortcuts
source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh

# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
