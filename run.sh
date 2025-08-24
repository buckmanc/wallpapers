#!/usr/bin/env bash

git -C gallery_maker pull
./gallery_maker/make_gallery.sh
# txtme "wallpapers updated"
