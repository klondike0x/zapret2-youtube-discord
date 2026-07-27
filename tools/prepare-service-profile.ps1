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
$source = [IO.File]::ReadAllText($profile, [Text.Encoding]::UTF8)
$normalized = $source.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
$content = "--chdir=$rootForConfig`r`n$normalized"
[IO.File]::WriteAllText($target, $content, (New-Object Text.UTF8Encoding($false)))
Write-Output $target
