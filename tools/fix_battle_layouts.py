#!/usr/bin/env python3
"""Fix battle layouts line-by-line."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BATTLES = ROOT / "battles"


def fix_file(path: Path) -> bool:
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    changed = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("[node") and "instance=ExtResource(" in line:
            inst_m = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
            inst_id = inst_m.group(1) if inst_m else ""
            j = i + 1
            stats_id = None
            body_lines: list[str] = []
            while j < len(lines) and not lines[j].startswith("[node"):
                if lines[j].startswith("stats = ExtResource("):
                    sm = re.search(r'stats = ExtResource\("([^"]+)"\)', lines[j])
                    if sm:
                        stats_id = sm.group(1)
                        j += 1
                        changed = True
                        continue
                body_lines.append(lines[j])
                j += 1
            if stats_id and inst_id != stats_id:
                line = line.replace(f'instance=ExtResource("{inst_id}")', f'instance=ExtResource("{stats_id}")')
                changed = True
            out.append(line)
            out.extend(body_lines)
            i = j
            continue
        if "scenes/enemy/enemy.tscn" in line:
            changed = True
            i += 1
            continue
        out.append(line)
        i += 1
    if changed:
        path.write_text("\n".join(out) + "\n", encoding="utf-8")
    return changed


def main() -> None:
    for path in sorted(BATTLES.glob("*.tscn")):
        if fix_file(path):
            print(f"Fixed {path.name}")


if __name__ == "__main__":
    main()
