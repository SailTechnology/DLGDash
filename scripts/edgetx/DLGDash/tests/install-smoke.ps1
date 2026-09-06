# Requires PowerShell 7. Only generated temporary cards are modified.
$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DLGDash-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$results = @()
foreach ($board in @('pa01', 'v16', 'x9d', 'x9d+', 'x9d+2019', 'gx12')) {
    $card = Join-Path $testRoot $board
    foreach ($dir in @('MODELS', 'RADIO', 'WIDGETS/DLGDash/profiles', 'SCRIPTS/TELEMETRY')) {
        New-Item -ItemType Directory -Path (Join-Path $card $dir) -Force | Out-Null
    }
    [IO.File]::WriteAllText((Join-Path $card 'RADIO/radio.yml'), "board: $board`n")
    [IO.File]::WriteAllText((Join-Path $card 'MODELS/demo.yml'), "name: Demo`n")
    [IO.File]::WriteAllText((Join-Path $card 'WIDGETS/DLGDash/profiles/demo.a'), 'preserve this profile')
    [IO.File]::WriteAllText((Join-Path $card 'SCRIPTS/TELEMETRY/DLG.luac'), 'old compiled cache')
    $backup = (& (Join-Path $source 'Backup-Radio.ps1') -CardRoot $card -BackupRoot (Join-Path $testRoot ('backup-' + $board))) | ConvertFrom-Json
    $args = @{ CardRoot=$card; BackupDirectory=$backup.Backup }
    if ($board -ne 'pa01') {
        $rejected = $false
        try { & (Join-Path $source 'Install-DLGDash.ps1') @args | Out-Null } catch { $rejected = $_.Exception.Message -like '*-AllowExperimental*' }
        if (-not $rejected) { throw 'Missing experimental opt-in' }
        $args.AllowExperimental = $true
    }
    $installed = (& (Join-Path $source 'Install-DLGDash.ps1') @args) | ConvertFrom-Json
    if ($installed.Version -ne '1.0.0' -or $installed.VerifiedUnchangedModelRadioFiles -ne 2 -or $installed.VerifiedUnchangedWidgetProfiles -ne 1) { throw 'Installation verification mismatch' }
    if (Test-Path -LiteralPath (Join-Path $card 'SCRIPTS/TELEMETRY/DLG.luac')) { throw 'Old cache survived' }
    if (-not (Test-Path -LiteralPath (Join-Path $backup.Backup 'SCRIPTS/TELEMETRY/DLG.luac'))) { throw 'Old cache is not recoverable' }
    [IO.File]::AppendAllText((Join-Path $card 'MODELS/demo.yml'), 'changed')
    $rejected = $false
    try { & (Join-Path $source 'Install-DLGDash.ps1') @args | Out-Null } catch { $rejected = $_.Exception.Message -like '*fresh backup*' }
    if (-not $rejected) { throw 'Stale model backup was accepted' }
    $results += @{ Board=$board; Status='PASS'; InstalledFiles=$installed.Installed.Count }
}
[pscustomobject]@{ TemporaryTestRoot=$testRoot; Tests=$results; HardwareUsed=$false } | ConvertTo-Json -Depth 4
