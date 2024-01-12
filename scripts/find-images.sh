#!/usr/bin/env bash

input="$1"
if [ -z "$input" ] || [[ ! -d "$input" ]]
then
  input="."
else
  shift
fi

find "$input" "$@" -type f |
file --mime-type -f - |
grep -F image/ |
rev | cut -d : -f 2- | rev |
sort -t'/' -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k6,6 -k7,7
