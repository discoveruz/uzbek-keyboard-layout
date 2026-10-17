import unittest

from klc import KlcKey
from verifier import expected_text

# Direct's [ key: ö, with [ and { moved to AltGr; Caps Lock works on the key alone (Cap flag 1).
O_BRACKET = KlcKey("ö", "Ö", "[", "{", caps_lock=True, caps_lock_alt_gr=False)
# Classic's O key: ö on AltGr, and Caps Lock works with AltGr too (Cap flag 5).
O_KEY = KlcKey("o", "O", "ö", "Ö", caps_lock=True, caps_lock_alt_gr=True)
# Turkish-style's \ key: comma, and no Caps Lock (Cap flag 0).
COMMA_BACKSLASH = KlcKey(",", ";", "\\", "|", caps_lock=False, caps_lock_alt_gr=False)


class ExpectedTextTests(unittest.TestCase):
    def test_caps_lock_works_like_shift_and_caps_lock_with_shift_gives_lowercase(self):
        self.assertEqual(expected_text(O_BRACKET, shift=False, caps=True, alt_gr=False), "Ö")
        self.assertEqual(expected_text(O_BRACKET, shift=True, caps=True, alt_gr=False), "ö")

    def test_caps_lock_leaves_alt_gr_alone_without_cap_flag_4(self):
        self.assertEqual(expected_text(O_BRACKET, shift=False, caps=True, alt_gr=True), "[")
        self.assertEqual(expected_text(O_BRACKET, shift=True, caps=False, alt_gr=True), "{")

    def test_caps_lock_works_with_alt_gr_with_cap_flag_4(self):
        self.assertEqual(expected_text(O_KEY, shift=False, caps=True, alt_gr=True), "Ö")
        self.assertEqual(expected_text(O_KEY, shift=True, caps=True, alt_gr=True), "ö")

    def test_caps_lock_does_nothing_without_cap_flag_1(self):
        self.assertEqual(expected_text(COMMA_BACKSLASH, shift=False, caps=True, alt_gr=False), ",")
        self.assertEqual(expected_text(COMMA_BACKSLASH, shift=True, caps=True, alt_gr=False), ";")

    def test_a_key_with_nothing_on_alt_gr_ignores_alt_gr(self):
        q = KlcKey("q", "Q", None, None, caps_lock=True, caps_lock_alt_gr=False)
        self.assertEqual(expected_text(q, shift=True, caps=False, alt_gr=True), "Q")
        self.assertEqual(expected_text(q, shift=False, caps=True, alt_gr=True), "Q")

    def test_a_missing_alt_gr_character_types_nothing(self):
        x = KlcKey("x", "X", "y", None, caps_lock=True, caps_lock_alt_gr=False)
        self.assertEqual(expected_text(x, shift=True, caps=False, alt_gr=True), "")


if __name__ == "__main__":
    unittest.main()
