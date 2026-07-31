$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$library = Join-Path $root 'tools\strategy-targets.ps1'
if (-not (Test-Path -LiteralPath $library)) {
    throw 'Missing tools/strategy-targets.ps1'
}
. $library

foreach ($name in @(
    'Get-DefaultStrategyTargets',
    'ConvertTo-SafeTargetName',
    'ConvertTo-StrategyTarget',
    'Read-SavedStrategyTargets',
    'Save-StrategyTargets',
    'Remove-SavedStrategyTarget',
    'Reset-SavedStrategyTargets',
    'Complete-StrategyTargetSelection',
    'Select-StrategyTargets'
)) {
    if (-not (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "Missing function: $name"
    }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('zapret2-target-tests-' + [guid]::NewGuid().ToString('N'))
$targetsPath = Join-Path $tempDir 'targets.txt'
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $defaults = @(Get-DefaultStrategyTargets)
    Assert-True ($defaults.Count -eq 2) 'Expected Discord and YouTube defaults'
    Assert-True (@($defaults | Where-Object Name -eq 'DiscordMain').Count -eq 1) 'Discord default missing'
    Assert-True (@($defaults | Where-Object Name -eq 'YouTubeWeb').Count -eq 1) 'YouTube default missing'

    $safeName = ConvertTo-SafeTargetName ' My custom-target! '
    Assert-True ($safeName -eq 'My_custom_target') "Unsafe target name normalization: $safeName"

    $urlTarget = ConvertTo-StrategyTarget -Name 'Custom Web' -Value 'https://example.com/path?q=1'
    Assert-True ($urlTarget.Name -eq 'Custom_Web') 'URL target name was not normalized'
    Assert-True ($urlTarget.Url -eq 'https://example.com/path?q=1') 'Valid HTTPS URL was changed'
    Assert-True ($urlTarget.Ping -eq 'example.com') 'URL host was not selected for ping'

    $pingTarget = ConvertTo-StrategyTarget -Name 'DNS test' -Value 'PING:1.1.1.1'
    Assert-True ($null -eq $pingTarget.Url) 'Ping-only target unexpectedly has URL'
    Assert-True ($pingTarget.Ping -eq '1.1.1.1') 'Valid ping IP was rejected'

    $barePingTarget = ConvertTo-StrategyTarget -Name 'Discord ping' -Value 'discord.com'
    Assert-True ($null -eq $barePingTarget.Url) 'Bare hostname unexpectedly has URL'
    Assert-True ($barePingTarget.Ping -eq 'discord.com') 'Bare ping hostname was rejected'

    foreach ($invalid in @(
        'ftp://example.com',
        'https://user:password@example.com',
        'PING:bad host',
        'PING:example.com;Remove-Item C:\',
        'not a target'
    )) {
        $rejected = $false
        try { [void](ConvertTo-StrategyTarget -Name 'Unsafe' -Value $invalid) } catch { $rejected = $true }
        Assert-True $rejected "Unsafe target accepted: $invalid"
    }

    Save-StrategyTargets -Path $targetsPath -Targets @($urlTarget, $pingTarget)
    $saved = @(Read-SavedStrategyTargets -Path $targetsPath)
    Assert-True ($saved.Count -eq 2) 'Saved targets were not read back'
    Assert-True ((Get-Content -LiteralPath $targetsPath -Raw) -match 'Custom_Web\s*=\s*"https://example.com/path\?q=1"') 'Existing targets.txt format changed'

    Remove-SavedStrategyTarget -Path $targetsPath -Name 'Custom Web'
    $remaining = @(Read-SavedStrategyTargets -Path $targetsPath)
    Assert-True ($remaining.Count -eq 1 -and $remaining[0].Name -eq 'DNS_test') 'Saved target removal failed'

    Reset-SavedStrategyTargets -Path $targetsPath
    Assert-True (-not (Test-Path -LiteralPath $targetsPath)) 'Reset did not remove targets.txt'

    $script:answers = [Collections.Generic.Queue[string]]::new()
    @('2', 'Temporary target', 'https://example.org', '') | ForEach-Object { $script:answers.Enqueue($_) }
    $reader = { param([string]$Prompt) if ($script:answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:answers.Dequeue() }
    $temporary = @(Select-StrategyTargets -Path $targetsPath -ReadInput $reader -NonInteractive)
    Assert-True ($temporary.Count -eq 3) 'Temporary target selection should include defaults and one custom target'
    Assert-True (@($temporary | Where-Object Name -eq 'Temporary_target').Count -eq 1) 'Temporary custom target missing'
    Assert-True (-not (Test-Path -LiteralPath $targetsPath)) 'Temporary target was persisted unexpectedly'

    Save-StrategyTargets -Path $targetsPath -Targets @($urlTarget)
    $script:answers = [Collections.Generic.Queue[string]]::new()
    @('3', '1') | ForEach-Object { $script:answers.Enqueue($_) }
    $savedReader = { param([string]$Prompt) if ($script:answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:answers.Dequeue() }
    $selectedSaved = @(Select-StrategyTargets -Path $targetsPath -ReadInput $savedReader -NonInteractive)
    Assert-True ($selectedSaved.Count -eq 1 -and $selectedSaved[0].Name -eq 'Custom_Web') 'Saved target selection failed'

    $script:answers = [Collections.Generic.Queue[string]]::new()
    @('4', 'Replacement', 'https://example.net', '', 'N', '3', '1') | ForEach-Object { $script:answers.Enqueue($_) }
    $preserveReader = { param([string]$Prompt) if ($script:answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:answers.Dequeue() }
    $preserved = @(Select-StrategyTargets -Path $targetsPath -ReadInput $preserveReader -NonInteractive)
    Assert-True ($preserved.Count -eq 1 -and $preserved[0].Name -eq 'Custom_Web') 'Declining overwrite did not preserve targets.txt'
    Assert-True (@(Read-SavedStrategyTargets -Path $targetsPath | Where-Object Name -eq 'Replacement').Count -eq 0) 'Declined replacement was written'

    $script:answers = [Collections.Generic.Queue[string]]::new()
    @('5', '1', 'Y', '6') | ForEach-Object { $script:answers.Enqueue($_) }
    $deleteReader = { param([string]$Prompt) if ($script:answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:answers.Dequeue() }
    $afterDelete = @(Select-StrategyTargets -Path $targetsPath -ReadInput $deleteReader -NonInteractive)
    Assert-True (-not (Test-Path -LiteralPath $targetsPath)) 'Interactive delete did not remove the final saved target'
    Assert-True ($afterDelete.Count -eq 2) 'Interactive delete did not return restored defaults'

    Save-StrategyTargets -Path $targetsPath -Targets @($urlTarget)
    $script:answers = [Collections.Generic.Queue[string]]::new()
    @('6', 'Y') | ForEach-Object { $script:answers.Enqueue($_) }
    $resetReader = { param([string]$Prompt) if ($script:answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $script:answers.Dequeue() }
    $afterReset = @(Select-StrategyTargets -Path $targetsPath -ReadInput $resetReader -NonInteractive)
    Assert-True (-not (Test-Path -LiteralPath $targetsPath)) 'Interactive reset did not remove targets.txt'
    Assert-True ($afterReset.Count -eq 2) 'Interactive reset did not return defaults'

    Write-Output 'PASS interactive strategy target validation, persistence, removal, reset and scripted selection'
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
