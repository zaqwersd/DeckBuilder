#!/usr/bin/env python3
"""Fix intent slot ext_resource id mismatches in enemy tscn files."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

for path in (ROOT / "enemies").rglob("*_enemy.tscn"):
    text = path.read_text(encoding="utf-8")
    original = text
    slot_m = re.search(r'\[ext_resource type="PackedScene" path="res://scenes/ui/intent_slot\.tscn" id="([^"]+)"\]', text)
    attack_m = re.search(r'\[ext_resource type="Texture2D" path="res://art/attack\.png" id="([^"]+)"\]', text)
    if slot_m:
        sid = slot_m.group(1)
        text = re.sub(
            r'\[node name="EditorPreviewIntentSlot" parent="IntentUI" instance=ExtResource\("[^"]+"\)\]',
            f'[node name="EditorPreviewIntentSlot" parent="IntentUI" instance=ExtResource("{sid}")]',
            text,
        )
    if attack_m:
        aid = attack_m.group(1)
        text = re.sub(
            r'(\[node name="Icon" parent="IntentUI/EditorPreviewIntentSlot" index="0"\]\ntexture = )ExtResource\("[^"]+"\)',
            rf'\1ExtResource("{aid}")',
            text,
        )
    text = re.sub(r'(text = "[^"]*")\n(\[node name="ModifierHandler")', r"\1\n\n\2", text)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"fixed {path.relative_to(ROOT)}")
