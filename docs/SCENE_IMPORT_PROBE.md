# Scene import probe (2026-11-03)

Extracted a small scene resource to inspect the container and dependencies:

`adreno_200/scene/BL_TempleYardA_NearObjects.scene`

- File size: 2029 bytes
- Header: `1FDKENONCTX3`
- Contains scene object names such as `bl_scene02a_hw_prop_brick`, `scene`, `flags`, `position`, `rotation`
- It is a CTX3/KDF scene object, not a ready glTF scene.

No scene-to-glTF converter exists in `tools/` yet. A correct importer must:

1. Parse the scene object graph and mesh references.
2. Resolve the referenced `.mesh` resources with the existing mesh/Skl pipeline.
3. Preserve node transforms and material/texture references.
4. Decide how far objects (`*_FarObjects`) and FX scenes are merged for one arena.
5. Only then replace the procedural arena.

This is deliberately **not** implemented as a fake procedural stand-in. Current arena remains procedural until the mesh/reference graph is converted and verified.
