# .bash_profile
[[ -d ~/.bash_profile.d ]] && \
    for f in ~/.bash_profile.d/*; do
        . $f
    done

[[ -f ~/.profile ]] && . ~/.profile

[[ -f ~/.bashrc ]] && . ~/.bashrc
