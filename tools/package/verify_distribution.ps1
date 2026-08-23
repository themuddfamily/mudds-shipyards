<#!
.SYNOPSIS
  Verify one extracted Mudds Shipyards distribution locally.
.DESCRIPTION
  Checks every SHA256SUMS.txt entry and the distribution manifest's honest
  signing/native status. It performs no launch, signing, or native validation.
#!>
[CmdletBinding()]
param([string]$Root = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root)
$sumPath = Join-Path $rootPath 'SHA256SUMS.txt'
$manifestPath = Join-Path $rootPath 'distribution-manifest.json'
try {
    if (-not (Test-Path -LiteralPath $sumPath -PathType Leaf)) { throw 'SHA256SUMS.txt is missing' }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'distribution-manifest.json is missing' }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or [string]$manifest.signing -ne 'NOT_RUN' -or [string]$manifest.native_validation -ne 'NOT_RUN') {
        throw 'Manifest is missing the honest unsigned/native-NOT_RUN boundary'
    }
    $count = 0
    foreach ($line in Get-Content -LiteralPath $sumPath) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Invalid SHA256SUMS.txt entry' }
        $relative = $Matches[2]
        if ($relative.Contains('\') -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains('../')) { throw "Unsafe checksum path: $relative" }
        $target = Join-Path $rootPath ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing checked file: $relative" }
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Matches[1]) { throw "Checksum mismatch: $relative" }
        $count++
    }
    if ($count -lt 1) { throw 'Checksum manifest is empty' }
    [pscustomobject]@{ status = 'PASS'; files_checked = $count; signing = $manifest.signing; native_validation = $manifest.native_validation } | ConvertTo-Json -Compress
} catch {
    Write-Error $_
    exit 2
}
