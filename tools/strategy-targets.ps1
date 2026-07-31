function Get-DefaultStrategyTargets {
    @(
        [PSCustomObject]@{ Name = 'DiscordMain'; Url = 'https://discord.com'; Ping = 'discord.com' },
        [PSCustomObject]@{ Name = 'YouTubeWeb'; Url = 'https://www.youtube.com'; Ping = 'www.youtube.com' }
    )
}

function ConvertTo-SafeTargetName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $safe = [Regex]::Replace($Name.Trim(), '[^A-Za-z0-9_]+', '_').Trim('_')
    if (-not $safe) { throw 'Target name must contain a letter or number.' }
    if ($safe.Length -gt 48) { $safe = $safe.Substring(0, 48).TrimEnd('_') }
    if (-not $safe) { throw 'Target name is invalid.' }
    $safe
}

function Test-StrategyTargetHost {
    param([Parameter(Mandatory = $true)][string]$HostName)

    $candidate = $HostName.Trim()
    if (-not $candidate -or $candidate.Length -gt 253) { return $false }
    $address = $null
    if ([Net.IPAddress]::TryParse($candidate, [ref]$address)) { return $true }
    if ($candidate.EndsWith('.')) { $candidate = $candidate.TrimEnd('.') }
    if (-not $candidate -or $candidate.Length -gt 253) { return $false }
    foreach ($label in $candidate.Split('.')) {
        if ($label.Length -lt 1 -or $label.Length -gt 63) { return $false }
        if ($label -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$') { return $false }
    }
    return $true
}

function ConvertTo-StrategyTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $safeName = ConvertTo-SafeTargetName $Name
    $candidate = $Value.Trim()
    if ($candidate -match '^PING:(.+)$') {
        $pingHost = $matches[1].Trim()
        if (-not (Test-StrategyTargetHost $pingHost)) { throw 'Ping target must be a valid hostname or IP address.' }
        return [PSCustomObject]@{ Name = $safeName; Url = $null; Ping = $pingHost }
    }
    if ($candidate -notmatch '^[A-Za-z][A-Za-z0-9+.-]*:' -and (Test-StrategyTargetHost $candidate)) {
        return [PSCustomObject]@{ Name = $safeName; Url = $null; Ping = $candidate }
    }

    $uri = $null
    if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri)) {
        throw 'Target must be an http:// or https:// URL, or PING:hostname.'
    }
    if ($uri.Scheme -notin @('http', 'https') -or -not $uri.Host -or -not (Test-StrategyTargetHost $uri.Host)) {
        throw 'Only valid http:// and https:// URLs are accepted.'
    }
    if (-not [string]::IsNullOrEmpty($uri.UserInfo)) { throw 'URLs with embedded credentials are not accepted.' }
    if ($uri.Fragment) { throw 'URL fragments are not accepted.' }
    [PSCustomObject]@{ Name = $safeName; Url = $uri.AbsoluteUri; Ping = $uri.Host }
}

function Read-SavedStrategyTargets {
    param([Parameter(Mandatory = $true)][string]$Path)

    $items = @()
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        if ($line -notmatch '^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]+)"\s*$') {
            Write-Warning "Ignoring malformed target line: $line"
            continue
        }
        try {
            $items += ConvertTo-StrategyTarget -Name $matches[1] -Value $matches[2]
        } catch {
            Write-Warning "Ignoring invalid target '$($matches[1])': $($_.Exception.Message)"
        }
    }
    @($items)
}

function Save-StrategyTargets {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][array]$Targets
    )

    $normalized = @()
    $seen = @{}
    foreach ($target in $Targets) {
        $value = if ($target.Url) { [string]$target.Url } else { 'PING:' + [string]$target.Ping }
        $item = ConvertTo-StrategyTarget -Name ([string]$target.Name) -Value $value
        $key = $item.Name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { throw "Duplicate target name: $($item.Name)" }
        $seen[$key] = $true
        $normalized += $item
    }
    if ($normalized.Count -eq 0) { throw 'At least one target is required.' }

    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $lines = @($normalized | ForEach-Object {
        $value = if ($_.Url) { $_.Url } else { 'PING:' + $_.Ping }
        '{0}="{1}"' -f $_.Name, $value
    })
    $temporary = "$Path.$PID.tmp"
    try {
        [IO.File]::WriteAllText($temporary, (($lines -join "`r`n") + "`r`n"), [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    } finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

function Remove-SavedStrategyTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $safeName = ConvertTo-SafeTargetName $Name
    $targets = @(Read-SavedStrategyTargets -Path $Path | Where-Object { -not $_.Name.Equals($safeName, [StringComparison]::OrdinalIgnoreCase) })
    if ($targets.Count -eq 0) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    } else {
        Save-StrategyTargets -Path $Path -Targets $targets
    }
}

function Reset-SavedStrategyTargets {
    param([Parameter(Mandatory = $true)][string]$Path)
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Read-NewStrategyTargets {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$ReadInput,
        [array]$InitialTargets = @()
    )

    $targets = @($InitialTargets)
    while ($true) {
        $name = (& $ReadInput 'Target name (blank to finish)').Trim()
        if (-not $name) { break }
        $value = (& $ReadInput 'Full http(s) URL or PING:hostname').Trim()
        try {
            $newTarget = ConvertTo-StrategyTarget -Name $name -Value $value
            $targets = @($targets | Where-Object { -not $_.Name.Equals($newTarget.Name, [StringComparison]::OrdinalIgnoreCase) }) + @($newTarget)
            Write-Host "Added target: $($newTarget.Name)" -ForegroundColor Green
        } catch {
            Write-Host "Invalid target: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    @($targets)
}

function Show-StrategyTargets {
    param([array]$Targets)
    Write-Host ''
    Write-Host 'Selected targets:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $Targets.Count; $i++) {
        $value = if ($Targets[$i].Url) { $Targets[$i].Url } else { 'PING:' + $Targets[$i].Ping }
        Write-Host ('  [{0}] {1} = {2}' -f ($i + 1), $Targets[$i].Name, $value) -ForegroundColor Gray
    }
}

function Complete-StrategyTargetSelection {
    param([array]$Targets)
    Show-StrategyTargets -Targets $Targets
    @($Targets)
}

function Select-StrategyTargets {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [scriptblock]$ReadInput = { param([string]$Prompt) Read-Host $Prompt },
        [switch]$NonInteractive
    )

    while ($true) {
        $saved = @(Read-SavedStrategyTargets -Path $Path)
        Write-Host ''
        Write-Host 'Select test targets:' -ForegroundColor Cyan
        Write-Host '  [1] Use default Discord and YouTube targets'
        Write-Host '  [2] Add targets for this run only'
        Write-Host '  [3] Use selected saved targets'
        Write-Host '  [4] Add and save targets'
        Write-Host '  [5] Delete a saved target'
        Write-Host '  [6] Restore defaults (remove targets.txt)'
        $choice = (& $ReadInput 'Option (1-6)').Trim()

        if ($choice -eq '1') { return @(Complete-StrategyTargetSelection -Targets @(Get-DefaultStrategyTargets)) }
        if ($choice -eq '2') {
            $temporary = @(Read-NewStrategyTargets -ReadInput $ReadInput -InitialTargets @(Get-DefaultStrategyTargets))
            if ($temporary.Count -gt 0) { return @(Complete-StrategyTargetSelection -Targets $temporary) }
        } elseif ($choice -eq '3') {
            if ($saved.Count -eq 0) { Write-Host 'No saved targets. Add targets first.' -ForegroundColor Yellow; if ($NonInteractive) { throw 'No saved targets.' }; continue }
            Show-StrategyTargets $saved
            $raw = (& $ReadInput 'Saved target numbers, or 0 for all').Trim()
            if ($raw -eq '0') { return @(Complete-StrategyTargetSelection -Targets $saved) }
            if ($raw -match '^\d+(?:[ ,]+\d+)*$') {
                $indices = @($raw -split '[ ,]+' | ForEach-Object { [int]$_ } | Sort-Object -Unique)
                if (@($indices | Where-Object { $_ -lt 1 -or $_ -gt $saved.Count }).Count -eq 0) {
                    $selected = @($indices | ForEach-Object { $saved[$_ - 1] })
                    return @(Complete-StrategyTargetSelection -Targets $selected)
                }
            }
            Write-Host 'Invalid saved-target selection.' -ForegroundColor Yellow
            if ($NonInteractive) { throw 'Invalid saved-target selection.' }
        } elseif ($choice -eq '4') {
            $base = if ($saved.Count) { $saved } else { @() }
            $updated = @(Read-NewStrategyTargets -ReadInput $ReadInput -InitialTargets $base)
            if ($updated.Count -eq 0) { Write-Host 'No targets to save.' -ForegroundColor Yellow; continue }
            if (Test-Path -LiteralPath $Path) {
                $confirm = (& $ReadInput 'Replace existing targets.txt? (Y/N)').Trim()
                if ($confirm -notmatch '^(?i:y|yes)$') { Write-Host 'Existing targets.txt was preserved.' -ForegroundColor Yellow; continue }
            }
            Save-StrategyTargets -Path $Path -Targets $updated
            Write-Host "Saved targets to $Path" -ForegroundColor Green
            return @(Complete-StrategyTargetSelection -Targets $updated)
        } elseif ($choice -eq '5') {
            if ($saved.Count -eq 0) { Write-Host 'No saved targets to delete.' -ForegroundColor Yellow; continue }
            Show-StrategyTargets $saved
            $raw = (& $ReadInput 'Saved target number to delete').Trim()
            if ($raw -match '^\d+$' -and [int]$raw -ge 1 -and [int]$raw -le $saved.Count) {
                $confirm = (& $ReadInput "Delete $($saved[[int]$raw - 1].Name)? (Y/N)").Trim()
                if ($confirm -match '^(?i:y|yes)$') { Remove-SavedStrategyTarget -Path $Path -Name $saved[[int]$raw - 1].Name }
            } else { Write-Host 'Invalid saved-target number.' -ForegroundColor Yellow }
        } elseif ($choice -eq '6') {
            if (Test-Path -LiteralPath $Path) {
                $confirm = (& $ReadInput 'Remove targets.txt and restore defaults? (Y/N)').Trim()
                if ($confirm -notmatch '^(?i:y|yes)$') { continue }
            }
            Reset-SavedStrategyTargets -Path $Path
            Write-Host 'Default Discord and YouTube targets restored.' -ForegroundColor Green
            return @(Complete-StrategyTargetSelection -Targets @(Get-DefaultStrategyTargets))
        } else {
            Write-Host 'Invalid option.' -ForegroundColor Yellow
            if ($NonInteractive) { throw 'Invalid target-menu option.' }
        }
    }
}
