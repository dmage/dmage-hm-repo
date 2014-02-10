# .profile
[[ -d ~/.profile.d ]] && \
    for f in ~/.profile.d/*; do
        . $f
    done
