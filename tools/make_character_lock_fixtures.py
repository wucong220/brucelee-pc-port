#!/usr/bin/env python3
"""Build the progress-save / unlock-table fixtures used by the character gate test.

The gate is the part under test, so its inputs are produced here, outside Godot:

  * five checksummed `progress_save.json` envelopes (empty / partial / full /
    EXP-only) plus a corrupted one and one carrying an out-of-range id, all in
    the recovered save schema.  The checksums are `sha256(payload_json)` exactly
    like `SaveManager.save_state`;
  * unlock-table variants derived from the real decoded table: the story-event
    fighter row for character 5 (the master) removed, and one with no fighter
    rows at all.  These prove the `unknown_character_id` fail-closed path without
    editing the tracked data;
  * decoded story-table variants: no characters table, and a characters table
    without the decoded `unlock_item_names.fighter` index;
  * a decoded menu-art variant with no `fighters` table, so the dock cannot map
    its items to characters.

Every fixture is written under --out; nothing inside the project is modified.

Usage:
    python -X utf8 tools/make_character_lock_fixtures.py --out evidence/fixtures
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNLOCKS = ROOT / "godot" / "data" / "progress" / "unlocks.json"
STORY = ROOT / "godot" / "data" / "story" / "story_mode.json"
SCHEMA = "dragonwarrior-progress/1"

# Character item ids that are gated by a story-EXP threshold (decoded from
# unlocks.list: item_type == "fighter" in story_unlocks).
EXP_FIGHTERS = (0, 1, 9, 14)
# Character item ids gated by a completed story event (item_type == "fighter" in
# story_event_unlocks).
EVENT_FIGHTERS = (3, 5, 6, 7, 8, 10, 11, 12, 13)
# The two characters the decoded data marks always_available.
ALWAYS_AVAILABLE = ("bruce lee c", "shen lo")


def load_unlock_rows() -> dict[int, dict]:
    """Map character item id -> its recovered unlock row (both grant kinds)."""
    unlocks = json.loads(UNLOCKS.read_text(encoding="utf-8"))
    rows: dict[int, dict] = {}
    for row in unlocks["story_unlocks"]:
        if row.get("item_type") == "fighter":
            rows[int(row["item_id"])] = {"id": int(row["id"]), "source": "story_exp",
                                         "exp": int(row["exp"])}
    for row in unlocks["story_event_unlocks"]:
        if row.get("item_type") == "fighter":
            rows[int(row["item_id"])] = {"id": int(row["id"]), "source": "story_event",
                                         "chapter": row["chapter"],
                                         "event": row.get("event_maptitle", "")}
    return rows


def payload(*, exp: int = 0, character_items: tuple[int, ...] = (),
            extra_ids: tuple[int, ...] = (), rows: dict[int, dict] | None = None) -> dict:
    rows = rows if rows is not None else load_unlock_rows()
    events = []
    ids = []
    for item in character_items:
        row = rows[item]
        ids.append(row["id"])
        if row["source"] == "story_event":
            events.append(f"{row['chapter']}/{row['event']}")
    events.sort()
    ids = sorted(ids + list(extra_ids))
    return {
        "schema": SCHEMA,
        "version": 1,
        "story": {
            "exp": exp,
            "events_completed": events,
            "chapters_completed": [],
            "completed_difficulties": [],
        },
        "unlocks": {
            "unlocked_ids": ids,
            "sources": {str(rows[item]["id"]): rows[item]["source"]
                        for item in character_items},
        },
        "achievements": {"reached": []},
        "counters": {},
        "mode_clears": {
            "arcade": {"easy": False, "medium": False, "hard": False},
            "time_attack": {"easy": False, "medium": False, "hard": False},
        },
    }


def envelope(state: dict, checksum: str | None = None) -> dict:
    payload_json = json.dumps(state, sort_keys=True, separators=(",", ":"))
    return {
        "schema": SCHEMA,
        "version": 1,
        "saved_utc": "2026-11-04T00:00:00",
        "checksum": checksum if checksum is not None else hashlib.sha256(
            payload_json.encode("utf-8")).hexdigest(),
        "payload_json": payload_json,
    }


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "evidence" / "fixtures")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    rows = load_unlock_rows()
    saved = sorted(rows)
    partial = (7, 13)  # sin fu and lo ming a
    assert set(saved) == set(EXP_FIGHTERS) | set(EVENT_FIGHTERS), saved
    assert all(rows[item]["source"] == "story_exp" for item in EXP_FIGHTERS)
    assert all(rows[item]["source"] == "story_event" for item in EVENT_FIGHTERS)

    saves = {
        # A valid save with nothing unlocked (the state a fresh progress run
        # writes): the thirteen gated characters stay closed, the two
        # always-available ones stay open.
        "save_empty.json": envelope(payload()),
        # Only sin fu (item 7) and lo ming a (item 13) granted.
        "save_partial.json": envelope(payload(character_items=partial)),
        # Every recovered fighter grant.
        "save_full.json": envelope(payload(character_items=tuple(saved))),
        # MAX story EXP but no unlocked id: proves the gate reads the recorded
        # grants, not an EXP re-computation.
        "save_exp_only.json": envelope(payload(exp=20000)),
        # Corrupt checksum: SaveManager must reject it and the gate must close.
        "save_corrupt.json": envelope(
            payload(character_items=tuple(saved)), checksum="0" * 64),
        # A save carrying an id outside the recovered 0..116 id space: the id
        # grants nothing and is surfaced, while the valid grants still apply.
        "save_unknown_id.json": envelope(
            payload(character_items=tuple(saved), extra_ids=(500,))),
    }
    for name, data in saves.items():
        write_json(args.out / name, data)

    unlocks = json.loads(UNLOCKS.read_text(encoding="utf-8"))
    event_rows = unlocks["story_event_unlocks"]
    missing_master = [
        row for row in event_rows
        if not (row.get("item_type") == "fighter" and int(row.get("item_id", -1)) == 5)]
    write_json(args.out / "unlocks_missing_fighter_5.json",
               {"num_ids": unlocks["num_ids"],
                "story_unlocks": unlocks["story_unlocks"],
                "story_event_unlocks": missing_master})
    write_json(args.out / "unlocks_no_fighter.json",
               {"num_ids": unlocks["num_ids"],
                "story_unlocks": [row for row in unlocks["story_unlocks"]
                                  if row.get("item_type") != "fighter"],
                "story_event_unlocks": [row for row in event_rows
                                        if row.get("item_type") != "fighter"]})

    story = json.loads(STORY.read_text(encoding="utf-8"))
    tables = story.get("tables", {})
    # No characters table at all: the gate cannot build a row, so the
    # always_available exception cannot be proven either (everything closes).
    write_json(args.out / "story_missing_characters.json",
               {"schema": story.get("schema", "brucelee-story-mode/1"), "tables": {}})
    # Characters table present, decoded unlock name index missing: the gate
    # cannot match a row to its unlock item id by name and closes everything.
    write_json(args.out / "story_missing_fighter_names.json",
               {"schema": story.get("schema", "brucelee-story-mode/1"),
                "tables": {"characters": tables.get("characters", []),
                           "unlock_item_names": {}}})
    # Menu-art decode without the fighters table: the dock items cannot be
    # resolved to characters, so the gate refuses to trust the dock.
    write_json(args.out / "menu_art_no_fighters.json",
               {"schema": "brucelee-menu-art/1", "fighters": []})

    summary = {
        "saves": sorted(saves),
        "save_partial_character_items": list(partial),
        "save_partial_unlock_ids": sorted(rows[item]["id"] for item in partial),
        "save_full_unlock_ids": sorted(rows[item]["id"] for item in saved),
        "always_available": list(ALWAYS_AVAILABLE),
        "fighter_grants": {str(item): rows[item] for item in sorted(rows)},
        "unlocks_missing_fighter_5_rows": len(missing_master),
        "story_missing_characters_tables": 0,
    }
    write_json(args.out / "character_lock_fixtures.json", summary)
    print("CHARACTER_LOCK_FIXTURES=" + json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
