param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\..\output\DLGDash-v1.0.1-beta.1'),
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$')][string]$PackageName = 'DLGDash-v1.0.1-beta.1.zip'
)
$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath($OutputDirectory)
$stage = Join-Path $output ('package-' + [IO.Path]::GetRandomFileName())
$sd = Join-Path $stage 'SD'
$widget = Join-Path $sd 'WIDGETS\DLGDash'
$tool = Join-Path $sd 'SCRIPTS\TOOLS'
$telemetry = Join-Path $sd 'SCRIPTS\TELEMETRY'
New-Item -ItemType Directory -Path $widget, $tool, $telemetry -Force | Out-Null
foreach ($name in @('compat.lua', 'profile.lua', 'core.lua', 'draw.lua', 'settings.lua', 'settings-pages.lua', 'color-settings.lua', 'main.lua', 'locale.lua', 'diagnostics.lua', 'mono-ui.lua', 'mono-settings.lua')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $widget $name) -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'lang') -Destination $widget -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DLGSetup.lua') -Destination $tool -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DLG.lua') -Destination $telemetry -Force
New-Item -ItemType Directory -Path (Join-Path $widget 'profiles'), (Join-Path $widget 'diagnostics') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination $sd -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\THIRD_PARTY_NOTICES.md') -Destination $sd
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\docs\INSTALL-BEGINNER.md') -Destination $sd
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\docs\images') -Destination $sd -Recurse
$files = @(Get-ChildItem -LiteralPath $sd -Recurse -File)
foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($sd, $file.FullName)
    if ($relative -match '(^|\\)(MODELS|RADIO|profiles|diagnostics)(\\|$)|\.luac$') {
        throw "Personal configuration or compiled cache in share package: $relative"
    }
}
$archive = Join-Path $output $PackageName
Compress-Archive -LiteralPath $sd -DestinationPath $archive -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries = @($zip.Entries | Where-Object { $_.Name -ne '' })
    if ($entries.Count -ne $files.Count) { throw 'Package file count mismatch' }
    foreach ($folder in @('SD/WIDGETS/DLGDash/profiles/', 'SD/WIDGETS/DLGDash/diagnostics/')) {
        if (-not ($zip.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq $folder })) { throw "Missing old-firmware save directory: $folder" }
    }
    foreach ($entry in $entries) {
        $stream = $entry.Open()
        try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) }
        finally { $stream.Dispose() }
        $local = Join-Path $stage ($entry.FullName.Replace('/', '\'))
        if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash -ne $hash) { throw "Package hash mismatch: $local" }
    }
} finally { $zip.Dispose() }
[pscustomobject]@{ Archive = $archive; Files = $files.Count; SHA256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash } | ConvertTo-Json
