param(
    [Parameter(Mandatory = $true)]
    [string]$ProfilePath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$profile = (Resolve-Path -LiteralPath $ProfilePath).Path
$target = if ($OutputPath) { [IO.Path]::GetFullPath($OutputPath) } else { Join-Path $PSScriptRoot 'service-active.txt' }
$rootForConfig = $root.Replace('\', '/')
$raw = [IO.File]::ReadAllBytes($profile)
$prefix = [Text.Encoding]::UTF8.GetBytes("--chdir=$rootForConfig`r`n")
$combined = New-Object byte[] ($prefix.Length + $raw.Length)
[Array]::Copy($prefix, 0, $combined, 0, $prefix.Length)
[Array]::Copy($raw, 0, $combined, $prefix.Length, $raw.Length)
[IO.File]::WriteAllBytes($target, $combined)
Write-Output $target
