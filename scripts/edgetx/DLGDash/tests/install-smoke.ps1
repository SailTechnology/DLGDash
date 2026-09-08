# Requires PowerShell 7. Only generated temporary cards are modified.
$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DLGDash-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$results = @()
$radios = Get-Content -LiteralPath (Join-Path $source 'radios.json') -Raw | ConvertFrom-Json
foreach ($board in $radios.board) {
    $card = Join-Path $testRoot $board
    foreach ($dir in @('MODELS', 'RADIO', 'BACKUP', 'WIDGETS/DLGDash/profiles', 'SCRIPTS/TELEMETRY')) {
        New-Item -ItemType Directory -Path (Join-Path $card $dir) -Force | Out-Null
    }
    [IO.File]::WriteAllText((Join-Path $card 'RADIO/radio.yml'), "board: $board`n")
    [IO.File]::WriteAllText((Join-Path $card 'MODELS/demo.yml'), "name: Demo`n")
    [IO.File]::WriteAllText((Join-Path $card 'BACKUP/old.yml'), "name: Old model`n")
    [IO.File]::WriteAllText((Join-Path $card 'WIDGETS/DLGDash/profiles/demo.a'), 'preserve this profile')
    [IO.File]::WriteAllText((Join-Path $card 'SCRIPTS/TELEMETRY/DLG.luac'), 'old compiled cache')
    $backup = (& (Join-Path $source 'Backup-Radio.ps1') -CardRoot $card -BackupRoot (Join-Path $testRoot ('backup-' + $board))) | ConvertFrom-Json
    if ($backup.ArchivedModelFiles -ne 1) { throw 'Archived model backup is missing' }
    $args = @{ CardRoot=$card; BackupDirectory=$backup.Backup }
    if ($board -ne 'pa01') {
        $rejected = $false
        try { & (Join-Path $source 'Install-DLGDash.ps1') @args | Out-Null } catch { $rejected = $_.Exception.Message -like '*-AllowExperimental*' }
        if (-not $rejected) { throw 'Missing experimental opt-in' }
        $args.AllowExperimental = $true
    }
    $installed = (& (Join-Path $source 'Install-DLGDash.ps1') @args) | ConvertFrom-Json
    $target = $radios | Where-Object board -eq $board | Select-Object -First 1
    if ($installed.Screen -ne $target.screen) { throw 'Wrong installation screen class' }
    $forbidden = if ($target.screen -eq 'Monochrome') { @('draw.lua','color-settings.lua','locale.lua','main.lua','lang/zh.lua','lang/zh') } else { @('mono-ui.lua','mono-settings.lua','lang/mono.lua','lang/mono') }
    foreach ($name in $forbidden) {
        if (Test-Path -LiteralPath (Join-Path $card "WIDGETS/DLGDash/$name")) { throw "Wrong-screen resource installed: $name" }
    }
    if ($installed.Version -ne '1.1.0' -or $installed.VerifiedUnchangedModelRadioFiles -ne 2 -or $installed.VerifiedUnchangedWidgetProfiles -ne 1) { throw 'Installation verification mismatch' }
    if (Test-Path -LiteralPath (Join-Path $card 'SCRIPTS/TELEMETRY/DLG.luac')) { throw 'Old cache survived' }
    if (-not (Test-Path -LiteralPath (Join-Path $backup.Backup 'SCRIPTS/TELEMETRY/DLG.luac'))) { throw 'Old cache is not recoverable' }
    $archivedHash = (Get-FileHash -LiteralPath (Join-Path $backup.Backup 'BACKUP/old.yml')).Hash
    if ((Get-FileHash -LiteralPath (Join-Path $card 'BACKUP/old.yml')).Hash -ne $archivedHash) { throw 'Archived model was changed' }
    foreach ($folder in @('profiles', 'diagnostics')) {
        if (-not (Test-Path -LiteralPath (Join-Path $card ('WIDGETS/DLGDash/' + $folder)) -PathType Container)) { throw 'Legacy save folder is missing' }
    }
    [IO.File]::AppendAllText((Join-Path $card 'MODELS/demo.yml'), 'changed')
    $rejected = $false
    try { & (Join-Path $source 'Install-DLGDash.ps1') @args | Out-Null } catch { $rejected = $_.Exception.Message -like '*fresh backup*' }
    if (-not $rejected) { throw 'Stale model backup was accepted' }
    $results += @{ Board=$board; Status='PASS'; InstalledFiles=$installed.Installed.Count }
}
$unknown = Join-Path $testRoot 'unknown'
$null = New-Item -ItemType Directory -Path (Join-Path $unknown 'RADIO') -Force
[IO.File]::WriteAllText((Join-Path $unknown 'RADIO/radio.yml'), "board: unknown`n")
$rejected = $false
try { & (Join-Path $source 'Install-DLGDash.ps1') -CardRoot $unknown -BackupDirectory $testRoot -AllowExperimental | Out-Null } catch { $rejected = $_.Exception.Message -like '*Unsupported radio*' }
if (-not $rejected -or (Test-Path -LiteralPath (Join-Path $unknown 'WIDGETS'))) { throw 'Unknown board was modified' }
[pscustomobject]@{ TemporaryTestRoot=$testRoot; Tests=$results; HardwareUsed=$false } | ConvertTo-Json -Depth 4
