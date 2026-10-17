"""Reads a Windows layout in MSKLC's source format, reduced to what the Linux layouts need.

Parsing follows KlcLayout in mac/Sources/UzbekKeyboardMac/Klc.swift: anything the Linux layouts
can't carry over (dead keys, ligatures, SGCaps, other keys) stops the build instead of being skipped.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


@dataclass(frozen=True)
class KlcKey:
    """What one key types in a .klc layout; None where it types nothing."""
    base: Optional[str]
    shift: Optional[str]
    alt_gr: Optional[str]
    alt_gr_shift: Optional[str]
    # Caps Lock works like Shift for the key alone (Cap flag 1).
    caps_lock: bool
    # Caps Lock works like Shift with AltGr too (Cap flag 4).
    caps_lock_alt_gr: bool


class KlcError(Exception):
    pass


# Windows scan codes, as the .klc files write them, to XKB key names for the 47 main typing keys and Space.
XKB_KEY_NAMES: Dict[str, str] = {
    "29": "TLDE", "02": "AE01", "03": "AE02", "04": "AE03", "05": "AE04", "06": "AE05", "07": "AE06",
    "08": "AE07", "09": "AE08", "0a": "AE09", "0b": "AE10", "0c": "AE11", "0d": "AE12",
    "10": "AD01", "11": "AD02", "12": "AD03", "13": "AD04", "14": "AD05", "15": "AD06", "16": "AD07",
    "17": "AD08", "18": "AD09", "19": "AD10", "1a": "AD11", "1b": "AD12", "2b": "BKSL",
    "1e": "AC01", "1f": "AC02", "20": "AC03", "21": "AC04", "22": "AC05", "23": "AC06", "24": "AC07",
    "25": "AC08", "26": "AC09", "27": "AC10", "28": "AC11",
    "2c": "AB01", "2d": "AB02", "2e": "AB03", "2f": "AB04", "30": "AB05", "31": "AB06", "32": "AB07",
    "33": "AB08", "34": "AB09", "35": "AB10",
    "39": "SPCE",
}

# Keys the Linux layouts leave to the system, with what they must type in the .klc for that to be right.
KEYS_LEFT_TO_LINUX: Dict[str, KlcKey] = {
    # The extra key next to left Shift on ISO keyboards.
    "56": KlcKey(base="\\", shift="|", alt_gr=None, alt_gr_shift=None, caps_lock=False, caps_lock_alt_gr=False),
    # Keypad decimal point.
    "53": KlcKey(base=".", shift=".", alt_gr=None, alt_gr_shift=None, caps_lock=False, caps_lock_alt_gr=False),
}


@dataclass(frozen=True)
class KlcLayout:
    # The KBD description, which Windows shows as the layout's name.
    name: str
    # XKB key name to what the key types.
    keys: Dict[str, KlcKey]


def load(path: Path) -> KlcLayout:
    # MSKLC writes UTF-16 with a byte order mark.
    return parse(Path(path).read_text(encoding="utf-16"))


def parse(text: str) -> KlcLayout:
    name: Optional[str] = None
    keys: Dict[str, KlcKey] = {}
    shift_states: List[int] = []
    section: Optional[str] = None
    for raw_line in text.splitlines():
        line = raw_line.split("//")[0].strip()
        if not line or line.startswith(";"):
            continue
        parts = line.split()
        if _is_keyword(parts[0]):
            section = parts[0]
            if section == "KBD":
                open_quote, close_quote = line.find('"'), line.rfind('"')
                if open_quote < close_quote:
                    name = line[open_quote + 1:close_quote]
            continue
        if section == "SHIFTSTATE":
            try:
                shift_states.append(int(parts[0]))
            except ValueError:
                raise KlcError(f"Unreadable shift state: {line}") from None
        elif section == "LAYOUT":
            scan_code, key = _parse_key(parts, shift_states, line)
            if scan_code in XKB_KEY_NAMES:
                keys[XKB_KEY_NAMES[scan_code]] = key
            elif scan_code in KEYS_LEFT_TO_LINUX:
                if key != KEYS_LEFT_TO_LINUX[scan_code]:
                    raise KlcError(f"Key {scan_code} changed, but the Linux layouts keep the system's key there: {line}")
            else:
                raise KlcError(f"Key {scan_code} has no place in the Linux layouts: {line}")
    if name is None:
        raise KlcError("No KBD line with the layout's name.")
    return KlcLayout(name=name, keys=keys)


def _is_keyword(token: str) -> bool:
    return all("A" <= c <= "Z" or c == "_" for c in token)


def _parse_key(parts: List[str], shift_states: List[int], line: str) -> Tuple[str, KlcKey]:
    if len(parts) < 3 + len(shift_states):
        raise KlcError(f"Too few columns: {line}")
    try:
        cap = int(parts[2])
    except ValueError:
        cap = -1
    if cap not in (0, 1, 4, 5):
        raise KlcError(f"Unsupported Caps Lock column {parts[2]}: {line}")
    columns: Dict[int, Optional[str]] = {}
    for i, state in enumerate(shift_states):
        columns[state] = _decode(parts[3 + i], line)
    # Ctrl columns (state 2) are skipped: the Linux layouts keep the US Control keys.
    key = KlcKey(
        base=columns.get(0), shift=columns.get(1), alt_gr=columns.get(6), alt_gr_shift=columns.get(7),
        caps_lock=cap & 1 != 0, caps_lock_alt_gr=cap & 4 != 0,
    )
    return parts[0].lower(), key


def _decode(value: str, line: str) -> Optional[str]:
    if value == "-1":
        return None
    # One character is the character itself, so a lone "@" is an at sign, not a dead-key mark.
    if len(value) == 1:
        return value
    if value == "%%":
        raise KlcError(f"Ligatures aren't supported on Linux yet: {line}")
    if value.endswith("@"):
        raise KlcError(f"Dead keys aren't supported on Linux yet: {line}")
    try:
        return chr(int(value, 16))
    except ValueError:
        raise KlcError(f"Unreadable character {value}: {line}") from None
