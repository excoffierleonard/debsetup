# Enable colors
autoload -U colors && colors

# Set the prompt space pretty
PROMPT="%{$fg_bold[green]%}%n%{$reset_color%}@%{$fg_bold[green]%}%M %{$fg_bold[blue]%}%~ %{$reset_color%}%# "

# Setup zsh autocompletion
autoload -Uz compinit
compinit

# Setup zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Setup fzf
source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh

# Make the ls command better
alias ls="exa -alh --group-directories-first"
alias gti="git"
alias vim="nvim"
alias cl="clear"
alias grep="rg"
alias cd="z"
alias top="btop"
alias :q="exit"
alias lg="lazygit"
alias python="python3"
alias pip="pip3"

# Keep 5000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history
setopt histignorealldups sharehistory

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Execute Neofetch at startup
echo ""
neofetch