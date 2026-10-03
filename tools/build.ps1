<#
.SYNOPSIS
    Exports the game. Produces build/windows/HeroesDuel.exe by default.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/build.ps1
    powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target web
    powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target all -Debug
.PARAMETER Target
    windows (default), macos, web, or all.
.PARAMETER Debug
    Export a debug build, which prints errors and allows remote debugging.
.PARAMETER Godot
    Path to the Godot executable. Defaults to $env:GODOT, then
    ..\tools\godot\4.7.2\ beside this repository, then "godot" on PATH.
#>
param(
    [ValidateSet("windows", "macos", "web", "all")]
    [string]$Target = "windows",
    [switch]$Debug,
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Godot) {
    $local = Join-Path $root "..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    if ($env:GODOT) { $Godot = $env:GODOT }
    elseif (Test-Path $local) { $Godot = (Resolve-Path $local).Path }
    else { $Godot = "godot" }
}

$presets = @{
    windows = @{ Name = "Windows Desktop"; Output = "build/windows/HeroesDuel.exe" }
    # Exported from Windows the .app cannot be code-signed, because the signing tools are
    # macOS-only. macOS will refuse to open it until the quarantine flag is cleared.
    macos   = @{ Name = "macOS"; Output = "build/macos/HeroesDuel.zip" }
    web     = @{ Name = "Web"; Output = "build/web/index.html" }
}
$wanted = if ($Target -eq "all") { @("windows", "macos", "web") } else { @($Target) }
$mode = if ($Debug) { "--export-debug" } else { "--export-release" }

# Rebuild the import cache first: a newly added image or script is invisible until then.
Write-Host "== Importing"
& $Godot --headless --path $root --import | Out-Null

$failed = @()
foreach ($key in $wanted) {
    $preset = $presets[$key]
    $output = Join-Path $root $preset.Output
    New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
    Write-Host "== Exporting $($preset.Name)"
    & $Godot --headless --path $root $mode $preset.Name $output
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $output)) {
        $failed += $preset.Name
        continue
    }
    $size = [math]::Round((Get-Item $output).Length / 1MB, 1)
    Write-Host "   $($preset.Output)  ($size MB)"
}

if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
Write-Host "Done."
exit 0
