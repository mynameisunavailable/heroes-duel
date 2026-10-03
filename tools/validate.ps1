<#
.SYNOPSIS
    Validates the project headlessly: import, smoke test, and a 300-frame boot run whose
    log is scanned for errors. Exits non-zero on any failure.
.PARAMETER Godot
    Path to the Godot console executable. Defaults to $env:GODOT, then
    ..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe beside this repository,
    then "godot" on PATH.
#>
param([string]$Godot = "")

$ErrorActionPreference = "Continue"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Godot) {
    $local = Join-Path $root "..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    if ($env:GODOT) { $Godot = $env:GODOT }
    elseif (Test-Path $local) { $Godot = (Resolve-Path $local).Path }
    else { $Godot = "godot" }
}
$build = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null
$errorPattern = 'SCRIPT ERROR|Parse Error|ERROR:'
$failures = @()

function Invoke-Godot([string]$Name, [string[]]$GodotArgs) {
    $out = Join-Path $build "$Name.out.log"
    $err = Join-Path $build "$Name.err.log"
    $proc = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $proc.Handle
    $proc.WaitForExit()
    $text = "$(Get-Content $out -Raw)`n$(Get-Content $err -Raw)"
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = $text }
}

Write-Host "== Import"
$r = Invoke-Godot "import" @("--headless", "--path", "`"$root`"", "--import")
if ($r.ExitCode -ne 0 -or $r.Output -match $errorPattern) { $failures += "import"; Write-Host $r.Output }

Write-Host "== Smoke test"
$r = Invoke-Godot "smoke" @("--headless", "--path", "`"$root`"", "-s", "res://tools/smoke_test.gd")
Write-Host $r.Output.Trim()
if ($r.ExitCode -ne 0 -or $r.Output -notmatch 'SMOKE OK' -or $r.Output -match $errorPattern) { $failures += "smoke test" }

Write-Host "== Unit tests (GUT)"
if (Test-Path (Join-Path $root "addons/gut/gut_cmdln.gd")) {
    $r = Invoke-Godot "gut" @("--headless", "--path", "`"$root`"", "-s", "addons/gut/gut_cmdln.gd",
        "-gdir=res://tests/unit", "-ginclude_subdirs", "-gexit")
    $summary = ($r.Output -split "`n" | Select-String -Pattern 'Tests\s+\d+|Passing Tests|Failing Tests|All tests passed') -join "; "
    if ($summary) { Write-Host $summary.Trim() }
    if ($r.ExitCode -ne 0) { $failures += "unit tests"; Write-Host $r.Output }
} else {
    Write-Host "GUT is not installed in addons/gut; skipping."
}

Write-Host "== Boot run (300 frames)"
$r = Invoke-Godot "boot" @("--headless", "--path", "`"$root`"", "--quit-after", "300")
if ($r.ExitCode -ne 0 -or $r.Output -match $errorPattern) { $failures += "boot run"; Write-Host $r.Output }

if ($failures.Count -gt 0) {
    Write-Host "FAILED: $($failures -join ', ')"
    exit 1
}
Write-Host "All checks passed."
exit 0
