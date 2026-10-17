import unittest
from pathlib import Path

import klc
from klc import KlcError, KlcKey

# The repo root, where the three .klc files live.
REPO_ROOT = Path(__file__).resolve().parents[2]


def load_klc(file):
    return klc.load(REPO_ROOT / file)


def klc_text(layout_lines):
    """A minimal .klc with the same shift states as the real files and the given LAYOUT lines."""
    return "\r\n".join([
        'KBD\ttest\t"Test Layout"',
        "",
        "SHIFTSTATE",
        "",
        "0\t//Column 4",
        "1\t//Column 5 : Shft",
        "2\t//Column 6 :       Ctrl",
        "6\t//Column 7 :       Ctrl Alt",
        "7\t//Column 8 : Shft  Ctrl Alt",
        "",
        "LAYOUT\t\t;an extra '@' at the end is a dead key",
        "",
        layout_lines,
        "",
        "KEYNAME",
        "",
        "01\tEsc",
    ])


class KlcTests(unittest.TestCase):
    def test_reads_the_layout_name(self):
        self.assertEqual(load_klc("Uzbek-Latin-2026-Classic.klc").name, "Uzbek Latin 2026 (Classic)")
        self.assertEqual(load_klc("Uzbek-Latin-2026-Turkish-style.klc").name, "Uzbek Latin 2026 (Turkish-style)")

    def test_every_main_key_gets_its_own_xkb_key(self):
        # 47 typing keys plus Space; two keys sharing an XKB name would silently lose one.
        for file in ["Uzbek-Latin-2026-Classic.klc", "Uzbek-Latin-2026-Direct.klc", "Uzbek-Latin-2026-Turkish-style.klc"]:
            with self.subTest(file=file):
                self.assertEqual(len(load_klc(file).keys), 48)

    def test_classic_o_key_types_uzbek_letters_with_alt_gr(self):
        o = load_klc("Uzbek-Latin-2026-Classic.klc").keys["AD09"]
        self.assertEqual(o, KlcKey(base="o", shift="O", alt_gr="ö", alt_gr_shift="Ö", caps_lock=True, caps_lock_alt_gr=True))

    def test_direct_left_bracket_key_types_o_with_diaeresis(self):
        bracket = load_klc("Uzbek-Latin-2026-Direct.klc").keys["AD11"]
        self.assertEqual(bracket, KlcKey(base="ö", shift="Ö", alt_gr="[", alt_gr_shift="{", caps_lock=True, caps_lock_alt_gr=False))

    def test_direct_right_bracket_key_types_the_apostrophes_with_alt_gr(self):
        bracket = load_klc("Uzbek-Latin-2026-Direct.klc").keys["AD12"]
        self.assertEqual(bracket.alt_gr, "ʼ")
        self.assertEqual(bracket.alt_gr_shift, "ʻ")

    def test_turkish_style_backslash_key_types_comma(self):
        backslash = load_klc("Uzbek-Latin-2026-Turkish-style.klc").keys["BKSL"]
        self.assertEqual(backslash, KlcKey(base=",", shift=";", alt_gr="\\", alt_gr_shift="|", caps_lock=False, caps_lock_alt_gr=False))

    def test_one_character_values_are_literal_and_longer_ones_are_hex(self):
        layout = load_klc("Uzbek-Latin-2026-Classic.klc")
        self.assertEqual(layout.keys["AE01"].base, "1")
        self.assertEqual(layout.keys["AE01"].shift, "!")
        self.assertEqual(layout.keys["SPCE"].base, " ")

    def test_a_lone_at_sign_is_a_character_not_a_dead_key(self):
        two = klc.parse(klc_text("03\t2\t\t0\t2\t@\t-1\t-1\t-1")).keys["AE02"]
        self.assertEqual(two.shift, "@")

    def test_none_is_none(self):
        a = klc.parse(klc_text("1e\tA\t\t1\ta\tA\t-1\t-1\t-1")).keys["AC01"]
        self.assertEqual(a, KlcKey(base="a", shift="A", alt_gr=None, alt_gr_shift=None, caps_lock=True, caps_lock_alt_gr=False))

    def test_dead_keys_stop_the_build(self):
        with self.assertRaisesRegex(KlcError, "Dead keys"):
            klc.parse(klc_text("1e\tA\t\t1\ta\tA\t-1\t00e1@\t-1"))

    def test_ligatures_stop_the_build(self):
        with self.assertRaisesRegex(KlcError, "Ligatures"):
            klc.parse(klc_text("1e\tA\t\t1\ta\tA\t-1\t%%\t-1"))

    def test_sgcaps_stop_the_build(self):
        with self.assertRaisesRegex(KlcError, "Caps Lock"):
            klc.parse(klc_text("1e\tA\t\tSGCap\ta\tA\t-1\t-1\t-1"))

    def test_keys_outside_the_main_block_stop_the_build(self):
        with self.assertRaisesRegex(KlcError, "no place"):
            klc.parse(klc_text("7e\tABNT_C2\t0\t002e\t002c\t-1\t-1\t-1"))

    def test_changing_a_key_left_to_linux_stops_the_build(self):
        # Linux keeps its own key next to left Shift, so the .klc must still type \ and | there.
        with self.assertRaisesRegex(KlcError, "56"):
            klc.parse(klc_text("56\tOEM_102\t0\t003c\t003e\t-1\t-1\t-1"))

    def test_a_key_left_to_linux_that_matches_is_skipped(self):
        layout = klc.parse(klc_text("56\tOEM_102\t0\t005c\t007c\t001c\t-1\t-1"))
        self.assertEqual(layout.keys, {})

    def test_a_missing_name_stops_the_build(self):
        with self.assertRaisesRegex(KlcError, "KBD"):
            klc.parse(klc_text("1e\tA\t\t1\ta\tA\t-1\t-1\t-1").replace('KBD\ttest\t"Test Layout"', ""))


if __name__ == "__main__":
    unittest.main()
