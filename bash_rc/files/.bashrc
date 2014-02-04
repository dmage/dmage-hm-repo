# .bashrc
if [[ $- != *i* ]] ; then
    # Shell is non-interactive.  Be done now!
    return
fi

[[ -f /etc/bash_completion ]] &&
    . /etc/bash_completion

if [[ -f ~/.dir_colors ]] ; then
    eval $(dircolors -b ~/.dir_colors)
elif [[ -f /etc/DIR_COLORS ]] ; then
    eval $(dircolors -b /etc/DIR_COLORS)
fi

#BSD#@export CLICOLOR=1
#GNU#@alias ls='ls --color=auto'
alias grep='grep --colour=auto'

# wrappe around unicode bug
alias mc='LANG="C" mc'

# Change the window title of X terminals
case ${TERM} in
    xterm*|rxvt*|Eterm|aterm|kterm|gnome)
        PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/$HOME/~}\007"'
    ;;
    screen)
        PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/$HOME/~}\033\\"'
    ;;
esac

[[ -f ~/.shellrc ]] &&
    . ~/.shellrc

[[ -d ~/.bashrc.d ]] &&
    for f in ~/.bashrc.d/*; do
        . $f
    done
