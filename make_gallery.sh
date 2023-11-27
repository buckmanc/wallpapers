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
# git_root=$(git rev-parse --show-toplevel)
raw_root="https://raw.githubusercontent.com/buckmanc/Wallpapers/main"

thumbnailMD="${path_root}/.internals/thumbnails.md"
thumbnails_dir="${path_root}/.internals/thumbnails"
thumbnails_old_dir="${path_root}/.internals/thumbnails_old"
readmeTemplatePath="${path_root}/.internals/README_template.md"
fileListFile="${path_root}/.internals/filelist.md"

mkdir -p "$thumbnails_dir"
mv "$thumbnails_dir" "$thumbnails_old_dir"
mkdir -p "$thumbnails_dir"

rm "$thumbnailMD" > /dev/null 2>&1 || true
rm "$fileListFile" > /dev/null 2>&1 || true


# stackoverflow.com/a/60559975/1995812
imgFiles=$(
	find "$path_root" -maxdepth 5 -mindepth 3 -type f -not -path '*/thumbnails*' |
	file --mime-type -f - |
	grep -F image/ |
	rev | cut -d : -f 2- | rev |
	sort -t'/' -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k6,6 -k7,7
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
		# sort the attrib files
		sort -u -o "$dirAttribPath" "$dirAttribPath"

		attrib="$(grep -iPo "(?<=$(quoteRe "$filename")\s).+$" "$dirAttribPath")" || true
	else
		attrib=''
	fi

	# attempted to pull attribution from metadata using imagemagick but did not succeed

	# allow for initial load of attribution from the filename
	if [[ -z "$attrib" ]] && echo "$filename" | grep -qiP "[-_ ]by[-_ ]"
	then
		attrib="$(echo "${filename%%.*}" | sed 's/[-_]/ /g' | sed 's/\( \|^\)\w/\U&/g' | sed 's/ \(By\|And\) /\L&/g' )"
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
		targetHeight="${targetHeight%%.*}"
		targetDimensions="${targetWidth}x${targetHeight}"

		# echo
		# echo "aspectRatio: $aspectRatio"
		# echo "targetDimensions: $targetDimensions"

		# resize images, then crop to the desired resolution
		convert -background none -thumbnail "$targetDimensions^" -unsharp 0x1.0 -gravity Center -extent "$targetDimensions" +repage "$src" "$target"
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
	pape_url="$raw_root/${src_escaped#"$path_root/"}"
	dirReadme_url="${dirReadmePath_escaped#"$path_root/"}"

	folderName="$(basename "$(dirname "$src")")"
	parentFolderName="$(basename "$(dirname "$(dirname "$src")")")"
	folderPath="$(dirname "$src")"
	parentFolderPath="$(dirname "$(dirname "$src")")"

	if [ -n "$attrib" ]
	then
		# strip markdown links out of the alt text
		alt_text=$(echo "$attrib" | sed 's/([^)]*)//g' | sed 's/[][]//g')
	else
		alt_text="$filename"
	fi

	folderPathReggie="$(quoteRe "${folderPath}/")"
	parentFolderPathReggie="$(quoteRe "${parentFolderPath}/")"
	parentFolderHeader="# $parentFolderName - $(echo "$imgFiles" | grep -iPc "$parentFolderPathReggie")"
	folderHeader="## [$folderName]($dirReadme_url) - $(echo "$imgFiles" | grep -iPc "$folderPathReggie")"

	# echo "${thumbnailMD}"
	# echo  "^$(quoteRe "${parentFolderHeader}")$"

	if ! grep -qP "^$(quoteRe "${parentFolderHeader}")$" "$thumbnailMD"
 	then
		echo "${parentFolderHeader}" >> "$thumbnailMD"
	fi
	if ! grep -qP "^$(quoteRe "${folderHeader}")\$" "$thumbnailMD"
	then
	    echo "${folderHeader}" >> "$thumbnailMD"
	fi

	echo    "$src" >> "$fileListFile"
	echo    "[![$alt_text]($thumb_url \"$alt_text\")]($pape_url)" >> "$thumbnailMD" 
	echo -n "[![$alt_text]($filename_escaped \"$alt_text\")]($pape_url)" >> "$dirReadmePath"

	# have to do a bunch of shenanigans to get the attribution immediately below the picture
	if [ -n "$attrib" ]
	then
		echo "\\" >> "$dirReadmePath"
		echo "$attrib" >> "$dirReadmePath"
	else
		echo >> "$dirReadmePath"
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

	i=0
	total=$(echo "$mdFiles" | wc -l)

	echo "$mdFiles" | while read -r src; do
		((i++)) || true
		descname="$(basename "$(dirname "$src")")/$(basename "$src")"
		printf '%4d/%d: %s... ' "$i" "$total" "$descname"
			metaTitle="${src%.*}"
		metaTitle="${metaTitle#"$path_root"}"
		metaTitle="${metaTitle#/}"
		htmlPath="${src%.*}.html"
		if [ -f "$htmlPath" ]
		then
			rm "$htmlPath"
		fi
		

		htmlText=$(pandoc --from=gfm --to=html --standalone --metadata title="$metaTitle" "$src")
		htmlText="${htmlText//.md/.html}"
		htmlText="${htmlText//.MD/.html}"
		htmlText="${htmlText//"$raw_root"/}"

		echo "$htmlText" | while read htmlLine; do

		# write existing line to file
		echo "$htmlLine" >> "$htmlPath"

		if [[ "$htmlLine" == "</header>" ]]
		then
			modText="<iframe name=\"dummyframe\" id=\"dummyframe\" style=\"display: none;\"></iframe>"
		echo "$modText" >> "$htmlPath"

		fi

		if [[ "$htmlLine" == *"href"* && "$htmlLine" == *"img src"* && "$htmlLine" != *".internals/thumbnails"* && "$htmlPath" != *"thumbnails_test"* ]]
		then
			href=$(echo "$htmlLine" | grep -iPo '(?<=href=")[^"]+')
			title=$(echo "$htmlLine" | grep -iPo '(?<=title=")[^"]+')

			#TODO fix this script's indenting

			renamePrefil="$(basename "$href" | urldecode)"
			renamePrefil="${renamePrefil%.*}"
			
			modText="
			<form action=\"/cgi-bin/move\" target=\"dummyframe\">
			<input type=\"hidden\" id=\"dirname\" name=\"dirname\" value=\"$(dirname "$href")\">
			<input type=\"hidden\" id=\"sourcename\" name=\"sourcename\" value=\"$(basename "$href" | urldecode)\">
			  <label for=\"destname\">new file name:</label>
			  <input type=\"text\" id=\"destname\" name=\"destname\" value=\"$renamePrefil\"><br>
				  <input type=\"submit\" value=\"Rename\">
				  </form>
				  <br>
				  "

		# write new stuff to file
		echo "$modText" >> "$htmlPath"

		fi


	done


		sed -i '12i img {max-width: 100%;	height: auto;}' "$htmlPath"
	
		echo "done!"
	done
fi
