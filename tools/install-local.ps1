param(
    [Parameter(Mandatory=$true)][string]$GameRoot,
    [string]$SettingsFile
)
$ErrorActionPreference='Stop'
$running=Get-Process -Name Wow,WowT,WowB -ErrorAction SilentlyContinue
if ($running -and $SettingsFile) { throw 'Close the game before changing saved settings.' }
$root=Split-Path -Parent $PSScriptRoot
$game=[IO.Path]::GetFullPath($GameRoot)
if (-not (Test-Path -LiteralPath (Join-Path $game 'Wow.exe'))) { throw 'Not a retail game directory.' }
$target=Join-Path $game 'Interface/AddOns/ExecutionerWatch'
$backup=Join-Path $root ('backups/installed-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup | Out-Null
if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination $backup -Recurse }
if ($SettingsFile) {
    $settings=[IO.Path]::GetFullPath($SettingsFile)
    $allowed=Join-Path $game 'WTF/Account/'
    if (-not $settings.StartsWith($allowed.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Settings path must be under this game account directory.' }
    if ([IO.Path]::GetFileName($settings) -ne 'ExecutionerWatch.lua') { throw 'Only main addon settings may be changed.' }
    Copy-Item -LiteralPath $settings -Destination (Join-Path $backup 'ExecutionerWatchDB.lua')
}
$source=Join-Path $root 'ExecutionerWatch'
$files=@('ExecutionerWatch.toc') + @(Get-Content -LiteralPath (Join-Path $source 'ExecutionerWatch.toc') | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() })
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($file in $files) {
    $from=Join-Path $source $file
    $to=Join-Path $target $file
    Copy-Item -LiteralPath $from -Destination $to -Force
    $a=[Convert]::ToBase64String([IO.File]::ReadAllBytes($from))
    $b=[Convert]::ToBase64String([IO.File]::ReadAllBytes($to))
    if ($a -ne $b) { throw "Installed file mismatch: $file" }
}
if ($SettingsFile) {
    $content=[IO.File]::ReadAllText($settings)
    # Enable only the requested five-bar display. Keep all other preferences.
    $content=$content.Replace('["showPips"] = false','["showPips"] = true')
    [IO.File]::WriteAllText($settings,$content,(New-Object Text.UTF8Encoding($false)))
}
Write-Output "Installed and verified $($files.Count) files: $target"
Write-Output "Backup: $backup"
if ($running) { Write-Output 'Game running: addon source updated; /reload is required. Saved settings were not modified.' }
