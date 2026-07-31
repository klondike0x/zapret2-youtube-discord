param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$profilesDir = Join-Path $root 'profiles'
$resultsDir = Join-Path $PSScriptRoot 'test results'
$exe = Join-Path $root 'bin\winws2.exe'
$targetsFile = Join-Path $PSScriptRoot 'targets.txt'
$targetsLibrary = Join-Path $PSScriptRoot 'strategy-targets.ps1'
if (-not (Test-Path -LiteralPath $targetsLibrary)) { throw 'strategy-targets.ps1 missing' }
. $targetsLibrary

function Exit-WithMessage {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Red,
        [int]$Code = 1
    )
    Write-Host $Message -ForegroundColor $Color
    if ($SelfTest) { exit $Code }
    Write-Host 'Press any key to close...' -ForegroundColor Yellow
    try { [void][Console]::ReadKey($true) } catch {}
    exit $Code
}

function Release-TestMutex {
    if ($script:testMutexAcquired) {
        try { $script:testMutex.ReleaseMutex() } catch {}
        $script:testMutexAcquired = $false
    }
    if ($script:testMutex) {
        $script:testMutex.Dispose()
        $script:testMutex = $null
    }
}

$script:testMutex = [Threading.Mutex]::new($false, 'Local\zapret2-youtube-discord-strategy-tests')
$script:testMutexAcquired = $script:testMutex.WaitOne(0)
if (-not $script:testMutexAcquired) {
    Exit-WithMessage '[ERROR] Strategy tests are already running.'
}

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

function Stop-TestEngine {
    param([Diagnostics.Process]$Process)
    if ($Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        try { [void]$Process.WaitForExit(3000) } catch {}
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
    $runId = [guid]::NewGuid().ToString('N')
    $tempName = "dry-service-$safe-$runId.txt"
    $temp = Join-Path $profilesDir $tempName
    try {
        $previousStrategyTest = $env:StrategyTest
        $env:StrategyTest = '1'
        $text = [IO.File]::ReadAllText($Profile.FullName)
        [IO.File]::WriteAllText($temp, "--dry-run`r`n" + ($text -replace "(?<!`r)`n", "`r`n"), [Text.UTF8Encoding]::new($false))
        $output = ''
        $ok = $false
        foreach ($attempt in 1..10) {
            $cmdFile = Join-Path $profilesDir "dry-service-$safe-$runId.cmd"
            $stdoutFile = Join-Path $profilesDir "dry-service-$safe-$runId.stdout"
            $stderrFile = Join-Path $profilesDir "dry-service-$safe-$runId.stderr"
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
        Remove-Item -LiteralPath (Join-Path $profilesDir "dry-service-$safe-$runId.cmd") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $profilesDir "dry-service-$safe-$runId.stdout") -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $profilesDir "dry-service-$safe-$runId.stderr") -Force -ErrorAction SilentlyContinue
        $env:StrategyTest = $previousStrategyTest
    }
}

function Start-TestEngine {
    param([IO.FileInfo]$Profile)
    $runtime = Join-Path $PSScriptRoot "strategy-test-$PID.txt"
    $stdout = Join-Path $PSScriptRoot "strategy-test-$PID.stdout"
    $stderr = Join-Path $PSScriptRoot "strategy-test-$PID.stderr"
    [IO.File]::WriteAllBytes($runtime, [IO.File]::ReadAllBytes($Profile.FullName))
    $process = $null
    try {
        $process = Start-Process -FilePath $exe -ArgumentList "@tools/$([IO.Path]::GetFileName($runtime))" -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $ready = $false
        foreach ($attempt in 1..40) {
            if ($process.HasExited) { break }
            $output = ((Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue))
            if ($output -match 'capture is started') { $ready = $true; break }
            Start-Sleep -Milliseconds 250
        }
        if (-not $ready) {
            Stop-TestEngine -Process $process
            Write-Host '  runtime did not report capture readiness' -ForegroundColor Red
            return $null
        }
        $process
    } catch {
        Stop-TestEngine -Process $process
        throw
    }
}

function Invoke-TargetChecks {
    param([array]$Targets, [Diagnostics.Process]$Process)
    $results = @()
    foreach ($target in $Targets) {
        if ($Process -and $Process.HasExited) { throw 'winws2 exited before target checks completed.' }
        $tokens = @()
        if ($target.Url) {
            foreach ($test in @(
                @{ Label='HTTP'; Args=@('--http1.1') },
                @{ Label='TLS1.2'; Args=@('--tlsv1.2','--tls-max','1.2') },
                @{ Label='TLS1.3'; Args=@('--tlsv1.3','--tls-max','1.3') }
            )) {
                $previousErrorAction = $ErrorActionPreference
                try {
                    $ErrorActionPreference = 'Continue'
                    & curl.exe -I -sS -m 6 -o NUL @($test.Args) $target.Url 2>$null
                    $curlExit = $LASTEXITCODE
                } catch {
                    $curlExit = 1
                } finally {
                    $ErrorActionPreference = $previousErrorAction
                }
                $tokens += if ($curlExit -eq 0) { "$($test.Label):OK" } else { "$($test.Label):ERROR" }
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
    if ($profiles.Count -eq 0) { throw 'no general profiles found' }
    $selfTestTargets = @(if (Test-Path -LiteralPath $targetsFile) { Read-SavedStrategyTargets -Path $targetsFile } else { Get-DefaultStrategyTargets })
    if ($selfTestTargets.Count -eq 0) { throw 'no valid strategy targets found' }
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
if ($profiles.Count -eq 0) {
    Exit-WithMessage '[ERROR] No general*.txt profiles were found.'
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Exit-WithMessage '[ERROR] Run the strategy test as Administrator.'
}
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Exit-WithMessage '[ERROR] curl.exe not found.'
}
if (Get-Service -Name 'winws2' -ErrorAction SilentlyContinue) {
    Exit-WithMessage '[ERROR] Remove the winws2 service before testing strategies.'
}
if ((Get-RunningWinws2).Count -gt 0) {
    Write-Host '[ERROR] Close manual winws2.exe before testing strategies.' -ForegroundColor Red
    Exit-WithMessage 'The test preserves processes it did not start and requires a clean network state.' -Color Yellow
}

$selected = @(Read-ProfileSelection -Profiles $profiles)
try {
    $targets = @(Select-StrategyTargets -Path $targetsFile)
    } catch {
        Exit-WithMessage ("[ERROR] Unable to configure test targets: {0}" -f $_.Exception.Message)
    }
    if ($targets.Count -eq 0) {
        Write-Host '[ERROR] No targets selected. Test cancelled.' -ForegroundColor Red
        Write-Host 'Press any key to close...'
        [void][Console]::ReadKey($true)
        exit 1
    }
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
$global = @()
$proc = $null
$runAborted = $false
$fatalError = $null

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
        $checks = @(Invoke-TargetChecks -Targets $targets -Process $proc)
        if ($proc.HasExited) { throw 'winws2 exited while target checks were running.' }
        $score = 0
        foreach ($check in $checks) {
            $score += $check.Score
            Write-Host ('  {0,-20} {1} Ping:{2}' -f $check.Name, ($check.Tokens -join ' '), $check.Ping)
        }
        $global += [PSCustomObject]@{ Profile=$profile.BaseName; Score=$score; Checks=$checks }
        Stop-TestEngine -Process $proc
        $proc = $null
    }
} catch {
    $runAborted = $true
    $fatalError = $_.Exception.Message
    Write-Host ''
    Write-Host "Strategy test failed: $fatalError" -ForegroundColor Red
    Write-Host 'The error was preserved on screen instead of closing the window.' -ForegroundColor Yellow
} finally {
    Stop-TestEngine -Process $proc
    Remove-Item -LiteralPath (Join-Path $PSScriptRoot "strategy-test-$PID.txt") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $PSScriptRoot "strategy-test-$PID.stdout") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $PSScriptRoot "strategy-test-$PID.stderr") -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '=== Transport observations ===' -ForegroundColor Cyan
foreach ($item in $global) { Write-Host ("{0}: score={1}" -f $item.Profile, $item.Score) }

$resultFile = Join-Path $resultsDir ("test_results_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
$maxPossible = @($targets | Where-Object { $_.Url }).Count * 3
$validResults = @($global | Where-Object { $_.Score -ge 0 })
$maxScore = if ($validResults.Count) { ($validResults | Measure-Object -Property Score -Maximum).Maximum } else { $null }
$topProfiles = if ($null -ne $maxScore) { @($validResults | Where-Object { $_.Score -eq $maxScore } | ForEach-Object { $_.Profile }) } else { @() }
$reportLines = [Collections.Generic.List[string]]::new()
$reportLines.Add('ZAPRET2 STRATEGY TEST REPORT')
$reportLines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$reportLines.Add(('Targets  : {0}' -f (($targets | ForEach-Object { $_.Name }) -join ', ')))
$reportLines.Add(('Run      : {0}' -f $(if ($runAborted) { 'ABORTED' } else { 'COMPLETED' })))
if ($runAborted) { $reportLines.Add(('Error    : {0}' -f $fatalError)) }
$reportLines.Add('')
$reportLines.Add('TRANSPORT SUMMARY')
$reportLines.Add(('Profile'.PadRight(32) + 'Score'.PadRight(10) + 'Result'))
$reportLines.Add(('-' * 62))
foreach ($item in $global) {
    $result = if ($item.Score -lt 0) { 'PARSER/RUNTIME ERROR' } elseif ($maxPossible -eq 0) { 'NO TRANSPORT CHECKS CONFIGURED' } elseif ($item.Score -eq $maxPossible) { 'ALL CHECKS PASSED' } elseif ($item.Score -eq 0) { 'NO HTTP/TLS CHECKS PASSED' } else { 'PARTIAL' }
    $scoreText = if ($item.Score -lt 0) { 'n/a' } else { '{0}/{1}' -f $item.Score, $maxPossible }
    $reportLines.Add(($item.Profile.PadRight(32) + $scoreText.PadRight(10) + $result))
}
$reportLines.Add('')
$reportLines.Add('MAXIMUM TRANSPORT SCORE')
if ($runAborted) {
    $reportLines.Add('RUN STATUS: ABORTED')
    $reportLines.Add('No maximum is reported for an incomplete run.')
} elseif ($maxPossible -eq 0) {
    $reportLines.Add('NO TRANSPORT CHECKS CONFIGURED')
} elseif ($topProfiles.Count) {
    $reportLines.Add(('Score   : {0}/{1}' -f $maxScore, $maxPossible))
    $reportLines.Add(('Profiles: {0}' -f ($topProfiles -join ', ')))
} else {
    $reportLines.Add('No profile completed the transport checks.')
}
$reportLines.Add('')
$reportLines.Add('DETAILED RESULTS')
foreach ($item in $global) {
    $reportLines.Add('')
    $reportLines.Add(('[{0}]' -f $item.Profile))
    $detailScore = if ($item.Score -lt 0) { 'n/a' } else { '{0}/{1}' -f $item.Score, $maxPossible }
    $reportLines.Add(('Score       : {0}' -f $detailScore))
    if (-not $item.Checks -or $item.Checks.Count -eq 0) {
        $reportLines.Add('Checks      : parser or runtime error')
        continue
    }
    foreach ($check in $item.Checks) {
        $reportLines.Add(('  {0}' -f $check.Name))
        $reportLines.Add(('    Transport: {0}' -f ($check.Tokens -join ', ')))
        $reportLines.Add(('    Ping     : {0}' -f $check.Ping))
    }
}
$reportLines.Add('')
$reportLines.Add('NOTES')
$reportLines.Add('* Scores count successful HTTP, TLS 1.2 and TLS 1.3 transport checks.')
$reportLines.Add('* Ping is informational and is not included in the score.')
$reportLines.Add('* An OK result may still be a block page or an HTTP error response.')
$reportLines.Add('* Results are specific to this network and do not prove universal bypass effectiveness.')
Set-Content -LiteralPath $resultFile -Value $reportLines -Encoding UTF8
Write-Host "Results saved to $resultFile" -ForegroundColor Green
Write-Host 'A successful curl connection may still be a block page or HTTP error.' -ForegroundColor Yellow
Write-Host 'This score is network-specific transport evidence, not proof of bypass or universal effectiveness.' -ForegroundColor Yellow
Release-TestMutex
Write-Host 'Press any key to close...'
[void][Console]::ReadKey($true)
if ($runAborted) { exit 1 }
