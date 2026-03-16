# ~/.bashrc

# Source global definitions
[[ -f /etc/bashrc ]] && source /etc/bashrc

# Load modular configs
for file in ~/.{exports,aliases,functions,extra}; do
  [[ -r "$file" ]] && source "$file"
done
unset file

# fnm (Node version manager)
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell bash)"
fi
