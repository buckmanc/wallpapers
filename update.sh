set -e

gitroot=$(git rev-parse --show-toplevel)

git fetch --depth 1
if [[ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]
then
	echo "already up to date"
else
	# file mod times are restored here so as to not pollute galleries and recent file lists
	# otherwise the entire repo shows as new every update

	echo "logging file modification times"
	mtimeScript=$("$gitroot/.internals/create_mtime_script.sh")
	git reset --hard origin/main
	git clean -dfx
	git gc --prune=all
	echo "restoring file modification times"
	eval "$mtimeScript"
fi
