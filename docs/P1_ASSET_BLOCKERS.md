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
- Also tried `BL_SinFu_01_High.Skl` as retarget source
  (`62C3EAA9…8301`): converter rejects with
  `animation reference or skeleton SHA-256 does not match expectation`.
  The correct source skeleton reference for `all_sp_pnch_low_forset04` is still
  unidentified.
- Also tried `BL_Ken_Goodall_01_High.Skl` (`9FC87D19…722B`): same
  `animation reference or skeleton SHA-256` rejection.
- Also tried `bl_brucelee_01_High.Skl` (`4A6D4532…2E3`): converter rejects
  `candidate source identity or target identity does not match`.
  No successful retarget; no Brick brutal clip was merged.
- Corrected the ANM SHA-256 used in earlier attempts: the actual
  `all_sp_pnch_low_forset04.anm` hash is
  `82CBDE2C8EEA15DAAC5C19AFBC535113C976141234332395BCB7B19BC5C3BB6F`
  (not `188b6994…`). Retrying with the corrected hash still fails with
  `animation reference or skeleton SHA-256 does not match expectation`,
  so the source skeleton/reference remains the blocker.

## `m02_movefwd`

Resolved as a candidate via Ken→Bruce retarget:
`bruce_candidate_92_movefwd_20261103.glb`. Still requires frame/visual
validation; it is CANDIDATE, not native-verified.
