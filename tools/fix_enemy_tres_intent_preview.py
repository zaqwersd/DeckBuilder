#!/usr/bin/env python3
"""Fix editor_preview_intents ext id in enemy .tres files."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTENT_SCRIPT = "res://custom_resources/intent.gd"

TRES_FILES = list((ROOT / "enemies").rglob("*.tres"))


def fix_tres(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text
    if "uses_scene_ui_layout" not in text:
        return False

    intent_id = None
    for m in re.finditer(
        r'\[ext_resource type="Script"[^\]]*path="(?:res://custom_resources/intent\.gd|[^"]*intent\.gd)" id="([^"]+)"\]',
        text,
    ):
        intent_id = m.group(1)
    if intent_id is None:
        intent_id = "preview_intent_script"
        insert = f'[ext_resource type="Script" path="{INTENT_SCRIPT}" id="{intent_id}"]\n\n'
        text = text.replace("\n[resource]", "\n" + insert + "[resource]", 1)

    has_preview_sub = '[sub_resource type="Resource" id="Intent_preview_attack"]' in text
    if not has_preview_sub:
        sub = (
            f'[sub_resource type="Resource" id="Intent_preview_attack"]\n'
            f'script = ExtResource("{intent_id}")\n'
            f"kind = 0\n"
            f'base_text = ""\n\n'
        )
        text = text.replace("\n[resource]", "\n" + sub + "[resource]", 1)
    else:
        text = re.sub(
            r'(\[sub_resource type="Resource" id="Intent_preview_attack"\]\nscript = ExtResource\(")[^"]+("\])',
            rf"\g<1>{intent_id}\2",
            text,
        )
        if "kind = 0" not in text.split("Intent_preview_attack")[1].split("[resource]")[0]:
            text = text.replace(
                f'script = ExtResource("{intent_id}")',
                f'script = ExtResource("{intent_id}")\nkind = 0\nbase_text = ""',
                1,
            )

    text = re.sub(
        r'editor_preview_intents = Array\[ExtResource\("[^"]+"\)\]\(\[SubResource\("Intent_preview_attack"\)\]\)',
        f'editor_preview_intents = Array[ExtResource("{intent_id}")]([SubResource("Intent_preview_attack")])',
        text,
    )
    if "editor_preview_intents" not in text and "editor_preview_action" in text:
        text = text.replace(
            "editor_preview_action",
            f'editor_preview_intents = Array[ExtResource("{intent_id}")]([SubResource("Intent_preview_attack")])\neditor_preview_action',
            1,
        )

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    for path in sorted(TRES_FILES):
        if fix_tres(path):
            print(f"fixed {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
