param(
    [Parameter(Mandatory = $true)]
    [string]$ProfilePath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'bin\winws2.exe'
$profile = (Resolve-Path -LiteralPath $ProfilePath).Path
$activeProfile = Join-Path $PSScriptRoot 'preset-active.txt'

Copy-Item -LiteralPath $profile -Destination $activeProfile -Force
Set-Location -LiteralPath $root
& $exe "@tools/preset-active.txt"
exit $LASTEXITCODE
