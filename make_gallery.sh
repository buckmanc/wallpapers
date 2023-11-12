#!/usr/bin/env bash
set -e

# Usage: ./make_gallery.sh
#
# Run in a directory with a "papes/" subdirectory, and it will create a
# "thumbnails/" subdirectory.
#
# Uses imagemagick's `convert`, so make sure that's installed.
#
# heavily modified from github.com/jonascarpay/Wallpapers

# stackoverflow.com/a/296135731995812
quoteRe() {
	sed -e 's/[^^]/[&]/g; s/\^/\\^/g; $!a\'$'\n''\\n' <<<"$1" | tr -d '\n'
}

path_root="." # TODO make this the script dir
# or is the git root better?
# gitroot=$(git rev-parse --show-toplevel)

thumbnailMD="${path_root}/.internals/thumbnails.md"
thumbnails_dir="${path_root}/.internals/thumbnails"
thumbnails_old_dir="${path_root}/.internals/thumbnails_old"
readmeTemplatePath="${path_root}/.internals/README_template.md"

mkdir -p "$thumbnails_dir"
mv "$thumbnails_dir" "$thumbnails_old_dir"
mkdir -p "$thumbnails_dir"

if [ -f "$thumbnailMD" ]
then
	rm "$thumbnailMD"
fi

# stackoverflow.com/a/60559975/1995812
imgFiles=$(
	find "$path_root" -maxdepth 5 -mindepth 3 -type f -not -path '*/thumbnails*' |
	file --mime-type -f - |
	grep -F image/ |
	rev | cut -d : -f 2- | rev | sort
)

# delete the folder readme files
find "$path_root" -maxdepth 5 -mindepth 3 -type f -iname 'readme.md' -delete

i=0
total=$(echo "$imgFiles" | wc -l)

echo "$imgFiles" | while read -r src; do
	((i++)) || true
	filename="$(basename "$src")"
	printf '%4d/%d: %s... ' "$i" "$total" "$filename"

	dirReadmePath="$(dirname "$src")/README.MD"
	dirAttribPath="$(dirname "$src")/attrib.md"
	if [ -f "$dirAttribPath" ]
	then
		attrib="$(grep -iPo "(?<=$(quoteRe "$filename")\s).+$" "$dirAttribPath")" || true
	else
		attrib=''
	fi

	# attempted to pull attribution from metadata using imagemagick but did not succeed

	# allow for initial load of attribution from the filename
	if [[ -z "$attrib" && "$filename" == *"_by_"* ]]
	then
		attrib="$(echo "${filename%%.*}" | sed 's/_/ /g' | sed 's/\( \|^\)\w/\U&/g' | sed 's/ \(By\|And\) /\L&/g' )"
		echo "$filename $attrib" >> "$dirAttribPath"
	fi

	target="${thumbnails_dir}/${src#"$path_root/"}"
	thumbnail_old="${thumbnails_old_dir}/${src#"$path_root/"}"

	target_dir="$(dirname "$target")"
	mkdir -p "$target_dir"

	if [[ ! -f "$thumbnail_old" ]]; then
		if [[ "$src" == *"/mobile/"* ]]; then
			targetWidth=97
			aspectRatio="9/20"
		else
			targetWidth=200
			aspectRatio="16/9"
		fi

		targetHeight=$(echo "$targetWidth/($aspectRatio)" | bc -l)
		targetHeight=$(echo ${targetHeight%%.*})
		targetDimensions="${targetWidth}x${targetHeight}"

		# echo
		# echo "aspectRatio: $aspectRatio"
		# echo "targetDimensions: $targetDimensions"

		# resize images, then crop to the desired resolution
		convert -thumbnail $targetDimensions^ -gravity Center -extent $targetDimensions +repage "$src" "$target"
		echo "converted!"
	else
		mv "$thumbnail_old" "$target"
		echo "skipped!"
	fi

	src_escaped="${src// /%20}"
	filename_escaped="${filename// /%20}"
	target_escaped="${target// /%20}"
	dirReadmePath_escaped="${dirReadmePath// /%20}"
	thumb_url="${target_escaped#"$path_root/"}"
	pape_url="${src_escaped#"$path_root/"}"
	dirReadme_url="${dirReadmePath_escaped#"$path_root/"}"

	folderName="$(basename "$(dirname "$src")")"

	if [ -n "$attrib" ]
	then
		# strip markdown links out of the alt text
		alt_text=$(echo "$attrib" | sed 's/([^)]*)//g' | sed 's/[][]//g')
	else
		alt_text="$filename"
	fi

	if [ ! -f "$dirReadmePath" ]
	then
	    echo "## [$folderName]($dirReadme_url)" >> "$thumbnailMD"
	fi

	echo "[![$alt_text]($thumb_url \""$alt_text"\")]($pape_url)" >> "$thumbnailMD" 
	echo "[![$alt_text]($filename_escaped \""$alt_text"\")]($filename_escaped)" >> "$dirReadmePath"
	if [ -n "$attrib" ]
	then
		echo "$attrib" >> "$dirReadmePath"
	fi
	echo >> "$dirReadmePath"
done

readmeTemplate="$(cat "$readmeTemplatePath")"
thumbnailText="$(cat "$thumbnailMD")"
echo "${readmeTemplate/\{thumbnails\}/"$thumbnailText"}" > README.MD

rm "$thumbnailMD"
rm -rf "$thumbnails_old_dir"

# if pandoc is installed, convert the markdown files to html for easy preview and debugging
if type pandoc >/dev/null 2>&1
then
	mdFiles=$(find "$path_root" -maxdepth 5 -type f -iname '*.md')
	echo "$mdFiles" | while read -r src; do
		metaTitle="${src%.*}"
		metaTitle="${metaTitle#"$path_root"}"
		metaTitle="${metaTitle#/}"
		htmlPath="${src%.*}.html"

		# pandoc --from=gfm --to=html --standalone --metadata title="$metaTitle" "$src" -o "$htmlPath"
		htmlText=$(pandoc --from=gfm --to=html --standalone --metadata title="$metaTitle" "$src")
		htmlText=$(echo "${htmlText//.md/.html}")
		htmlText=$(echo "${htmlText//.MD/.html}")
		echo "$htmlText" > "$htmlPath"

		sed -i '12i img {max-width: 100%;	height: auto;}' "$htmlPath"
	
	done
fi
