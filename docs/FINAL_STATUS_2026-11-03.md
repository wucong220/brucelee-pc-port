# Current port status (2026-11-03 11:05)

## Package

`D:\BruceLeeWork\DragonWarrior-Current91-20261103`

- Built through `build_windows.ps1 -RuntimeAssetRoot`.
- Includes exe/pck, audio, menu, scene, ui, launch.ps1, A/B/HallA direct launchers.

## Playable

- Temple Yard A: 18 far props / 18 textures / 3 near props.
- Temple Yard B: 18 far props / 18 textures / 3 near props; `bigtemple` fixed by
  ATC RGBA block-order and top-down orientation corrections.
- Tournament Hall A: interior renders after skipping `bl_scene04a_hw_fx_biglighta`
  and `bl_scene04a_hw_fx_biglightb`; together those two planes overdraw the screen white.
- A/B menu selection and direct launchers, plus `DragonWarrior_HallA_Direct.cmd`
  and a `TOURNAMENT HALL A` main-menu entry.
- J menu-confirm enters the fight and preserves the first attack.
- SPECIAL LOW KICK (`S` hold, then `D+U`) verified to `special_kick_low_hit`.

## Not complete

- Original game-text textures: decoded alpha is a splat mask, not lettering.
- Brick brutal: `all_sp_pnch_low_forset04` retargeted Bruce -> Brick and merged;
  self-test reports `opponent_brutal_clip: true`. Candidate, not native-verified.
- Remaining 8 characters, 8 scenes, most UI and many audio files are still absent.
