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

# Execute Neofetch at startup
echo ""
neofetch