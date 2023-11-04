set -e

git fetch --depth 1
git reset --hard origin/main
git clean -dfx
git gc --prune=all
