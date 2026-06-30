#!/usr/bin/env python3
"""Generate *_enemy.tscn from existing EnemyStats .tres (one-time migration helper)."""
from __future__ import annotations

import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

INTENT_BASE_LEFT = -120.0
INTENT_BASE_RIGHT = 120.0
INTENT_BASE_TOP = -108.0
INTENT_BASE_BOTTOM = -45.0

ENEMIES = [
    ("BatEnemy", "enemies/bat/bat_enemy.tres", "enemies/bat/bat_enemy.tscn"),
    ("RatEnemy", "enemies/rat/rat_enemy.tres", "enemies/rat/rat_enemy.tscn"),
    ("CrabEnemy", "enemies/crab/crab_enemy.tres", "enemies/crab/crab_enemy.tscn"),
    ("SpiderEnemy", "enemies/spider/spider_enemy.tres", "enemies/spider/spider_enemy.tscn"),
    ("MimicEnemy", "enemies/mimic/mimic_enemy.tres", "enemies/mimic/mimic_enemy.tscn"),
    ("BoneChewerEnemy", "enemies/bone_chewer/bone_chewer_enemy.tres", "enemies/bone_chewer/bone_chewer_enemy.tscn"),
    ("PilgrimEnemy", "enemies/pilgrim/pilgrim_enemy.tres", "enemies/pilgrim/pilgrim_enemy.tscn"),
    ("IgneousBursterEnemy", "enemies/igneous_burster/igneous_burster_enemy.tres", "enemies/igneous_burster/igneous_burster_enemy.tscn"),
    ("LittleSkeltonEnemy", "enemies/little_skelton/little_skelton_enemy.tres", "enemies/little_skelton/little_skelton_enemy.tscn"),
    ("ShellMechEnemy", "enemies/shell_mech/shell_mech_enemy.tres", "enemies/shell_mech/shell_mech_enemy.tscn"),
    ("GhostSummonerEnemy", "enemies/ghost_summoner/ghost_summoner.tres", "enemies/ghost_summoner/ghost_summoner_enemy.tscn"),
    ("SpookEnemy", "enemies/ghost_summoner/spook.tres", "enemies/ghost_summoner/spook_enemy.tscn"),
    ("EvilSpiritEnemy", "enemies/evil_spirit/evil_spirit.tres", "enemies/evil_spirit/evil_spirit_enemy.tscn"),
    ("HeavenGuardianEnemy", "enemies/heaven_guardian/heaven_guardian.tres", "enemies/heaven_guardian/heaven_guardian_enemy.tscn"),
    ("ShadowSamuraiEnemy", "enemies/shadow_samurai/shadow_samurai.tres", "enemies/shadow_samurai/shadow_samurai_enemy.tscn"),
    ("WaterMonsterEnemy", "enemies/water_monster/water_monster.tres", "enemies/water_monster/water_monster_enemy.tscn"),
]

ART_PATH_RE = re.compile(r'path="(res://art/[^"]+\.png)"')
ART_LINE_RE = re.compile(r"^art = ExtResource\(")
SCALE_RE = re.compile(r"art_scale = Vector2\(([-\d.]+),\s*([-\d.]+)\)")
HBW_RE = re.compile(r"health_bar_width = (\d+)")
STATUS_RE = re.compile(r"status_bar_offset = Vector2\(([-\d.]+),\s*([-\d.]+)\)")
INTENT_RE = re.compile(r"intent_ui_offset = Vector2\(([-\d.]+),\s*([-\d.]+)\)")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        sig = f.read(8)
        if sig[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Not PNG: {path}")
        while True:
            length_bytes = f.read(4)
            if len(length_bytes) < 4:
                break
            length = struct.unpack(">I", length_bytes)[0]
            chunk_type = f.read(4)
            data = f.read(length)
            f.read(4)
            if chunk_type == b"IHDR":
                w, h = struct.unpack(">II", data[:8])
                return w, h
    raise ValueError(f"No IHDR in {path}")


def parse_tres(text: str) -> dict:
    art_paths = ART_PATH_RE.findall(text)
    art = None
    for line in text.splitlines():
        if ART_LINE_RE.match(line.strip()):
            idx = int(re.search(r"ExtResource\(\"(\d+)", line).group(1))
            # ext_resource ids are like id="2_bat1" - match by order in file
            break
    # First art = line references ext id; find matching path from ext_resources in order
    ext_paths: list[str] = []
    for line in text.splitlines():
        m = re.search(r'\[ext_resource type="Texture2D"[^]]*path="(res://art/[^"]+)"', line)
        if m:
            ext_paths.append(m.group(1))
    for line in text.splitlines():
        if ART_LINE_RE.match(line.strip()):
            ref = re.search(r'ExtResource\("([^"]+)"\)', line)
            if ref:
                ref_id = ref.group(1)
                for eline in text.splitlines():
                    if f'id="{ref_id}"' in eline and "path=" in eline:
                        art = re.search(r'path="(res://art/[^"]+)"', eline).group(1)
                        break
            if art is None and ext_paths:
                art = ext_paths[0]
            break

    scale_m = SCALE_RE.search(text)
    scale = (float(scale_m.group(1)), float(scale_m.group(2))) if scale_m else (3.0, 3.0)
    hbw_m = HBW_RE.search(text)
    hbw = int(hbw_m.group(1)) if hbw_m else 180
    status_m = STATUS_RE.search(text)
    status = (float(status_m.group(1)), float(status_m.group(2))) if status_m else (0.0, 14.0)
    intent_m = INTENT_RE.search(text)
    intent = (float(intent_m.group(1)), float(intent_m.group(2))) if intent_m else (0.0, 0.0)
    return {"art": art, "scale": scale, "hbw": hbw, "status": status, "intent": intent}


def sprite_foot_y(art_path: str) -> float:
    rel = art_path.replace("res://", "").replace("/", "\\")
    w, h = png_size(ROOT / rel.replace("\\", "/"))
    return h / 2.0  # centered Sprite2D


def build_tscn(node_name: str, tres_rel: str, art: str, scale: tuple, hbw: int, status: tuple, intent: tuple) -> str:
    foot = sprite_foot_y(art)
    sx, sy = status
    status_pos_x = -hbw / 2.0 + sx
    status_pos_y = foot + sy
    ix, iy = intent
    il = INTENT_BASE_LEFT + ix
    ir = INTENT_BASE_RIGHT + ix
    it = INTENT_BASE_TOP - iy
    ib = INTENT_BASE_BOTTOM - iy
    sx_s, sy_s = scale
    tres_path = f"res://{tres_rel.replace(chr(92), '/')}"

    return f"""[gd_scene load_steps=11 format=3]

[ext_resource type="Texture2D" path="{art}" id="1_art"]
[ext_resource type="Script" path="res://scenes/enemy/enemy.gd" id="2_script"]
[ext_resource type="Texture2D" path="res://art/arrow.png" id="3_arrow"]
[ext_resource type="PackedScene" path="res://scenes/ui/status_bar.tscn" id="4_status_bar"]
[ext_resource type="PackedScene" path="res://scenes/ui/intent_ui.tscn" id="5_intent_ui"]
[ext_resource type="PackedScene" path="res://scenes/modifier_handler/modifier_handler.tscn" id="6_modifier"]
[ext_resource type="PackedScene" path="res://scenes/modifier_handler/modifier.tscn" id="7_modifier_item"]
[ext_resource type="PackedScene" path="res://scenes/enemy/enemy_target_highlight.tscn" id="8_highlight"]
[ext_resource type="Script" path="res://scenes/ui/combatant_hover_name.gd" id="9_hover_name"]
[ext_resource type="Resource" path="{tres_path}" id="10_stats"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_hitbox"]

[node name="{node_name}" type="Area2D" groups=["enemies"]]
collision_layer = 4
script = ExtResource("2_script")
stats = ExtResource("10_stats")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2({sx_s}, {sy_s})
texture = ExtResource("1_art")

[node name="Arrow" type="Sprite2D" parent="."]
visible = false
position = Vector2(72, 0)
rotation = -1.5708
texture = ExtResource("3_arrow")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
scale = Vector2({sx_s}, {sy_s})
shape = SubResource("RectangleShape2D_hitbox")

[node name="StatusBar" parent="." instance=ExtResource("4_status_bar")]
position = Vector2({status_pos_x:.1f}, {status_pos_y:.1f})
status_tooltips_open_to_right = false

[node name="HoverNameOverlay" type="Label" parent="."]
modulate = Color(1, 1, 1, 0)
mouse_filter = 2
script = ExtResource("9_hover_name")

[node name="IntentUI" parent="." instance=ExtResource("5_intent_ui")]
offset_left = {il:.1f}
offset_top = {it:.1f}
offset_right = {ir:.1f}
offset_bottom = {ib:.1f}

[node name="ModifierHandler" parent="." instance=ExtResource("6_modifier")]

[node name="DamageDealtModifier" parent="ModifierHandler" instance=ExtResource("7_modifier_item")]

[node name="DamageTakenModifier" parent="ModifierHandler" instance=ExtResource("7_modifier_item")]
type = 1

[node name="TargetHighlight" parent="." instance=ExtResource("8_highlight")]
"""


def patch_tres(tres_path: Path, scene_rel: str) -> None:
    text = tres_path.read_text(encoding="utf-8")
    scene_path = f"res://{scene_rel.replace(chr(92), '/')}"
    text = STATUS_RE.sub("", text)
    text = INTENT_RE.sub("", text)
    text = re.sub(r"\n\n+", "\n", text)
    if "uses_scene_ui_layout" not in text:
        text = text.replace(
            "display_name = ",
            f'enemy_scene = ExtResource("99_scene")\nuses_scene_ui_layout = true\ndisplay_name = ',
            1,
        )
        # insert ext_resource for scene before [resource]
        insert = f'[ext_resource type="PackedScene" path="{scene_path}" id="99_scene"]\n\n'
        text = text.replace("\n[resource]", f"\n{insert}[resource]", 1)
    else:
        text = re.sub(
            r'enemy_scene = ExtResource\("[^"]+"\)',
            f'enemy_scene = ExtResource("99_scene")',
            text,
        )
        text = re.sub(
            r'\[ext_resource type="PackedScene" path="[^"]+" id="99_scene"\]',
            f'[ext_resource type="PackedScene" path="{scene_path}" id="99_scene"]',
            text,
        )
    tres_path.write_text(text, encoding="utf-8")


def main() -> None:
    for node_name, tres_rel, scene_rel in ENEMIES:
        tres_path = ROOT / tres_rel
        scene_path = ROOT / scene_rel
        cfg = parse_tres(tres_path.read_text(encoding="utf-8"))
        if not cfg["art"]:
            raise SystemExit(f"No art for {tres_rel}")
        tscn = build_tscn(node_name, tres_rel, cfg["art"], cfg["scale"], cfg["hbw"], cfg["status"], cfg["intent"])
        scene_path.parent.mkdir(parents=True, exist_ok=True)
        scene_path.write_text(tscn, encoding="utf-8")
        patch_tres(tres_path, scene_rel)
        print(f"OK {scene_rel}")


if __name__ == "__main__":
    main()
