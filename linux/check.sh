#!/bin/bash
# Checks the Linux layouts on Linux, in Docker. For each Linux version, linux/check/run.sh builds the
# package from the .klc files, installs it for a test user as a person would, and checks every key with
# libxkbcommon, which GNOME, KDE Plasma and other Wayland desktops build their keyboards with.
#
#   linux/check.sh                  Ubuntu 22.04 (libxkbcommon 1.4), Ubuntu 24.04 and the latest Fedora
#   linux/check.sh debian:13        only the images given
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -gt 0 ]; then
    images=("$@")
else
    images=(ubuntu:22.04 ubuntu:24.04 fedora:latest)
fi

for image in "${images[@]}"; do
    printf '\n=== %s\n' "$image"
    tag="uzbek-keyboard-check:${image//[:\/]/-}"
    docker build --quiet --build-arg BASE="$image" --tag "$tag" linux/check
    docker run --rm --volume "$PWD:/repo:ro" "$tag" bash /repo/linux/check/run.sh
done
printf '\nPassed on %s.\n' "${images[*]}"
