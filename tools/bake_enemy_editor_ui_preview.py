#!/usr/bin/env python3
"""Bake per-enemy editor UI preview (intent slots + health label) into *_enemy.tscn."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTENT_SLOT = "res://scenes/ui/intent_slot.tscn"
PREVIEW_JSON = ROOT / "tools" / "enemy_editor_ui_preview.json"

FALLBACK: dict[str, dict] = {
    "enemies/bat/bat_enemy.tscn": {
        "max_health": 21,
        "bar_width": 80,
        "intents": [{"icon": "res://art/attack.png", "label": "3×2"}],
    },
    "enemies/rat/rat_enemy.tscn": {
        "max_health": 36,
        "bar_width": 110,
        "intents": [{"icon": "res://art/attack.png", "label": "9"}],
    },
    "enemies/crab/crab_enemy.tscn": {
        "max_health": 40,
        "bar_width": 125,
        "intents": [{"icon": "res://art/attack.png", "label": "11"}],
    },
    "enemies/spider/spider_enemy.tscn": {
        "max_health": 46,
        "bar_width": 150,
        "intents": [{"icon": "res://art/attack.png", "label": "10"}],
    },
    "enemies/mimic/mimic_enemy.tscn": {
        "max_health": 91,
        "bar_width": 160,
        "intents": [{"icon": "res://art/attack.png", "label": "14"}],
    },
    "enemies/bone_chewer/bone_chewer_enemy.tscn": {
        "max_health": 98,
        "bar_width": 250,
        "intents": [{"icon": "res://art/attack.png", "label": "11"}],
    },
    "enemies/pilgrim/pilgrim_enemy.tscn": {
        "max_health": 147,
        "bar_width": 250,
        "intents": [{"icon": "res://art/attack.png", "label": "4×3"}],
    },
    "enemies/igneous_burster/igneous_burster_enemy.tscn": {
        "max_health": 57,
        "bar_width": 200,
        "intents": [{"icon": "res://art/attack.png", "label": "7"}],
    },
    "enemies/little_skelton/little_skelton_enemy.tscn": {
        "max_health": 16,
        "bar_width": 96,
        "intents": [{"icon": "res://art/attack.png", "label": "4"}],
    },
    "enemies/shell_mech/shell_mech_enemy.tscn": {
        "max_health": 91,
        "bar_width": 200,
        "intents": [{"icon": "res://art/attack.png", "label": "21"}],
    },
    "enemies/ghost_summoner/ghost_summoner_enemy.tscn": {
        "max_health": 325,
        "bar_width": 260,
        "intents": [{"icon": "res://art/attack.png", "label": "5×3"}],
    },
    "enemies/ghost_summoner/spook_enemy.tscn": {
        "max_health": 100,
        "bar_width": 200,
        "intents": [
            {"icon": "res://art/attack.png", "label": "6"},
            {"icon": "res://art/buff.png", "label": ""},
        ],
    },
    "enemies/evil_spirit/evil_spirit_enemy.tscn": {
        "max_health": 258,
        "bar_width": 320,
        "intents": [
            {"icon": "res://art/attack.png", "label": "20"},
            {"icon": "res://art/debuff.png", "label": ""},
        ],
    },
    "enemies/heaven_guardian/heaven_guardian_enemy.tscn": {
        "max_health": 450,
        "bar_width": 320,
        "intents": [
            {"icon": "res://art/attack.png", "label": "36"},
            {"icon": "res://art/buff.png", "label": ""},
        ],
    },
    "enemies/shadow_samurai/shadow_samurai_enemy.tscn": {
        "max_health": 320,
        "bar_width": 210,
        "intents": [{"icon": "res://art/attack.png", "label": "1×6"}],
    },
    "enemies/water_monster/water_monster_enemy.tscn": {
        "max_health": 240,
        "bar_width": 300,
        "intents": [{"icon": "res://art/attack.png", "label": "20"}],
    },
}


def load_preview_map() -> dict[str, dict]:
    out = {k: dict(v) for k, v in FALLBACK.items()}
    if PREVIEW_JSON.exists():
        try:
            rows = json.loads(PREVIEW_JSON.read_text(encoding="utf-8"))
            for row in rows:
                if not row or row.get("error"):
                    continue
                scene = row.get("scene", "")
                if not scene.startswith("res://"):
                    continue
                rel = scene.replace("res://", "")
                if row.get("intents"):
                    out[rel] = {
                        "max_health": row["max_health"],
                        "bar_width": row["bar_width"],
                        "intents": row["intents"],
                    }
        except json.JSONDecodeError:
            pass
    return out


def build_intent_block(intents: list[dict], slot_ext: str, icon_ids: dict[str, str]) -> str:
    lines: list[str] = []
    for i, it in enumerate(intents):
        name = f"EditorPreviewIntentSlot{i}" if i else "EditorPreviewIntentSlot"
        icon_path = it.get("icon", "res://art/attack.png")
        icon_id = icon_ids[icon_path]
        label = it.get("label", "")
        lines.append(f'\n[node name="{name}" parent="IntentUI" instance=ExtResource("{slot_ext}")]')
        lines.append("layout_mode = 2")
        lines.append("")
        lines.append(f'[node name="Icon" parent="IntentUI/{name}" index="0"]')
        lines.append(f'texture = ExtResource("{icon_id}")')
        lines.append("")
        lines.append(f'[node name="ValueLabel" parent="IntentUI/{name}" index="1"]')
        lines.append(f'text = "{label}"')
        if label == "":
            lines.append("visible = false")
    return "\n".join(lines) + "\n"


def patch_tscn(path: Path, cfg: dict) -> None:
    text = path.read_text(encoding="utf-8")
    max_hp = int(cfg["max_health"])
    bar_w = int(cfg["bar_width"])
    health_text = f"{max_hp}/{max_hp}"
    intents: list[dict] = cfg["intents"]

    text = re.sub(
        r'\n\[node name="EditorPreviewIntentSlot[^"]*" parent="IntentUI"[^\]]*\][\s\S]*?(?=\n\[node name="(?!Icon|ValueLabel)|\Z)',
        "\n",
        text,
    )
    text = re.sub(
        r'\n\[node name="Icon" parent="IntentUI/EditorPreviewIntentSlot[^\]]*" index="0"\][^\n]*\n',
        "\n",
        text,
    )
    text = re.sub(
        r'\n\[node name="ValueLabel" parent="IntentUI/EditorPreviewIntentSlot[^\]]*" index="1"\][^\n]*(?:\nvisible = false)?',
        "",
        text,
    )
    text = re.sub(
        r'\n\[ext_resource type="Texture2D" path="res://art/(?:attack|buff|debuff)\.png" id="[^"]+"\]',
        "",
        text,
    )

    icons = list(dict.fromkeys(it.get("icon", "res://art/attack.png") for it in intents))
    slot_m = re.search(
        rf'\[ext_resource type="PackedScene" path="{re.escape(INTENT_SLOT)}" id="([^"]+)"\]',
        text,
    )
    if not slot_m:
        raise SystemExit(f"{path}: missing intent_slot ext_resource")
    slot_id = slot_m.group(1)

    icon_ids: dict[str, str] = {}
    nums = [int(m.group(1)) for m in re.finditer(r'id="(\d+)', text)]
    next_num = (max(nums) if nums else 10) + 1
    insert_ext = ""
    attack_id = f"{next_num}_attack"
    next_num += 1
    icon_ids["res://art/attack.png"] = attack_id
    insert_ext += f'\n[ext_resource type="Texture2D" path="res://art/attack.png" id="{attack_id}"]'
    for icon_path in icons:
        if icon_path == "res://art/attack.png":
            continue
        iid = f"{next_num}_preview_icon"
        next_num += 1
        icon_ids[icon_path] = iid
        insert_ext += f'\n[ext_resource type="Texture2D" path="{icon_path}" id="{iid}"]'
    if insert_ext and "[sub_resource type=" in text:
        text = text.replace("\n[sub_resource type=", insert_ext + "\n\n[sub_resource type=", 1)
    elif insert_ext:
        text = text.replace("\n[node name=", insert_ext + "\n\n[node name=", 1)

    intent_block = build_intent_block(intents, slot_id, icon_ids)
    intent_ui_m = re.search(r'(\[node name="IntentUI"[^\]]*\][^\[]*)', text, re.DOTALL)
    if not intent_ui_m:
        raise SystemExit(f"{path}: no IntentUI")
    insert_at = intent_ui_m.end(1)
    text = text[:insert_at] + intent_block + text[insert_at:]

    # 锚点 offset 会锁死 StatusBar 宽度；先转为 position，再写入血条 override。
    sb_node = re.search(
        r'(\[node name="StatusBar" parent="[^\]]+"[^\]]*\]\n)'
        r'(?:unique_id=\d+\s*\n)?'
        r'offset_left = ([^\n]+)\n'
        r'offset_top = ([^\n]+)\n'
        r'offset_right = [^\n]+\n'
        r'offset_bottom = [^\n]+\n'
        r'(status_tooltips_open_to_right = false\n)',
        text,
    )
    if sb_node:
        header = sb_node.group(1)
        left = float(sb_node.group(2))
        top = float(sb_node.group(3))
        tail = sb_node.group(4)
        text = text.replace(sb_node.group(0), f"{header}position = Vector2({left}, {top})\n{tail}", 1)

    status_tail = re.compile(
        r'(\[node name="StatusBar" parent="[^\]]+"[^\]]*\][^\n]*\n'
        r'(?:.*\n)*?'
        r'status_tooltips_open_to_right = false\n)'
    )

    health_row_line = f'[node name="HealthRow" parent="StatusBar" index="0"]\nbar_width = {bar_w}\n\n'
    barhost_line = (
        f'[node name="BarHost" parent="StatusBar/HealthRow" index="0"]\n'
        f"custom_minimum_size = Vector2({bar_w}, 10)\n\n"
    )

    if '[node name="BarHost" parent="StatusBar/HealthRow"' in text:
        text = re.sub(
            r'(\[node name="BarHost" parent="StatusBar/HealthRow" index="0"\]\n)custom_minimum_size = Vector2\([^\)]+\)',
            rf"\1custom_minimum_size = Vector2({bar_w}, 10)",
            text,
            count=1,
        )
    else:
        m = status_tail.search(text)
        if m:
            text = text[: m.end(1)] + barhost_line + text[m.end(1) :]

    if '[node name="HealthRow" parent="StatusBar" index="0"]' in text:
        if re.search(r'\[node name="HealthRow" parent="StatusBar" index="0"\]\nbar_width = ', text):
            text = re.sub(
                r'(\[node name="HealthRow" parent="StatusBar" index="0"\]\n)bar_width = \d+',
                rf"\1bar_width = {bar_w}",
                text,
                count=1,
            )
        else:
            text = text.replace(
                '[node name="HealthRow" parent="StatusBar" index="0"]\n',
                f'[node name="HealthRow" parent="StatusBar" index="0"]\nbar_width = {bar_w}\n',
                1,
            )
    elif '[node name="BarHost" parent="StatusBar/HealthRow" index="0"]' in text:
        text = text.replace(
            '[node name="BarHost" parent="StatusBar/HealthRow" index="0"]\n',
            health_row_line + '[node name="BarHost" parent="StatusBar/HealthRow" index="0"]\n',
            1,
        )
    else:
        m = status_tail.search(text)
        if m:
            text = text[: m.end(1)] + health_row_line + barhost_line + text[m.end(1) :]

    hp_override = (
        f'\n[node name="HPBar" parent="StatusBar/HealthRow/BarHost" index="0"]\n'
        f"max_value = {float(max_hp)}\n"
        f"value = {float(max_hp)}\n\n"
        f'[node name="HealthLabel" parent="StatusBar/HealthRow/BarHost" index="1"]\n'
        f'text = "{health_text}"\n'
    )
    if '[node name="HPBar" parent="StatusBar/HealthRow/BarHost"' in text:
        text = re.sub(
            r'\n\[node name="HPBar" parent="StatusBar/HealthRow/BarHost" index="0"\]\nmax_value = [^\n]+\nvalue = [^\n]+',
            f"\n[node name=\"HPBar\" parent=\"StatusBar/HealthRow/BarHost\" index=\"0\"]\nmax_value = {float(max_hp)}\nvalue = {float(max_hp)}",
            text,
            count=1,
        )
        text = re.sub(
            r'(\[node name="HealthLabel" parent="StatusBar/HealthRow/BarHost" index="1"\]\n)text = "[^"]*"',
            rf'\1text = "{health_text}"',
            text,
            count=1,
        )
    else:
        barhost_m = re.search(
            r'(\[node name="BarHost" parent="StatusBar/HealthRow" index="0"\]\ncustom_minimum_size = Vector2\([^\)]+\)\n)',
            text,
        )
        if barhost_m:
            text = text[: barhost_m.end(1)] + hp_override + text[barhost_m.end(1) :]

    path.write_text(text, encoding="utf-8")


def main() -> None:
    preview = load_preview_map()
    for rel, cfg in sorted(preview.items()):
        path = ROOT / rel
        if not path.exists():
            print(f"skip missing {rel}")
            continue
        patch_tscn(path, cfg)
        print(f"OK {rel}")


if __name__ == "__main__":
    main()
