# .bash_profile
[[ -f ~/.profile ]] && . ~/.profile
[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -d ~/.bashrc.d ]]; then
	for bashrc in ~/.bashrc.d/*; do
		. $bashrc
	done
fi

if [[ -d ~/.shellrc.d ]]; then
	for shellrc in ~/.shellrc.d/*; do
		. $shellrc
	done
fi
