"""Checks the installed layouts key by key, the way Wayland desktops (GNOME, KDE Plasma and others) read
them: through libxkbcommon, which looks in ~/.config/xkb before the system's XKB files. As in
mac/Sources/UzbekKeyboardMac/Verifier.swift, the expectations come straight from the .klc files and the
system's US layout, not from the generator: with Control a key types what it types on US; otherwise the
.klc decides.
"""
from __future__ import annotations

import ctypes
import itertools
import os
import tempfile
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple

import klc
from klc import KlcKey, KlcLayout
from xkb_files import LAYOUT_NAME

# Where a uz2026 layout is checked: on its own, and as each of the four layouts XKB allows at once.
PLACEMENTS = [
    ([LAYOUT_NAME], "on its own"),
    ([LAYOUT_NAME, "us"], "as layout 1 of 2"),
    (["us", LAYOUT_NAME], "as layout 2 of 2"),
    (["us", "ru", LAYOUT_NAME], "as layout 3 of 3"),
    (["us", "ru", "de", LAYOUT_NAME], "as layout 4 of 4"),
]
# Layouts that must compile exactly as the system has them, with or without the files in ~/.config/xkb.
OTHER_LAYOUTS = ["us", "ru,us", "tr"]
MODIFIER_NAMES = ["Shift", "Caps Lock", "AltGr", "Ctrl"]

XKB_CONTEXT_NO_DEFAULT_INCLUDES = 1
XKB_CONTEXT_NO_ENVIRONMENT_NAMES = 2
XKB_KEYMAP_FORMAT_TEXT_V1 = 1
XKB_KEY_UP, XKB_KEY_DOWN = 0, 1
XKB_STATE_MODS_EFFECTIVE = 8
XKB_CONSUMED_MODE_XKB, XKB_CONSUMED_MODE_GTK = 0, 1


def expected_text(key: KlcKey, shift: bool, caps: bool, alt_gr: bool) -> str:
    """What the .klc says a key types, read the Windows way: Caps Lock works like Shift where the key's
    Cap flag says so, and with Shift it gives lowercase. A key with nothing on AltGr ignores AltGr, as
    Linux keys do. "" is nothing."""
    if alt_gr and (key.alt_gr is not None or key.alt_gr_shift is not None):
        character = key.alt_gr_shift if shift != (caps and key.caps_lock_alt_gr) else key.alt_gr
    else:
        character = key.shift if shift != (caps and key.caps_lock) else key.base
    return character or ""


class VerifyError(Exception):
    pass


class RuleNames(ctypes.Structure):
    _fields_ = [(field, ctypes.c_char_p) for field in ("rules", "model", "layout", "variant", "options")]


@dataclass(frozen=True)
class Press:
    """What a key press gives an app: the keysym, the text, and the active modifiers it consumed."""
    keysym: int
    text: str
    consumed_xkb: int
    consumed_gtk: int


def _bind(library: str, signatures) -> ctypes.CDLL:
    lib = ctypes.CDLL(library)
    for name, (restype, argtypes) in signatures.items():
        function = getattr(lib, name)
        function.restype, function.argtypes = restype, argtypes
    return lib


class Xkb:
    """The libxkbcommon and libxkbregistry calls the check needs."""

    def __init__(self):
        p, u32, i, s, size = ctypes.c_void_p, ctypes.c_uint32, ctypes.c_int, ctypes.c_char_p, ctypes.c_size_t
        try:
            self.lib = _bind("libxkbcommon.so.0", {
                "xkb_context_new": (p, [i]),
                "xkb_context_unref": (None, [p]),
                "xkb_context_include_path_append": (i, [p, s]),
                "xkb_context_num_include_paths": (ctypes.c_uint, [p]),
                "xkb_context_include_path_get": (s, [p, ctypes.c_uint]),
                "xkb_keymap_new_from_names": (p, [p, ctypes.POINTER(RuleNames), i]),
                "xkb_keymap_unref": (None, [p]),
                "xkb_keymap_get_as_string": (p, [p, i]),
                "xkb_keymap_key_by_name": (u32, [p, s]),
                "xkb_keymap_mod_get_index": (u32, [p, s]),
                "xkb_state_new": (p, [p]),
                "xkb_state_unref": (None, [p]),
                "xkb_state_update_key": (i, [p, u32, i]),
                "xkb_state_update_mask": (i, [p, u32, u32, u32, u32, u32, u32]),
                "xkb_state_serialize_mods": (u32, [p, i]),
                "xkb_state_key_get_one_sym": (u32, [p, u32]),
                "xkb_state_key_get_utf8": (i, [p, u32, s, size]),
                "xkb_state_key_get_consumed_mods2": (u32, [p, u32, i]),
                "xkb_keysym_get_name": (i, [u32, s, size]),
                "xkb_utf32_to_keysym": (u32, [u32]),
            })
            self.registry = _bind("libxkbregistry.so.0", {
                "rxkb_context_new": (p, [i]),
                "rxkb_context_parse_default_ruleset": (ctypes.c_bool, [p]),
                "rxkb_context_unref": (p, [p]),
                "rxkb_layout_first": (p, [p]),
                "rxkb_layout_next": (p, [p]),
                "rxkb_layout_get_name": (s, [p]),
                "rxkb_layout_get_variant": (s, [p]),
                "rxkb_layout_get_description": (s, [p]),
            })
        except OSError as error:
            raise VerifyError(f"Can't load libxkbcommon or libxkbregistry ({error}). The check runs on Linux, "
                              "where desktops build keyboards with them.") from None
        self.libc = ctypes.CDLL(None)
        self.libc.free.argtypes = [p]

    def user_context(self) -> int:
        """A context as a desktop has it: ~/.config/xkb first, then the system's XKB files."""
        return self.lib.xkb_context_new(XKB_CONTEXT_NO_ENVIRONMENT_NAMES)

    def system_context(self) -> int:
        """A context with only the system's XKB files."""
        user_folders = {os.path.realpath(folder) for folder in user_xkb_folders()}
        default = self.user_context()
        context = self.lib.xkb_context_new(XKB_CONTEXT_NO_DEFAULT_INCLUDES | XKB_CONTEXT_NO_ENVIRONMENT_NAMES)
        for index in range(self.lib.xkb_context_num_include_paths(default)):
            path = self.lib.xkb_context_include_path_get(default, index)
            if os.path.realpath(path.decode()) not in user_folders:
                self.lib.xkb_context_include_path_append(context, path)
        self.lib.xkb_context_unref(default)
        return context

    def keymap(self, context: int, layouts: str, variants: str = "") -> Optional[int]:
        names = RuleNames(b"evdev", b"pc105", layouts.encode(), variants.encode(), None)
        return self.lib.xkb_keymap_new_from_names(context, ctypes.byref(names), 0) or None

    def keymap_text(self, keymap: int) -> str:
        pointer = self.lib.xkb_keymap_get_as_string(keymap, XKB_KEYMAP_FORMAT_TEXT_V1)
        text = ctypes.string_at(pointer).decode()
        self.libc.free(pointer)
        return text

    def quiet_keymap(self, with_user_files: bool, layouts: str, variants: str = "") -> Tuple[Optional[str], str]:
        """Compiles a keymap in a fresh context with warnings on, and returns its text (None when it doesn't
        compile) and what the compiler said, which libxkbcommon writes to stderr."""
        os.environ["XKB_LOG_LEVEL"], os.environ["XKB_LOG_VERBOSITY"] = "warning", "10"
        with tempfile.TemporaryFile() as log:
            saved_stderr = os.dup(2)
            os.dup2(log.fileno(), 2)
            try:
                context = self.user_context() if with_user_files else self.system_context()
                keymap = self.keymap(context, layouts, variants)
                text = self.keymap_text(keymap) if keymap else None
                if keymap:
                    self.lib.xkb_keymap_unref(keymap)
                self.lib.xkb_context_unref(context)
            finally:
                os.dup2(saved_stderr, 2)
                os.close(saved_stderr)
                del os.environ["XKB_LOG_LEVEL"], os.environ["XKB_LOG_VERBOSITY"]
            log.seek(0)
            return text, log.read().decode(errors="replace")

    def state(self, keymap: int, layout_index: int, shift: bool, caps: bool, alt_gr: bool, control: bool) -> int:
        """A keyboard with these modifier keys pressed, as a person presses them."""
        state = self.lib.xkb_state_new(keymap)
        self.lib.xkb_state_update_mask(state, 0, 0, 0, 0, 0, layout_index)
        if caps:
            caps_lock = self.key(keymap, "CAPS")
            self.lib.xkb_state_update_key(state, caps_lock, XKB_KEY_DOWN)
            self.lib.xkb_state_update_key(state, caps_lock, XKB_KEY_UP)
        for held, name in ((shift, "LFSH"), (alt_gr, "RALT"), (control, "LCTL")):
            if held:
                self.lib.xkb_state_update_key(state, self.key(keymap, name), XKB_KEY_DOWN)
        return state

    def key(self, keymap: int, name: str) -> int:
        return self.lib.xkb_keymap_key_by_name(keymap, name.encode())

    def control_mask(self, keymap: int) -> int:
        return 1 << self.lib.xkb_keymap_mod_get_index(keymap, b"Control")

    def press(self, state: int, keycode: int) -> Press:
        buffer = ctypes.create_string_buffer(64)
        length = self.lib.xkb_state_key_get_utf8(state, keycode, buffer, len(buffer))
        active = self.lib.xkb_state_serialize_mods(state, XKB_STATE_MODS_EFFECTIVE)
        return Press(
            keysym=self.lib.xkb_state_key_get_one_sym(state, keycode),
            text=buffer.raw[:length].decode(errors="replace"),
            consumed_xkb=self.lib.xkb_state_key_get_consumed_mods2(state, keycode, XKB_CONSUMED_MODE_XKB) & active,
            consumed_gtk=self.lib.xkb_state_key_get_consumed_mods2(state, keycode, XKB_CONSUMED_MODE_GTK) & active,
        )

    def keysym_name(self, keysym: int) -> str:
        buffer = ctypes.create_string_buffer(64)
        self.lib.xkb_keysym_get_name(keysym, buffer, len(buffer))
        return buffer.value.decode()

    def registered_layouts(self) -> dict:
        """(layout, variant) to description, for every layout keyboard settings can offer."""
        context = self.registry.rxkb_context_new(0)
        layouts = {}
        if self.registry.rxkb_context_parse_default_ruleset(context):
            layout = self.registry.rxkb_layout_first(context)
            while layout:
                variant = self.registry.rxkb_layout_get_variant(layout)
                description = self.registry.rxkb_layout_get_description(layout)
                key = (self.registry.rxkb_layout_get_name(layout).decode(), variant.decode() if variant else "")
                layouts[key] = description.decode() if description else ""
                layout = self.registry.rxkb_layout_next(layout)
        self.registry.rxkb_context_unref(context)
        return layouts


def user_xkb_folders() -> List[str]:
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return [os.path.join(config, "xkb"), os.path.join(os.path.expanduser("~"), ".xkb")]


def modifier_description(combination: Sequence[bool]) -> str:
    names = [name for name, on in zip(MODIFIER_NAMES, combination) if on]
    return "+".join(names) if names else "no modifiers"


def run(layouts: Sequence[Tuple[str, KlcLayout]]) -> Tuple[bool, List[str]]:
    """Checks every installed layout; `passed` is False when one is missing or types something wrong."""
    xkb = Xkb()
    installed, _ = xkb.quiet_keymap(True, LAYOUT_NAME)
    if installed is None:
        return False, [f"{LAYOUT_NAME}: not found. Install the layouts with install.sh first."]
    user = xkb.user_context()
    system = xkb.system_context()
    us = xkb.keymap(system, "us")
    xkb.lib.xkb_context_unref(system)
    if us is None:
        raise VerifyError("This system's XKB files have no US layout to compare with.")
    passed = True
    report: List[str] = []
    # The first layout is the default section, which desktops ask for without a variant.
    default_variant = layouts[0][0]
    for variant, layout in layouts:
        rmlvo_variant = "" if variant == default_variant else variant
        title = f"{layout.name} [{LAYOUT_NAME}{f'({rmlvo_variant})' if rmlvo_variant else ''}]"
        # What the compiler says about the uz2026 files comes first: it usually explains the wrong keys.
        _, messages = xkb.quiet_keymap(True, LAYOUT_NAME, rmlvo_variant)
        compiler_lines = [line for line in messages.splitlines() if mentions_our_files(line)]
        problems = [f"compiler: {line}" for line in dict.fromkeys(compiler_lines)]
        for placement, where in PLACEMENTS:
            index = placement.index(LAYOUT_NAME)
            variants = ",".join(rmlvo_variant if i == index else "" for i in range(len(placement)))
            keymap = xkb.keymap(user, ",".join(placement), variants)
            if keymap is None:
                problems.append(f"doesn't compile {where}")
                continue
            problems += [f"{where}: {line}" for line in compare(xkb, keymap, index, layout, us)]
            xkb.lib.xkb_keymap_unref(keymap)
        if problems:
            passed = False
            report.append(f"{title}: {len(problems)} problems:")
            report += [f"  {problem}" for problem in problems[:20]]
        else:
            report.append(f"{title}: all {len(klc.XKB_KEY_NAMES)} keys type what they should with every mix of "
                          "Shift, Caps Lock, AltGr and Ctrl, on its own and next to other layouts.")
    registered = xkb.registered_layouts()
    for variant, layout in layouts:
        key = (LAYOUT_NAME, "" if variant == default_variant else variant)
        if registered.get(key) != layout.name:
            passed = False
            report.append(f"Keyboard settings list {key} as {registered.get(key)!r}, expected {layout.name!r}.")
    for other in OTHER_LAYOUTS:
        problem = compare_with_system(xkb, other)
        if problem:
            passed = False
            report.append(problem)
    if passed:
        report.append(f"Keyboard settings list all {len(layouts)} layouts, and {', '.join(OTHER_LAYOUTS)} are unchanged.")
    xkb.lib.xkb_keymap_unref(us)
    xkb.lib.xkb_context_unref(user)
    return passed, report


def compare(xkb: Xkb, keymap: int, index: int, layout: KlcLayout, us: int) -> List[str]:
    """Every key press, under every combination of Shift, Caps Lock, AltGr and Ctrl, that types something
    other than it should."""
    mismatches = []
    control = xkb.control_mask(keymap)
    for combination in itertools.product([False, True], repeat=4):
        shift, caps, alt_gr, ctrl = combination
        state = xkb.state(keymap, index, *combination)
        us_state = xkb.state(us, 0, *combination)
        for name in klc.XKB_KEY_NAMES.values():
            actual = xkb.press(state, xkb.key(keymap, name))
            problem = None
            if ctrl and not alt_gr:
                expected = xkb.press(us_state, xkb.key(us, name))
                if actual != expected:
                    problem = f"expected {describe(xkb, expected)} as on US, got {describe(xkb, actual)}"
            else:
                text = expected_text(layout.keys[name], shift, caps, alt_gr)
                keysym = xkb.lib.xkb_utf32_to_keysym(ord(text)) if text else 0
                if actual.keysym != keysym or (not ctrl and actual.text != text):
                    problem = f"expected {xkb.keysym_name(keysym)} {text!r}, got {describe(xkb, actual)}"
                elif ctrl and (actual.consumed_xkb | actual.consumed_gtk) & control:
                    problem = "Ctrl is consumed, so shortcuts don't see it"
            if problem:
                mismatches.append(f"<{name}> with {modifier_description(combination)}: {problem}")
        xkb.lib.xkb_state_unref(state)
        xkb.lib.xkb_state_unref(us_state)
    return mismatches


def describe(xkb: Xkb, press: Press) -> str:
    return f"{xkb.keysym_name(press.keysym)} {press.text!r} (consumes {press.consumed_xkb:#x}/{press.consumed_gtk:#x})"


def mentions_our_files(line: str) -> bool:
    return LAYOUT_NAME in line.lower() or any(folder in line for folder in user_xkb_folders())


def compare_with_system(xkb: Xkb, layouts: str) -> Optional[str]:
    """None when `layouts` compile to the same keymap with and without the files in ~/.config/xkb."""
    with_user_files, _ = xkb.quiet_keymap(True, layouts)
    system_only, _ = xkb.quiet_keymap(False, layouts)
    if with_user_files != system_only:
        return f"{layouts} compiles differently with the files in {user_xkb_folders()[0]}."
    return None


def run_removed() -> Tuple[bool, List[str]]:
    """Checks that no uz2026 layout is left and that other layouts are as the system has them."""
    xkb = Xkb()
    report: List[str] = []
    text, _ = xkb.quiet_keymap(True, LAYOUT_NAME)
    if text is not None:
        report.append(f"{LAYOUT_NAME} still compiles.")
    if any(name == LAYOUT_NAME for name, _ in xkb.registered_layouts()):
        report.append(f"Keyboard settings still list {LAYOUT_NAME}.")
    for other in OTHER_LAYOUTS:
        problem = compare_with_system(xkb, other)
        if problem:
            report.append(problem)
    if not report:
        report.append(f"No {LAYOUT_NAME} layout is left, and {', '.join(OTHER_LAYOUTS)} are as the system has them.")
        return True, report
    return False, report
