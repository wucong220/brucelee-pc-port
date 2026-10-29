import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from character_to_gltf import GltfExportError, convert_file
from test_kdf_mesh import mesh_fixture


class TestGltfPublication(unittest.TestCase):
    def test_more_than_twenty_animations_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaisesRegex(GltfExportError, 'too many candidate'):
                convert_file(
                    root / 'missing.mesh',
                    root / 'candidate.glb',
                    animation_sources=[
                        root / f'animation-{index}.anm' for index in range(21)
                    ],
                )
            self.assertFalse((root / 'candidate.glb').exists())

    def test_output_in_project_or_known_sync_folder_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'project'
            project.mkdir()
            sync = root / 'OneDrive'
            sync.mkdir()
            source = root / 'mesh.bin'
            source.write_bytes(mesh_fixture(skinned=False))
            with patch('character_to_gltf._PROJECT_ROOT', project):
                for output in (project / 'candidate.glb', sync / 'candidate.glb'):
                    with self.subTest(output=output):
                        with self.assertRaises(GltfExportError):
                            convert_file(source, output)
                        self.assertFalse(output.exists())

    def test_local_input_in_project_and_sync_named_folder_is_read_only(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'project'
            source_folder = project / 'OneDrive'
            source_folder.mkdir(parents=True)
            source = source_folder / 'mesh.bin'
            payload = mesh_fixture(skinned=False)
            source.write_bytes(payload)
            output = root / 'candidate.glb'
            with patch('character_to_gltf._PROJECT_ROOT', project):
                convert_file(source, output)
            self.assertEqual(source.read_bytes(), payload)
            self.assertTrue(output.is_file())

    def test_partial_write_leaves_no_target_or_temporary_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output = root / 'mesh.bin', root / 'candidate.glb'
            source.write_bytes(mesh_fixture(skinned=False))
            real_fdopen = os.fdopen

            class FailingWriter:
                def __init__(self, fd, mode):
                    self.file = real_fdopen(fd, mode)

                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    self.file.close()

                def write(self, data):
                    self.file.write(data[:16])
                    raise OSError('simulated partial write')

            with patch('character_to_gltf.os.fdopen', side_effect=FailingWriter):
                with self.assertRaisesRegex(OSError, 'simulated partial write'):
                    convert_file(source, output)
            self.assertFalse(output.exists())
            self.assertEqual(list(root.glob('.brucelee-glb-*.tmp')), [])

    def test_concurrent_destination_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output = root / 'mesh.bin', root / 'candidate.glb'
            source.write_bytes(mesh_fixture(skinned=False))
            operation = 'rename' if os.name == 'nt' else 'link'
            real_publish = getattr(os, operation)
            concurrent_data = b'created by another process'

            def create_competing_target(src, dst):
                Path(dst).write_bytes(concurrent_data)
                real_publish(src, dst)

            with patch('character_to_gltf.os.' + operation, side_effect=create_competing_target):
                with self.assertRaises(FileExistsError):
                    convert_file(source, output)
            self.assertEqual(output.read_bytes(), concurrent_data)
            self.assertEqual(list(root.glob('.brucelee-glb-*.tmp')), [])

    def test_publication_failure_cleans_temporary_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output = root / 'mesh.bin', root / 'candidate.glb'
            source.write_bytes(mesh_fixture(skinned=False))
            operation = 'rename' if os.name == 'nt' else 'link'
            with patch('character_to_gltf.os.' + operation, side_effect=OSError('publish failed')):
                with self.assertRaisesRegex(OSError, 'publish failed'):
                    convert_file(source, output)
            self.assertFalse(output.exists())
            self.assertEqual(list(root.glob('.brucelee-glb-*.tmp')), [])

    @unittest.skipUnless(os.name == 'nt', 'Windows rename behavior only')
    def test_windows_publication_does_not_need_hardlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output = root / 'mesh.bin', root / 'candidate.glb'
            source.write_bytes(mesh_fixture(skinned=False))
            with patch('character_to_gltf.os.link', side_effect=OSError('link unsupported')) as link:
                convert_file(source, output)
            link.assert_not_called()
            self.assertTrue(output.is_file())
            self.assertEqual(list(root.glob('.brucelee-glb-*.tmp')), [])

    def test_dangling_output_symlink_is_not_followed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output, missing = root / 'mesh.bin', root / 'candidate.glb', root / 'missing.glb'
            source.write_bytes(mesh_fixture(skinned=False))
            try:
                output.symlink_to(missing)
            except (OSError, NotImplementedError):
                self.skipTest('symlink creation unavailable')
            with self.assertRaisesRegex(GltfExportError, 'already exists'):
                convert_file(source, output)
            self.assertTrue(output.is_symlink())
            self.assertFalse(missing.exists())
            self.assertEqual(list(root.glob('.brucelee-glb-*.tmp')), [])


if __name__ == '__main__':
    unittest.main()
