#!/usr/bin/env bash

set -e

path_root="$(git rev-parse --show-toplevel)"
tempImgPaths='/tmp/wallpaper-header-temp.txt'
targetWidth=3000

rootDirs="$(find "$path_root/.internals/thumbnails" -mindepth 1 -maxdepth 1 -type d)"

echo "$rootDirs" | while read -r rootDir
do
  rootDirName="$(basename "$rootDir")"
  outpath="$path_root/.internals/headers/${rootDirName}.png"

  echo "making $rootDirName header image..."

  if [[ -f "$tempImgPaths" ]]
  then
    rm "$tempImgPaths"
  fi
  if [[ -f "$outpath" ]]
  then
    rm "$outpath"
  fi

  # do a rough calc to get the right amount of images
  exampleImg="$("$path_root/scripts/find-images" "$rootDir" | head -n 1)" 
  imgWidth="$(identify -format '%w' "$exampleImg")"
  imgLimit="$(echo "($targetWidth / ($imgWidth+25)) -2" | bc -l | cut -d '.' -f1)"

  dirs="$(find "$rootDir" -mindepth 1 -type d | shuf)"
  dirCount="$(echo "$dirs" | wc -l)"
  i=0
  imgPerDir=1
  if [[ "$dirCount" -lt "$imgLimit" ]]
  then
    # chop off the decimal because rounding in bash is insane
    imgPerDir="$(echo "$imgLimit / $dirCount" | bc -l | cut -d '.' -f1)"
    imgPerDir=$((imgPerDir+1))
  fi

  while read -r dir
  do
    ((i++)) || true
    if [[ "$i" -gt "$imgLimit" ]]
    then
      break
    fi

    imgPaths="$("$path_root/scripts/find-images" "$dir" -maxdepth 1 | shuf -n "$imgPerDir" | xargs -d '\n' -I{} echo '"'"{}[0]"'"')"
    if [[ -n "$imgPaths" ]]
    then
      echo "$imgPaths" >> "$tempImgPaths"
    fi
  done < <( echo "$dirs" )


  # not clear on all parts of this
  cat "$tempImgPaths" | shuf -n "$imgLimit" | montage -size 50x1 null: @- null: \
	  -auto-orient  -thumbnail "500x500>^" \
	  -bordercolor Lavender -background black +polaroid \
	  -gravity center -background none \
	  -background none \
	  -geometry -20+2  -tile x1 \
	  "$outpath"

  convert "$outpath" -resize "x500>^" "$outpath"

  if [[ -f "$tempImgPaths" ]]
  then
    rm "$tempImgPaths"
  fi
done
