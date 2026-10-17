"""Builds the Linux layouts from the .klc files, and checks the installed ones.

build writes symbols/uz2026, types/uz2026, rules/evdev and rules/evdev.xml, which install.sh copies into
~/.config/xkb. verify checks every key of the installed layouts against the .klc files, and
verify-removed checks that install.sh --remove left nothing behind.
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import List, Tuple

import klc
import xkb_files
from klc import KlcLayout

USAGE = """\
usage: xkblayouts.py build <output folder>
       xkblayouts.py verify
       xkblayouts.py verify-removed
Run it in the folder with the .klc files (the repo root)."""

# The three layouts, the .klc files they come from and their XKB variants; the first is the default.
# Catalog in installer/Layouts.cs and MacLayouts.swift list the same three.
LAYOUTS = [
    ("Uzbek-Latin-2026-Classic.klc", "classic"),
    ("Uzbek-Latin-2026-Direct.klc", "direct"),
    ("Uzbek-Latin-2026-Turkish-style.klc", "turkish-style"),
]


def load_layouts(folder: Path) -> List[Tuple[str, KlcLayout]]:
    layouts = []
    for file, variant in LAYOUTS:
        path = folder / file
        # A missing file almost always means xkblayouts.py runs in the wrong folder.
        if not path.exists():
            raise klc.KlcError(f"Can't find {file} in {folder}. Run xkblayouts.py from the repo root, where the .klc files are.")
        layouts.append((variant, klc.load(path)))
    return layouts


def main(arguments: List[str]) -> int:
    folder = Path.cwd()
    try:
        if len(arguments) == 2 and arguments[0] == "build":
            xkb_files.write(load_layouts(folder), Path(arguments[1]))
            print(f"Wrote the XKB files to {arguments[1]}")
            return 0
        if arguments in (["verify"], ["verify-removed"]):
            # Only the checks need libxkbcommon, so building works anywhere.
            import verifier
            try:
                passed, report = verifier.run(load_layouts(folder)) if arguments == ["verify"] else verifier.run_removed()
            except verifier.VerifyError as error:
                print(error, file=sys.stderr)
                return 1
            print("\n".join(report))
            return 0 if passed else 1
    except (klc.KlcError, xkb_files.XkbError) as error:
        print(error, file=sys.stderr)
        return 1
    print(USAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
