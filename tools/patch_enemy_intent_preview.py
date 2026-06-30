#!/usr/bin/env python3
"""Add attack intent placeholder slot + editor_preview_action to all enemies."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# (tscn_rel, tres_rel, preview_action, placeholder_label)
ENEMIES = [
    ("enemies/bat/bat_enemy.tscn", "enemies/bat/bat_enemy.tres", "BatAttackAction", "3"),
    ("enemies/rat/rat_enemy.tscn", "enemies/rat/rat_enemy.tres", "RatStrike9", "9"),
    ("enemies/crab/crab_enemy.tscn", "enemies/crab/crab_enemy.tres", "CrabStrike11", "11"),
    ("enemies/spider/spider_enemy.tscn", "enemies/spider/spider_enemy.tres", "SpiderStrike10", "10"),
    ("enemies/mimic/mimic_enemy.tscn", "enemies/mimic/mimic_enemy.tres", "MimicStrike14", "14"),
    ("enemies/bone_chewer/bone_chewer_enemy.tscn", "enemies/bone_chewer/bone_chewer_enemy.tres", "BoneChewerStrike11", "11"),
    ("enemies/pilgrim/pilgrim_enemy.tscn", "enemies/pilgrim/pilgrim_enemy.tres", "PilgrimOpening", ""),
    ("enemies/igneous_burster/igneous_burster_enemy.tscn", "enemies/igneous_burster/igneous_burster_enemy.tres", "Strike7", "7"),
    ("enemies/little_skelton/little_skelton_enemy.tscn", "enemies/little_skelton/little_skelton_enemy.tres", "LittleSkeltonStrike4", "4"),
    ("enemies/shell_mech/shell_mech_enemy.tscn", "enemies/shell_mech/shell_mech_enemy.tres", "Strike21", "21"),
    ("enemies/ghost_summoner/ghost_summoner_enemy.tscn", "enemies/ghost_summoner/ghost_summoner.tres", "Strike5x3", "5"),
    ("enemies/ghost_summoner/spook_enemy.tscn", "enemies/ghost_summoner/spook.tres", "Intent2", "6"),
    ("enemies/evil_spirit/evil_spirit_enemy.tscn", "enemies/evil_spirit/evil_spirit.tres", "Strike20Haunted", "20"),
    ("enemies/heaven_guardian/heaven_guardian_enemy.tscn", "enemies/heaven_guardian/heaven_guardian.tres", "Strike36Strength10", "36"),
    ("enemies/shadow_samurai/shadow_samurai_enemy.tscn", "enemies/shadow_samurai/shadow_samurai.tres", "Strike1x6", "6"),
    ("enemies/water_monster/water_monster_enemy.tscn", "enemies/water_monster/water_monster.tres", "Strike20", "20"),
]

INTENT_SLOT = "res://scenes/ui/intent_slot.tscn"
ATTACK_ICON = "res://art/attack.png"
INTENT_SCRIPT = "res://custom_resources/intent.gd"

SLOT_BLOCK = """
[node name="EditorPreviewIntentSlot" parent="IntentUI" instance=ExtResource("{slot_id}")]
layout_mode = 2

[node name="Icon" parent="IntentUI/EditorPreviewIntentSlot" index="0"]
texture = ExtResource("{attack_id}")

[node name="ValueLabel" parent="IntentUI/EditorPreviewIntentSlot" index="1"]
text = "{label}"
"""


def next_id(text: str) -> str:
    ids = [int(m.group(1)) for m in re.finditer(r'id="(\d+)_', text)]
    return str(max(ids, default=0) + 1)


def patch_tscn(path: Path, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if "EditorPreviewIntentSlot" in text:
        text = re.sub(
            r'\[node name="ValueLabel" parent="IntentUI/EditorPreviewIntentSlot" index="1"\]\ntext = "[^"]*"',
            f'[node name="ValueLabel" parent="IntentUI/EditorPreviewIntentSlot" index="1"]\ntext = "{label}"',
            text,
        )
        path.write_text(text, encoding="utf-8")
        return

    slot_id = next_id(text)
    attack_id = str(int(slot_id) + 1)
    if f'path="{INTENT_SLOT}"' not in text:
        text = text.replace(
            "[sub_resource type=",
            f'[ext_resource type="PackedScene" path="{INTENT_SLOT}" id="{slot_id}_intent_slot"]\n'
            f'[ext_resource type="Texture2D" path="{ATTACK_ICON}" id="{attack_id}_attack"]\n\n[sub_resource type=',
            1,
        )
    else:
        slot_m = re.search(rf'\[ext_resource type="PackedScene" path="{re.escape(INTENT_SLOT)}" id="([^"]+)"\]', text)
        attack_m = re.search(rf'\[ext_resource type="Texture2D" path="{re.escape(ATTACK_ICON)}" id="([^"]+)"\]', text)
        slot_id = slot_m.group(1) if slot_m else f"{next_id(text)}_intent_slot"
        attack_id = attack_m.group(1) if attack_m else f"{next_id(text)}_attack"

    block = SLOT_BLOCK.format(slot_id=slot_id, attack_id=attack_id, label=label)
    intent_m = re.search(r'(\[node name="IntentUI"[^\]]*\][^\[]*)', text, re.DOTALL)
    if not intent_m:
        print(f"skip {path.name}: no IntentUI")
        return
    insert_at = intent_m.end(1)
    text = text[:insert_at] + block + text[insert_at:]
    if "load_steps=" in text.splitlines()[0]:
        text = re.sub(r"load_steps=(\d+)", lambda m: f"load_steps={int(m.group(1)) + 2}", text, count=1)
    path.write_text(text, encoding="utf-8")


def patch_tres(path: Path, action: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if INTENT_SCRIPT not in text:
        intent_id = "99_intent"
        text = text.replace(
            "\n[resource]",
            f'\n[ext_resource type="Script" path="{INTENT_SCRIPT}" id="{intent_id}"]\n\n'
            f'[sub_resource type="Resource" id="Intent_preview_attack"]\n'
            f'script = ExtResource("{intent_id}")\n'
            f"kind = 0\n"
            f'base_text = ""\n\n[resource]',
            1,
        )
    text = re.sub(r"editor_preview_action = &\"[^\"]*\"\n?", "", text)
    text = re.sub(r"editor_preview_intents = [^\n]*\n?", "", text)
    if "display_name" in text:
        text = text.replace(
            "display_name = ",
            f'editor_preview_action = &"{action}"\neditor_preview_intents = Array[ExtResource("99_intent")]([SubResource("Intent_preview_attack")])\ndisplay_name = ',
            1,
        )
    else:
        text = text.replace(
            "[resource]\n",
            f'[resource]\neditor_preview_action = &"{action}"\n',
            1,
        )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    for tscn_rel, tres_rel, action, label in ENEMIES:
        patch_tscn(ROOT / tscn_rel, label)
        patch_tres(ROOT / tres_rel, action, label)
        print(f"OK {tscn_rel}")


if __name__ == "__main__":
    main()
