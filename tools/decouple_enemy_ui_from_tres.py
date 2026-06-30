#!/usr/bin/env python3
"""Move UI preview fields from enemy .tres to *_enemy.tscn; strip conflicting tres data."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENEMIES = ROOT / "enemies"

TRES_GLOB = "**/*.tres"
TSCN_SUFFIX = None  # filled from enemy_scene_path in each tres


def parse_tres(path: Path) -> tuple[str, str | None, str | None]:
    text = path.read_text(encoding="utf-8")
    if "editor_preview_action" not in text and "editor_preview_intents" not in text:
        return text, None, None
    action_m = re.search(r'editor_preview_action\s*=\s*&"([^"]*)"', text)
    action = action_m.group(1) if action_m else None
    scene_m = re.search(r'enemy_scene_path\s*=\s*"([^"]+)"', text)
    scene_path = scene_m.group(1) if scene_m else None

    # drop intent script ext_resource only used for preview placeholder
    lines = text.splitlines()
    intent_ext_ids: set[str] = set()
    for line in lines:
        m = re.match(r'\[ext_resource type="Script".*path="res://custom_resources/intent\.gd" id="([^"]+)"\]', line)
        if m:
            intent_ext_ids.add(m.group(1))

    out_lines: list[str] = []
    skip_sub = False
    for line in lines:
        if line.startswith("[sub_resource type=\"Resource\" id=\"Intent_preview_attack\"]"):
            skip_sub = True
            continue
        if skip_sub:
            if line.startswith("[") or line.startswith("[resource]"):
                skip_sub = False
            else:
                continue
        if re.match(r"editor_preview_action\s*=", line):
            continue
        if re.match(r"editor_preview_intents\s*=", line):
            continue
        if re.match(r"health_bar_width\s*=", line):
            continue
        if "custom_resources/intent.gd" in line and any(f'id="{i}"' in line for i in intent_ext_ids):
            # keep if still referenced elsewhere
            rest = "\n".join(lines)
            eid = re.search(r'id="([^"]+)"', line).group(1)
            if rest.count(f'ExtResource("{eid}")') <= 1:
                continue
        out_lines.append(line)

    return "\n".join(out_lines) + ("\n" if not text.endswith("\n") else ""), action, scene_path


def patch_tscn(scene_rel: str, action: str | None) -> None:
    if not action:
        return
    tscn = ROOT / scene_rel.replace("res://", "").replace("/", "\\")
    if not tscn.exists():
        tscn = ROOT / scene_rel.replace("res://", "")
    if not tscn.exists():
        print(f"WARN missing tscn: {scene_rel}")
        return
    text = tscn.read_text(encoding="utf-8")
    if re.search(r"editor_preview_action\s*=", text):
        text = re.sub(
            r'editor_preview_action\s*=\s*&"[^"]*"',
            f'editor_preview_action = &"{action}"',
            text,
        )
    else:
        # insert after stats = line on Enemy root
        text = re.sub(
            r"(stats = ExtResource\(\"[^\"]+\"\)\n)",
            rf'\1editor_preview_action = &"{action}"\n',
            text,
            count=1,
        )
    tscn.write_text(text, encoding="utf-8")
    print(f"patched tscn: {tscn.relative_to(ROOT)}")


def main() -> None:
    for tres in sorted(ENEMIES.glob(TRES_GLOB)):
        new_text, action, scene_path = parse_tres(tres)
        if action is None and "uses_scene_ui_layout" not in tres.read_text(encoding="utf-8"):
            continue
        old = tres.read_text(encoding="utf-8")
        if new_text != old:
            tres.write_text(new_text, encoding="utf-8")
            print(f"cleaned tres: {tres.relative_to(ROOT)}")
        if scene_path and action:
            patch_tscn(scene_path, action)


if __name__ == "__main__":
    main()
