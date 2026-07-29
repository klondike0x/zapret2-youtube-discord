$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$controlPath = Join-Path $root 'tools\service-control.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($controlPath, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | ForEach-Object Message | Out-String) }

foreach ($name in @('Get-ImageExecutable', 'Get-ServiceConfigPath', 'Assert-CurrentOwner')) {
    $functionAst = $ast.Find({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if (-not $functionAst) { throw "Function not found: $name" }
    Invoke-Expression $functionAst.Extent.Text
}

$exe = 'C:\zapret\bundle\bin\winws2.exe'
$config = 'C:\zapret\bundle\tools\service-active.txt'
$cases = @(
    ('"{0}" @"{1}"' -f $exe, $config),
    ('{0} @{1}' -f $exe, $config),
    ('"{0}" @{1}' -f $exe, $config),
    ('{0} @"{1}"' -f $exe, $config)
)

foreach ($imagePath in $cases) {
    $actualExe = Get-ImageExecutable $imagePath
    $actualConfig = Get-ServiceConfigPath $imagePath
    if (-not $actualExe.Equals($exe, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Executable parse failed: $imagePath -> $actualExe"
    }
    if (-not $actualConfig.Equals($config, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Config parse failed: $imagePath -> $actualConfig"
    }
}

foreach ($invalid in @(
    'C:\other\winws2.exe',
    'C:\other\winws2.exe --wrong',
    'C:\other\winws2.exe @C:\config.txt extra'
)) {
    if (Get-ServiceConfigPath $invalid) { throw "Invalid ImagePath accepted: $invalid" }
}

$activeFull = $config
foreach ($imagePath in $cases) {
    Assert-CurrentOwner ([PSCustomObject]@{ PathName = $imagePath })
}

$foreignCases = @(
    ('C:\other\winws2.exe @{0}' -f $config),
    ('{0} @C:\other\service-active.txt' -f $exe),
    ('C:\other\winws2.exe @C:\other\service-active.txt')
)
foreach ($imagePath in $foreignCases) {
    $rejected = $false
    try {
        Assert-CurrentOwner ([PSCustomObject]@{ PathName = $imagePath })
    } catch {
        if ($_.Exception.Message -like 'Refusing to manage winws2 owned by another installation:*') {
            $rejected = $true
        } else {
            throw
        }
    }
    if (-not $rejected) { throw "Foreign service ownership accepted: $imagePath" }
}

Write-Output 'PASS quoted and unquoted winws2 ImagePath parsing with exact ownership rejection'
