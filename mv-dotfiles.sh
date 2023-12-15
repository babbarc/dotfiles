#!/bin/bash

rlpath=$(realpath -s "$1")

if [ ! -f "$rlpath" ]; then
	if [ ! -d "$rlpath" ]; then
		read -r -p "not a file or directory. continue? " choice
		case "$choice" in
		n | N) exit ;;
		y | Y) echo "Proceeding..." ;;
		*) echo 'Response not valid' && exit ;;
		esac
	fi
fi

[[ -L "$rlpath" ]] && echo "symbolic exists. nothing to do." && exit

bname=$(basename "$rlpath")
dpath="$HOME/.dotfiles/$bname"
dname=$(dirname "$rlpath")

if [ -e "$dpath" ]; then
	echo "File exists. Nothing to move."
else
	echo "Moving $bname to $HOME/.dotfiles/"
	mv -i "$rlpath" "$HOME/.dotfiles/"
fi

echo "Creating symbolic link $rlpath -> $dpath"
ln -s -t "$dname" "$dpath"
