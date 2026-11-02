# Movement root motion data (candidate GLB)

Source: candidate GLB `Animation` track
`Z_up_to_glTF_Y_up/root/character` position keys. Values are candidate/source
units and are **not** assigned to gameplay until the locomotion chain lands.

File: `godot/data/movement_root_motion.json`

Clips currently extracted:

- `m01_stepfwd`
- `m01_stepbck`
- `m01_steprht`
- `m01_steplft`
- `m01_movebck`
- `m01_movelft`
- `m01_moverht`

Missing for a complete native chain:

- `m02_movefwd` — original ANM extracted to
  `D:\BruceLeeWork\anim_movefwd\`, but its skeleton reference does not match the
  current Bruce candidate; it needs a separate retarget/严格骨架 path.
- `m02_moveback` etc. are not in the current candidate.

The next implementation step is a `step -> move` action chain plus a root
position accumulator; no velocity formula is used for the final path.
