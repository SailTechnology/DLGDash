# Requires PowerShell 7. Tests extracted release files, never a real radio.
param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [string]$NodeExecutable = 'node',
    [switch]$ZorroOnly
)
$ErrorActionPreference = 'Stop'
$zip = (Resolve-Path -LiteralPath $Archive).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DLGDash-package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $testRoot
$sd = Join-Path $testRoot 'SD'
$widget = Join-Path $sd 'WIDGETS/DLGDash'
foreach ($folder in @('profiles', 'diagnostics')) {
    if (-not (Test-Path -LiteralPath (Join-Path $widget $folder) -PathType Container)) { throw "Missing save directory: $folder" }
}
foreach ($file in Get-ChildItem -LiteralPath $sd -Recurse -File) {
    $relative = [IO.Path]::GetRelativePath($sd, $file.FullName).Replace('\', '/')
    if ($relative -match '(^|/)(MODELS|RADIO|profiles|diagnostics|node_modules)(/|$)|\.(luac|exe|c)$') { throw "Unexpected release file: $relative" }
}
if ($ZorroOnly) {
    $allowed = @('compat.lua', 'profile.lua', 'core.lua', 'settings.lua', 'settings-pages.lua', 'diagnostics.lua', 'mono-ui.lua', 'mono-settings.lua')
    $actual = @(Get-ChildItem -LiteralPath $widget -File | Select-Object -ExpandProperty Name)
    if (Compare-Object $allowed $actual) { throw 'Zorro runtime file set differs from its monochrome allowlist' }
    foreach ($name in @('zh', 'zh.lua')) {
        if (Test-Path -LiteralPath (Join-Path $widget ('lang/' + $name))) { throw 'Color language assets leaked into Zorro package' }
    }
    foreach ($name in @('README.md', 'INSTALL-ZORRO.md', 'images/zorro-large.png', 'images/zorro-servos-large.png', 'images/zorro-settings-large.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sd $name))) { throw "Missing Zorro guide asset: $name" }
    }
}
$runner = Join-Path $PSScriptRoot 'run-mono.cjs'
& $NodeExecutable $runner --zorro --legacy --sd-root $sd
if ($LASTEXITCODE -ne 0) { throw 'Packaged Zorro legacy tests failed' }
& $NodeExecutable $runner --zorro --sd-root $sd
if ($LASTEXITCODE -ne 0) { throw 'Packaged Zorro modern tests failed' }
[pscustomobject]@{ Archive=$zip; ExtractedSD=$sd; Status='PASS'; HardwareUsed=$false } | ConvertTo-Json
