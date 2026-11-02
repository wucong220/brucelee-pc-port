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

## 2026-11-03 parser progress

`tools/kdf_object.py` now recognizes the one-byte zero prefix used by scene
external-reference tables (object tables have no prefix). The sample parses to:

- `scene` frame with 3 children
- 3 `object` nodes
- each object has one `mesh` visual
- refs include
  `scene/hw/bl_templeyarda_nearobjects/meshes/bl_scene02a_hw_prop_brick*.mesh`
  and `shaders/scene.shd` / one `.tex`

The node/visual graph is now recoverable. Mesh conversion and arena merge are
still not implemented; no procedural scene has been replaced yet.

## 2026-11-03 static mesh probe

Extracted and converted one scene prop:

`bl_scene02a_hw_prop_brick.Mesh`

with `tools/character_to_gltf.py` (no Skl, static mesh):

- 488 vertices
- 507 triangles
- 1 subset
- output GLB `brick_prop.glb`
- GLB size 14,340 bytes

This proves scene `.mesh` resources can be fed through the existing static
mesh converter. It does **not** yet prove scene transforms/material binding or
arena composition; those are the next steps.

## 2026-11-03 far-scene graph

`BL_TempleYardA_FarObjects.scene` now parses to:

- 22 nodes
- 39 external references
- 19 visuals
- nodes include `bl_scene02a_hw_grounda/b`, `fartemple`, `bigtemple`,
  `redgate`, trees/rocks, `combatarea`, `skydome`, `bl_scene_sun`

Its pose-transform table is a different layout and currently returns
`pose_transform_error`; the node/visual graph is available, transforms are not
yet trusted. Far-scene mesh conversion and merge are still pending.



This is deliberately **not** implemented as a fake procedural stand-in. Current arena remains procedural until the mesh/reference graph is converted and verified.
