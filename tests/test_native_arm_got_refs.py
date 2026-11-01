import struct
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from native_arm_got_refs import scan


def words(*items):
    return struct.pack('<' + 'I' * len(items), *items)


class GotReferences(unittest.TestCase):
    def scan(self, code, literals, target=0x3000, window=64):
        def read(address):
            if address not in literals:
                raise ValueError('unmapped')
            return literals[address]
        return scan(code, 0x1000, read, target, window)

    def test_pic_add_and_index(self):
        # ldr r0,[pc,#0x18]; add r0,pc,r0; ldr r1,[pc,#0x14]; ldr r2,[r0,r1]
        code = words(0xe59f0018, 0xe08f0000, 0xe59f1014, 0xe7902001)
        hits = self.scan(code, {0x1020: 0xff4, 0x1024: 0x1000})
        self.assertEqual([h['ldr'] for h in hits], [0x100c])
        self.assertEqual(hits[0]['slot'], 0x3000)
        self.assertEqual([p[0] for p in hits[0]['provenance']], [0x1000, 0x1004, 0x1008])

    def test_clobber_branch_and_condition(self):
        literals = {0x1020: 0xff4, 0x1024: 0x1000}
        prefix = (0xe59f0018, 0xe08f0000, 0xe59f1014)
        for middle in (0xe3a00000, 0xea000000, 0x13a00000):
            with self.subTest(middle=middle):
                self.assertEqual(self.scan(words(*prefix, middle, 0xe7902001), literals), [])

    def test_wrong_slot_and_expired(self):
        code = words(0xe59f0018, 0xe08f0000, 0xe59f1014, 0xe7902001)
        literals = {0x1020: 0xff4, 0x1024: 0x1000}
        self.assertEqual(self.scan(code, literals, target=0x3004), [])
        self.assertEqual(self.scan(code, literals, window=8), [])

    def test_oldest_source_in_second_add_operand_at_window_boundary(self):
        # r1's earlier literal is the second ADD operand; LDR at +16.
        code = words(0xe59f1018, 0xe59f0018, 0xe0802001,
                     0xe59f3014, 0xe7924003)
        literals = {0x1020: 0x1000, 0x1024: 0x1000, 0x1028: 0x1000}
        self.assertEqual([h['ldr'] for h in self.scan(code, literals, window=16)], [0x1010])
        self.assertEqual(self.scan(code, literals, window=15), [])

    def test_missing_capstone_import_and_cli(self):
        tools = str(Path(__file__).resolve().parents[1] / 'tools')
        script = str(Path(tools) / 'native_arm_got_refs.py')
        probe = "import sys; sys.path.insert(0, sys.argv[1]); import native_arm_got_refs"
        imported = subprocess.run([sys.executable, '-S', '-c', probe, tools], capture_output=True, text=True, errors='replace')
        self.assertNotEqual(imported.returncode, 0)
        self.assertIn('ModuleNotFoundError', imported.stderr)
        self.assertNotIn('SystemExit', imported.stderr)
        cli = subprocess.run([sys.executable, '-S', script, '--help'], capture_output=True, text=True, errors='replace')
        self.assertEqual(cli.returncode, 1)
        self.assertIn('Python capstone is required', cli.stderr)
        self.assertNotIn('Traceback', cli.stderr)

    def test_callee_saved_and_forward_branch(self):
        # r4 carries PIC base across BL and a conditional branch over a return.
        code = words(0xe59f4018, 0xeb000000, 0xe08f4004, 0x0a000001,
                     0xe8bd8010, 0xe1a00000, 0xe59f1004, 0xe7942001)
        hits = self.scan(code, {0x1020: 0xff0, 0x1024: 0x1000})
        self.assertEqual([h['ldr'] for h in hits], [0x101c])

    def test_unmapped_literal_and_shifted_index(self):
        code = words(0xe59f0018, 0xe08f0000, 0xe59f1014, 0xe7902101)
        self.assertEqual(self.scan(code, {}), [])
        self.assertEqual(self.scan(code, {0x1020: 0xff4, 0x1024: 0x1000}), [])


if __name__ == '__main__':
    unittest.main()
