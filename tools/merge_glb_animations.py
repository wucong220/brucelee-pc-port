#!/usr/bin/env python3
"""Append animation clips from one GLB to another without rebuilding geometry.

The two files must expose the same skeleton node names. Only animation
accessors, buffer views and the binary payload are copied; meshes, materials,
skins and the base file's existing animations are left unchanged.
"""
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


class MergeError(RuntimeError):
    pass


def _read_glb(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if len(raw) < 12:
        raise MergeError(f"not a GLB: {path}")
    magic, version, total = struct.unpack_from("<III", raw, 0)
    if magic != 0x46546C67 or version != 2 or total != len(raw):
        raise MergeError(f"unsupported GLB header: {path}")
    offset = 12
    result = {}
    binary = b""
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        payload = raw[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            result = json.loads(payload.rstrip(b" \t\r\n\x00").decode("utf-8"))
        elif kind == 0x004E4942:
            binary = payload
        offset += 8 + length
    if not result:
        raise MergeError(f"GLB has no JSON chunk: {path}")
    return result, binary


def _write_glb(path: Path, document: dict, binary: bytes) -> None:
    json_bytes = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    binary += b"\x00" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(binary)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(struct.pack("<III", 0x46546C67, 2, total))
        handle.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        handle.write(json_bytes)
        handle.write(struct.pack("<II", len(binary), 0x004E4942))
        handle.write(binary)


def _node_names(document: dict) -> dict[int, str]:
    result = {}
    for index, node in enumerate(document.get("nodes", [])):
        name = node.get("name")
        if name:
            result[index] = name
    return result


def _component_bytes(component_type: int) -> int:
    sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    if component_type not in sizes:
        raise MergeError(f"unsupported accessor component type: {component_type}")
    return sizes[component_type]


def _element_count(type_name: str) -> int:
    values = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
              "MAT2": 4, "MAT3": 9, "MAT4": 16}
    if type_name not in values:
        raise MergeError(f"unsupported accessor type: {type_name}")
    return values[type_name]


def merge(base_path: Path, add_path: Path, output: Path) -> dict:
    if output.exists():
        raise MergeError(f"output already exists: {output}")
    base, base_binary = _read_glb(base_path)
    add, add_binary = _read_glb(add_path)
    base_nodes = {name: index for index, name in _node_names(base).items()}
    add_nodes = _node_names(add)

    accessors = base.setdefault("accessors", [])
    views = base.setdefault("bufferViews", [])
    animations = base.setdefault("animations", [])
    existing_names = {str(item.get("name", "")) for item in animations}
    binary = bytearray(base_binary)

    def append_accessor(source_index: int, cache: dict[int, int]) -> int:
        if source_index in cache:
            return cache[source_index]
        if not 0 <= source_index < len(add.get("accessors", [])):
            raise MergeError(f"animation accessor out of range: {source_index}")
        source = add["accessors"][source_index]
        if "sparse" in source:
            raise MergeError("sparse accessors are not supported")
        view_index = source.get("bufferView")
        if view_index is None:
            raise MergeError("accessor has no bufferView")
        if not 0 <= view_index < len(add.get("bufferViews", [])):
            raise MergeError("accessor bufferView out of range")
        view = add["bufferViews"][view_index]
        if "byteStride" in view:
            raise MergeError("strided buffer views are not supported")
        byte_offset = int(view.get("byteOffset", 0)) + int(source.get("byteOffset", 0))
        count = int(source["count"])
        width = _element_count(str(source["type"])) * _component_bytes(
            int(source["componentType"])
        )
        payload = add_binary[byte_offset:byte_offset + count * width]
        if len(payload) != count * width:
            raise MergeError("accessor payload is truncated")
        while len(binary) % 4:
            binary.append(0)
        target_offset = len(binary)
        binary.extend(payload)
        new_view = dict(view)
        new_view.pop("byteStride", None)
        new_view["buffer"] = 0
        new_view["byteOffset"] = target_offset
        new_view["byteLength"] = len(payload)
        views.append(new_view)
        new_accessor = dict(source)
        new_accessor.pop("byteOffset", None)
        new_accessor["bufferView"] = len(views) - 1
        accessors.append(new_accessor)
        cache[source_index] = len(accessors) - 1
        return cache[source_index]

    added = 0
    for animation in add.get("animations", []):
        name = str(animation.get("name", ""))
        if not name:
            raise MergeError("animation lacks a name")
        if name in existing_names:
            raise MergeError(f"animation already exists: {name}")
        accessor_cache: dict[int, int] = {}
        samplers = []
        channels = []
        for sampler in animation.get("samplers", []):
            samplers.append({
                "input": append_accessor(int(sampler["input"]), accessor_cache),
                "output": append_accessor(int(sampler["output"]), accessor_cache),
                "interpolation": sampler.get("interpolation", "LINEAR"),
            })
        for channel in animation.get("channels", []):
            target = channel.get("target", {})
            old_node = int(target.get("node", -1))
            node_name = add_nodes.get(old_node)
            if node_name is None or node_name not in base_nodes:
                raise MergeError(f"animation target node is missing: {node_name!r}")
            if not 0 <= int(channel.get("sampler", -1)) < len(samplers):
                raise MergeError("animation channel sampler is out of range")
            channels.append({
                "sampler": int(channel["sampler"]),
                "target": {"node": base_nodes[node_name],
                           "path": str(target["path"])},
            })
        animations.append({"name": name, "samplers": samplers, "channels": channels})
        existing_names.add(name)
        added += 1

    if not base.get("buffers"):
        base["buffers"] = [{"byteLength": 0}]
    base["buffers"][0]["byteLength"] = len(binary)
    _write_glb(output, base, bytes(binary))
    return {
        "output": str(output),
        "added_animations": added,
        "animation_count": len(animations),
        "bytes": output.stat().st_size,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path)
    parser.add_argument("add", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(merge(args.base, args.add, args.output), indent=2))
    except (OSError, MergeError, ValueError) as exc:
        print(f"error: {exc}", file=__import__("sys").stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
