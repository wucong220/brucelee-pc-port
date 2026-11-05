extends RefCounted
class_name PortDockCursor
## Recovered locked-card cursor rule for the Bruce Lee dock.
##
## Recovered from the local ARM binary (`libdefault.so`, sha256
## 1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70) with Ghidra
## 12.2 (image base 0x00010000):
##
##   * `krm::CBruceLeeDock::SetLocked(unsigned int index, bool locked)`
##     @ 0x0021100c — writes the locked bool into the dock's per-option validity
##     vector at `*(this+0x114) + *(this+0x118)*index`.
##   * `krm::CBruceLeeDock::OnKeyPress(EKeyCode)` @ 0x00211e14 — for LEFT (0x0e)
##     and RIGHT (0x0f) it steps one option in that direction, clamps at the ends
##     when the dock is not wrap-around (`wraparround=false` in selectfighter.ui /
##     selectscenery.ui), and **repeats while the option's validity byte is
##     non-zero**, i.e. it SKIPS locked options.  If no unlocked option exists in
##     that direction (it reaches the boundary) it restores the previous
##     selection and stops.
##   * `krm::CBruceLeeDock::ChangeSelectedOption()` @ 0x00211950 — fires the
##     change action only when the landed option's validity byte is 0 (unlocked).
##
## This module reproduces exactly that rule.  It does NOT invent a wrap-around or
## any other cursor policy: `wraparround=false` is the decoded UI value and the
## skip is the decompiled loop.  No credit to this file is needed for the credits
## screen (see evidence/credits_scroll.json).

const NOT_RECOVERED := "NOT RECOVERED"
const RULE := "CBruceLeeDock::OnKeyPress skips SetLocked indices; clamps at ends (wraparround=false); restores selection when no unlocked option remains in the move direction"


## Resolve one LEFT/RIGHT step.  `locked[i]` is true for a locked card.
## Returns {index, moved, skipped, stale_restore, rule}.
static func move(current: int, step: int, count: int, locked: Array) -> Dictionary:
	if count <= 0:
		return {"index": current, "moved": false, "skipped": 0,
				"stale_restore": false, "rule": RULE}
	var direction: int = 1 if step > 0 else -1
	var walk: int = current
	var skipped: int = 0
	while true:
		var candidate: int = walk + direction
		if candidate < 0 or candidate >= count:
			# Reached the boundary; the original restores the pre-move selection.
			return {"index": current, "moved": false, "skipped": skipped,
					"stale_restore": skipped > 0, "rule": RULE}
		walk = candidate
		var is_locked: bool = candidate < locked.size() and bool(locked[candidate])
		if not is_locked:
			return {"index": walk, "moved": walk != current, "skipped": skipped,
					"stale_restore": false, "rule": RULE}
		skipped += 1
	# Unreachable: the loop returns at the boundary or an unlocked option.
	return {"index": current, "moved": false, "skipped": skipped,
			"stale_restore": true, "rule": RULE}


## True when `step` is LEFT or RIGHT per the recovered key codes (0x0e / 0x0f).
static func is_horizontal_key(key_code: int) -> bool:
	return key_code == 0x0e or key_code == 0x0f
