# Movement root motion data (candidate GLB)

Source: candidate GLB `Animation` track
`Z_up_to_glTF_Y_up/root/character` position keys. Values are candidate/source
units and are **not** assigned to gameplay until the locomotion chain lands.

File: `godot/data/movement_root_motion.json`

Clips currently extracted:

- `m01_stepfwd`
- `m02_movefwd` (Ken→Bruce retarget, `CANDIDATE`)
- `m01_stepbck`
- `m01_steprht`
- `m01_steplft`
- `m01_movebck`
- `m01_movelft`
- `m01_moverht`

`m02_movefwd` was extracted from the original set but its ANM skeleton is Ken.
It was converted through the converter's `--retarget-animation` path
(`BL_Ken_Goodall_01_High.Skl` → `bl_brucelee_01_High.Skl`) and merged as
`bruce_candidate_92_movefwd_20261103.glb`. This is a candidate cross-skeleton
clip, not a frame-verified native result.

Implementation: `fighter.gd` now samples these tracks in
`_locomotion_root_delta()`, applies them through the existing facing/scale
adapter, chains `step* -> move*` at frame 4, and reseeds the root accumulator
when an action changes or a move track wraps. Training keeps its dummy close
to the player while a step lesson is active.

