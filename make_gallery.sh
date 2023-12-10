#!/usr/bin/env bash
set -e

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
tocMD="${path_root}/.internals/tableofcontents.md"
thumbnails_dir="${path_root}/.internals/thumbnails"
thumbnails_old_dir="${path_root}/.internals/thumbnails_old"
readmeTemplatePath="${path_root}/.internals/README_template.md"
fileListFile="${path_root}/.internals/filelist.md"

mkdir -p "$thumbnails_dir"
mv "$thumbnails_dir" "$thumbnails_old_dir"
mkdir -p "$thumbnails_dir"

rm "$thumbnailMD" > /dev/null 2>&1 || true
rm "$tocMD" > /dev/null 2>&1 || true
rm "$fileListFile" > /dev/null 2>&1 || true


# stackoverflow.com/a/60559975/1995812
GetImageFiles() {
	find "$path_root" -maxdepth 5 -mindepth 3 -type f -not -path '*/thumbnails*' |
	file --mime-type -f - |
	grep -F image/ |
	rev | cut -d : -f 2- | rev |
	sort -t'/' -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k6,6 -k7,7
}
imgFiles="$(GetImageFiles)"

# if type pyphash-sort >/dev/null 2>&1
# then
# 	echo "calculating perceptual hash sort"
# 	echo "this could take a while"
# 	imgFiles="$(echo "$imgFiles" | pyphash-sort "(/forests/|/space/|/misc/|/leaves/)")"
# fi

# if perceptual hashing is available, append the hash to the start of the file for applicable categories
if type pyphash >/dev/null 2>&1
then
	echo -n "checking for missing perceptual hash sort data..."
	echo "$imgFiles" | while read -r path
	do
		filename="$(basename "$path")"
		if echo "$path" | grep -qiP "(/forests/|/space/|/misc/|/leaves/)" && ! echo "$filename" | grep -qiP '^[a-f0-9]{16}_'
		then
			echo -n "moving ${path}..."
			newPath="$(dirname "$path")/$(pyphash "$path")_$filename"
			mv --backup=numbered "$path" "$newPath"
			echo "done"
		fi

	done

	imgFiles="$(GetImageFiles)"

	echo "done!"
fi


# delete the folder readme files
find "$path_root" -maxdepth 5 -mindepth 3 -type f -iname 'readme.md' -delete

i=0
totalImages=$(echo "$imgFiles" | wc -l)

echo "$imgFiles" | while read -r src; do
	((i++)) || true
	filename="$(basename "$src")"
	printf '\033[2K%4d/%d: %s...' "$i" "$totalImages" "$filename" | cut -c "-$COLUMNS" | tr -d $'\n'

	dirReadmePath="$(dirname "$src")/README.MD"

	attrib=''
	dirAttribPath="$(dirname "$src")/attrib.md"
	if [ -f "$dirAttribPath" ]
	then
		# sort the attrib files
		sort -u -o "$dirAttribPath" "$dirAttribPath"

		attrib="$(grep -iPo "(?<=$(quoteRe "$filename")\s).+$" "$dirAttribPath")" | sed 's/ \+/ /g' || true
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

		fitCaret="^"
		bgColor="none"

		# altered logic for images that sit in the center
		if echo "$src" | grep -iq "/floaters/"
		then
			fitCaret=""
			bgColor="black"
		fi

		# resize images, then crop to the desired resolution
		convert -background "$bgColor" -thumbnail "${targetDimensions}${fitCaret}" -unsharp 0x1.0 -gravity Center -extent "$targetDimensions" +repage "$src" "$target"
		# echo "converted!"
		echo ""
	else
		mv "$thumbnail_old" "$target"
		# echo "skipped!"
		echo -en "\r"
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

	folderCount="$(echo "$imgFiles" | grep -iPc "$folderPathReggie")"
	parentFolderCount="$(echo "$imgFiles" | grep -iPc "$parentFolderPathReggie")"

	# specifying a custom ID failed locally
	# generating a copy of the auto header id by using the visible text and replacing spaces
	folderAutoHeaderID="$(echo "$folderName - $folderCount" | sed 's/ /-/g')"
	parentFolderAutoHeaderID="$(echo "$parentFolderName - $parentFolderCount" | sed 's/ /-/g')"

	parentFolderHeader="# $parentFolderName - $parentFolderCount"

	folderHeader="## [$folderName]($dirReadme_url) - $folderCount"
	parentFolderToc="$parentFolderName - $parentFolderCount" # linking here isn't working, probably because it ends up in an HTML tag
	# plus how would you expand the section?
	folderToc="[$folderName](#$folderAutoHeaderID) - $(echo "$imgFiles" | grep -iPc "$folderPathReggie")"

	# echo "${thumbnailMD}"
	# echo  "^$(quoteRe "${parentFolderHeader}")$"

	if ! grep --no-messages -qP "^$(quoteRe "${parentFolderHeader}")$" "$thumbnailMD"
 	then
		echo "${parentFolderHeader}" >> "$thumbnailMD"
		echo "</details><details><summary>${parentFolderToc}</summary>" >> "$tocMD"
	fi
	if ! grep -qP "^$(quoteRe "${folderHeader}")\$" "$thumbnailMD"
	then
		echo "${folderHeader}" >> "$thumbnailMD"
		echo "" >> "$tocMD"
		echo "- ${folderToc}" >> "$tocMD"
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

echo ""

thumbnailText="$(cat "$thumbnailMD")"
tocText="$(cat "$tocMD" | perl -00pe 's/^<\/details>//g')</details>"
readmeTemplate="$(cat "$readmeTemplatePath")"
readmeTemplate="${readmeTemplate/\{thumbnails\}/"$thumbnailText"}" 
readmeTemplate="${readmeTemplate/\{table of contents\}/"$tocText"}" 
readmeTemplate="${readmeTemplate/\{total\}/"$(numfmt --grouping "$totalImages")"}" 
echo "$readmeTemplate" > README.MD

rm "$thumbnailMD"
rm "$tocMD"
rm -rf "$thumbnails_old_dir"

# if pandoc is installed, convert the markdown files to html for easy preview and debugging
if type pandoc >/dev/null 2>&1
then
	mdFiles=$(find "$path_root" -maxdepth 5 -type f -iname '*.md' -not -path '*/.internals/*' -not -iname 'attrib.md' | sort -t'/' -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k6,6 -k7,7)

	i=0
	total=$(echo "$mdFiles" | wc -l)

	echo "$mdFiles" | while read -r src
	do
		((i++)) || true
		descname="$(basename "$(dirname "$src")")/$(basename "$src")"
		printf '\033[2K%4d/%d: %s...' "$i" "$total" "$descname" | cut -c "-$COLUMNS" | tr -d $'\n'
		metaTitle="${src%.*}"
		metaTitle="${metaTitle#"$path_root"}"
		metaTitle="${metaTitle#/}"
		metaTitle="$(echo "$metaTitle" | sed 's|/README$||g')"

		if [ "${src,,}" = "${path_root,,}/readme.md" ]
		then
			metaTitle="Wallpapers"
		fi
		htmlPath="${src%.*}.html"
		if [ -f "$htmlPath" ]
		then
			rm "$htmlPath"
		fi
		

		htmlText=$(pandoc --from=gfm+auto_identifiers --to=html --standalone --metadata title="$metaTitle" "$src")
		htmlText="${htmlText//.md/.html}"
		htmlText="${htmlText//.MD/.html}"
		htmlText="${htmlText//"$raw_root"/}"

		echo "$htmlText" | while read htmlLine
		do

			# write existing line to file
			echo "$htmlLine" >> "$htmlPath"

			if [[ "$htmlLine" == "</header>" ]]
			then
				modText="<iframe name=\"dummyframe\" id=\"dummyframe\" style=\"display: none;\"></iframe>"
				echo "$modText" >> "$htmlPath"

			fi

			if [[ "$htmlLine" == *"href"* && "$htmlLine" == *"img src"* && "$htmlLine" != *".internals/thumbnails"* && "$htmlPath" != *"thumbnails_test"* ]]
			then
				href="$(echo "$htmlLine" | grep -iPo '(?<=href=")[^"]+' | urldecode)"
				title=$(echo "$htmlLine" | grep -iPo '(?<=title=")[^"]+')

				renamePrefil="$(basename "$href")"
				renamePrefil="${renamePrefil%.*}"
				if [ -f "${path_root}${href}" ]
				then
					resolution=$(identify -ping -format '%wx%h' "${path_root}${href}" 2>&1)
				else
					resolution="???"

				fi
				
				modText="
				<form action=\"/cgi-bin/move\" target=\"dummyframe\" style='width:400px'>
				<input type=\"hidden\" id=\"dirname\" name=\"dirname\" value=\"$(dirname "$href")\">
				<input type=\"hidden\" id=\"sourcename\" name=\"sourcename\" value=\"$(basename "$href")\">
				<label>${resolution}</label>
				<br>
				<label for=\"destname\">new file name:</label>
				<input type=\"text\" id=\"destname\" name=\"destname\" style='width:100%' value=\"$renamePrefil\"><br>
				<input type=\"submit\" value=\"Rename\">
				</form>
				<br>
				"

				# write new stuff to file
				echo "$modText" >> "$htmlPath"

			fi


		done

		# make sure images don't blow out the page
		sed -i '12i img {max-width: 100%;	height: auto;}' "$htmlPath"
		# remove that double header from the main readme
		perl -i -00pe 's|<header.+?>Wallpapers<.+?</header>||gs' "$htmlPath"

		echo -en "\r"

	done
fi

echo ""

echo "done at $(date)"
