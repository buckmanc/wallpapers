#!/usr/bin/env bash

sourceDir="$1"

if [[ ! -d "$sourceDir" ]]
then
  echo "need source dir"
  exit 1
fi

sourceDir="$(realpath "$sourceDir")"
destDir="$sourceDir/all"

# echo "sourceDir $sourceDir"
# echo "destDir $destDir"
# exit 1

if [[ -d "$destDir" ]]
then
  rm "$destDir" -r
fi

mkdir -p "$destDir"

# on certain platforms, such as git bash, symlinks cannot be created outside of the current directory
cd "$destDir"

gitRoot="$(git rev-parse --show-toplevel)"
files="$("$gitRoot/scripts/find-images" "$sourceDir" -not -type l)"
total="$(echo "$files" | wc -l)"
i=0

while read -r src
do
  ((i++))
  printf '\r\033[2K%s%4d/%d' "symlinking: " "$i" "$total" | cut -c "-$COLUMNS" | tr -d $'\n'

  destFileName="$(echo ${src#"$sourceDir/"} | perl -pe 's|\.{2,10}|_|g' | perl -pe 's|[/ _()]+|_|g')"
  linkDest="$destDir/$destFileName"
  ln -s -T "$src" "$linkDest"
done < <( echo "$files" )

echo
