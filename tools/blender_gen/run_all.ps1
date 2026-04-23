param(
    [string]$BlenderExe = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptPath = Join-Path $repoRoot "tools/blender_gen/run_all.py"

if ([string]::IsNullOrWhiteSpace($BlenderExe)) {
    $candidates = @(
        "$env:ProgramFiles\\Blender Foundation\\Blender 5.1\\blender.exe",
        "$env:ProgramFiles\\Blender Foundation\\Blender 5.0\\blender.exe",
        "$env:ProgramFiles\\Blender Foundation\\Blender 4.6\\blender.exe",
        "$env:ProgramFiles\\Blender Foundation\\Blender 4.5\\blender.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $BlenderExe = $candidate
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($BlenderExe)) {
        $resolved = (Get-Command blender -ErrorAction SilentlyContinue)
        if ($null -ne $resolved) {
            $BlenderExe = $resolved.Source
        }
    }
}

if (-not (Test-Path $BlenderExe)) {
    throw "Unable to find blender.exe. Pass -BlenderExe explicitly."
}

Push-Location $repoRoot
try {
    & $BlenderExe -b --python $scriptPath
}
finally {
    Pop-Location
}
