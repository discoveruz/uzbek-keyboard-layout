#!/bin/bash
# Runs inside the check container (see linux/check.sh): builds the Linux package from the repo mounted
# at /repo, installs it for this user the way a person would, and checks every key with libxkbcommon.
set -euo pipefail

step() {
    printf '\n== %s\n' "$1"
}

fail() {
    echo "FAILED: $1"
    exit 1
}

expect_input_sources() {
    local sources
    sources=$(gsettings get org.gnome.desktop.input-sources sources)
    [ "$sources" = "$1" ] || fail "GNOME's input sources are $sources, expected $1"
}

# The mount is read-only, and the build writes build/ and dist/.
mkdir /tmp/repo
cp -R /repo/*.klc /repo/build-linux-package.sh /repo/linux /tmp/repo/
cd /tmp/repo

step "Build the package"
./build-linux-package.sh
mkdir /tmp/package
tar -xzf dist/UzbekKeyboardLinux.tar.gz -C /tmp/package
install=/tmp/package/UzbekKeyboardLinux/install.sh
xkb="$HOME/.config/xkb"

step "install.sh leaves someone else's XKB files alone"
mkdir -p "$xkb/rules"
echo "! include %S/evdev" > "$xkb/rules/evdev"
if "$install" direct; then
    fail "install.sh replaced someone else's rules/evdev"
fi
[ "$(cat "$xkb/rules/evdev")" = "! include %S/evdev" ] || fail "install.sh changed someone else's rules/evdev"
[ ! -e "$xkb/symbols/uz2026" ] || fail "install.sh installed some files anyway"
rm -r "$xkb"

step "Install on GNOME"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
"$install" direct
expect_input_sources "[('xkb', 'us'), ('xkb', 'uz2026+direct')]"
# A second run replaces its own files and doesn't add the layout twice.
"$install" direct
"$install" classic
expect_input_sources "[('xkb', 'us'), ('xkb', 'uz2026+direct'), ('xkb', 'uz2026')]"

step "Check every key"
python3 linux/xkblayouts.py verify

step "The check notices a wrong key"
cp "$xkb/symbols/uz2026" /tmp/uz2026
sed -i '0,/odiaeresis/s//adiaeresis/' "$xkb/symbols/uz2026"
if python3 linux/xkblayouts.py verify > /tmp/wrong-key.txt; then
    fail "verify passed with ä in place of ö"
fi
grep -m 3 "<AD09>" /tmp/wrong-key.txt || fail "verify failed, but not on the changed key: $(cat /tmp/wrong-key.txt)"
cp /tmp/uz2026 "$xkb/symbols/uz2026"

step "Remove"
"$install" --remove
expect_input_sources "[('xkb', 'us')]"
python3 linux/xkblayouts.py verify-removed
[ ! -e "$xkb" ] || fail "install.sh --remove left $xkb behind: $(find "$xkb")"

step "Install and remove without GNOME"
# Without GNOME's schemas, as on KDE Plasma, install.sh only says where to add the layout.
XDG_DATA_DIRS=/nonexistent "$install" turkish-style | grep -F "Add Uzbek Latin 2026 (Turkish-style) in your keyboard settings." \
    || fail "install.sh didn't say where to add the layout"
expect_input_sources "[('xkb', 'us')]"
XDG_DATA_DIRS=/nonexistent "$install" --remove
[ ! -e "$xkb" ] || fail "install.sh --remove left $xkb behind: $(find "$xkb")"

. /etc/os-release
printf '\nAll checks passed on %s.\n' "$PRETTY_NAME"
