param(
    [Parameter(Mandatory = $true)][string]$CardRoot,
    [Parameter(Mandatory = $true)][string]$BackupDirectory,
    [switch]$AllowExperimental
)
$ErrorActionPreference = 'Stop'
$card = (Resolve-Path -LiteralPath $CardRoot).Path
$backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
$radioFile = Join-Path $card 'RADIO\radio.yml'
if (-not (Test-Path -LiteralPath $radioFile)) { throw 'Not an EdgeTX SD card' }
$radioText = Get-Content -LiteralPath $radioFile -Raw
if ($radioText -notmatch '(?m)^board:\s*([^\r\n]+)\s*$') { throw 'Radio board is missing' }
$board = $Matches[1].Trim()
$radios = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'radios.json') -Raw | ConvertFrom-Json
if ($board -notin $radios.board) { throw "Unsupported radio board: $board" }
$target = $radios | Where-Object board -eq $board | Select-Object -First 1
if ($board -ne 'pa01' -and -not $AllowExperimental) { throw 'Experimental radios require explicit -AllowExperimental; ground validation is pending' }
$manifest = Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw | ConvertFrom-Json
$flightFiles = @($manifest | Where-Object { $_.Path -like 'MODELS\*' -or $_.Path -like 'RADIO\*' })
$profileFiles = @($manifest | Where-Object { $_.Path -like 'WIDGETS\DLGDash\profiles\*' })
if ($flightFiles.Count -lt 2) { throw 'Model/radio backup is missing' }
foreach ($entry in $manifest) {
    $original = Join-Path $card $entry.Path
    $saved = Join-Path $backup $entry.Path
    if ((Get-FileHash -LiteralPath $saved -Algorithm SHA256).Hash -ne $entry.SHA256) { throw "Damaged backup: $saved" }
    if ((Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash -ne $entry.SHA256) { throw "Card changed; create a fresh backup: $original" }
}
$allFlight = @()
foreach ($folder in @('MODELS', 'RADIO')) {
    $allFlight += Get-ChildItem -LiteralPath (Join-Path $card $folder) -Recurse -File -Force
}
if ($allFlight.Count -ne $flightFiles.Count) { throw 'Model/radio file set changed; create a fresh backup' }
$widgetDir = Join-Path $card 'WIDGETS\DLGDash'
$toolDir = Join-Path $card 'SCRIPTS\TOOLS'
$telemetryDir = Join-Path $card 'SCRIPTS\TELEMETRY'
$sources = @('compat.lua', 'profile.lua', 'core.lua', 'settings.lua', 'settings-pages.lua', 'diagnostics.lua', 'DLGSetup.lua')
$mono = $target.screen -eq 'Monochrome'
if ($mono) { $sources += @('mono-ui.lua', 'mono-settings.lua', 'DLG.lua') }
else { $sources += @('draw.lua', 'color-settings.lua', 'main.lua', 'locale.lua') }
$languageRoot = Join-Path $PSScriptRoot 'lang'
for ($page = 1; $page -le 10; $page++) { $sources += "pages/$page.lua" }
$language = if ($mono) { 'mono' } else { 'zh' }
if (-not (Test-Path -LiteralPath (Join-Path $languageRoot "$language.lua"))) { throw 'Missing Chinese language pack' }
$sources += @("lang/$language.lua", 'lang/OFL.txt')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $languageRoot $language) -Recurse -File) {
    $sources += [IO.Path]::GetRelativePath($PSScriptRoot, $file.FullName)
}
foreach ($name in $sources) { if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name))) { throw "Missing source: $name" } }
New-Item -ItemType Directory -Path $widgetDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $widgetDir 'profiles') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $widgetDir 'diagnostics') -Force | Out-Null
New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
$installed = @()
$caches = @('SCRIPTS/TOOLS/DLGSetup.luac', 'SCRIPTS/TELEMETRY/DLG.luac')
foreach ($name in $sources) {
    $source = Join-Path $PSScriptRoot $name
    $destination = Join-Path $(if ($name -eq 'DLGSetup.lua') { $toolDir } elseif ($name -eq 'DLG.lua') { $telemetryDir } else { $widgetDir }) $name
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $expected = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $expected) { throw "Install verification failed: $destination" }
    if ([IO.Path]::GetExtension($name) -eq '.lua') { $caches += [IO.Path]::GetRelativePath($card, [IO.Path]::ChangeExtension($destination, '.luac')) }
    $installed += [pscustomobject]@{ Path = [IO.Path]::GetRelativePath($card, $destination); SHA256 = $expected }
}
foreach ($cache in $caches | Select-Object -Unique) {
    $compiled = Join-Path $card $cache
    if (Test-Path -LiteralPath $compiled) {
        $compiledRelative = [IO.Path]::GetRelativePath($card, $compiled)
        $compiledBackup = Join-Path $backup $compiledRelative
        if (-not (Test-Path -LiteralPath $compiledBackup)) { throw "Compiled script was not backed up: $compiled" }
        if ((Get-FileHash -LiteralPath $compiled).Hash -ne (Get-FileHash -LiteralPath $compiledBackup).Hash) { throw "Compiled backup mismatch: $compiled" }
        Remove-Item -LiteralPath $compiled
    }
}
foreach ($entry in @($flightFiles) + @($profileFiles)) {
    if ((Get-FileHash -LiteralPath (Join-Path $card $entry.Path) -Algorithm SHA256).Hash -ne $entry.SHA256) { throw "Model/radio verification failed: $($entry.Path)" }
}
$result = [pscustomobject]@{
    Version = '1.0.1-beta.5'
    Board = $board
    Screen = $target.screen
    Card = $card
    Backup = $backup
    VerifiedUnchangedModelRadioFiles = $flightFiles.Count
    VerifiedUnchangedWidgetProfiles = $profileFiles.Count
    Installed = $installed
    HardwareAcceptance = 'Pending real-radio verification of this release'
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'installation-verification.json') -Encoding utf8
$result | ConvertTo-Json -Depth 5
