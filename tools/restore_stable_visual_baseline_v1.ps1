param(
    [switch]$DryRun,
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$baselineRoot = Join-Path $repoRoot 'baselines\stable_visual_baseline_v1'
$sourceRoot = Join-Path $baselineRoot 'source'
$manifestPath = Join-Path $baselineRoot 'baseline_manifest.json'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Baseline manifest not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $sourceRoot)) {
    throw "Baseline source directory not found: $sourceRoot"
}

$manifestRaw = Get-Content -LiteralPath $manifestPath -Raw
$manifest = $manifestRaw | ConvertFrom-Json
if ($manifest.baseline_id -ne 'stable_visual_baseline_v1') {
    throw "Unexpected baseline id in manifest: $($manifest.baseline_id)"
}

$entries = @($manifest.files)
if ($entries.Count -eq 0) {
    throw 'No files defined in baseline manifest.'
}

Write-Host "Restoring baseline: $($manifest.baseline_id)"
Write-Host "Snapshot source HEAD: $($manifest.source_head)"
Write-Host "Files to restore: $($entries.Count)"

if ($DryRun) {
    foreach ($entry in $entries) {
        Write-Host "[DRY-RUN] would restore: $($entry.path)"
    }
    exit 0
}

$backupRoot = $null
if (-not $NoBackup) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupRoot = Join-Path $repoRoot "baselines\backups\stable_visual_baseline_v1_$timestamp"
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    Write-Host "Backup directory: $backupRoot"
}

foreach ($entry in $entries) {
    $relPath = [string]$entry.path
    $normalizedRel = $relPath.Replace('/', '\\')

    $src = Join-Path $sourceRoot $normalizedRel
    if (-not (Test-Path -LiteralPath $src)) {
        throw "Snapshot file missing: $src"
    }

    $dst = Join-Path $repoRoot $normalizedRel
    $dstDir = Split-Path -Parent $dst
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

    if ($backupRoot -and (Test-Path -LiteralPath $dst)) {
        $backupPath = Join-Path $backupRoot $normalizedRel
        $backupDir = Split-Path -Parent $backupPath
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item -LiteralPath $dst -Destination $backupPath -Force
    }

    Copy-Item -LiteralPath $src -Destination $dst -Force

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dst).Hash.ToLower()
    $expectedHash = ([string]$entry.sha256).ToLower()
    if ($actualHash -ne $expectedHash) {
        throw "Hash mismatch after restore for $relPath`nExpected: $expectedHash`nActual:   $actualHash"
    }

    Write-Host "Restored: $relPath"
}

Write-Host 'Baseline restore completed successfully.'
