$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.IO.Compression.FileSystem
function FileHash($path) {
    $inputStream = [IO.File]::OpenRead($path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash($inputStream)).Replace('-','') }
    finally { $inputStream.Dispose(); $algorithm.Dispose() }
}
$stage = Join-Path $root ('.research/package-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($name in @('ExecutionerWatch', 'ExecutionerProbe')) {
    $source = Join-Path $root $name
    $toc = Join-Path $source ($name + '.toc')
    $files = @($name + '.toc') + @(Get-Content -LiteralPath $toc | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() })
    $target = Join-Path $stage $name
    New-Item -ItemType Directory -Path $target | Out-Null
    foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $target $file) }
    Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $target
    New-Item -ItemType Directory -Path (Join-Path $target 'docs') | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'docs/VALIDATION.md') -Destination (Join-Path $target 'docs/VALIDATION.md')
    $archive = Join-Path $root ('dist/' + $name + '-0.9.1.zip')
    Compress-Archive -LiteralPath $target -DestinationPath $archive -Force
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $expected = @($files) + @('README.md', 'docs/VALIDATION.md')
        $actual = @($zip.Entries | Where-Object { $_.Name })
        if ($actual.Count -ne $expected.Count) { throw 'Unexpected archive file count' }
        foreach ($file in $expected) {
            $entry = $actual | Where-Object { $_.FullName.Replace('\','/') -eq ($name + '/' + $file) }
            if (-not $entry) { throw "Missing archived file: $file" }
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
            finally { $stream.Dispose(); $sha.Dispose() }
            $original = FileHash (Join-Path $target $file)
            if ($hash -ne $original) { throw "Archive mismatch: $file" }
        }
        Write-Output "$name archive verified: $($actual.Count) files"
    } finally { $zip.Dispose() }
    Write-Output ("SHA256 " + (FileHash $archive))
}
