"""Headless Blender entrypoint for Ooze Tactics generated mesh kit.

Usage (from repo root):
    blender -b --python tools/blender_gen/run_all.py
"""

from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path


THIS_FILE = Path(__file__).resolve()
BLENDER_GEN_DIR = THIS_FILE.parent
REPO_ROOT = THIS_FILE.parents[2]
SCRIPTS_DIR = BLENDER_GEN_DIR / "scripts"

if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from asset_generators import ASSET_REPLACEMENT_MAP, build_and_export_all  # noqa: E402


def _as_repo_relative(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT)).replace("\\", "/")


def main() -> int:
    export_dir = REPO_ROOT / "assets" / "meshes" / "generated"
    output_dir = BLENDER_GEN_DIR / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    exported_paths = build_and_export_all(export_dir)

    manifest = {
        "repo_root": str(REPO_ROOT),
        "export_dir": _as_repo_relative(export_dir),
        "assets": [_as_repo_relative(path) for path in exported_paths],
        "replacement_map": ASSET_REPLACEMENT_MAP,
    }

    manifest_path = output_dir / "export_manifest.json"
    replacement_map_path = output_dir / "replacement_map.md"

    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    replacement_lines = [
        "# Generated Asset Replacement Map",
        "",
        "This maps generated Blender assets to current primitive-driven render responsibilities.",
        "",
    ]
    for asset_name, description in ASSET_REPLACEMENT_MAP.items():
        replacement_lines.append(f"- `{asset_name}` -> {description}")

    replacement_map_path.write_text("\n".join(replacement_lines) + "\n", encoding="utf-8")

    print("[blender_gen] Export complete")
    print(f"[blender_gen] Export dir: {_as_repo_relative(export_dir)}")
    for path in exported_paths:
        print(f"[blender_gen] - {_as_repo_relative(path)}")
    print(f"[blender_gen] Manifest: {_as_repo_relative(manifest_path)}")
    print(f"[blender_gen] Replacement map: {_as_repo_relative(replacement_map_path)}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception:  # pragma: no cover
        print("[blender_gen] Fatal error")
        print(traceback.format_exc())
        raise SystemExit(1)
