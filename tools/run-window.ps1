$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'bin\winws2.exe'
Set-Location -LiteralPath $root
& $exe "@tools/preset-active.txt"
exit $LASTEXITCODE
