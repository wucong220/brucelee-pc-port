# Scene variants and blockers (2026-11-03)

## Working

- Temple Yard A: 19 far props / 19 textures, 3 near props, verified screenshot.
- Temple Yard B: 17 far props / 17 textures, 3 near props, verified screenshot.
  `bigtemple` is intentionally not rendered because its current UV/material
  binding produces a large beige plane.

## Not working

- Tournament Hall A: 14 far / 3 near visuals parsed and converted, but the
  current one-mesh/one-texture path paints whole architecture surfaces with a
  texture sheet. Not imported.
- Original game text: the decoded `BL_gameText-*` alpha is a splat mask, not
  letter shapes; direct alpha-to-white display produces a white blob. Disabled.
- Brick brutal reaction: source skeleton/reference for
  `all_sp_pnch_low_forset04` still unidentified.

## Runtime entry points

- `DragonWarrior.cmd`: Temple Yard A
- `DragonWarrior_TempleYardB.cmd`: Temple Yard B
- Main menu: `TEMPLE YARD B` reloads with `BRUCELEE_SCENE=templeyardb`
