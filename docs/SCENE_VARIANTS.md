# Scene variants and blockers (2026-11-03)

## Working

- Temple Yard A: 18 far props / 18 textures, 3 near props, verified screenshot.
- Temple Yard B: 18 far props / 18 textures, 3 near props, verified screenshot.
  `bigtemple` renders with corrected ATC RGBA block order and top-down orientation.
- Tournament Hall A: 14 far visuals render with the generic camera; generic
  additive/unshaded handling is applied to `fx_`/light entries instead of
  per-scene culling. 3 near props are loaded from `scene/halla/near`.
- Square B: 11 far visuals + sky; manifest entry renamed `bl_squareb_hw_sky`
  so the loader does not skip the inward-facing dome.
- Harbour A: 3 far visuals (quay, tyre, fence); sparse but renders. The full
  harbour vista lives in sibling animation scenes and is not composed yet.

## Generic loader

The engine now loads `scene/<BRUCELEE_SCENE>/far` and
`scene/<BRUCELEE_SCENE>/near` for any variant. There is no per-scene camera:
`_native_camera_pose` is shared, matching `CBeatEmUpCamera::Update`.

## Available original content

Full `data.zpak` report: 2144 resources, 70 `.scene`, 10
`*_FarObjects.scene`, and 5 character skeletons (Bruce, Brick, Master,
SinFu, Ken). Square B was extracted and converted to 11 GLBs / 9 PNGs, but its
camera still sits inside the roof; it is not shipped yet.

## Not working

- Square B: extracted/converted but not visually usable yet.
- `TIME_IS_UP`: attempted, unverified, reverted.
- Brick brutal: candidate retarget only; see P1_ASSET_BLOCKERS.

## Runtime entry points

- `DragonWarrior.cmd`: main menu with Temple Yard A behind it
- `DragonWarrior_TempleYardB.cmd`: main menu with Temple Yard B behind it
- `DragonWarrior_A_Direct.cmd`: Temple Yard A fight directly
- `DragonWarrior_B_Direct.cmd`: Temple Yard B fight directly
- `DragonWarrior_HallA_Direct.cmd`: Tournament Hall A directly
- Main menu `TEMPLE YARD A/B`: reload into the selected arena
