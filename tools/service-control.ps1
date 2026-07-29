param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Remove', 'Start', 'Stop', 'Status')]
    [string]$Action,
    [string]$ProfilePath,
    [string]$ProfileRelative
)

$ErrorActionPreference = 'Stop'
$serviceName = 'winws2'
$legacyServiceName = 'zapret2-youtube-discord'
$displayName = 'zapret2 YouTube Discord'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$exe = [IO.Path]::GetFullPath((Join-Path $root 'bin\winws2.exe'))
$active = Join-Path $PSScriptRoot 'service-active.txt'
$activeFull = [IO.Path]::GetFullPath($active)
$next = Join-Path $PSScriptRoot 'service-next.txt'
$backup = Join-Path $PSScriptRoot 'service-backup.txt'
$prepare = Join-Path $PSScriptRoot 'prepare-service-profile.ps1'
$sc = 'C:\Windows\System32\sc.exe'
if (-not (Test-Path -LiteralPath $sc -PathType Leaf)) { throw "Trusted service controller not found: $sc" }
$controlMutex = [Threading.Mutex]::new($false, 'Global\zapret2-youtube-discord-service-control')
if (-not $controlMutex.WaitOne(0)) { throw 'Service manager is already running.' }

function Get-ServiceRecord([string]$Name) {
    Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
}

function Get-ImageExecutable([string]$ImagePath) {
    $expanded = [Environment]::ExpandEnvironmentVariables($ImagePath).Trim()
    if ($expanded.StartsWith('"')) {
        $end = $expanded.IndexOf('"', 1)
        if ($end -lt 2) { return $null }
        return [IO.Path]::GetFullPath($expanded.Substring(1, $end - 1))
    }
    $space = $expanded.IndexOf(' ')
    $value = if ($space -lt 0) { $expanded } else { $expanded.Substring(0, $space) }
    if (-not $value) { return $null }
    return [IO.Path]::GetFullPath($value)
}

function Get-ServiceConfigPath([string]$ImagePath) {
    if (-not $ImagePath) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($ImagePath).Trim()
    $match = [Regex]::Match($expanded, '^\s*"[^"]+"\s+@"([^"]+)"\s*$')
    if (-not $match.Success) { return $null }
    try { return [IO.Path]::GetFullPath($match.Groups[1].Value) } catch { return $null }
}

function Assert-CurrentOwner([object]$Service) {
    if (-not $Service) { return }
    $actual = Get-ImageExecutable $Service.PathName
    $actualConfig = Get-ServiceConfigPath $Service.PathName
    if (-not $actual -or -not $actual.Equals($exe, [StringComparison]::OrdinalIgnoreCase) -or
        -not $actualConfig -or -not $actualConfig.Equals($activeFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to manage winws2 owned by another installation: $($Service.PathName)"
    }
}

function Assert-ServiceStillOwned {
    $current = Get-ServiceRecord $serviceName
    if (-not $current) { throw "Service $serviceName disappeared during the operation." }
    Assert-CurrentOwner $current
    return $current
}

function Wait-ServiceState([string]$Name, [string]$State, [int]$Seconds = 15) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $record = Get-ServiceRecord $Name
        if ($State -eq 'Absent' -and -not $record) { return }
        if ($record -and $record.State -eq $State) { return }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    $actual = if ($record) { $record.State } else { 'Absent' }
    throw "Service $Name did not reach $State. Current state: $actual"
}

function Find-ServiceRecord([string]$Name, [int]$Seconds = 3) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $record = Get-ServiceRecord $Name
        if ($record) { return $record }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Stop-CurrentService([object]$Service) {
    if (-not $Service -or $Service.State -eq 'Stopped') { return }
    $Service = Assert-ServiceStillOwned
    Stop-Service -Name $serviceName -Force
    Wait-ServiceState $serviceName 'Stopped'
}

function Test-LegacyOwner([object]$Legacy) {
    if (-not $Legacy) { return $false }
    $expectedScript = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'run-service.ps1'))
    $trustedHost = [IO.Path]::GetFullPath('C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')
    $match = [Regex]::Match(
        $Legacy.PathName,
        '^\s*"([^"]+)"\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+"([^"]+)"\s+-ProfilePath\s+"([^"]+)"\s*$'
    )
    if (-not $match.Success) { return $false }
    $hostPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($match.Groups[1].Value))
    $actualScript = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($match.Groups[2].Value))
    $actualProfile = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($match.Groups[3].Value))
    $profileRoot = [IO.Path]::GetFullPath((Join-Path $root 'profiles')).TrimEnd('\') + '\'
    return $hostPath.Equals($trustedHost, [StringComparison]::OrdinalIgnoreCase) -and
        $actualScript.Equals($expectedScript, [StringComparison]::OrdinalIgnoreCase) -and
        $actualProfile.StartsWith($profileRoot, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-LegacyStillOwned {
    $legacy = Get-ServiceRecord $legacyServiceName
    if (-not $legacy) { throw "Legacy service $legacyServiceName disappeared during the operation." }
    if (-not (Test-LegacyOwner $legacy)) {
        throw "Legacy service $legacyServiceName changed ownership during the operation."
    }
    return $legacy
}

function Remove-LegacyIfOwned {
    $legacy = Get-ServiceRecord $legacyServiceName
    if (-not $legacy) { return }
    if (-not (Test-LegacyOwner $legacy)) {
        Write-Warning "Legacy service $legacyServiceName belongs to another installation and was preserved."
        return
    }
    if ($legacy.State -ne 'Stopped') {
        $legacy = Assert-LegacyStillOwned
        Stop-Service -Name $legacyServiceName -Force
        Wait-ServiceState $legacyServiceName 'Stopped'
    }
    [void](Assert-LegacyStillOwned)
    & $sc delete $legacyServiceName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete legacy service $legacyServiceName" }
    Wait-ServiceState $legacyServiceName 'Absent'
}

function Install-Profile {
    if (-not $ProfilePath -or -not $ProfileRelative) { throw 'ProfilePath and ProfileRelative are required.' }
    $existing = Get-ServiceRecord $serviceName
    Assert-CurrentOwner $existing
    $previousProfile = if ($existing) {
        (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name Profile -ErrorAction SilentlyContinue).Profile
    } else { $null }
    $previousBinaryPath = if ($existing) { $existing.PathName } else { $null }
    $previousStartMode = if ($existing) { $existing.StartMode } else { $null }
    $previousWasRunning = [bool]($existing -and $existing.State -eq 'Running')
    $activeExisted = Test-Path -LiteralPath $active
    $created = $false
    $createdRemoved = $false
    $updatedExisting = $false
    Remove-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue
    try {
        & $prepare -ProfilePath $ProfilePath -OutputPath $next
        if (-not (Test-Path -LiteralPath $next)) { throw 'Failed to prepare service profile.' }
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        if ($activeExisted) { Copy-Item -LiteralPath $active -Destination $backup -Force }
        Stop-CurrentService $existing
        Move-Item -LiteralPath $next -Destination $active -Force
        $binaryPath = '"{0}" @"{1}"' -f $exe, $active
        if (-not $existing) {
            New-Service -Name $serviceName -BinaryPathName $binaryPath -DisplayName $displayName -StartupType Automatic | Out-Null
            $created = $true
        } else {
            $updatedExisting = $true
            [void](Assert-ServiceStillOwned)
            & $sc config $serviceName binPath= $binaryPath start= auto | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Failed to update service configuration.' }
        }
        & $sc description $serviceName 'Zapret2 DPI bypass with a selectable Lua profile' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Failed to update service description.' }
        New-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name Profile -PropertyType String -Value $ProfileRelative -Force | Out-Null
        Start-Service -Name $serviceName
        Wait-ServiceState $serviceName 'Running'
        try { Remove-LegacyIfOwned } catch { Write-Warning "The new service is running, but legacy cleanup failed: $_" }
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        Write-Output "Service installed and running with $ProfileRelative."
    } catch {
        $installError = $_
        if (-not $existing -and -not $created) {
            $unexpected = Find-ServiceRecord $serviceName
            if ($unexpected) {
                try {
                    Assert-CurrentOwner $unexpected
                    $created = $true
                } catch {
                    Write-Warning "Unexpected service was preserved during rollback: $($_.Exception.Message)"
                }
            }
        }
        if ($created) {
            try {
                [void](Assert-ServiceStillOwned)
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                [void](Assert-ServiceStillOwned)
                & $sc delete $serviceName | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Rollback failed to delete the newly created service.' }
                Wait-ServiceState $serviceName 'Absent' 10
                $createdRemoved = $true
            } catch {
                Write-Warning "New service was preserved because safe rollback could not confirm ownership: $_"
            }
        }
        if (-not $existing -and -not $created) {
            if ($activeExisted -and (Test-Path -LiteralPath $backup)) {
                Move-Item -LiteralPath $backup -Destination $active -Force
            } elseif (-not $activeExisted) {
                Remove-Item -LiteralPath $active -Force -ErrorAction SilentlyContinue
            }
        }
        if (-not $created -and $existing) {
            $rollbackErrors = [Collections.Generic.List[string]]::new()
            try {
                if ($activeExisted -and (Test-Path -LiteralPath $backup)) {
                    Move-Item -LiteralPath $backup -Destination $active -Force
                } elseif (-not $activeExisted) {
                    Remove-Item -LiteralPath $active -Force -ErrorAction Stop
                }
            } catch { $rollbackErrors.Add("profile: $_") }
            try {
                [void](Assert-ServiceStillOwned)
                if ($updatedExisting) {
                    $restoreStart = switch ($previousStartMode) { 'Auto' { 'auto' } 'Disabled' { 'disabled' } default { 'demand' } }
                    [void](Assert-ServiceStillOwned)
                    & $sc config $serviceName binPath= $previousBinaryPath start= $restoreStart | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw 'Failed to restore service configuration.' }
                }
                [void](Assert-ServiceStillOwned)
                if ($null -ne $previousProfile) {
                    New-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name Profile -PropertyType String -Value $previousProfile -Force | Out-Null
                } else {
                    Remove-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name Profile -ErrorAction SilentlyContinue
                }
                if ($previousWasRunning) {
                    [void](Assert-ServiceStillOwned)
                    Start-Service -Name $serviceName
                    Wait-ServiceState $serviceName 'Running'
                }
            } catch { $rollbackErrors.Add("service: $_") }
            if ($rollbackErrors.Count) { Write-Warning "Rollback incomplete: $($rollbackErrors -join '; ')" }
        } elseif ($createdRemoved) {
            if ($activeExisted -and (Test-Path -LiteralPath $backup)) {
                Move-Item -LiteralPath $backup -Destination $active -Force
            } elseif (-not $activeExisted) {
                Remove-Item -LiteralPath $active -Force -ErrorAction SilentlyContinue
            }
        }
        throw $installError
    } finally {
        Remove-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue
    }
}

switch ($Action) {
    'Install' { Install-Profile }
    'Remove' {
        $service = Get-ServiceRecord $serviceName
        Assert-CurrentOwner $service
        if ($service) {
            Stop-CurrentService $service
            [void](Assert-ServiceStillOwned)
            & $sc delete $serviceName | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Failed to delete service.' }
            Wait-ServiceState $serviceName 'Absent'
        }
        Remove-Item -LiteralPath $active, $next, $backup -Force -ErrorAction SilentlyContinue
        Remove-LegacyIfOwned
        Write-Output 'Service removed.'
    }
    'Start' {
        $service = Get-ServiceRecord $serviceName
        if (-not $service) { throw 'Service winws2 is not installed.' }
        Assert-CurrentOwner $service
        Start-Service -Name $serviceName
        Wait-ServiceState $serviceName 'Running'
        Write-Output 'Service is running.'
    }
    'Stop' {
        $service = Get-ServiceRecord $serviceName
        if (-not $service) { throw 'Service winws2 is not installed.' }
        Stop-CurrentService $service
        Write-Output 'Service is stopped.'
    }
    'Status' {
        $service = Get-ServiceRecord $serviceName
        if (-not $service) {
            Write-Output 'Service winws2 is not installed.'
        } else {
            Assert-CurrentOwner $service
            $profile = (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name Profile -ErrorAction SilentlyContinue).Profile
            Write-Output "State: $($service.State)"
            Write-Output "PID: $($service.ProcessId)"
            Write-Output "Profile: $profile"
            Write-Output "ImagePath: $($service.PathName)"
        }
    }
}
