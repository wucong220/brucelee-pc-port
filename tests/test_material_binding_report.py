from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from material_binding_report import build_report, parse_mesh_specs


def object_report():
    references = [
        {'ordinal': 0, 'path': 'objects/hair_hw_skhigh.mesh'},
        {'ordinal': 1, 'path': 'objects/hair/textures/diffuse.tex'},
        {'ordinal': 2, 'path': 'objects/hair/textures/normal.tex'},
        {'ordinal': 3, 'path': 'objects/hair/textures/material.tex'},
        {'ordinal': 4, 'path': 'objects/body_hw_skhigh.mesh'},
        {'ordinal': 5, 'path': 'objects/body/textures/diffuse.tex'},
        {'ordinal': 6, 'path': 'objects/body/textures/normal.tex'},
        {'ordinal': 7, 'path': 'objects/body/textures/material.tex'},
    ]
    uses = [
        {'record_ordinal': 10, 'property': 'mesh', 'reference_id': 0},
        {'record_ordinal': 12, 'property': 'diffuse', 'reference_id': 1},
        {'record_ordinal': 13, 'property': 'normal', 'reference_id': 2},
        {'record_ordinal': 14, 'property': 'material', 'reference_id': 3},
        {'record_ordinal': 20, 'property': 'mesh', 'reference_id': 4},
        {'record_ordinal': 22, 'property': 'diffuse', 'reference_id': 5},
        {'record_ordinal': 23, 'property': 'normal', 'reference_id': 6},
        {'record_ordinal': 24, 'property': 'material', 'reference_id': 7},
    ]
    return {
        'sha256': 'object-hash',
        'decoded_bytes': 100,
        'external_references': references,
        'external_reference_uses': uses,
    }


def program_report():
    return {
        'sha256': 'program-hash',
        'decoded_bytes': 200,
        'texture_constants': [
            {'name': 'diffuse'},
            {'name': 'normal'},
            {'name': 'material'},
        ],
    }


def mesh_report(kind):
    if kind == 'hair':
        subsets = [{
            'record_start': 14,
            'index_range': [0, 843],
            'vertex_range': [0, 213],
            'triangle_count': 281,
            'material': 'hair_hw',
        }]
        return {
            'sha256': 'hair-mesh-hash',
            'vertex_count': 213,
            'index_count': 843,
            'subset_count': 1,
            'subsets': subsets,
        }
    subsets = [
        {
            'record_start': 16,
            'index_range': [0, 6141],
            'vertex_range': [0, 1445],
            'triangle_count': 2047,
            'material': 'body_hw',
        },
        {
            'record_start': 32,
            'index_range': [6141, 8505],
            'vertex_range': [1445, 2075],
            'triangle_count': 788,
            'material': 'body_hw',
        },
        {
            'record_start': 48,
            'index_range': [8505, 10080],
            'vertex_range': [2075, 2448],
            'triangle_count': 525,
            'material': 'body_hw',
        },
    ]
    return {
        'sha256': 'body-mesh-hash',
        'vertex_count': 2448,
        'index_count': 10080,
        'subset_count': 3,
        'subsets': subsets,
    }


class TestMaterialBindingReport(unittest.TestCase):
    def test_builds_hair_and_body_mappings(self):
        result = build_report(
            object_report(),
            program_report(),
            {'hair': mesh_report('hair'), 'body': mesh_report('body')},
        )
        self.assertEqual(result['evidence_level'], 'STATIC_VERIFIED')
        self.assertEqual(result['schema_version'], 2)
        self.assertEqual(result['program_texture_constants'], [
            'diffuse', 'normal', 'material',
        ])
        self.assertEqual(
            result['bindings']['hair']['textures']['normal']['reference_id'],
            2,
        )
        self.assertEqual(
            result['bindings']['body']['textures']['material']['path'],
            'objects/body/textures/material.tex',
        )
        self.assertEqual(result['bindings']['body']['subset_count'], 3)
        self.assertEqual(
            result['bindings']['body']['subsets'][1]['index_range'],
            [6141, 8505],
        )

    def test_rejects_missing_texture_property(self):
        source = object_report()
        source['external_reference_uses'] = [
            use for use in source['external_reference_uses']
            if not (use['record_ordinal'] == 13)
        ]
        with self.assertRaisesRegex(KdfError, 'missing texture properties: normal'):
            build_report(
                source,
                program_report(),
                {'hair': mesh_report('hair'), 'body': mesh_report('body')},
            )

    def test_rejects_mesh_material_mismatch(self):
        body_mesh = mesh_report('body')
        body_mesh['subsets'][1]['material'] = 'other_material'
        with self.assertRaisesRegex(KdfError, 'does not match'):
            build_report(
                object_report(),
                program_report(),
                {'hair': mesh_report('hair'), 'body': body_mesh},
            )

    def test_mesh_arguments_require_one_part_each(self):
        parsed = parse_mesh_specs(['hair=C:/private/hair.mesh',
                                   'body=C:/private/body.mesh'])
        self.assertEqual(set(parsed), {'hair', 'body'})
        for invalid in (
                [], ['hair=C:/private/hair.mesh'],
                ['hair=C:/a', 'hair=C:/b', 'body=C:/c']):
            with self.subTest(values=invalid), self.assertRaises(KdfError):
                parse_mesh_specs(invalid)


    def test_mesh_reports_are_required(self):
        with self.assertRaises(TypeError):
            build_report(object_report(), program_report())
        with self.assertRaisesRegex(KdfError, 'exactly hair and body'):
            build_report(
                object_report(),
                program_report(),
                {'hair': mesh_report('hair')},
            )


if __name__ == '__main__':
    unittest.main()
