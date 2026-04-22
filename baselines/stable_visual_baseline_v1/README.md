# stable_visual_baseline_v1

This folder is a file-level checkpoint for the last accepted 3D readability baseline.

## Contents
- `source/` contains exact file snapshots.
- `baseline_manifest.json` lists tracked files and SHA256 hashes.

## Restore
Run:

```powershell
tools\restore_stable_visual_baseline_v1.ps1
```

Optional flags:
- `-DryRun` to preview changes
- `-NoBackup` to skip creating a backup copy of existing files
