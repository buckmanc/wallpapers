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

mkdir -p thumbnails
mv thumbnails thumbnails_old
mkdir thumbnails

thumbnailMD="thumbnails.md"
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
	fi

	target="${path_root}/thumbnails/${src#"$path_root/"}"
	thumbnail_old="${path_root}/thumbnails_old/${src#"$path_root/"}"

	target_dir="$(dirname "$target")"
	mkdir -p "$target_dir"

	if [[ ! -f "$thumbnail_old" ]]; then
		# results in thumbnails of varying aspect ratio
		# convert -thumbnail 200x112 "$src" "$target"
		# resize images, then crop to the desired resolution
		# TODO what about mobile/portrait wallpapers?
		convert -thumbnail 200x112^ -gravity Center -extent 200x112 +repage "$src" "$target"
		echo "converted!"
	else
		mv "$thumbnail_old" "$target"
		echo "skipped!"
	fi

	src_escaped="${src// /%20}"
	filename_escaped="${filename// /%20}"
	dirReadmePath_escaped="${dirReadmePath// /%20}"
	thumb_url="thumbnails/${src_escaped#"$path_root/"}"
	pape_url="${src_escaped#"$path_root/"}"
	dirReadme_url="${dirReadmePath_escaped#"$path_root/"}"

	folderName="$(basename "$(dirname "$src")")"

	if [ -n "$attrib" ]
	then
		alt_text="$attrib"
	else
		alt_text="$filename"
	fi

	if [ ! -f "$dirReadmePath" ]
	then
		echo "
<style>
img {
	max-width: 100%;
	height: auto;
}
</style>
	    " >> "$dirReadmePath"

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

readmeTemplate="$(cat markdown_templates/README.MD)"
thumbnailText="$(cat "$thumbnailMD")"
echo "${readmeTemplate/\{thumbnails\}/"$thumbnailText"}" > README.MD

rm "$thumbnailMD"
rm -rf thumbnails_old

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

	
	done
fi
