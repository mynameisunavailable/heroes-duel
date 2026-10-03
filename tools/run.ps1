<#
.SYNOPSIS
    Runs the game. Any extra arguments are passed straight to Godot.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/run.ps1
    powershell -ExecutionPolicy Bypass -File tools/run.ps1 --resolution 1280x720
.PARAMETER Godot
    Path to the Godot executable. Defaults to $env:GODOT, then
    ..\tools\godot\4.7.2\ beside this repository, then "godot" on PATH.
#>
param(
    [string]$Godot = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Godot) {
    $local = Join-Path $root "..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
    if ($env:GODOT) { $Godot = $env:GODOT }
    elseif (Test-Path $local) { $Godot = (Resolve-Path $local).Path }
    else { $Godot = "godot" }
}

$arguments = @("--path", $root)
if ($GodotArgs) { $arguments += $GodotArgs }

Write-Host "Running Heroes Duel. Close the window, or press Esc then Quit, to stop."
& $Godot @arguments
exit $LASTEXITCODE
