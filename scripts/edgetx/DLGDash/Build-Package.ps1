param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\..\output\DLGDash-v1.0.1-beta.5'),
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$')][string]$PackageName,
    [ValidateSet('Color', 'Monochrome', 'Universal', 'Zorro')][string]$Target = 'Color'
)
$ErrorActionPreference = 'Stop'
if (-not $PackageName) {
    $PackageName = "DLGDash-$Target-v1.0.1-beta.5.zip"
}
$monoOnly = $Target -in @('Monochrome', 'Zorro')
$colorOnly = $Target -eq 'Color'
$output = [IO.Path]::GetFullPath($OutputDirectory)
$stage = Join-Path $output ('package-' + [IO.Path]::GetRandomFileName())
$sd = Join-Path $stage 'SD'
$widget = Join-Path $sd 'WIDGETS\DLGDash'
$tool = Join-Path $sd 'SCRIPTS\TOOLS'
$telemetry = Join-Path $sd 'SCRIPTS\TELEMETRY'
New-Item -ItemType Directory -Path $widget, $tool, $telemetry -Force | Out-Null
$runtime = @('compat.lua', 'profile.lua', 'core.lua', 'settings.lua', 'settings-pages.lua', 'diagnostics.lua')
if (-not $colorOnly) { $runtime += @('mono-ui.lua', 'mono-settings.lua') }
if (-not $monoOnly) { $runtime += @('draw.lua', 'color-settings.lua', 'main.lua', 'locale.lua') }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'pages') -Destination $widget -Recurse
foreach ($name in $runtime) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $widget $name) -Force
}
if ($monoOnly -or $colorOnly) {
    $lang = Join-Path $widget 'lang'
    New-Item -ItemType Directory -Path $lang | Out-Null
    $assets = if ($monoOnly) { @('mono.lua', 'mono', 'OFL.txt') } else { @('zh.lua', 'zh', 'OFL.txt') }
    foreach ($name in $assets) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('lang/' + $name)) -Destination $lang -Recurse
    }
} else {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'lang') -Destination $widget -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DLGSetup.lua') -Destination $tool -Force
if (-not $colorOnly) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DLG.lua') -Destination $telemetry -Force }
New-Item -ItemType Directory -Path (Join-Path $widget 'profiles'), (Join-Path $widget 'diagnostics') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\THIRD_PARTY_NOTICES.md') -Destination $sd
$docs = Join-Path $PSScriptRoot '..\..\..\docs'
Copy-Item -LiteralPath (Join-Path $docs 'RADIOS.md') -Destination $sd
if ($monoOnly) {
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-MONO.md') -Destination (Join-Path $sd 'README.md')
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-MONO.md') -Destination $sd
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-ZORRO.md') -Destination $sd
    New-Item -ItemType Directory -Path (Join-Path $sd 'images') | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $docs 'images') -File | Where-Object { $_.Name -match '^(x9d|gx12|zorro|t14).*large\.png$' }) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $sd 'images')
    }
} elseif ($colorOnly) {
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-COLOR.md') -Destination (Join-Path $sd 'README.md')
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-COLOR.md') -Destination $sd
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-V12.md') -Destination $sd
    New-Item -ItemType Directory -Path (Join-Path $sd 'images') | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $docs 'images') -File | Where-Object { $_.Name -match '^(pa01|v16|v12).*\.png$' }) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $sd 'images')
    }
} else {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination $sd -Force
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-BEGINNER.md') -Destination $sd
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-V12.md') -Destination $sd
    Copy-Item -LiteralPath (Join-Path $docs 'INSTALL-ZORRO.md') -Destination $sd
    Copy-Item -LiteralPath (Join-Path $docs 'images') -Destination $sd -Recurse
}
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
[pscustomobject]@{ Archive = $archive; Target = $Target; Files = $files.Count; SHA256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash } | ConvertTo-Json
