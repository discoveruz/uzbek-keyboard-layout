"""Writes the Linux (XKB) versions of the layouts from the .klc layouts.

Each layout is US (us(basic)) with the .klc's keys on top, and right Alt as AltGr. A key that types
something other than on US keeps its US characters for Control, in Levels 5 and 6 of a key type in
types/uz2026, so shortcuts stay where they are on a US keyboard, as Windows keeps them through the
.klc's VK column and the Mac layouts through Apple's U.S. Control maps.
"""
from __future__ import annotations

import itertools
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, FrozenSet, List, Optional, Sequence, Tuple
from xml.sax.saxutils import escape

import klc
from klc import KlcKey, KlcLayout

# The layouts' name in XKB: symbols/uz2026, with sections such as uz2026(direct).
LAYOUT_NAME = "uz2026"
# In a comment at the top of every file written here; install.sh only replaces or removes files that have it.
MARKER = "Uzbek Latin 2026 keyboard layouts"

SHIFT, LOCK, LEVEL3, CONTROL = "Shift", "Lock", "LevelThree", "Control"
LEVEL_NAMES = ["Base", "Shift", "AltGr", "Shift AltGr", "Control", "Shift Control"]

# What each key types on US, alone and with Shift.
US_KEYS: Dict[str, Tuple[str, str]] = {
    "TLDE": ("`", "~"), "AE01": ("1", "!"), "AE02": ("2", "@"), "AE03": ("3", "#"), "AE04": ("4", "$"),
    "AE05": ("5", "%"), "AE06": ("6", "^"), "AE07": ("7", "&"), "AE08": ("8", "*"), "AE09": ("9", "("),
    "AE10": ("0", ")"), "AE11": ("-", "_"), "AE12": ("=", "+"),
    "AD01": ("q", "Q"), "AD02": ("w", "W"), "AD03": ("e", "E"), "AD04": ("r", "R"), "AD05": ("t", "T"),
    "AD06": ("y", "Y"), "AD07": ("u", "U"), "AD08": ("i", "I"), "AD09": ("o", "O"), "AD10": ("p", "P"),
    "AD11": ("[", "{"), "AD12": ("]", "}"), "BKSL": ("\\", "|"),
    "AC01": ("a", "A"), "AC02": ("s", "S"), "AC03": ("d", "D"), "AC04": ("f", "F"), "AC05": ("g", "G"),
    "AC06": ("h", "H"), "AC07": ("j", "J"), "AC08": ("k", "K"), "AC09": ("l", "L"), "AC10": (";", ":"),
    "AC11": ("'", '"'),
    "AB01": ("z", "Z"), "AB02": ("x", "X"), "AB03": ("c", "C"), "AB04": ("v", "V"), "AB05": ("b", "B"),
    "AB06": ("n", "N"), "AB07": ("m", "M"), "AB08": (",", "<"), "AB09": (".", ">"), "AB10": ("/", "?"),
    "SPCE": (" ", " "),
}

# The standard XKB four-level types for the .klc's Cap flags 0, 1 and 5.
FOUR_LEVEL_TYPES = {
    (False, False): "FOUR_LEVEL",
    (True, False): "FOUR_LEVEL_SEMIALPHABETIC",
    (True, True): "FOUR_LEVEL_ALPHABETIC",
}

# Keysym names for the ASCII symbols; letters and digits are their own names.
ASCII_KEYSYMS = {
    " ": "space", "!": "exclam", '"': "quotedbl", "#": "numbersign", "$": "dollar", "%": "percent",
    "&": "ampersand", "'": "apostrophe", "(": "parenleft", ")": "parenright", "*": "asterisk", "+": "plus",
    ",": "comma", "-": "minus", ".": "period", "/": "slash", ":": "colon", ";": "semicolon", "<": "less",
    "=": "equal", ">": "greater", "?": "question", "@": "at", "[": "bracketleft", "\\": "backslash",
    "]": "bracketright", "^": "asciicircum", "_": "underscore", "`": "grave", "{": "braceleft", "|": "bar",
    "}": "braceright", "~": "asciitilde",
}
# The Uzbek letters' keysym names. Characters without a name here are written as Unicode keysyms
# (U02BC); `xkblayouts.py verify` checks that libxkbcommon has no other keysym for them.
LETTER_KEYSYMS = {
    "ö": "odiaeresis", "Ö": "Odiaeresis", "ç": "ccedilla", "Ç": "Ccedilla",
    "ş": "scedilla", "Ş": "Scedilla", "ğ": "gbreve", "Ğ": "Gbreve",
}


class XkbError(Exception):
    pass


@dataclass(frozen=True)
class KeyType:
    """One of the types in types/uz2026."""
    name: str
    modifiers: Tuple[str, ...]
    # For every combination of the modifiers: the level it picks and the modifiers it leaves unconsumed.
    entries: Tuple[Tuple[FrozenSet[str], int, FrozenSet[str]], ...]


@dataclass
class KeyDefinition:
    type: str
    keysyms: List[str]
    # The type's definition when it's one from types/uz2026 rather than a standard XKB type.
    custom_type: Optional[KeyType] = None


def keysym_name(character: Optional[str]) -> str:
    if character is None:
        return "NoSymbol"
    if character.isascii() and character.isalnum():
        return character
    return ASCII_KEYSYMS.get(character) or LETTER_KEYSYMS.get(character) or f"U{ord(character):04X}"


def us_key(name: str) -> KlcKey:
    base, shift = US_KEYS[name]
    # On US, Caps Lock only works on the letters.
    return KlcKey(base, shift, None, None, caps_lock=base.isalpha(), caps_lock_alt_gr=False)


def key_definitions(layout: KlcLayout) -> Dict[str, KeyDefinition]:
    """The keys that type something other than on US, in keyboard order; us(basic) has the rest."""
    definitions: Dict[str, KeyDefinition] = {}
    for name in klc.XKB_KEY_NAMES.values():
        key = layout.keys.get(name)
        if key is None:
            continue
        us = us_key(name)
        changes_us = (key.base, key.shift, key.caps_lock) != (us.base, us.shift, us.caps_lock)
        has_alt_gr = key.alt_gr is not None or key.alt_gr_shift is not None
        if not changes_us and not has_alt_gr:
            continue
        four_level = FOUR_LEVEL_TYPES.get((key.caps_lock, key.caps_lock_alt_gr))
        if four_level is None:
            raise XkbError(f"Key <{name}>: Caps Lock only with AltGr (Cap flag 4) isn't supported on Linux yet.")
        characters = [key.base, key.shift, key.alt_gr, key.alt_gr_shift]
        if not changes_us:
            # Only AltGr changes, so with Control the key already types what it types on US.
            definitions[name] = KeyDefinition(four_level, [keysym_name(c) for c in characters])
        elif not has_alt_gr:
            raise XkbError(f"Key <{name}> types something other than on US but has nothing on AltGr; "
                           "the Linux layouts can't carry that over yet.")
        else:
            key_type = control_type(key.caps_lock, key.caps_lock_alt_gr, us.caps_lock)
            keysyms = [keysym_name(c) for c in characters + [us.base, us.shift]]
            definitions[name] = KeyDefinition(key_type.name, keysyms, key_type)
    return definitions


def control_type(caps_lock: bool, caps_lock_alt_gr: bool, us_letter: bool) -> KeyType:
    """The type for a key that types something other than on US.

    Levels 1 to 4 are the key alone, Shift, AltGr and Shift+AltGr, with Caps Lock as the .klc's Cap flag
    says. With Control and without AltGr, the key types its US character instead: Level 5, or Level 6
    with Shift, or with Caps Lock where the US key is a letter. Control is never consumed, so apps see
    the US character with Control held, exactly as on US.
    """
    name = f"UZ2026_{FOUR_LEVEL_TYPES[(caps_lock, caps_lock_alt_gr)]}_CONTROL_{'ALPHABETIC' if us_letter else 'TWO_LEVEL'}"
    uses_lock = caps_lock or caps_lock_alt_gr or us_letter
    modifiers = (SHIFT, LOCK, LEVEL3, CONTROL) if uses_lock else (SHIFT, LEVEL3, CONTROL)
    entries = []
    for count in range(len(modifiers) + 1):
        for combination in itertools.combinations(modifiers, count):
            on = frozenset(combination)
            shift, lock = SHIFT in on, LOCK in on
            if CONTROL in on and LEVEL3 not in on:
                level = 6 if shift != (lock and us_letter) else 5
                # Where Caps Lock does nothing to the US key, it stays unconsumed, as on US.
                preserved = {CONTROL, LOCK} if lock and not us_letter else {CONTROL}
            else:
                if LEVEL3 in on:
                    level = 4 if shift != (lock and caps_lock_alt_gr) else 3
                else:
                    level = 2 if shift != (lock and caps_lock) else 1
                preserved = {CONTROL} & on
            entries.append((on, level, frozenset(preserved)))
    return KeyType(name, modifiers, tuple(entries))


def key_types(layouts: Sequence[KlcLayout]) -> List[KeyType]:
    """The types from types/uz2026 that the layouts use, each once."""
    types: Dict[str, KeyType] = {}
    for layout in layouts:
        for definition in key_definitions(layout).values():
            if definition.custom_type is not None:
                types.setdefault(definition.type, definition.custom_type)
    return list(types.values())


def symbols_file(layouts: Sequence[Tuple[str, KlcLayout]]) -> str:
    """symbols/uz2026: a section for each layout, named after its variant; the first is the default."""
    lines = [
        f"// {MARKER}, generated from the .klc files by linux/xkblayouts.py.",
        "// Don't edit this file: change the .klc file and build again.",
        "//",
        "// Each layout is US with the .klc's keys on top, and right Alt is AltGr. A key that types",
        "// something other than on US keeps its US characters for Control (Levels 5 and 6, see",
        "// types/uz2026), so shortcuts stay where they are on a US keyboard.",
    ]
    for index, (variant, layout) in enumerate(layouts):
        lines += [
            "",
            ("default " if index == 0 else "") + "partial alphanumeric_keys modifier_keys",
            f'xkb_symbols "{variant}" {{',
            '    include "us(basic)"',
            f'    name[Group1] = "{layout.name}";',
            "",
        ]
        for name, definition in key_definitions(layout).items():
            lines.append(f'    key <{name}> {{ type[Group1] = "{definition.type}", [ {", ".join(definition.keysyms)} ] }};')
        lines += ["", '    include "level3(ralt_switch)"', "};"]
    return "\n".join(lines) + "\n"


def types_file(types: Sequence[KeyType]) -> str:
    lines = [
        f"// {MARKER}, generated from the .klc files by linux/xkblayouts.py.",
        "// Don't edit this file: change the .klc file and build again.",
        "//",
        "// The types of the keys that type something other than on US; see control_type in",
        "// linux/xkb_files.py. rules/evdev adds them whenever a uz2026 layout is in use.",
        "",
        'default partial xkb_types "default" {',
        "    virtual_modifiers LevelThree;",
    ]
    for key_type in types:
        lines += ["", f'    type "{key_type.name}" {{', f"        modifiers = {'+'.join(key_type.modifiers)};"]
        for on, level, preserved in key_type.entries:
            lines.append(f"        map[{modifier_list(on)}] = Level{level};")
            if preserved:
                lines.append(f"        preserve[{modifier_list(on)}] = {modifier_list(preserved)};")
        for level, level_name in enumerate(LEVEL_NAMES, 1):
            lines.append(f'        level_name[Level{level}] = "{level_name}";')
        lines.append("    };")
    lines.append("};")
    return "\n".join(lines) + "\n"


def modifier_list(modifiers: FrozenSet[str]) -> str:
    return "+".join(m for m in (SHIFT, LOCK, LEVEL3, CONTROL) if m in modifiers) or "None"


def rules_file() -> str:
    """rules/evdev: the system's rules, plus types/uz2026 whenever a uz2026 layout is in use."""
    lines = [
        f"// {MARKER}, generated by linux/xkblayouts.py. Don't edit this file.",
        "//",
        "// The system's rules, plus the key types in types/uz2026 whenever a uz2026 layout is in use:",
        "// on its own (layout) or as one of several (layout[1] to layout[4]). layout[any] would cover",
        "// them all, but needs libxkbcommon 1.8.",
        "",
        "! include %S/evdev",
    ]
    for header in ["layout"] + [f"layout[{index}]" for index in range(1, 5)]:
        lines += ["", f"! {header} = types", f"  {LAYOUT_NAME} = +{LAYOUT_NAME}"]
    return "\n".join(lines) + "\n"


def registry_file(layouts: Sequence[Tuple[str, KlcLayout]]) -> str:
    """rules/evdev.xml: lists the layouts, so keyboard settings can offer them."""
    (_, default), *variants = layouts
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE xkbConfigRegistry SYSTEM "xkb.dtd">',
        f"<!-- {MARKER}, generated from the .klc files by linux/xkblayouts.py. Don't edit this file. -->",
        '<xkbConfigRegistry version="1.1">',
        "  <layoutList>",
        "    <layout>",
        "      <configItem>",
        f"        <name>{LAYOUT_NAME}</name>",
        "        <shortDescription>uz</shortDescription>",
        f"        <description>{escape(default.name)}</description>",
        "        <countryList>",
        "          <iso3166Id>UZ</iso3166Id>",
        "        </countryList>",
        "        <languageList>",
        "          <iso639Id>uzb</iso639Id>",
        "        </languageList>",
        "      </configItem>",
        "      <variantList>",
    ]
    for variant, layout in variants:
        lines += [
            "        <variant>",
            "          <configItem>",
            f"            <name>{variant}</name>",
            f"            <description>{escape(layout.name)}</description>",
            "          </configItem>",
            "        </variant>",
        ]
    lines += ["      </variantList>", "    </layout>", "  </layoutList>", "</xkbConfigRegistry>"]
    return "\n".join(lines) + "\n"


def write(layouts: Sequence[Tuple[str, KlcLayout]], folder: Path) -> None:
    """Writes symbols/uz2026, types/uz2026, rules/evdev and rules/evdev.xml into `folder`."""
    # Everything is built before anything is written, so a layout that can't be carried over writes nothing.
    files = {
        f"symbols/{LAYOUT_NAME}": symbols_file(layouts),
        f"types/{LAYOUT_NAME}": types_file(key_types([layout for _, layout in layouts])),
        "rules/evdev": rules_file(),
        "rules/evdev.xml": registry_file(layouts),
    }
    for path, text in files.items():
        target = Path(folder) / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
