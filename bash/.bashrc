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

# zoxide (스마트 cd — z 명령어)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

# fzf 키 바인딩 (Ctrl+R 히스토리 검색 등)
if command -v fzf &>/dev/null; then
  # fzf 버전에 따라 --bash 플래그 지원 여부 다름
  eval "$(fzf --bash 2>/dev/null)" || \
    source /usr/share/doc/fzf/examples/key-bindings.bash 2>/dev/null || true
fi

# atuin (히스토리 강화 — Linux/macOS 전용)
if command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"
fi

# starship 프롬프트 (마지막에 선언해야 PS1 override 보장)
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
fi
