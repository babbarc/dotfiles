#!/bin/bash

read -n1 "link .zshrc? (y/n): " confirm
if [[ $confirm == [yY] ]]; then
	[[ -f $HOME/.zshrc ]] && read -n1 "$HOME/.zshrc exists, delete it? (y/n): " delete
fi
