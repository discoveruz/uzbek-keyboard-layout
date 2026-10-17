#!/bin/bash
# Installs the Uzbek Latin 2026 keyboard layouts for the person running it, into ~/.config/xkb, where
# Wayland desktops (GNOME, KDE Plasma and others) look for keyboard layouts of their own. No sudo needed.
#
#   ./install.sh                 asks which layout to turn on
#   ./install.sh direct          classic, direct or turkish-style
#   ./install.sh --remove        takes the layouts out again
#
# All three layouts are installed either way; on GNOME the chosen one is also added to the input sources.
# It ships in UzbekKeyboardLinux.tar.gz next to the xkb folder that build-linux-package.sh generates.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
xkb="${XDG_CONFIG_HOME:-$HOME/.config}/xkb"
files=(symbols/uz2026 types/uz2026 rules/evdev rules/evdev.xml)
# Every file this installs has this in a comment; a file without it belongs to someone else.
marker="Uzbek Latin 2026 keyboard layouts"

# Prints a message in Uzbek, then in English.
say() {
    printf '%s\n%s\n\n' "$1" "$2"
}

usage() {
    say "Foydalanish: ./install.sh [classic | direct | turkish-style], oʻchirish uchun ./install.sh --remove" \
        "Usage: ./install.sh [classic | direct | turkish-style], or ./install.sh --remove to take the layouts out"
}

ours() {
    grep -qF "$marker" "$1" 2>/dev/null
}

gnome() {
    command -v gsettings >/dev/null && gsettings list-keys org.gnome.desktop.input-sources >/dev/null 2>&1
}

layout_name() {
    case "$1" in
        classic) echo "Uzbek Latin 2026 (Classic)" ;;
        direct) echo "Uzbek Latin 2026 (Direct)" ;;
        turkish-style) echo "Uzbek Latin 2026 (Turkish-style)" ;;
    esac
}

# GNOME keeps its keyboards in a list such as [('xkb', 'us'), ('xkb', 'uz2026+direct')]; Classic is the
# default layout, so it is plain 'uz2026'.
input_source() {
    if [ "$1" = classic ]; then echo "('xkb', 'uz2026')"; else echo "('xkb', 'uz2026+$1')"; fi
}

add_input_source() {
    local source sources
    source=$(input_source "$1")
    sources=$(gsettings get org.gnome.desktop.input-sources sources)
    case "$sources" in
        *"$source"*) return ;;
        *"[]") sources="[$source]" ;;
        *) sources="${sources%]}, $source]" ;;
    esac
    gsettings set org.gnome.desktop.input-sources sources "$sources"
}

remove_input_sources() {
    local sources remaining
    sources=$(gsettings get org.gnome.desktop.input-sources sources)
    remaining=$(printf '%s' "$sources" | sed -E "s/\('xkb', 'uz2026(\+[a-z-]+)?'\)(, )?//g; s/, \]$/]/")
    if [ "$remaining" != "$sources" ]; then
        gsettings set org.gnome.desktop.input-sources sources "$remaining"
    fi
}

choose_layout() {
    say "Qaysi klaviatura yoqilsin?" "Which layout should be turned on?"
    printf '  1) Klassik · Classic\n  2) Toʻgʻridan-toʻgʻri · Direct\n  3) Turkcha uslub · Turkish-style\n\n'
    local answer
    while true; do
        read -r -p "Raqamini kiriting · Type its number (1-3): " answer
        case "$answer" in
            1) layout=classic; return ;;
            2) layout=direct; return ;;
            3) layout=turkish-style; return ;;
        esac
    done
}

install_layouts() {
    local layout=$1 file
    if [ ! -d "$here/xkb" ]; then
        say "Klaviatura fayllari bu dastur yonida yoʻq. UzbekKeyboardLinux.tar.gz ichidagi install.sh ni ishga tushiring." \
            "The layout files aren't next to this script. Run the install.sh from UzbekKeyboardLinux.tar.gz."
        exit 1
    fi
    # Check every file first, so that nothing changes when one belongs to someone else.
    for file in "${files[@]}"; do
        if [ -e "$xkb/$file" ] && ! ours "$xkb/$file"; then
            say "$xkb/$file allaqachon mavjud va uni bu dastur yaratmagan, shuning uchun hech narsa oʻzgartirilmadi. Uni $here/xkb/$file bilan qoʻlda birlashtiring yoki boshqa joyga koʻchirib, dasturni qayta ishga tushiring." \
                "$xkb/$file already exists and isn't from this installer, so nothing was changed. Merge it by hand with $here/xkb/$file, or move it away and run this again."
            exit 1
        fi
    done
    for file in "${files[@]}"; do
        mkdir -p "$(dirname "$xkb/$file")"
        cp "$here/xkb/$file" "$xkb/$file"
    done
    say "Klaviaturalar $xkb papkasiga oʻrnatildi." "The layouts are installed in $xkb."

    if [ -n "$layout" ]; then
        if gnome; then
            add_input_source "$layout"
            say "$(layout_name "$layout") kiritish manbalariga qoʻshildi." "$(layout_name "$layout") is added to your input sources."
        else
            say "$(layout_name "$layout") ni klaviatura sozlamalarida qoʻshing." "Add $(layout_name "$layout") in your keyboard settings."
        fi
    fi
    # X servers only read the system's XKB folder, never ~/.config/xkb.
    if [ "${XDG_SESSION_TYPE:-}" = x11 ]; then
        say "Bu X11 seansi, bu klaviaturalar esa faqat Wayland seansida ishlaydi. Kirish oynasida Wayland seansini tanlang." \
            "This is an X11 session, and these layouts only work in a Wayland session. Pick one on the login screen."
    fi
    # Desktops only look for ~/.config/xkb when they start.
    say "Klaviaturadan foydalanish uchun tizimdan chiqib, qayta kiring." "Log out and back in to start using it."
}

remove_layouts() {
    local file
    for file in "${files[@]}"; do
        if ours "$xkb/$file"; then
            rm "$xkb/$file"
        fi
    done
    # Only empty folders go; ~/.config/xkb may hold someone else's files too.
    rmdir "$xkb/symbols" "$xkb/types" "$xkb/rules" "$xkb" 2>/dev/null || true
    if gnome; then
        remove_input_sources
    fi
    say "Klaviaturalar oʻchirildi. Tizimdan chiqib, qayta kiring." "The layouts are removed. Log out and back in to finish."
}

if [ "$(id -u)" -eq 0 ]; then
    say "Bu dasturni sudo bilan emas, oʻz hisobingizdan ishga tushiring: klaviaturalar faqat sizning hisobingizga oʻrnatiladi." \
        "Run this as yourself, not with sudo: the layouts are installed for your account only."
    exit 1
fi

case "${1:-}" in
    --remove)
        remove_layouts
        ;;
    classic | direct | turkish-style)
        install_layouts "$1"
        ;;
    "")
        layout=""
        if [ -t 0 ]; then
            choose_layout
        fi
        install_layouts "$layout"
        ;;
    -h | --help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac
