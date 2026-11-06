#!/bin/sh
# Builds dist/WrekkitForever-<version>.zip from the .toc version, with the
# addon inside a folder named WrekkitForever (the client only loads an addon
# whose folder matches its .toc; GitHub's "Source code" archives do not).
#   sh tools/release.sh            build the zip, after the tests pass
#   sh tools/release.sh publish    and publish it as release v<version>
set -e
cd "$(dirname "$0")/.."
version="$(sed -n 's/^## Version: *//p' WrekkitForever/WrekkitForever.toc | tr -d '\r')"
lua tools/test.lua
rm -rf dist && mkdir -p dist
python -c "import shutil; shutil.make_archive('dist/WrekkitForever-$version', 'zip', '.', 'WrekkitForever')"
echo "built dist/WrekkitForever-$version.zip"
if [ "$1" = "publish" ]; then
  git tag -a "v$version" -m "Wrekkit Forever $version"
  git push origin "v$version"
  gh release create "v$version" "dist/WrekkitForever-$version.zip" \
    --title "Wrekkit Forever $version" --notes-file .github/release-notes.md
fi
