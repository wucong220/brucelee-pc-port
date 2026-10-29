from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
import unittest
import warnings
import zlib
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError, parse_context
from kdf_fighting_set import inspect_archive, inspect_bytes
from test_pak_extract import archive_fixture


def fixture(*, missing_binary=False, missing_attack=False, duplicate_name=False):
    strings = ['animations', 'name', 'binary', 'attack', 'impacts', 'damage_time',
               'damage_amount', 'attack_radius', 'body_part', 'height', 'strength',
               'direction', 'lowpunch1', 'lowkick1', 'larm', 'lleg', 'medium', 'low',
               'normal', 'frontal', 'anim/', 'punch', 'kick', 'anm']
    nodes = [(0, 0)]

    def reserve(n):
        start = len(nodes)
        nodes.extend([(0, 0)] * n)
        return start

    def dictionary(index, keys):
        start = reserve(len(keys) * 2)
        nodes[index] = (0x30000000 | len(keys), start - index)
        result = {}
        for n, key in enumerate(keys):
            nodes[start + n * 2] = (0x60000000, strings.index(key))
            result[key] = start + n * 2 + 1
        return result

    def array(index, count):
        start = reserve(count)
        nodes[index] = (0x40000000 | count, start - index if count else 0)
        return list(range(start, start + count))

    root = dictionary(0, ['animations'])
    slots = array(root['animations'], 2)
    loc = {}
    for no, name in enumerate(('lowpunch1', 'lowkick1')):
        keys = ['name']
        if not (missing_binary and no == 1):
            keys.append('binary')
        if not (missing_attack and no == 1):
            keys.append('attack')
        anim = dictionary(slots[no], keys)
        nodes[anim['name']] = (0x60000000, strings.index('lowpunch1' if duplicate_name else name))
        if 'binary' in anim:
            nodes[anim['binary']] = (0x70000000, no)
        loc[name] = {'animation': slots[no], 'name': anim['name'], 'binary': anim.get('binary'),
                     'attack': anim.get('attack')}
        if 'attack' not in anim:
            continue
        attack = dictionary(anim['attack'], ['impacts'])
        impact_slots = array(attack['impacts'], 2 if no == 0 else 1)
        loc[name]['impacts'] = attack['impacts']
        for n, slot in enumerate(impact_slots):
            impact = dictionary(slot, ['damage_time', 'damage_amount', 'attack_radius',
                                       'body_part', 'height', 'strength', 'direction'])
            times = array(impact['damage_time'], 2)
            nodes[times[0]] = (0, 5 + n + no * 2)
            nodes[times[1]] = (0, 8 + n + no * 2)
            nodes[impact['damage_amount']] = (0, 5 + n)
            nodes[impact['attack_radius']] = (0x20000000, 0x428c0000)
            nodes[impact['body_part']] = (0x60000000, strings.index('larm' if no == 0 else 'lleg'))
            nodes[impact['height']] = (0x60000000, strings.index('medium' if no == 0 else 'low'))
            nodes[impact['strength']] = (0x60000000, strings.index('normal'))
            nodes[impact['direction']] = (0x60000000, strings.index('frontal'))
            if n == 0:
                loc[name].update({'impact': slot, 'time': impact['damage_time'],
                                  'amount': impact['damage_amount']})

    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 2, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        raw.extend(struct.pack('<II', (zlib.crc32(encoded) + len(encoded)) & 0xffffffff, len(encoded)))
        raw.extend(encoded + b'\0')
    raw.extend(b'\0' * ((len(raw) - 0x1c) & 3))
    raw.extend(bytes([strings.index('anim/'), strings.index('punch'), strings.index('anm'),
                      strings.index('anim/'), strings.index('kick'), strings.index('anm')]))
    raw.extend(b'DATA' + struct.pack('<IIIII', len(nodes), 0, 0, 0, 0))
    for first, second in nodes:
        raw.extend(struct.pack('<II', first, second))
    raw.extend(b'0123456789abcdef')
    return bytes(raw), loc


class TestFightingSet(unittest.TestCase):
    def test_list_actions_allows_missing_binary_and_marks_duplicate_names(self):
        raw, _ = fixture(missing_binary=True, missing_attack=True, duplicate_name=True)
        result = inspect_bytes(raw, list_actions=True)
        self.assertEqual(result['action_count'], 2)
        self.assertEqual(result['duplicate_names'], ['lowpunch1'])
        summary = inspect_bytes(raw, list_actions=True, summary=True)
        self.assertEqual(summary['actions'], ['lowpunch1', 'lowpunch1'])
        self.assertEqual(summary['attack_action_count'], 1)
        self.assertEqual(summary['impact_record_count'], 2)
        self.assertEqual(summary['impact_count_distribution'], {0: 1, 2: 1})
        with self.assertRaisesRegex(KdfError, 'summary requires'):
            inspect_bytes(raw, ['lowpunch1'], summary=True)
        self.assertEqual([x['name'] for x in result['actions']], ['lowpunch1', 'lowpunch1'])
        self.assertEqual([x['name_occurrences'] for x in result['actions']], [2, 2])
        self.assertEqual(result['actions'][0]['animation_file']['basename'], 'punch')
        self.assertIsNone(result['actions'][1]['animation_file'])
        with self.assertRaisesRegex(KdfError, 'duplicate requested action'):
            inspect_bytes(raw, ['lowpunch1'])
        with self.assertRaisesRegex(KdfError, 'mutually exclusive'):
            inspect_bytes(raw, ['lowpunch1'], list_actions=True)

    def test_list_rejects_invalid_present_binary(self):
        raw, loc = fixture()
        bad = bytearray(raw)
        offset = parse_context(raw)['data_offset'] + 24 + loc['lowpunch1']['binary'] * 8
        struct.pack_into('<II', bad, offset, 0x70000000, 999)
        with self.assertRaisesRegex(KdfError, 'invalid file reference'):
            inspect_bytes(bytes(bad), list_actions=True)

    def test_two_actions_and_multiple_impacts(self):
        raw, _ = fixture()
        result = inspect_bytes(raw, ['lowkick1', 'lowpunch1'])
        kick, punch = result['actions']
        self.assertEqual(kick['animation_file']['basename'], 'kick')
        self.assertEqual(kick['impacts'][0]['damage_time_raw'], [7, 10])
        self.assertEqual(kick['impacts'][0]['damage_amount_raw'], 5)
        self.assertEqual(kick['impacts'][0]['decoded_fields']['attack_radius'],
                         {'type': 'float', 'value': 70.0})
        self.assertEqual(kick['impacts'][0]['decoded_fields']['body_part'],
                         {'type': 'string', 'value': 'lleg'})
        self.assertEqual(kick['impacts'][0]['decoded_fields']['height'],
                         {'type': 'string', 'value': 'low'})
        self.assertEqual(kick['impacts'][0]['decoded_fields']['strength'],
                         {'type': 'string', 'value': 'normal'})
        self.assertEqual(kick['impacts'][0]['decoded_fields']['direction'],
                         {'type': 'string', 'value': 'frontal'})
        self.assertEqual([i['damage_time_raw'] for i in punch['impacts']], [[5, 8], [6, 9]])
        self.assertEqual(punch['impacts'][1]['damage_amount_raw'], 6)
        self.assertEqual(punch['impacts'][0]['decoded_fields']['body_part'],
                         {'type': 'string', 'value': 'larm'})
        self.assertEqual(punch['impacts'][0]['raw_fields']['damage_amount']['first'], 0)

    def test_invalid_types_offsets_and_references_fail_closed(self):
        raw, loc = fixture()
        base = parse_context(raw)['data_offset'] + 24
        cases = [
            (loc['lowpunch1']['animation'], 0x40000003, None),
            (loc['lowpunch1']['animation'], None, 0),
            (loc['lowpunch1']['attack'], None, 0xffffffff),
            (loc['lowpunch1']['name'], 0x70000000, None),
            (loc['lowpunch1']['binary'], None, 999),
            (loc['lowpunch1']['time'], 0x40000001, None),
            (loc['lowpunch1']['amount'], 0x20000000, None),
        ]
        for index, first, second in cases:
            bad = bytearray(raw)
            offset = base + index * 8
            old_first, old_second = struct.unpack_from('<II', bad, offset)
            struct.pack_into('<II', bad, offset, old_first if first is None else first,
                             old_second if second is None else second)
            with self.subTest(index=index, first=first, second=second), self.assertRaises(KdfError):
                inspect_bytes(bytes(bad), ['lowpunch1'])
        with self.assertRaises(KdfError):
            inspect_bytes(raw, ['missing'])
        with self.assertRaises(KdfError):
            inspect_bytes(raw, ['lowpunch1', 'lowpunch1'])
        with self.assertRaises(KdfError):
            inspect_bytes(raw[:-1], ['lowpunch1'])

    def test_cli_reads_file_without_modifying_it(self):
        raw, _ = fixture()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'fixture.set'
            path.write_bytes(raw)
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_fighting_set.py'
            run = subprocess.run([sys.executable, str(script), str(path), '--action', 'lowpunch1'],
                                 capture_output=True, text=True, encoding='utf-8')
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn('lowpunch1', run.stdout)
            self.assertEqual(path.read_bytes(), raw)
            listed = subprocess.run([sys.executable, str(script), str(path), '--list-actions'],
                                    capture_output=True, text=True, encoding='utf-8')
            self.assertEqual(listed.returncode, 0, listed.stderr)
            self.assertEqual(len(json.loads(listed.stdout)['actions']), 2)
            summary = subprocess.run([sys.executable, str(script), str(path), '--list-actions',
                                      '--summary'], capture_output=True, text=True, encoding='utf-8')
            self.assertEqual(summary.returncode, 0, summary.stderr)
            self.assertEqual(json.loads(summary.stdout)['actions'], ['lowpunch1', 'lowkick1'])
            both = subprocess.run([sys.executable, str(script), str(path), '--list-actions',
                                   '--action', 'lowpunch1'], capture_output=True, text=True)
            self.assertNotEqual(both.returncode, 0)

    def test_archive_and_nested_zip_are_read_only_and_require_exact_path(self):
        raw, _ = fixture()
        raw = raw[:-16] + struct.pack('<I', 100) + b'example-value!!!'[:12]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            zpak = root / 'data.zpak'
            archive_fixture(zpak, [raw], references=[(0, 'adreno_200/set/brucelee.set')])
            before = hashlib.sha256(zpak.read_bytes()).hexdigest()
            report = inspect_archive(zpak, ['lowpunch1'])
            self.assertEqual(report['actions'][0]['impacts'][0]['damage_time_raw'], [5, 8])
            self.assertEqual(report['archive']['resource_path'], 'adreno_200/set/brucelee.set')
            self.assertEqual(hashlib.sha256(zpak.read_bytes()).hexdigest(), before)
            self.assertEqual(len(inspect_archive(zpak, list_actions=True)['actions']), 2)
            outer = root / 'outer.zip'
            with zipfile.ZipFile(outer, 'w') as archive:
                archive.writestr('payload/data.zpak', zpak.read_bytes())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_fighting_set.py'
            run = subprocess.run([sys.executable, str(script), '--archive', str(outer),
                                  '--action', 'lowkick1'], capture_output=True,
                                 text=True, encoding='utf-8')
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(json.loads(run.stdout)['actions'][0]['impacts'][0]['damage_time_raw'], [7, 10])
            other = root / 'other.zpak'
            archive_fixture(other, [raw], references=[(0, 'adreno_200/set/other.set')])
            with self.assertRaisesRegex(ValueError, 'exactly one brucelee.set'):
                inspect_archive(other, ['lowpunch1'])
            bad = root / 'wrong-identity.zpak'
            mismatched = raw[:-16] + b'not-the-right-id'
            archive_fixture(bad, [mismatched], references=[(0, 'adreno_200/set/brucelee.set')])
            with self.assertRaisesRegex(ValueError, 'tail identity'):
                inspect_archive(bad, ['lowpunch1'])
            duplicated = root / 'duplicate.zpak'
            archive_fixture(duplicated, [raw], references=[(0, 'adreno_200/set/brucelee.set')])
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', UserWarning)
                with zipfile.ZipFile(duplicated, 'a') as archive:
                    archive.writestr('Core.pakh', b'conflicting member')
            with self.assertRaisesRegex(ValueError, 'duplicate PAK member'):
                inspect_archive(duplicated, ['lowpunch1'])
            both = subprocess.run([sys.executable, str(script), str(other), '--archive', str(zpak),
                                   '--action', 'lowpunch1'], capture_output=True, text=True)
            self.assertNotEqual(both.returncode, 0)


if __name__ == '__main__':
    unittest.main()
