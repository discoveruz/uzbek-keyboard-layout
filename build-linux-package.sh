#!/bin/bash
# Builds dist/UzbekKeyboardLinux.tar.gz: the three layouts as XKB files, generated from the .klc files,
# and install.sh, which installs them into the person's own ~/.config/xkb. Run this again after changing
# a .klc file. Needs Python 3; linux/check.sh tests the package on Linux in Docker.
set -euo pipefail
cd "$(dirname "$0")"

work=build/linux/UzbekKeyboardLinux

python3 -m unittest discover -s linux/tests -t linux
rm -rf build/linux
mkdir -p "$work" dist
python3 linux/xkblayouts.py build "$work/xkb"
cp linux/install.sh "$work/"

rm -f dist/UzbekKeyboardLinux.tar.gz
# COPYFILE_DISABLE stops macOS tar from adding ._ files for extended attributes.
COPYFILE_DISABLE=1 tar -czf dist/UzbekKeyboardLinux.tar.gz -C build/linux UzbekKeyboardLinux
echo "Done: dist/UzbekKeyboardLinux.tar.gz"
