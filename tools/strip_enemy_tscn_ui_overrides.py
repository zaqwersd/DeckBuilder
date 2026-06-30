#!/usr/bin/env python3
"""Remove baked HPBar / Intent preview overrides from *_enemy.tscn (preview is driven by scripts)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENEMIES = ROOT / "enemies"

STRIP_BLOCKS = [
    re.compile(
        r"\n?\[node name=\"HPBar\" parent=\"StatusBar/HealthRow/BarHost\" index=\"0\"\]\n"
        r"(?:max_value = .+\n)?(?:value = .+\n)?",
        re.MULTILINE,
    ),
    re.compile(
        r"\n?\[node name=\"HealthLabel\" parent=\"StatusBar/HealthRow/BarHost\" index=\"1\"\]\n"
        r"text = .+\n",
        re.MULTILINE,
    ),
    re.compile(
        r"\n?\[node name=\"Icon\" parent=\"IntentUI/EditorPreviewIntentSlot(?:\d*)?\" index=\"0\"\]\n"
        r"texture = .+\n",
        re.MULTILINE,
    ),
    re.compile(
        r"\n?\[node name=\"ValueLabel\" parent=\"IntentUI/EditorPreviewIntentSlot(?:\d*)?\" index=\"1\"\]\n"
        r"text = .+\n",
        re.MULTILINE,
    ),
]

# Remove unused attack texture ext_resource if only used by stripped Icon overrides.
ATTACK_EXT_RE = re.compile(
    r'\n?\[ext_resource type="Texture2D" path="res://art/attack\.png" id="[^"]+"\]\n'
)


def clean_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text
    for pattern in STRIP_BLOCKS:
        text = pattern.sub("\n", text)
    if "attack.png" not in text:
        text = ATTACK_EXT_RE.sub("\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = 0
    for path in sorted(ENEMIES.rglob("*_enemy.tscn")):
        if clean_file(path):
            print(f"cleaned {path.relative_to(ROOT)}")
            changed += 1
    print(f"done: {changed} file(s) updated")


if __name__ == "__main__":
    main()
