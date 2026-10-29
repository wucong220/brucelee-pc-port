#!/usr/bin/env python3
"""Report static Hair/Body texture bindings without exporting game resources."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError
from kdf_object import inspect_file as inspect_object_file
from kdf_program import inspect_file as inspect_program_file

_TEXTURE_PROPERTIES = ('diffuse', 'normal', 'material')
_SEARCH_RECORDS = 32


def _single_binding(object_report: dict, kind: str) -> dict:
    references = {
        entry['ordinal']: entry['path']
        for entry in object_report['external_references']
    }
    mesh_uses = [
        use for use in object_report['external_reference_uses']
        if use['property'] == 'mesh'
        and kind in references[use['reference_id']].casefold()
        and 'skhigh' in references[use['reference_id']].casefold()
    ]
    if len(mesh_uses) != 1:
        raise KdfError(
            f'expected one {kind} skinned mesh binding; found {len(mesh_uses)}'
        )
    mesh_use = mesh_uses[0]
    following_mesh_records = [
        use['record_ordinal']
        for use in object_report['external_reference_uses']
        if use['property'] == 'mesh'
        and use['record_ordinal'] > mesh_use['record_ordinal']
    ]
    search_end = mesh_use['record_ordinal'] + _SEARCH_RECORDS
    if following_mesh_records:
        search_end = min(search_end, min(following_mesh_records))
    texture_uses = [
        use for use in object_report['external_reference_uses']
        if mesh_use['record_ordinal'] < use['record_ordinal']
        < search_end
        and use['property'] in _TEXTURE_PROPERTIES
    ]
    by_property = {}
    for use in texture_uses:
        if use['property'] in by_property:
            raise KdfError(
                f'{kind} repeats texture property {use["property"]!r}'
            )
        by_property[use['property']] = {
            'reference_id': use['reference_id'],
            'path': references[use['reference_id']],
        }
    missing = [name for name in _TEXTURE_PROPERTIES if name not in by_property]
    if missing:
        raise KdfError(
            f'{kind} is missing texture properties: {", ".join(missing)}'
        )
    return {
        'mesh': references[mesh_use['reference_id']],
        'textures': {
            name: by_property[name]
            for name in _TEXTURE_PROPERTIES
        },
    }


def build_report(object_report: dict, program_report: dict) -> dict:
    declared = [entry['name'] for entry in program_report['texture_constants']]
    if set(declared) != set(_TEXTURE_PROPERTIES):
        raise KdfError(
            'program texture constants do not match diffuse/normal/material'
        )
    return {
        'schema_version': 1,
        'evidence_level': 'STATIC_VERIFIED',
        'object_sha256': object_report['sha256'],
        'object_decoded_bytes': object_report['decoded_bytes'],
        'program_sha256': program_report['sha256'],
        'program_decoded_bytes': program_report['decoded_bytes'],
        'program_texture_constants': declared,
        'bindings': {
            'hair': _single_binding(object_report, 'hair'),
            'body': _single_binding(object_report, 'body'),
        },
        'boundaries': [
            'Static resource references and shader-constant declarations are resolved.',
            'Runtime texture loading success is not inferred from static references.',
            'Original Adreno lighting, blending, mip, and pixel output remain unverified.',
            'No original texture, mesh, shader source, or decoded binary payload is included.',
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('object', type=Path, help='decoded object resource')
    parser.add_argument('program', type=Path, help='decoded program resource')
    parser.add_argument('--output', type=Path, help='metadata JSON output path')
    args = parser.parse_args()
    try:
        result = build_report(
            inspect_object_file(args.object),
            inspect_program_file(args.program),
        )
        text = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        if args.output is None:
            sys.stdout.write(text)
        else:
            with args.output.open('w', encoding='utf-8', newline='\n') as output:
                output.write(text)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
