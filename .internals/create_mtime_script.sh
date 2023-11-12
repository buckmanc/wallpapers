

git ls-files | while read -r src; do
	echo "touch -c -d $(date -r "$src" "+%F") \"$src\""
done
