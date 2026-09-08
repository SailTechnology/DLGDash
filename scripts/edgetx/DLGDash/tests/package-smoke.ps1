# Tests extracted release files, never a real radio.
param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [string]$NodeExecutable = 'node',
    [Parameter(Mandatory = $true)][ValidateSet('Color', 'Monochrome')][string]$Target,
    [switch]$AllRadios
)
$ErrorActionPreference = 'Stop'
$zip = (Resolve-Path -LiteralPath $Archive).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DLGDash-package-' + [guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $zip -DestinationPath $testRoot
$sd = Join-Path $testRoot 'SD'
$widget = Join-Path $sd 'WIDGETS/DLGDash'
if (-not (Test-Path -LiteralPath (Join-Path $sd 'RADIOS.md'))) { throw 'Missing radio guide' }
if (Test-Path -LiteralPath (Join-Path $widget 'radios.json')) { throw 'Host radio catalog must not consume radio runtime memory' }
for ($page = 1; $page -le 10; $page++) {
    $pageFile = Join-Path $widget "pages/$page.lua"
    if (-not (Test-Path -LiteralPath $pageFile -PathType Leaf)) { throw "Missing page: $page" }
    if ((Get-Item -LiteralPath $pageFile).Length -gt 1200) { throw "Page compile size grew: $page" }
}
foreach ($folder in @('profiles', 'diagnostics')) {
    if (-not (Test-Path -LiteralPath (Join-Path $widget $folder) -PathType Container)) { throw "Missing save directory: $folder" }
}
foreach ($file in Get-ChildItem -LiteralPath $sd -Recurse -File) {
    $relative = [IO.Path]::GetRelativePath($sd, $file.FullName).Replace('\', '/')
    if ($relative -match '(^|/)(MODELS|RADIO|profiles|diagnostics|node_modules)(/|$)|\.(luac|exe|c)$') { throw "Unexpected release file: $relative" }
}
$allowed = @('compat.lua','profile.lua','core.lua','settings.lua','settings-pages.lua','diagnostics.lua')
if ($Target -eq 'Monochrome') { $allowed += @('mono-ui.lua','mono-settings.lua') }
else { $allowed += @('draw.lua','color-settings.lua','main.lua','locale.lua') }
$actual = @(Get-ChildItem -LiteralPath $widget -File | Select-Object -ExpandProperty Name)
if (Compare-Object $allowed $actual) { throw 'Runtime does not match screen type' }
$forbidden = if ($Target -eq 'Monochrome') { @('zh','zh.lua') } else { @('mono','mono.lua') }
foreach ($name in $forbidden) {
    if (Test-Path -LiteralPath (Join-Path $widget "lang/$name")) { throw "Wrong-screen asset: $name" }
}
if ($Target -eq 'Monochrome') {
    foreach ($name in @('INSTALL-MONO.md','INSTALL-ZORRO.md','images/zorro-large.png','images/t14-settings-large.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sd $name))) { throw "Missing guide: $name" }
    }
    foreach ($mode in @('--x9d','--gx12','--zorro','--t14')) {
        & $NodeExecutable (Join-Path $PSScriptRoot 'run-mono.cjs') $mode --sd-root $sd
        if ($LASTEXITCODE -ne 0) { throw "Packaged $mode test failed" }
    }
    & $NodeExecutable (Join-Path $PSScriptRoot 'run-mono.cjs') --zorro --legacy --sd-root $sd
    if ($LASTEXITCODE -ne 0) { throw 'Packaged legacy test failed' }
} else {
    if (Test-Path -LiteralPath (Join-Path $sd 'SCRIPTS/TELEMETRY/DLG.lua')) { throw 'Monochrome entry in color package' }
    foreach ($name in @('INSTALL-COLOR.md','INSTALL-V12.md','images/v12.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sd $name))) { throw "Missing guide: $name" }
    }
    foreach ($mode in @('--pa01','--v16','--v16-210','--v12')) {
        & $NodeExecutable (Join-Path $PSScriptRoot 'run.cjs') $mode --sd-root $sd
        if ($LASTEXITCODE -ne 0) { throw "Packaged $mode test failed" }
    }
}
if ($AllRadios) {
    & $NodeExecutable (Join-Path $PSScriptRoot 'run-radios.cjs') --target $Target --sd-root $sd
    if ($LASTEXITCODE -ne 0) { throw 'Packaged radio matrix failed' }
}
[pscustomobject]@{Archive=$zip;Target=$Target;ExtractedSD=$sd;Status='PASS';HardwareUsed=$false} | ConvertTo-Json
