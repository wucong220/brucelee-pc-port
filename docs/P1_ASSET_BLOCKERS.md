# P1 asset blockers

## `all_sp_pnch_low_forset04` / `impactbrutalmid`

- Needed by Brick brutal/medium reaction (`impactbrutalmid`).
- Source ANM extracted to
  `D:\BruceLeeWork\anim_brutal\adreno_200\animation\all_sp_pnch_low_forset04.anm`.
- The ANM's skeleton is not Brick; `character_to_gltf.py` correctly rejects direct
  Brick conversion.
- Retarget path attempted with `BL_The_Master_01_High.Skl`
  (`3CD7D288…12AE`) as source, Brick as target:
  `error: Skl name reference 0 does not target its node`.
- Therefore this clip is **not** merged; Brick brutal/medium remains a known gap.
  Do not force the clip into the Brick candidate or substitute a different
  brutal animation; wait for a correct source skeleton/reference mapping.

## `m02_movefwd`

Resolved as a candidate via Ken→Bruce retarget:
`bruce_candidate_92_movefwd_20261103.glb`. Still requires frame/visual
validation; it is CANDIDATE, not native-verified.
