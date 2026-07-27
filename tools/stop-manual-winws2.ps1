$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$exe = [IO.Path]::GetFullPath((Join-Path $root 'bin\winws2.exe'))
$stopped = 0

$servicePid = 0
try {
    $service = Get-CimInstance Win32_Service -Filter "Name='winws2'" -ErrorAction Stop
    if ($service.State -ne 'Stopped') { $servicePid = [int]$service.ProcessId }
} catch {}

$processes = @(Get-CimInstance Win32_Process -Filter "Name='winws2.exe'" -ErrorAction SilentlyContinue)
foreach ($process in $processes) {
    $path = $process.ExecutablePath
    if (-not $path) { continue }
    try { $path = [IO.Path]::GetFullPath($path) } catch { continue }
    if ($path -ne $exe -or [int]$process.ProcessId -eq $servicePid) { continue }

    $commandLine = [string]$process.CommandLine
    if ($commandLine -notmatch '@tools[\\/]preset-active\.txt') { continue }

    Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction Stop
    $stopped++
}

Write-Output $stopped
