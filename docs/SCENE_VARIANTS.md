# Scene variants and blockers (2026-11-03)

## Working

- Temple Yard A: 18 far props / 18 textures, 3 near props, verified screenshot.
- Temple Yard B: 17 far props / 17 textures, 3 near props, verified screenshot.
  `bigtemple` is intentionally not rendered because its texture is an
  `atc_rgba_explicit` resource whose current decode is a black/white mask.

## Not working

- Tournament Hall A: 14 far / 3 near visuals parsed and converted, but the
  current one-mesh/one-texture path paints whole architecture surfaces with a
  texture sheet. Not imported.
- Original game text: the decoded `BL_gameText-*` alpha is a splat mask, not
  letter shapes; direct alpha-to-white display produces a white blob. Disabled.
- Brick brutal reaction: source skeleton/reference for
  `all_sp_pnch_low_forset04` still unidentified.

## Runtime entry points

- `DragonWarrior.cmd`: opens the main menu with Temple Yard A loaded
- `DragonWarrior_TempleYardB.cmd`: opens the main menu with Temple Yard B loaded
- `DragonWarrior_A_Direct.cmd`: starts Temple Yard A fight directly
- `DragonWarrior_B_Direct.cmd`: starts Temple Yard B fight directly
- Main menu `TEMPLE YARD A/B`: reloads and now starts the selected arena
  directly (`BRUCELEE_MAIN_MENU=0`)
