from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class RetargetExportOptionsTests(unittest.TestCase):
    def test_incomplete_retarget_options_fail_before_output(self):
        script = Path(__file__).resolve().parents[1] / 'tools' / 'character_to_gltf.py'
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'output.glb'
            result = subprocess.run(
                [sys.executable, str(script), 'missing.mesh', '--output', str(output),
                 '--retarget-animation', 'missing.anm', 'a' * 64],
                capture_output=True, text=True, encoding='utf-8')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('requires animations and all source/target identity', result.stderr)
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
