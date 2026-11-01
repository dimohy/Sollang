"""Registration comparison must preserve layout meaning across arena renumbering."""
import copy
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'registered_universe', Path(__file__).with_name('verify-codegen-type-universe.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
compare = module.compare_registered_universe


class RegisteredUniverseTests(unittest.TestCase):
    def setUp(self):
        self.observation = dict(typeNames={'2': 'Int'}, records={
            'Structs': [dict(Id=1024, Name='p.Node', ModuleName='p',
                             Fields=[dict(Index=0, Name='next', Type=1030)])],
            'Enums': [dict(Id=1025, Name='p.Choice', ModuleName='p', PayloadWords=1,
                           Variants=[dict(Tag=0, Name='None', PayloadType=None),
                                     dict(Tag=1, Name='Some', PayloadType=1024)])],
            'Boxes': [dict(Id=1026, ElementType=1024, Size=16, Alignment=8)],
            'References': [dict(Id=1030, ElementType=1024)],
            'DynTraits': [dict(Id=1031, TraitName='p.Value')],
            'StaticArrays': [dict(Id=1032, ElementType=1024, ElementSize=8,
                                  ElementAlignment=8, FixedLength=3)],
            'DynamicArrays': [dict(Id=1033, ElementType=1024, ElementSize=8, ElementAlignment=8)],
            'Dictionaries': [dict(Id=1034, KeyType=2, ValueType=1024, KeySize=4,
                                  KeyAlignment=4, ValueOffset=8, ValueSize=8,
                                  ValueAlignment=8, EntryStride=16)]})
        self.text = '''universe-hash:123
universe:8
record:struct:100:p.Node:p
record:field:0:next:103
record:enum:101:p.Choice:p:1
record:variant:0:None:-1
record:variant:1:Some:100
record:box:102:901:16:8
record:reference:103:100
record:dyn:104:p.Value
record:static-array:105:100:8:8:3
record:dynamic-array:106:100:8:8
record:dictionary:107:17:100:4:4:8:8:8:16
alias:901:100
name:17:Int
name:100:a display alias is not declaration identity
name-error:999
'''

    def test_all_categories_survive_renumbering_aliases_and_recursive_nominals(self):
        result = compare(self.observation, self.text)
        self.assertTrue(result['equal'])
        self.assertEqual((result['managedTotal'], result['nativeTotal']), (8, 8))

    def test_layout_and_member_changes_in_every_category_are_detected(self):
        mutations = [('next:103', 'next:100'), ('Some:100', 'Some:17'),
                     ('102:901:16:8', '102:901:24:8'), ('103:100', '103:17'),
                     ('104:p.Value', '104:p.Other'), ('105:100:8:8:3', '105:100:8:8:4'),
                     ('106:100:8:8', '106:100:8:4'),
                     ('107:17:100:4:4:8:8:8:16', '107:17:100:4:4:8:8:8:24'),
                     ('p.Node:p', 'p.Node:q'), ('Choice:p:1', 'Choice:p:2')]
        for before, after in mutations:
            with self.subTest(before=before):
                self.assertFalse(compare(self.observation, self.text.replace(before, after))['equal'])

    def test_unknown_selected_type_is_not_replaced_by_a_display_default(self):
        with self.assertRaisesRegex(AssertionError, 'UNRESOLVED_REGISTERED_TYPE'):
            compare(self.observation, self.text.replace('next:103', 'next:999'))

    def test_malformed_and_duplicate_records_are_rejected(self):
        for suffix in ('record:reference:103:100\n', 'capture-error:100\n', 'alias:901:100\n'):
            with self.subTest(suffix=suffix), self.assertRaises(AssertionError):
                compare(self.observation, self.text + suffix)
        with self.assertRaisesRegex(AssertionError, 'NATIVE_UNIVERSE_COUNT_MISMATCH'):
            compare(self.observation, self.text.replace('universe:8', 'universe:7'))

    def test_duplicate_layout_meanings_are_counted_instead_of_deduplicated(self):
        observation = copy.deepcopy(self.observation)
        observation['records']['Boxes'].append(dict(Id=2048, ElementType=1024, Size=16, Alignment=8))
        self.assertFalse(compare(observation, self.text)['equal'])


if __name__ == '__main__':
    unittest.main()
