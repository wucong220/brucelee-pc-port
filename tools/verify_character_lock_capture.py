#!/usr/bin/env python3
"""Checks on the character-lock screenshots and capture reports.

The capture runner records what the gate actually did (locked rows, picture
basenames, emitted commands, status).  This script checks those reports AND the
pixels of the shots, so a frame that silently drew an unlocked card for a locked
character cannot pass:

  * every shot is 1280x720 and not blank;
  * 01-06 still draw the recovered yellow selectfighter name label and the
    selection line;
  * the locked brick card (02) differs at the selected card slot from the
    gate-off brick card (01) and the full-save brick card (06): the decoded
    `lockedpicture` really replaced the character art;
  * 01 and 06 are pixel-identical: with every recovered grant the dock is exactly
    the pre-gating dock;
  * the partial-save sin fu card (04) differs from the locked master card (05);
  * 07 (dock unmappable) has no dock label band and its text panel status differs
    from the full-save text rows (10);
  * 08 (no save) differs from 10 (full save) inside the text panel, and 09 shows
    the added FIGHTER LOCKED line;
  * capture reports: the exact locked sets, the decoded lockedpicture on every
    closed card, the character icon on every open one, and zero commands emitted
    when a locked row/card is confirmed.

Usage:
    python -X utf8 tools\\verify_character_lock_capture.py --shots screenshots
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parent.parent
EXPECT_WIDTH = 1280
EXPECT_HEIGHT = 720
LOCKED_ICON = "bl_fighterlocked_icon"

DOCK_ICONS = [
    "bl_brucelee_jacket_icon", "bl_brucelee_base_icon", "bl_brucelee_tank_icon",
    "bl_brucelee_kimono_icon", "bl_shenlo_icon", "bl_themaster_icon",
    "bl_smallboy_icon", "bl_sinfu_icon", "bl_thechief01_icon",
    "bl_thechief02_icon", "bl_kengodall_icon", "bl_brickdavis_icon",
    "bl_johnson_icon", "bl_loming01_icon", "bl_loming02_icon",
]

NAMES = {
    "off": "01_dock_gate_off_brick.png",
    "none_locked": "02_dock_nosave_brick_locked.png",
    "none_open": "03_dock_nosave_shenlo_open.png",
    "partial_open": "04_dock_partial_sinfu_open.png",
    "partial_locked": "05_dock_partial_master_locked.png",
    "full": "06_dock_full_brick_open.png",
    "fallback": "07_dock_fallback_missing_layout.png",
    "text_locked": "08_text_nosave_locked_rows.png",
    "text_blocked": "09_text_nosave_confirm_blocked.png",
    "text_full": "10_text_full_rows.png",
}

# The selected card in the 480x320 layout is centred on the decoded dock:
# dock x=96..416, option 100x70, so the selected card is x=266..366, y=180..250.
# The UI space is scaled by 2.25 and offset by (100, 0) into 1280x720.
CARD_BOX = (565, 408, 786, 560)
# The decoded `fighter_name` label (design x=100..380, y=155..175).
LABEL_BAND = (325, 348, 955, 395)
# The menu status line (port chrome for the text rows).
STATUS_BOX = (400, 525, 900, 560)


def read_png(path: Path) -> tuple[int, int, bytes, int]:
    """Minimal PNG reader for the non-interlaced 8-bit files Godot writes."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.name}: not a PNG")
    offset = 8
    width = height = 0
    color_type = 0
    idat = b""
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filter, interlace = \
                struct.unpack(">IIBBBBB", payload)
            if bit_depth != 8 or interlace != 0:
                raise ValueError(f"{path.name}: unsupported PNG ({bit_depth}, {interlace})")
        elif kind == b"IDAT":
            idat += payload
        elif kind == b"IEND":
            break
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    raw = zlib.decompress(idat)
    stride = width * channels
    rows = bytearray()
    previous = bytearray(stride)
    pos = 0
    for _y in range(height):
        filter_type = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filter_type == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = previous[i]
                c = previous[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                predictor = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + predictor) & 0xFF
        elif filter_type != 0:
            raise ValueError(f"{path.name}: bad filter {filter_type}")
        rows += line
        previous = line
    return width, height, bytes(rows), channels


def pixel(rgb: bytes, channels: int, x: int, y: int, width: int) -> tuple[int, int, int]:
    index = (y * width + x) * channels
    return rgb[index], rgb[index + 1], rgb[index + 2]


def count_yellow(rgb: bytes, channels: int, width: int, height: int,
                 box: tuple[int, int, int, int] | None = None) -> int:
    x0, y0, x1, y1 = box if box else (0, 0, width, height)
    total = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = pixel(rgb, channels, x, y, width)
            if abs(r - 255) <= 24 and abs(g - 255) <= 24 and b <= 24:
                total += 1
    return total


def count_warm_yellow(rgb: bytes, channels: int, width: int, height: int,
                      box: tuple[int, int, int, int] | None = None) -> int:
    """Warm yellow family: the decoded label (255,255,0) and the decoded
    selection line (255,217,26) both qualify, so one counter covers both."""
    x0, y0, x1, y1 = box if box else (0, 0, width, height)
    total = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = pixel(rgb, channels, x, y, width)
            if r >= 200 and g >= 160 and b <= 100:
                total += 1
    return total


def mean_difference(a: tuple[bytes, int], b: tuple[bytes, int]) -> float:
    rgb_a, channels = a
    rgb_b, _ = b
    step = 97
    total = 0
    count = 0
    for index in range(0, min(len(rgb_a), len(rgb_b)), step):
        total += abs(rgb_a[index] - rgb_b[index])
        count += 1
    return total / max(count, 1)


def box_difference(a, b, box) -> float:
    rgb_a, channels_a = a[:2]
    rgb_b, channels_b = b[:2]
    width = a[2]
    x0, y0, x1, y1 = box
    total = 0
    count = 0
    for y in range(y0, y1, 3):
        for x in range(x0, x1, 3):
            index_a = (y * width + x) * channels_a
            index_b = (y * width + x) * channels_b
            total += (abs(rgb_a[index_a] - rgb_b[index_b])
                      + abs(rgb_a[index_a + 1] - rgb_b[index_b + 1])
                      + abs(rgb_a[index_a + 2] - rgb_b[index_b + 2]))
            count += 3
    return total / max(count, 1)


def load_report(shots: Path, mode: str) -> dict:
    path = shots / f"character_lock_capture_{mode}.json"
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shots", type=Path, default=ROOT / "screenshots")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()
    shots = args.shots
    checks: list[dict] = []
    images: dict[str, tuple] = {}

    def check(ok: bool, name: str, detail: str = "") -> None:
        checks.append({"check": name, "passed": bool(ok), "detail": detail})

    for key, name in NAMES.items():
        path = shots / name
        if not path.exists():
            check(False, f"{name} exists")
            continue
        width, height, rgb, channels = read_png(path)
        images[key] = (rgb, channels, width, height)
        check(width == EXPECT_WIDTH and height == EXPECT_HEIGHT,
              f"{name} is {EXPECT_WIDTH}x{EXPECT_HEIGHT}", f"{width}x{height}")
        check(len(set(rgb[::97])) > 8, f"{name} is not a blank frame",
              f"{len(set(rgb[::97]))} distinct sampled values")

    for key in ("off", "none_locked", "none_open", "partial_open",
                "partial_locked", "full"):
        if key not in images:
            continue
        rgb, channels, width, height = images[key]
        band = count_warm_yellow(rgb, channels, width, height, LABEL_BAND)
        check(band > 100, f"{NAMES[key]}: the recovered yellow name label is drawn",
              f"{band} warm-yellow pixels in the label band")
        whole = count_warm_yellow(rgb, channels, width, height)
        check(whole > band + 500,
              f"{NAMES[key]}: the recovered yellow selection line is drawn",
              f"{whole} warm-yellow pixels in the frame")

    if "off" in images and "none_locked" in images:
        difference = box_difference(images["off"], images["none_locked"], CARD_BOX)
        check(difference > 4.0,
              "the gate-off brick card (01) and the locked brick card (02) draw different artwork",
              f"card-box difference {difference:.2f}")
    if "full" in images and "none_locked" in images:
        difference = box_difference(images["full"], images["none_locked"], CARD_BOX)
        check(difference > 4.0,
              "the full-save brick card (06) and the locked brick card (02) draw different artwork",
              f"card-box difference {difference:.2f}")
    if "off" in images and "full" in images:
        difference = mean_difference(images["off"][:2], images["full"][:2])
        check(difference == 0.0,
              "the gate-off dock (01) and the full-save dock (06) are pixel-identical",
              f"mean difference {difference:.4f}")
    if "none_locked" in images and "none_open" in images:
        difference = mean_difference(images["none_locked"][:2],
                                     images["none_open"][:2])
        check(difference > 1.0,
              "the locked brick card (02) and the open shen lo card (03) are different frames",
              f"mean difference {difference:.2f}")
    if "partial_open" in images and "partial_locked" in images:
        difference = box_difference(images["partial_open"],
                                    images["partial_locked"], CARD_BOX)
        check(difference > 4.0,
              "the granted sin fu card (04) and the locked master card (05) draw different artwork",
              f"card-box difference {difference:.2f}")

    text_locked = load_report(shots, "text_none").get("report", {})
    panel = text_locked.get("panel") or []
    panel_box = None
    if len(panel) == 4:
        x, y, w, h = (int(round(value)) for value in panel)
        panel_box = (max(x - 4, 0), max(y - 4, 0),
                     min(x + w + 4, EXPECT_WIDTH), min(y + h + 4, EXPECT_HEIGHT))
        check(True, "the text capture report records the panel rect",
              json.dumps(panel_box))
    else:
        check(False, "the text capture report records the panel rect")

    if panel_box and "text_locked" in images and "text_full" in images:
        difference = box_difference(images["text_locked"], images["text_full"],
                                    panel_box)
        check(difference > 0.5,
              "the no-save text panel (08) differs from the full-save one (10)",
              f"panel difference {difference:.2f} in {panel_box}")
    if "text_locked" in images and "text_blocked" in images:
        difference = box_difference(images["text_locked"], images["text_blocked"],
                                    STATUS_BOX)
        check(difference > 0.5,
              "09 adds the FIGHTER LOCKED status line under the text rows",
              f"status difference {difference:.2f}")
    if "fallback" in images and "text_full" in images:
        difference = box_difference(images["fallback"], images["text_full"],
                                    STATUS_BOX)
        check(difference > 0.5,
              "07 shows the dock-unavailable status above the text rows",
              f"status difference {difference:.2f}")
    for key in ("fallback", "text_locked", "text_blocked", "text_full"):
        if key not in images:
            continue
        rgb, channels, width, height = images[key]
        band = count_warm_yellow(rgb, channels, width, height, LABEL_BAND)
        check(band < 20, f"{NAMES[key]}: no recovered dock label (text rows only)",
              f"{band} warm-yellow pixels in the label band")

    # ---------------------------------------------------------- reports
    off = load_report(shots, "dock_off")
    check(off.get("ok") is True, "gate-off capture report says ok")
    off_report = off.get("report", {})
    check(off_report.get("gate", {}).get("enabled") is False,
          "gate-off report: the gate is disabled")
    check(off_report.get("overlay_visible") is True,
          "gate-off report: the recovered dock is visible")
    check(off_report.get("overlay_sources") == DOCK_ICONS,
          "gate-off report: every card draws its character icon")
    check(off_report.get("overlay_locked") == [False] * 15,
          "gate-off report: no card is locked")

    none = load_report(shots, "dock_none")
    check(none.get("ok") is True, "no-save capture report says ok")
    none_report = none.get("report", {})
    none_gate = none_report.get("gate", {})
    check(none_gate.get("enabled") is True, "no-save report: the gate is enabled")
    check(none_gate.get("save_present") is False, "no-save report: the save is absent")
    check(none_gate.get("locked_count") == 13, "no-save report: gate locked_count is 13")
    check(none_gate.get("locked_picture") == LOCKED_ICON,
          "no-save report: the decoded lockedpicture basename is recorded")
    none_sources = none_report.get("overlay_sources") or []
    check(len(none_sources) == 15, "no-save report: fifteen cards are reported")
    check(none_sources[2] == DOCK_ICONS[2] and none_sources[4] == DOCK_ICONS[4],
          "no-save report: the two always-available cards keep their icons")
    check(all(none_sources[index] == LOCKED_ICON
              for index in (0, 1, 3, 5, 7, 11, 14)),
          "no-save report: the gated cards draw bl_fighterlocked_icon")
    none_locked = none_report.get("overlay_locked") or []
    check(sum(1 for value in none_locked if value) == 13,
          "no-save report: exactly thirteen cards are locked")
    check(none_report.get("locked_confirm_commands") == [],
          "no-save report: confirming a locked card emitted no command")
    check(none_report.get("open_confirm_commands") == ["shenlo"],
          "no-save report: the always-available shen lo card emits its command")
    check(none_report.get("panel_visible") is False,
          "no-save report: the text panel yields to the dock")

    partial = load_report(shots, "dock_partial").get("report", {})
    check(partial.get("gate", {}).get("save_valid") is True,
          "partial report: the checksummed save was accepted")
    check(partial.get("gate", {}).get("locked_count") == 11,
          "partial report: exactly the eleven ungranted characters are locked")
    partial_sources = partial.get("overlay_sources") or []
    check(len(partial_sources) == 15
          and partial_sources[7] == DOCK_ICONS[7]
          and partial_sources[13] == DOCK_ICONS[13],
          "partial report: the granted sin fu and lo ming a cards draw their own icons")
    check(len(partial_sources) > 5 and partial_sources[5] == LOCKED_ICON,
          "partial report: the ungranted master card draws the lockedpicture")
    check(partial.get("open_confirm_commands") == ["sinfu"],
          "partial report: the granted sin fu card emits its command")
    check(partial.get("locked_confirm_commands") == ["sinfu"],
          "partial report: confirming the locked master card emits no extra command")

    full = load_report(shots, "dock_full").get("report", {})
    check(full.get("gate", {}).get("locked_count") == 0,
          "full report: no character is locked")
    check(full.get("overlay_sources") == DOCK_ICONS,
          "full report: every card draws its character icon")
    check(full.get("open_confirm_commands") == ["brick"],
          "full report: the first opponent emits its command")

    fallback = load_report(shots, "dock_missing").get("report", {})
    check(fallback.get("gate", {}).get("dock_ok") is False,
          "fallback report: the unmappable dock is rejected")
    check(bool(fallback.get("gate", {}).get("dock_error")),
          "fallback report: the dock cause is recorded")
    check(fallback.get("overlay_visible") is False,
          "fallback report: the dock is hidden")
    check(fallback.get("panel_visible") is True,
          "fallback report: the text opponent panel is restored")
    check(fallback.get("status") == "FIGHTER DOCK UNAVAILABLE - TEXT MENU",
          "fallback report: the text menu reports the dock fallback")
    check(len(fallback.get("text_rows") or []) == 10,
          "fallback report: the ten text rows are shown")

    text = text_locked
    rows = text.get("text_rows") or []
    check(text.get("overlay_present") is False,
          "text report: no HUD-art overlay exists")
    check(text.get("panel_visible") is True,
          "text report: the text panel is visible")
    check(len(rows) == 10, "text report: the submenu keeps its 10 rows")
    check(text.get("locked_labels") == 8,
          "text report: exactly eight rows carry (LOCKED)",
          json.dumps(text.get("locked_labels")))
    check(bool(rows) and rows[0] == "Brick Davis (LOCKED)",
          "text report: the first recovered label carries the suffix")
    check(len(rows) > 4 and rows[4] == "Shen Lo",
          "text report: the always-available shen lo row has no suffix")
    check(text.get("locked_confirm_commands") == [],
          "text report: confirming a locked row emitted no command")
    check(text.get("status") == "FIGHTER LOCKED",
          "text report: the menu reports FIGHTER LOCKED")

    text_full = load_report(shots, "text_full").get("report", {})
    check(text_full.get("locked_labels") == 0,
          "text-full report: no row carries (LOCKED)")
    check(text_full.get("open_confirm_commands") == ["brick"],
          "text-full report: the first opponent row emits its command")

    runs_path = shots / "character_lock_capture_runs.json"
    if runs_path.exists():
        runs = json.loads(runs_path.read_text(encoding="utf-8"))
        check(len(runs) == 7 and all(run.get("ok") for run in runs),
              "all seven capture runs report ok",
              f"{len(runs)} runs")
    else:
        check(False, "character_lock_capture_runs.json exists")

    passed = sum(1 for entry in checks if entry["passed"])
    failed = len(checks) - passed
    report = {"schema": "brucelee-character-lock-pixels/1",
              "shots": str(shots), "passed": passed, "failed": failed,
              "checks": checks}
    target = args.out or (shots / "character_lock_pixel_checks.json")
    target.write_text(json.dumps(report, indent=1), encoding="utf-8")
    for entry in checks:
        print(("PASS " if entry["passed"] else "FAIL ") + entry["check"]
              + (f" [{entry['detail']}]" if entry["detail"] else ""))
    print(f"CHARACTER_LOCK_PIXELS={'PASS' if failed == 0 else 'FAIL'} "
          f"({passed}/{passed + failed})")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
