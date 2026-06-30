#!/usr/bin/env python3
"""Replace enemy_scene ExtResource with enemy_scene_path string in all enemy tres."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SCENE_PATHS = {
    "enemies/bat/bat_enemy.tres": "res://enemies/bat/bat_enemy.tscn",
    "enemies/rat/rat_enemy.tres": "res://enemies/rat/rat_enemy.tscn",
    "enemies/crab/crab_enemy.tres": "res://enemies/crab/crab_enemy.tscn",
    "enemies/spider/spider_enemy.tres": "res://enemies/spider/spider_enemy.tscn",
    "enemies/mimic/mimic_enemy.tres": "res://enemies/mimic/mimic_enemy.tscn",
    "enemies/bone_chewer/bone_chewer_enemy.tres": "res://enemies/bone_chewer/bone_chewer_enemy.tscn",
    "enemies/pilgrim/pilgrim_enemy.tres": "res://enemies/pilgrim/pilgrim_enemy.tscn",
    "enemies/igneous_burster/igneous_burster_enemy.tres": "res://enemies/igneous_burster/igneous_burster_enemy.tscn",
    "enemies/little_skelton/little_skelton_enemy.tres": "res://enemies/little_skelton/little_skelton_enemy.tscn",
    "enemies/shell_mech/shell_mech_enemy.tres": "res://enemies/shell_mech/shell_mech_enemy.tscn",
    "enemies/ghost_summoner/ghost_summoner.tres": "res://enemies/ghost_summoner/ghost_summoner_enemy.tscn",
    "enemies/ghost_summoner/spook.tres": "res://enemies/ghost_summoner/spook_enemy.tscn",
    "enemies/evil_spirit/evil_spirit.tres": "res://enemies/evil_spirit/evil_spirit_enemy.tscn",
    "enemies/heaven_guardian/heaven_guardian.tres": "res://enemies/heaven_guardian/heaven_guardian_enemy.tscn",
    "enemies/shadow_samurai/shadow_samurai.tres": "res://enemies/shadow_samurai/shadow_samurai_enemy.tscn",
    "enemies/water_monster/water_monster.tres": "res://enemies/water_monster/water_monster_enemy.tscn",
}


def fix_tres(path: Path, scene_path: str) -> None:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r'\[ext_resource type="PackedScene" path="[^"]+" id="99_scene"\]\n', "", text)
    text = re.sub(r"enemy_scene = ExtResource\(\"99_scene\"\)\n", "", text)
    if "enemy_scene_path" not in text:
        text = text.replace(
            "uses_scene_ui_layout = true\n",
            f'uses_scene_ui_layout = true\nenemy_scene_path = "{scene_path}"\n',
            1,
        )
    else:
        text = re.sub(
            r'enemy_scene_path = "[^"]*"',
            f'enemy_scene_path = "{scene_path}"',
            text,
        )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    for rel, scene in SCENE_PATHS.items():
        fix_tres(ROOT / rel, scene)
        print(f"Fixed {rel}")


if __name__ == "__main__":
    main()
