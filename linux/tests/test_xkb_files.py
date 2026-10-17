import unittest
import xml.etree.ElementTree as ElementTree

import xkb_files
from klc import KlcKey, KlcLayout
from tests.test_klc import load_klc
from xkb_files import XkbError

SHIFT, LOCK, LEVEL3, CONTROL = "Shift", "Lock", "LevelThree", "Control"


def level_for(key_type, *pressed):
    """The level XKB picks for a key of this type with these modifiers on, and the ones it leaves unconsumed."""
    active = frozenset(pressed) & frozenset(key_type.modifiers)
    for modifiers, level, preserved in key_type.entries:
        if modifiers == active:
            return level, preserved
    return 1, frozenset()


def classic():
    return load_klc("Uzbek-Latin-2026-Classic.klc")


def direct():
    return load_klc("Uzbek-Latin-2026-Direct.klc")


def turkish_style():
    return load_klc("Uzbek-Latin-2026-Turkish-style.klc")


def type_of(layout, key):
    name = xkb_files.key_definitions(layout)[key].type
    return next(t for t in xkb_files.key_types([layout]) if t.name == name)


class KeyDefinitionTests(unittest.TestCase):
    def test_keys_that_type_what_us_types_are_left_to_us(self):
        self.assertEqual(set(xkb_files.key_definitions(classic())), {"AD09", "AC02", "AC05", "AB03", "AC11"})

    def test_classic_letters_get_their_uzbek_letter_with_alt_gr(self):
        o = xkb_files.key_definitions(classic())["AD09"]
        self.assertEqual((o.type, o.keysyms), ("FOUR_LEVEL_ALPHABETIC", ["o", "O", "odiaeresis", "Odiaeresis"]))

    def test_classic_quote_key_types_the_apostrophes_with_alt_gr(self):
        quote = xkb_files.key_definitions(classic())["AC11"]
        self.assertEqual((quote.type, quote.keysyms), ("FOUR_LEVEL", ["apostrophe", "quotedbl", "U02BC", "U02BB"]))

    def test_direct_changes_five_keys(self):
        self.assertEqual(set(xkb_files.key_definitions(direct())), {"AD11", "AD12", "AC10", "AC11", "AB03"})

    def test_a_key_that_moves_a_us_character_keeps_it_for_control(self):
        keys = xkb_files.key_definitions(direct())
        self.assertEqual(keys["AB03"].keysyms, ["ccedilla", "Ccedilla", "c", "C", "c", "C"])
        self.assertEqual(keys["AC10"].keysyms, ["scedilla", "Scedilla", "semicolon", "colon", "semicolon", "colon"])

    def test_turkish_style_backslash_key_keeps_backslash_for_control(self):
        backslash = xkb_files.key_definitions(turkish_style())["BKSL"]
        self.assertEqual(backslash.keysyms, ["comma", "semicolon", "backslash", "bar", "backslash", "bar"])

    def test_every_type_a_key_uses_is_standard_or_written(self):
        layouts = [classic(), direct(), turkish_style()]
        used = {d.type for layout in layouts for d in xkb_files.key_definitions(layout).values()}
        written = [t.name for t in xkb_files.key_types(layouts)]
        self.assertEqual(len(written), len(set(written)))
        self.assertEqual(used - set(written), used & {"FOUR_LEVEL", "FOUR_LEVEL_SEMIALPHABETIC", "FOUR_LEVEL_ALPHABETIC"})

    def test_caps_lock_only_with_alt_gr_stops_the_build(self):
        layout = KlcLayout(name="Test", keys={"AD09": KlcKey("o", "O", "ö", "Ö", caps_lock=False, caps_lock_alt_gr=True)})
        with self.assertRaisesRegex(XkbError, "AD09"):
            xkb_files.key_definitions(layout)

    def test_moving_a_character_with_nothing_on_alt_gr_stops_the_build(self):
        layout = KlcLayout(name="Test", keys={"AD11": KlcKey("ö", "Ö", None, None, caps_lock=True, caps_lock_alt_gr=False)})
        with self.assertRaisesRegex(XkbError, "AD11"):
            xkb_files.key_definitions(layout)


class KeyTypeTests(unittest.TestCase):
    def test_direct_c_key_follows_the_klc_without_control(self):
        c = type_of(direct(), "AB03")
        self.assertEqual(level_for(c), (1, frozenset()))
        self.assertEqual(level_for(c, LOCK), (2, frozenset()))
        self.assertEqual(level_for(c, LOCK, SHIFT), (1, frozenset()))
        self.assertEqual(level_for(c, LEVEL3), (3, frozenset()))
        # Cap flag 5: Caps Lock works with AltGr too.
        self.assertEqual(level_for(c, LEVEL3, LOCK), (4, frozenset()))

    def test_direct_c_key_types_us_c_with_control_and_keeps_control(self):
        c = type_of(direct(), "AB03")
        self.assertEqual(level_for(c, CONTROL), (5, {CONTROL}))
        self.assertEqual(level_for(c, CONTROL, SHIFT), (6, {CONTROL}))
        # As on the US C key, Caps Lock makes it a capital C.
        self.assertEqual(level_for(c, CONTROL, LOCK), (6, {CONTROL}))
        self.assertEqual(level_for(c, CONTROL, LEVEL3), (3, {CONTROL}))

    def test_direct_bracket_key_ignores_caps_lock_with_alt_gr(self):
        bracket = type_of(direct(), "AD11")
        self.assertEqual(level_for(bracket, LOCK), (2, frozenset()))
        self.assertEqual(level_for(bracket, LEVEL3, LOCK), (3, frozenset()))

    def test_direct_bracket_key_leaves_caps_lock_alone_with_control(self):
        # On US, Caps Lock does nothing to [ and stays unconsumed; with Control the key acts the same.
        bracket = type_of(direct(), "AD11")
        self.assertEqual(level_for(bracket, CONTROL, LOCK), (5, {CONTROL, LOCK}))
        self.assertEqual(level_for(bracket, CONTROL, SHIFT), (6, {CONTROL}))

    def test_turkish_style_backslash_key_has_no_caps_lock(self):
        backslash = type_of(turkish_style(), "BKSL")
        self.assertNotIn(LOCK, backslash.modifiers)
        self.assertEqual(level_for(backslash, LEVEL3, SHIFT), (4, frozenset()))
        self.assertEqual(level_for(backslash, CONTROL, SHIFT), (6, {CONTROL}))


class KeysymNameTests(unittest.TestCase):
    def test_names(self):
        self.assertEqual(xkb_files.keysym_name("a"), "a")
        self.assertEqual(xkb_files.keysym_name("7"), "7")
        self.assertEqual(xkb_files.keysym_name(","), "comma")
        self.assertEqual(xkb_files.keysym_name("ş"), "scedilla")
        self.assertEqual(xkb_files.keysym_name("ğ"), "gbreve")
        self.assertEqual(xkb_files.keysym_name(None), "NoSymbol")

    def test_characters_without_a_name_are_unicode_keysyms(self):
        # Not "gbreve": that keysym's value is 0x2bb, but it types ğ, not ʻ.
        self.assertEqual(xkb_files.keysym_name("ʻ"), "U02BB")


class RegistryTests(unittest.TestCase):
    def test_lists_the_first_layout_as_the_layout_and_the_others_as_variants(self):
        layouts = [("classic", classic()), ("direct", direct()), ("turkish-style", turkish_style())]
        registry = ElementTree.fromstring(xkb_files.registry_file(layouts).encode())
        layout = registry.find("layoutList/layout")
        self.assertEqual(layout.findtext("configItem/name"), "uz2026")
        self.assertEqual(layout.findtext("configItem/description"), "Uzbek Latin 2026 (Classic)")
        variants = [(v.findtext("configItem/name"), v.findtext("configItem/description"))
                    for v in layout.findall("variantList/variant")]
        self.assertEqual(variants, [("direct", "Uzbek Latin 2026 (Direct)"), ("turkish-style", "Uzbek Latin 2026 (Turkish-style)")])


if __name__ == "__main__":
    unittest.main()
