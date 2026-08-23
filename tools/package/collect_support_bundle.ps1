<#!
.SYNOPSIS
  Collect a privacy-safe local Mudds Shipyards support bundle.
.DESCRIPTION
  Copies only the named diagnostic/settings metadata files from an explicit
  user-data root. Save files, arbitrary paths, and native execution evidence
  are never collected. Obvious secret-shaped values are redacted.
#!>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$UserDataRoot,
    [Parameter(Mandatory = $true)] [string]$OutputZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Allowed = @('crash-log.json', 'crash-log.json.previous', 'settings.json', 'settings.cfg', 'session-diagnostics.json')
function Redact([string]$Text) {
    $redacted = [regex]::Replace($Text, '(?im)(["'']?(?:password|token|secret|api[_-]?key)["'']?\s*[:=]\s*["'']?)[^\s,"''}]+', '$1[REDACTED]')
    return [regex]::Replace($redacted, '(?im)(Authorization\s*:\s*Bearer\s+)[^\s]+', '$1[REDACTED]')
}

$root = [IO.Path]::GetFullPath($UserDataRoot)
$output = [IO.Path]::GetFullPath($OutputZip)
$parent = Split-Path -Parent $output
$staging = Join-Path $parent ('.mudds-support-' + [guid]::NewGuid().ToString('N'))
$temporaryZip = "$output.tmp"
try {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'User-data root is missing' }
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    $included = @()
    foreach ($name in $Allowed) {
        $source = Join-Path $root $name
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Set-Content -LiteralPath (Join-Path $staging $name) -Value (Redact (Get-Content -Raw -LiteralPath $source)) -Encoding UTF8
            $included += $name
        }
    }
    $metadata = @{ schema_version = 1; included_files = @($included | Sort-Object); excluded = @('save files', 'arbitrary user files', 'native execution evidence'); native_status = 'NOT_RUN' }
    $metadata | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $staging 'support-manifest.json') -Encoding UTF8
    if (Test-Path -LiteralPath $temporaryZip) { Remove-Item -LiteralPath $temporaryZip -Force }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $temporaryZip -CompressionLevel Optimal
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
    Move-Item -LiteralPath $temporaryZip -Destination $output
    [pscustomobject]@{ status = 'PASS'; output = $output; included_files = $included; native_status = 'NOT_RUN' } | ConvertTo-Json -Compress
} catch {
    Write-Error $_
    exit 2
} finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    if (Test-Path -LiteralPath $temporaryZip) { Remove-Item -LiteralPath $temporaryZip -Force }
}
