param(
    [Parameter(Mandatory = $true)]
    [string]$ProfilePath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'bin\winws2.exe'
$profile = (Resolve-Path -LiteralPath $ProfilePath).Path
$activeProfile = Join-Path $PSScriptRoot 'preset-active.txt'

# Cygwin getopt в winws2 чувствителен к пробелам и кириллице в имени
# @config. Runtime-копия всегда имеет безопасное ASCII-имя.
Copy-Item -LiteralPath $profile -Destination $activeProfile -Force
exit 0
