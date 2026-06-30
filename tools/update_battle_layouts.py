#!/usr/bin/env python3
"""Update battles/*.tscn to use per-enemy scenes instead of enemy.tscn + stats."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BATTLES = ROOT / "battles"

TRES_TO_SCENE = {
    "res://enemies/bat/bat_enemy.tres": "res://enemies/bat/bat_enemy.tscn",
    "res://enemies/rat/rat_enemy.tres": "res://enemies/rat/rat_enemy.tscn",
    "res://enemies/crab/crab_enemy.tres": "res://enemies/crab/crab_enemy.tscn",
    "res://enemies/spider/spider_enemy.tres": "res://enemies/spider/spider_enemy.tscn",
    "res://enemies/mimic/mimic_enemy.tres": "res://enemies/mimic/mimic_enemy.tscn",
    "res://enemies/bone_chewer/bone_chewer_enemy.tres": "res://enemies/bone_chewer/bone_chewer_enemy.tscn",
    "res://enemies/pilgrim/pilgrim_enemy.tres": "res://enemies/pilgrim/pilgrim_enemy.tscn",
    "res://enemies/igneous_burster/igneous_burster_enemy.tres": "res://enemies/igneous_burster/igneous_burster_enemy.tscn",
    "res://enemies/little_skelton/little_skelton_enemy.tres": "res://enemies/little_skelton/little_skelton_enemy.tscn",
    "res://enemies/shell_mech/shell_mech_enemy.tres": "res://enemies/shell_mech/shell_mech_enemy.tscn",
    "res://enemies/ghost_summoner/ghost_summoner.tres": "res://enemies/ghost_summoner/ghost_summoner_enemy.tscn",
    "res://enemies/ghost_summoner/spook.tres": "res://enemies/ghost_summoner/spook_enemy.tscn",
    "res://enemies/evil_spirit/evil_spirit.tres": "res://enemies/evil_spirit/evil_spirit_enemy.tscn",
    "res://enemies/heaven_guardian/heaven_guardian.tres": "res://enemies/heaven_guardian/heaven_guardian_enemy.tscn",
    "res://enemies/shadow_samurai/shadow_samurai.tres": "res://enemies/shadow_samurai/shadow_samurai_enemy.tscn",
    "res://enemies/water_monster/water_monster.tres": "res://enemies/water_monster/water_monster_enemy.tscn",
}

EXT_RE = re.compile(
    r'^\[ext_resource type="(?P<type>[^"]+)"(?:[^]]*) path="(?P<path>[^"]+)" id="(?P<id>[^"]+)"\]',
    re.MULTILINE,
)


def migrate_battle(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "scenes/enemy/enemy.tscn" not in text:
        return False

    ext_by_id: dict[str, tuple[str, str]] = {}
    for m in EXT_RE.finditer(text):
        ext_by_id[m.group("id")] = (m.group("type"), m.group("path"))

    stats_nodes: list[tuple[str, str, str]] = []  # node_block_id, stats_ext_id, tres_path
    for node_m in re.finditer(
        r'\[node name="(?P<name>[^"]+)"(?: parent="[^"]*")?(?: unique_id=\d+)? instance=ExtResource\("(?P<inst>[^"]+)"\)\]\n(?P<body>(?:[^\[]|\[(?!node ))*)',
        text,
    ):
        body = node_m.group("body")
        stats_m = re.search(r'stats = ExtResource\("([^"]+)"\)', body)
        if not stats_m:
            continue
        stats_id = stats_m.group(1)
        if stats_id not in ext_by_id:
            continue
        typ, tres_path = ext_by_id[stats_id]
        if typ != "Resource" or tres_path not in TRES_TO_SCENE:
            continue
        stats_nodes.append((node_m.group(0), stats_id, tres_path))

    if not stats_nodes:
        return False

    new_ext_resources: dict[str, str] = {}
    for _, stats_id, tres_path in stats_nodes:
        scene_path = TRES_TO_SCENE[tres_path]
        new_ext_resources[stats_id] = scene_path

    # Remove generic enemy.tscn ext_resources
    lines = text.splitlines()
    out_lines: list[str] = []
    skip_ids: set[str] = set()
    for _block, stats_id, _ in stats_nodes:
        skip_ids.add(stats_id)

    enemy_scene_ids: set[str] = set()
    for eid, (typ, epath) in ext_by_id.items():
        if typ == "PackedScene" and epath == "res://scenes/enemy/enemy.tscn":
            enemy_scene_ids.add(eid)

    for line in lines:
        m = EXT_RE.match(line)
        if m:
            eid, epath = m.group("id"), m.group("path")
            if epath == "res://scenes/enemy/enemy.tscn":
                continue
            if m.group("type") == "Resource" and epath in TRES_TO_SCENE and eid in new_ext_resources:
                out_lines.append(
                    f'[ext_resource type="PackedScene" path="{new_ext_resources[eid]}" id="{eid}"]'
                )
                continue
        out_lines.append(line)

    text = "\n".join(out_lines)

    for block, stats_id, tres_path in stats_nodes:
        scene_path = TRES_TO_SCENE[tres_path]
        # Replace instance target: stats id now points to PackedScene
        text = text.replace(
            f'instance=ExtResource("{stats_id}")',
            f'instance=ExtResource("{stats_id}")',
        )
        text = re.sub(
            rf'(\[node[^\]]* instance=ExtResource\("{stats_id}"\)\]\n(?:[^\[]|\[(?!node ))*?)stats = ExtResource\("{stats_id}"\)\n',
            r"\1",
            text,
        )

    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    count = 0
    for path in sorted(BATTLES.glob("*.tscn")):
        if migrate_battle(path):
            print(f"Updated {path.name}")
            count += 1
    print(f"Done: {count} files")


if __name__ == "__main__":
    main()
