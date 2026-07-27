param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$profilesDir = Join-Path $root 'profiles'
$resultsDir = Join-Path $PSScriptRoot 'test results'
$exe = Join-Path $root 'bin\winws2.exe'
$targetsFile = Join-Path $PSScriptRoot 'targets.txt'

function Get-Profiles {
    @(Get-ChildItem -LiteralPath $profilesDir -File -Filter 'general*.txt' |
        Sort-Object { [Regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) })
}

function Read-ProfileSelection {
    param([array]$Profiles)
    Write-Host ''
    Write-Host 'Select profiles:' -ForegroundColor Cyan
    Write-Host '  [0] All profiles' -ForegroundColor Gray
    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        Write-Host ('  [{0}] {1}' -f ($i + 1), $Profiles[$i].BaseName) -ForegroundColor Gray
    }
    while ($true) {
        $raw = (Read-Host 'Numbers/ranges (example: 1,3-6), 0 for all').Trim()
        if ($raw -eq '0') { return $Profiles }
        $indices = New-Object Collections.Generic.List[int]
        $validFormat = $true
        foreach ($part in ($raw -split '[,\s]+' | Where-Object { $_ })) {
            if ($part -match '^(\d+)-(\d+)$') {
                $first = [int]$matches[1]
                $last = [int]$matches[2]
                if ($first -gt $last) { $validFormat = $false; break }
                for ($n = $first; $n -le $last; $n++) { $indices.Add($n) }
            } elseif ($part -match '^\d+$') {
                $indices.Add([int]$part)
            } else {
                $validFormat = $false
                break
            }
        }
        $indices = @($indices | Sort-Object -Unique | Where-Object { $_ -ge 1 -and $_ -le $Profiles.Count })
        if ($validFormat -and $indices.Count -gt 0) {
            return @($indices | ForEach-Object { $Profiles[$_ - 1] })
        }
        Write-Host 'Invalid selection.' -ForegroundColor Yellow
    }
}

function Get-Targets {
    $items = @()
    if (Test-Path -LiteralPath $targetsFile) {
        foreach ($line in Get-Content -LiteralPath $targetsFile) {
            if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]+)"\s*$') {
                $value = $matches[2]
                $items += [PSCustomObject]@{
                    Name = $matches[1]
                    Url = if ($value -like 'PING:*') { $null } else { $value }
                    Ping = if ($value -like 'PING:*') { $value.Substring(5) } else { ([Uri]$value).Host }
                }
            }
        }
    }
    if ($items.Count -eq 0) {
        $items = @(
            [PSCustomObject]@{ Name='DiscordMain'; Url='https://discord.com'; Ping='discord.com' },
            [PSCustomObject]@{ Name='YouTubeWeb'; Url='https://www.youtube.com'; Ping='www.youtube.com' }
        )
    }
    $items
}

function Stop-TestEngine {
    param([Diagnostics.Process]$Process)
    if ($Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        try { $Process.WaitForExit(3000) } catch {}
    }
    Start-Sleep -Milliseconds 350
}

function Get-RunningWinws2 {
    try {
        @(Get-CimInstance Win32_Process -Filter "Name='winws2.exe'" -ErrorAction Stop)
    } catch {
        @(Get-Process -Name 'winws2' -ErrorAction SilentlyContinue)
    }
}

function Test-ProfileSyntax {
    param([IO.FileInfo]$Profile)
    $safe = [Regex]::Replace($Profile.BaseName, '[^A-Za-z0-9_-]', '-')
    $tempName = "dry-service-$safe.txt"
    $temp = Join-Path $profilesDir $tempName
    try {
        $previousStrategyTest = $env:StrategyTest
        $env:StrategyTest = '1'
        $text = [IO.File]::ReadAllText($Profile.FullName)
        [IO.File]::WriteAllText($temp, "--dry-run`r`n" + ($text -replace "(?<!`r)`n", "`r`n"), [Text.UTF8Encoding]::new($false))
        $output = ''
        $ok = $false
        foreach ($attempt in 1..10) {
            $cmdFile = Join-Path $profilesDir "dry-service-$safe.cmd"
            $stdoutFile = Join-Path $profilesDir "dry-service-$safe.stdout"
            $stderrFile = Join-Path $profilesDir "dry-service-$safe.stderr"
            $commandText = "@echo off`r`n`"$exe`" @profiles/$tempName`r`nexit /b %errorlevel%`r`n"
            [IO.File]::WriteAllText($cmdFile, $commandText, [Text.Encoding]::ASCII)
            $probe = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',"`"$cmdFile`"") -WorkingDirectory $root -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
            $output = ((Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue))
            $ok = ($probe.ExitCode -eq 0 -and $output -match 'parameters verified')
            if ($ok) { break }
            # On Windows a just-exited Cygwin winws2 instance can briefly keep
            # the single-instance primitive without returning diagnostic text.
            if ($output -and $output -notmatch 'copy of winws2 is already running') { break }
            Start-Sleep -Milliseconds (300 * $attempt)
        }
        [PSCustomObject]@{ Ok = $ok; Output = $output.Trim() }
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $profilesDir "dry-service-$safe.cmd") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $profilesDir "dry-service-$safe.stdout") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $profilesDir "dry-service-$safe.stderr") -Force -ErrorAction SilentlyContinue
        $env:StrategyTest = $previousStrategyTest
    }
}

function Start-TestEngine {
    param([IO.FileInfo]$Profile)
    $runtime = Join-Path $PSScriptRoot 'strategy-test-active.txt'
    [IO.File]::WriteAllBytes($runtime, [IO.File]::ReadAllBytes($Profile.FullName))
    $process = Start-Process -FilePath $exe -ArgumentList '@tools/strategy-test-active.txt' -WorkingDirectory $root -WindowStyle Minimized -PassThru
    Start-Sleep -Seconds 4
    if ($process.HasExited) { return $null }
    $process
}

function Invoke-TargetChecks {
    param([array]$Targets)
    $results = @()
    foreach ($target in $Targets) {
        $tokens = @()
        if ($target.Url) {
            foreach ($test in @(
                @{ Label='HTTP'; Args=@('--http1.1') },
                @{ Label='TLS1.2'; Args=@('--tlsv1.2','--tls-max','1.2') },
                @{ Label='TLS1.3'; Args=@('--tlsv1.3','--tls-max','1.3') }
            )) {
                & curl.exe -I -sS -m 6 -o NUL @($test.Args) $target.Url 2>$null
                $tokens += if ($LASTEXITCODE -eq 0) { "$($test.Label):OK" } else { "$($test.Label):ERROR" }
            }
        }
        $pingOk = Test-Connection -ComputerName $target.Ping -Count 1 -Quiet -ErrorAction SilentlyContinue
        $results += [PSCustomObject]@{
            Name = $target.Name
            Tokens = $tokens
            Ping = if ($pingOk) { 'OK' } else { 'Timeout' }
            Score = @($tokens | Where-Object { $_ -like '*:OK' }).Count
        }
    }
    $results
}

$profiles = Get-Profiles
if ($SelfTest) {
    if (-not (Test-Path -LiteralPath $exe)) { throw 'winws2.exe missing' }
    if ($profiles.Count -lt 23) { throw "expected at least 23 profiles, got $($profiles.Count)" }
    $runningForSelfTest = @(Get-RunningWinws2)
    if ($runningForSelfTest.Count -gt 0) {
        Write-Output "SELFTEST STRUCTURE PASS: $($profiles.Count) Zapret2 profiles; parser dry-run skipped because winws2.exe is already running"
        exit 0
    }
    foreach ($profile in $profiles) {
        $raw = [IO.File]::ReadAllBytes($profile.FullName)
        if (-not ([Text.Encoding]::UTF8.GetString($raw) -match '--lua-init=.*zapret-antidpi.lua')) {
            throw "$($profile.Name): Zapret2 Lua initialization missing"
        }
        $syntax = Test-ProfileSyntax -Profile $profile
        if (-not $syntax.Ok) {
            throw "$($profile.Name): parser dry-run failed: $($syntax.Output)"
        }
    }
    Write-Output "SELFTEST PARSER PASS: $($profiles.Count) Zapret2 profiles"
    exit 0
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '[ERROR] Run the strategy test as Administrator.' -ForegroundColor Red
    exit 1
}
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Host '[ERROR] curl.exe not found.' -ForegroundColor Red
    exit 1
}
if (Get-Service -Name 'winws2' -ErrorAction SilentlyContinue) {
    Write-Host '[ERROR] Remove the winws2 service before testing strategies.' -ForegroundColor Red
    exit 1
}
if ((Get-RunningWinws2).Count -gt 0) {
    Write-Host '[ERROR] Close manual winws2.exe before testing strategies.' -ForegroundColor Red
    Write-Host '        The test preserves processes it did not start and requires a clean network state.' -ForegroundColor Yellow
    exit 1
}

$selected = @(Read-ProfileSelection -Profiles $profiles)
$targets = @(Get-Targets)
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
$global = @()
$proc = $null

try {
    foreach ($profile in $selected) {
        Write-Host ''
        Write-Host "=== $($profile.BaseName) ===" -ForegroundColor Cyan
        Stop-TestEngine -Process $proc
        $proc = $null
        $syntax = Test-ProfileSyntax -Profile $profile
        if (-not $syntax.Ok) {
            Write-Host "  parser: ERROR $($syntax.Output)" -ForegroundColor Red
            $global += [PSCustomObject]@{ Profile=$profile.BaseName; Score=-1; Checks=@() }
            continue
        }
        Write-Host '  parser: parameters verified' -ForegroundColor Green
        $proc = Start-TestEngine -Profile $profile
        if (-not $proc) {
            Write-Host '  runtime: winws2 exited during initialization' -ForegroundColor Red
            $global += [PSCustomObject]@{ Profile=$profile.BaseName; Score=-1; Checks=@() }
            continue
        }
        Write-Host '  runtime: winws2 is running; checking targets...' -ForegroundColor Green
        $checks = @(Invoke-TargetChecks -Targets $targets)
        $score = 0
        foreach ($check in $checks) {
            $score += $check.Score
            Write-Host ('  {0,-20} {1} Ping:{2}' -f $check.Name, ($check.Tokens -join ' '), $check.Ping)
        }
        $global += [PSCustomObject]@{ Profile=$profile.BaseName; Score=$score; Checks=$checks }
        Stop-TestEngine -Process $proc
        $proc = $null
    }
} finally {
    Stop-TestEngine -Process $proc
    Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'strategy-test-active.txt') -Force -ErrorAction SilentlyContinue
}

$best = $global | Sort-Object Score -Descending | Select-Object -First 1
Write-Host ''
Write-Host '=== ANALYTICS ===' -ForegroundColor Cyan
foreach ($item in $global) { Write-Host ("{0}: score={1}" -f $item.Profile, $item.Score) }
if ($best -and $best.Score -ge 0) {
    Write-Host "Highest transport-check score: $($best.Profile)" -ForegroundColor Green
} else {
    Write-Host 'Highest transport-check score: not determined' -ForegroundColor Yellow
}

$resultFile = Join-Path $resultsDir ("test_results_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
$global | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultFile -Encoding UTF8
Write-Host "Results saved to $resultFile" -ForegroundColor Green
Write-Host 'A successful curl connection may still be a block page or HTTP error.' -ForegroundColor Yellow
Write-Host 'This score is network-specific transport evidence, not proof of bypass or universal effectiveness.' -ForegroundColor Yellow
Write-Host 'Press any key to close...'
[void][Console]::ReadKey($true)
