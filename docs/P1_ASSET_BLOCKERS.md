# P1 asset blockers

## `all_sp_pnch_low_forset04` / `impactbrutalmid` — RESOLVED

- Source ANM:
  `D:\BruceLeeWork\anim_brutal\adreno_200\animation\all_sp_pnch_low_forset04.anm`
- Correct ANM SHA-256:
  `82CBDE2C8EEA15DAAC5C19AFBC535113C976141234332395BCB7B19BC5C3BB6F`
- The ANM string table names the source skeleton:
  `skeletons/bl_brucelee_01_high.skl`
  (`bl_brucelee_01_High.Skl`, SHA-256 `4A6D4532…2E3`).
- Retarget Bruce → Brick with `character_to_gltf.py` succeeded:
  - 2,495 vertices / 3,657 triangles
  - 67 skin joints
  - rest-pose max error ~3.3e-4
  - animation `all_sp_pnch_low_forset04`
- The base Brick candidate already contained a placeholder animation with that
  name; it was removed and the successful retarget was merged back:
  `D:\BruceLeeWork\brick_candidate_brutal_20261103.glb`
- Self-test now reports `"opponent_brutal_clip": true`.
- `launch.ps1` points at the new Brick candidate.
- This is a candidate retarget, not a native-verified animation.

## `m02_movefwd`

Resolved as a candidate via Ken→Bruce retarget:
`bruce_candidate_92_movefwd_20261103.glb`. Still requires frame/visual
validation; it is CANDIDATE, not native-verified.
