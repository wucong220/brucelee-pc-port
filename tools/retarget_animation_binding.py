#!/usr/bin/env python3
"""Construct a strictly identified experimental cross-skeleton track mapping."""
from __future__ import annotations

from copy import deepcopy
import re

from audit_animation_retarget import audit
from kdf_data import KdfError


def retarget_candidate(binding: dict, source: dict, target: dict, *,
                       expected_animation_sha256: str,
                       expected_source_sha256: str,
                       expected_target_sha256: str,
                       expected_reference: str) -> dict:
    """Keep source evidence and raw values; do not compose or export transforms."""
    if (any(not isinstance(value, str) or re.fullmatch(r'[0-9a-f]{64}', value) is None
            for value in (expected_animation_sha256, expected_source_sha256,
                          expected_target_sha256))
            or not isinstance(expected_reference, str) or not expected_reference.endswith('.skl')
            or binding.get('pairing_status') != 'matched-provided-reference-and-hash'
            or binding.get('animation_sha256') != expected_animation_sha256
            or binding.get('skeleton_sha256') != expected_source_sha256
            or source.get('sha256') != expected_source_sha256
            or target.get('sha256') != expected_target_sha256
            or binding.get('skeleton_reference', {}).get('reference') != expected_reference):
        raise KdfError('candidate source identity or target identity does not match')
    result = audit(binding, source, target)
    mapped = []
    for original, identity in zip(binding['bindings'], result['mappings'], strict=True):
        item = deepcopy(original)
        item['nodeid'] = identity['target_nodeid']
        item['offset'] = identity['target_offset']
        mapped.append(item)
    return {
        'status': 'experimental-cross-skeleton-candidate',
        'mapping_status': result['status'],
        'source_pairing_status': binding['pairing_status'],
        'animation_sha256': binding['animation_sha256'],
        'source_skeleton_sha256': source['sha256'],
        'target_skeleton_sha256': target['sha256'],
        'source_skeleton_reference': expected_reference,
        'headers': deepcopy(binding['headers']),
        'bindings': mapped,
        'mapping': result['mappings'],
        'semantics': 'unverified; values unchanged; no transform composition',
    }
