param(
    [Parameter(Mandatory = $true)][string]$CardRoot,
    [Parameter(Mandatory = $true)][string]$BackupRoot
)
$ErrorActionPreference = 'Stop'
$card = (Resolve-Path -LiteralPath $CardRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $card 'RADIO\radio.yml'))) { throw 'Not an EdgeTX SD card' }
$target = Join-Path $BackupRoot ((Get-Date -Format 'yyyy-MM-dd_HHmmss') + '_before_DLGDash')
if (Test-Path -LiteralPath $target) { throw 'Backup directory already exists' }
New-Item -ItemType Directory -Path $target | Out-Null
$records = @()
foreach ($relative in @('MODELS', 'RADIO', 'BACKUP', 'WIDGETS\DLGDash', 'SCRIPTS\TOOLS\DLGSetup.lua', 'SCRIPTS\TOOLS\DLGSetup.luac', 'SCRIPTS\TELEMETRY\DLG.lua', 'SCRIPTS\TELEMETRY\DLG.luac', 'MODELS.zip')) {
    $source = Join-Path $card $relative
    if (-not (Test-Path -LiteralPath $source)) { continue }
    $files = if (Test-Path -LiteralPath $source -PathType Container) {
        @(Get-ChildItem -LiteralPath $source -Recurse -File -Force)
    } else { @(Get-Item -LiteralPath $source) }
    foreach ($file in $files) {
        $fileRelative = [IO.Path]::GetRelativePath($card, $file.FullName)
        $destination = Join-Path $target $fileRelative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        $before = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        Copy-Item -LiteralPath $file.FullName -Destination $destination
        $copied = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        $after = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        if ($before -ne $copied -or $before -ne $after) { throw "Backup mismatch: $fileRelative" }
        $records += [pscustomobject]@{ Path = $fileRelative; Bytes = $file.Length; SHA256 = $before }
    }
}
$records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $target 'manifest.json') -Encoding utf8
$archive = $target + '.zip'
Compress-Archive -LiteralPath $target -DestinationPath $archive
[pscustomobject]@{
    Backup = $target
    Archive = $archive
    Files = $records.Count
    ModelFiles = @($records | Where-Object { $_.Path -like 'MODELS\*' }).Count
    ArchivedModelFiles = @($records | Where-Object { $_.Path -like 'BACKUP\*' }).Count
    SHA256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
} | ConvertTo-Json
