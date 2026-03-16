# ~/.bashrc

# Source global definitions (Ubuntu: /etc/bash.bashrc, others: /etc/bashrc)
[[ -f /etc/bash.bashrc ]] && source /etc/bash.bashrc
[[ -f /etc/bashrc ]] && source /etc/bashrc

# 컬러 프롬프트
case "$TERM" in
  xterm-color|*-256color) color_prompt=yes ;;
esac
if [ -x /usr/bin/tput ] && tput setaf 1 &>/dev/null; then
  color_prompt=yes
fi
if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt

# Load modular configs
for file in ~/.{exports,aliases,functions,extra}; do
  [[ -r "$file" ]] && source "$file"
done
unset file

# fnm (Node version manager)
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell bash)"
fi
