#!/usr/bin/env bash

# convenience script

txt(){
	if [[ -x "$HOME/bin/txtme" ]]
	then
		"$HOME/bin/txtme" "$@"
	fi
	echo "$@"
}

echo "updating gallery maker:"
git -C gallery_maker pull

if ! ./gallery_maker/make_gallery.sh
then
	txt "wallpaper update failed"
else
	txt "wallpapers updated"
fi

# induce git to refresh the index if needed
git status > /dev/null
