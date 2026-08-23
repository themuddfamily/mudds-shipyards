<#!
.SYNOPSIS
  Non-admin Windows portable installer for an extracted Mudds Shipyards package.
.DESCRIPTION
  Operates only on explicit paths, validates SHA256SUMS.txt, keeps one rollback,
  and removes only files recorded in .mudds-owned.json. It makes no signing or
  native-validation claims. Run from an extracted distribution directory:
    .\install\windows_portable_installer.ps1 install -Destination C:\Games\Mudds
#!>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('install', 'upgrade', 'status', 'rollback', 'uninstall')]
    [string]$Command,
    [Parameter(Mandatory = $true)] [string]$Destination,
    [string]$Source = (Split-Path -Parent $PSScriptRoot),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$OwnershipName = '.mudds-owned.json'
$ChecksumName = 'SHA256SUMS.txt'
$LauncherName = 'Start Mudds Shipyards.cmd'

function Resolve-SafeDestination([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($resolved)
    if ($resolved.TrimEnd('\') -eq $root.TrimEnd('\')) { throw 'Destination must not be a filesystem root' }
    return $resolved.TrimEnd('\')
}

function Assert-Relative([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Contains('\') -or [IO.Path]::IsPathRooted($Name)) { throw "Unsafe package path: $Name" }
    $parts = $Name -split '/'
    if ($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) { throw "Unsafe package path: $Name" }
    return $Name
}

function Get-ChecksumEntries([string]$Root) {
    $checksum = Join-Path $Root $ChecksumName
    if (-not (Test-Path -LiteralPath $checksum -PathType Leaf)) { throw 'SHA256SUMS.txt is missing' }
    $entries = @{}
    foreach ($line in Get-Content -LiteralPath $checksum) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Invalid SHA256SUMS.txt entry' }
        $hash, $relative = $Matches[1], (Assert-Relative $Matches[2])
        if ($entries.ContainsKey($relative)) { throw "Duplicate checksum entry: $relative" }
        $target = Join-Path $Root ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing package file: $relative" }
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw "Checksum mismatch: $relative" }
        $entries[$relative] = $hash
    }
    return $entries
}

function Copy-Tree([string]$SourceRoot, [string]$TargetRoot, [hashtable]$Entries) {
    foreach ($relative in $Entries.Keys) {
        $target = Join-Path $TargetRoot ($relative -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath (Join-Path $SourceRoot ($relative -replace '/', '\')) -Destination $target -Force
    }
    $manifest = @{ schema_version = 1; files = @($Entries.Keys | Sort-Object) }
    $manifest | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $TargetRoot $OwnershipName) -Encoding UTF8
}

function Read-Owned([string]$Root) {
    $path = Join-Path $Root $OwnershipName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Ownership manifest is missing' }
    $manifest = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or $null -eq $manifest.files -or -not ($manifest.files -is [array])) { throw 'Invalid ownership manifest' }
    $owned = @($manifest.files | ForEach-Object { Assert-Relative ([string]$_) })
    if ($owned -contains $OwnershipName -or $owned.Count -ne (@($owned | Sort-Object -Unique).Count)) { throw 'Invalid ownership manifest' }
    return $owned
}

function Read-DistributionManifest([string]$Root) {
    $path = Join-Path $Root 'distribution-manifest.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Distribution manifest is missing' }
    $manifest = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace([string]$manifest.version) -or
        [string]::IsNullOrWhiteSpace([string]$manifest.source_commit)) { throw 'Invalid distribution manifest' }
    if ([string]$manifest.signing -ne 'NOT_RUN' -or [string]$manifest.native_validation -ne 'NOT_RUN') {
        throw 'Distribution contains an unverified signing or native-validation claim'
    }
    return $manifest
}

function Compare-DistributionVersion([string]$Left, [string]$Right) {
    $leftMatch = [regex]::Match($Left, '^v?(\d+)\.(\d+)\.(\d+)')
    $rightMatch = [regex]::Match($Right, '^v?(\d+)\.(\d+)\.(\d+)')
    if (-not $leftMatch.Success -or -not $rightMatch.Success) { throw 'Invalid distribution version' }
    for ($index = 1; $index -le 3; $index++) {
        $difference = [int]$leftMatch.Groups[$index].Value - [int]$rightMatch.Groups[$index].Value
        if ($difference -ne 0) { return $difference }
    }
    return 0
}

function Remove-Owned([string]$Root) {
    $owned = Read-Owned $Root
    foreach ($relative in $owned | Sort-Object { $_.Length } -Descending) {
        $path = Join-Path $Root ($relative -replace '/', '\')
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
    }
    Remove-Item -LiteralPath (Join-Path $Root $OwnershipName) -Force
}

$destination = Resolve-SafeDestination $Destination
$rollback = "$destination.rollback"
$staging = "$destination.staging"
try {
    switch ($Command) {
        'status' {
            if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'Installed package is missing' }
            $owned = Read-Owned $destination
            Get-ChecksumEntries $destination | Out-Null
            [pscustomobject]@{ destination = $destination; owned_file_count = $owned.Count; rollback_present = Test-Path -LiteralPath $rollback -PathType Container } | ConvertTo-Json -Compress
        }
        'uninstall' {
            if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'Installed package is missing' }
            Remove-Owned $destination
            [pscustomobject]@{ destination = $destination; reason = 'uninstalled' } | ConvertTo-Json -Compress
        }
        'rollback' {
            if (-not (Test-Path -LiteralPath $rollback -PathType Container)) { throw 'Rollback package is missing' }
            Get-ChecksumEntries $rollback | Out-Null
            if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination "$destination.current" -Force; Move-Item -LiteralPath "$destination.current" -Destination $rollback -Force }
            Move-Item -LiteralPath $rollback -Destination $destination -Force
            [pscustomobject]@{ destination = $destination; reason = 'rolled_back' } | ConvertTo-Json -Compress
        }
        default {
            $source = [IO.Path]::GetFullPath($Source)
            if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'Source distribution directory is missing' }
            $sourceManifest = Read-DistributionManifest $source
            $entries = Get-ChecksumEntries $source
            if (-not $entries.ContainsKey($LauncherName)) { throw 'Package launcher is missing' }
            if (Test-Path -LiteralPath $staging) { throw 'Staging directory already exists' }
            New-Item -ItemType Directory -Path $staging | Out-Null
            if (Test-Path -LiteralPath $destination -PathType Container) {
                $currentManifest = Read-DistributionManifest $destination
                $versionOrder = Compare-DistributionVersion ([string]$sourceManifest.version) ([string]$currentManifest.version)
                if (-not $Force -and $versionOrder -lt 0) { throw 'Downgrade requires -Force' }
                if (-not $Force -and $versionOrder -eq 0) { throw 'Same-version replacement requires -Force' }
                $existing = Read-Owned $destination
                foreach ($file in Get-ChildItem -LiteralPath $destination -File -Recurse) {
                    $relative = $file.FullName.Substring($destination.Length + 1).Replace('\', '/')
                    if ($existing -notcontains $relative) { $target = Join-Path $staging ($relative -replace '/', '\'); New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null; Copy-Item $file.FullName $target }
                }
            }
            Copy-Tree $source $staging $entries
            if (Test-Path -LiteralPath $rollback) { Remove-Item -LiteralPath $rollback -Recurse -Force }
            if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination $rollback }
            Move-Item -LiteralPath $staging -Destination $destination
            [pscustomobject]@{ destination = $destination; reason = 'installed' } | ConvertTo-Json -Compress
        }
    }
} catch {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    Write-Error $_
    exit 2
}
