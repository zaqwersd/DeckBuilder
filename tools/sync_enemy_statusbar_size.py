#!/usr/bin/env python3
"""Ensure *_enemy.tscn StatusBar has visible size (width=container_width, height=14)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIN_H = 14

BLOCK_RE = re.compile(
    r'(\[node name="StatusBar" parent="\.[^\]]*\][^\[]*)',
    re.DOTALL,
)


def patch_status_bar_block(block: str) -> str:
    cw_m = re.search(r"^container_width = (\d+)", block, re.MULTILINE)
    if not cw_m:
        return block
    cw = int(cw_m.group(1))
    block = re.sub(
        r"^size = Vector2\([^)]+\)",
        f"size = Vector2({cw}, {MIN_H})",
        block,
        count=1,
        flags=re.MULTILINE,
    )
    if "layout_mode = 0" not in block and "layout_mode = " not in block:
        block = block.rstrip() + "\nlayout_mode = 0\n"
    if "size = Vector2(" not in block:
        block = block.rstrip() + f"\nsize = Vector2({cw}, {MIN_H})\n"
    return block


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if 'name="StatusBar"' not in text:
        return False
    new_text = BLOCK_RE.sub(lambda m: patch_status_bar_block(m.group(1)), text)
    if new_text == text:
        return False
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> None:
    n = 0
    for path in sorted((ROOT / "enemies").rglob("*_enemy.tscn")):
        if patch_file(path):
            print(f"patched {path.relative_to(ROOT)}")
            n += 1
    print(f"done: {n} files")


if __name__ == "__main__":
    main()
