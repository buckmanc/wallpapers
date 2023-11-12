set -e

git fetch --depth 1
if [[ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]
then
	echo "already up to date"
else
	git reset --hard origin/main
	git clean -dfx
	git gc --prune=all
fi
