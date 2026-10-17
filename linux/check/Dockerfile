# The Linux that linux/check.sh tests the layouts on; it builds this once for each version it checks.
ARG BASE=ubuntu:24.04
FROM ${BASE}

# Python runs the generator and the check; libxkbcommon, libxkbregistry and the system's XKB files are
# what desktops build their keyboards from. gsettings and GNOME's schemas stand in for GNOME, whose input
# sources install.sh changes.
RUN if command -v apt-get >/dev/null; then \
        apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            python3 libxkbcommon0 libxkbregistry0 xkb-data libglib2.0-bin gsettings-desktop-schemas \
        && rm -rf /var/lib/apt/lists/*; \
    else \
        dnf install -y python3 libxkbcommon xkeyboard-config glib2 gsettings-desktop-schemas \
            tar gzip findutils shadow-utils \
        && dnf clean all; \
    fi

# install.sh refuses root, and a person's ~/.config/xkb is what the layouts go into.
RUN useradd --create-home tester
USER tester
WORKDIR /home/tester
# Without a desktop session there is no dconf; this backend keeps settings in a file in ~/.config instead.
ENV GSETTINGS_BACKEND=keyfile
