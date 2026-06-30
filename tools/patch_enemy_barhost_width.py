#!/usr/bin/env python3
"""Set BarHost width in *_enemy.tscn from matching .tres health_bar_width."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PAIRS = [
    ("enemies/bat/bat_enemy.tscn", "enemies/bat/bat_enemy.tres"),
    ("enemies/rat/rat_enemy.tscn", "enemies/rat/rat_enemy.tres"),
    ("enemies/crab/crab_enemy.tscn", "enemies/crab/crab_enemy.tres"),
    ("enemies/spider/spider_enemy.tscn", "enemies/spider/spider_enemy.tres"),
    ("enemies/mimic/mimic_enemy.tscn", "enemies/mimic/mimic_enemy.tres"),
    ("enemies/bone_chewer/bone_chewer_enemy.tscn", "enemies/bone_chewer/bone_chewer_enemy.tres"),
    ("enemies/pilgrim/pilgrim_enemy.tscn", "enemies/pilgrim/pilgrim_enemy.tres"),
    ("enemies/igneous_burster/igneous_burster_enemy.tscn", "enemies/igneous_burster/igneous_burster_enemy.tres"),
    ("enemies/little_skelton/little_skelton_enemy.tscn", "enemies/little_skelton/little_skelton_enemy.tres"),
    ("enemies/shell_mech/shell_mech_enemy.tscn", "enemies/shell_mech/shell_mech_enemy.tres"),
    ("enemies/ghost_summoner/ghost_summoner_enemy.tscn", "enemies/ghost_summoner/ghost_summoner.tres"),
    ("enemies/ghost_summoner/spook_enemy.tscn", "enemies/ghost_summoner/spook.tres"),
    ("enemies/evil_spirit/evil_spirit_enemy.tscn", "enemies/evil_spirit/evil_spirit.tres"),
    ("enemies/heaven_guardian/heaven_guardian_enemy.tscn", "enemies/heaven_guardian/heaven_guardian.tres"),
    ("enemies/shadow_samurai/shadow_samurai_enemy.tscn", "enemies/shadow_samurai/shadow_samurai.tres"),
    ("enemies/water_monster/water_monster_enemy.tscn", "enemies/water_monster/water_monster.tres"),
]

HBW_RE = re.compile(r"health_bar_width = (\d+)")
BARHOST_BLOCK = re.compile(
    r"\n\[node name=\"BarHost\" parent=\"StatusBar/HealthRow\" index=\"0\"\]\ncustom_minimum_size = Vector2\([^\)]+\)\n"
)


def patch_tscn(tscn_path: Path, width: int) -> None:
    text = tscn_path.read_text(encoding="utf-8")
    block = f'\n[node name="BarHost" parent="StatusBar/HealthRow" index="0"]\ncustom_minimum_size = Vector2({width}, 10)\n'
    if BARHOST_BLOCK.search(text):
        text = BARHOST_BLOCK.sub(block, text)
    elif '[node name="BarHost" parent="StatusBar/HealthRow"' in text:
        text = re.sub(
            r'(\[node name="BarHost" parent="StatusBar/HealthRow"[^\]]*\]\n)custom_minimum_size = Vector2\([^\)]+\)',
            rf'\1custom_minimum_size = Vector2({width}, 10)',
            text,
        )
    else:
        marker = '[node name="StatusBar"'
        idx = text.find(marker)
        if idx < 0:
            return
        end = text.find("\n\n", idx)
        if end < 0:
            end = len(text)
        text = text[:end] + block + text[end:]
    tscn_path.write_text(text, encoding="utf-8")


def main() -> None:
    for tscn_rel, tres_rel in PAIRS:
        tres = (ROOT / tres_rel).read_text(encoding="utf-8")
        m = HBW_RE.search(tres)
        if not m:
            print(f"skip {tscn_rel}: no health_bar_width")
            continue
        patch_tscn(ROOT / tscn_rel, int(m.group(1)))
        print(f"OK {tscn_rel} -> {m.group(1)}px")


if __name__ == "__main__":
    main()
