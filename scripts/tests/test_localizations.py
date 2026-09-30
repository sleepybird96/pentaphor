import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_localizations import validate

class LocalizationValidationTests(unittest.TestCase):
    def test_missing_translation_is_rejected(self):
        self.assertTrue(validate({'title':'Hello'}, {}))
    def test_placeholders_must_match(self):
        self.assertTrue(validate({'x':'%1$@ %2$@'}, {'x':'%1$@'}))
        self.assertEqual(validate({'x':'%1$@ %2$@'}, {'x':'%2$@ %1$@'}), [])
    def test_plural_variants_are_checked(self):
        a = {'count': {'NSStringLocalizedFormatKey':'%#@count@', 'count': {'NSStringFormatSpecTypeKey':'NSStringPluralRuleType', 'NSStringFormatValueTypeKey':'ld', 'one':'%ld time', 'other':'%ld times'}}}
        self.assertEqual(validate(a, a), [])
