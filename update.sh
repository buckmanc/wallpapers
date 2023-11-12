set -e

create_mtime_script(){
	git ls-files | while read -r src; do
		if [ -f "$src" ]
		then
			echo "touch -c -d $(date -r "$src" "+%F") \"$src\""
		fi
	done
}

gitroot=$(git rev-parse --show-toplevel)

git fetch --depth 1
if [[ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]
then
	echo "already up to date"
else
	# file mod times are restored here so as to not pollute galleries and recent file lists
	# otherwise the entire repo shows as new every update

	echo "logging file modification times"
	mtimeScript=$(create_mtime_script)
	git reset --hard origin/main
	git clean -dfx
	git gc --prune=all
	echo "restoring file modification times"
	eval "$mtimeScript"
fi
