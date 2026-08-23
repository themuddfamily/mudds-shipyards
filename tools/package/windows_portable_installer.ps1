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
    [ValidateSet('install', 'upgrade', 'status', 'rollback', 'uninstall', 'repair')]
    [string]$Command,
    [Parameter(Mandatory = $true)] [string]$Destination,
    [string]$Source = (Split-Path -Parent $PSScriptRoot),
    [switch]$Force,
    [switch]$StartMenuShortcut,
    [switch]$DesktopShortcut,
    [switch]$AddRemovePrograms
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$OwnershipName = '.mudds-owned.json'
$ChecksumName = 'SHA256SUMS.txt'
$LauncherName = 'Start Mudds Shipyards.cmd'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MuddsShipyardsPortable'
$InstallerLog = Join-Path $env:APPDATA 'Godot\app_userdata\Mudds Shipyards\installer-operation.log'

function Write-OperationLog([string]$Action, [string]$Version, [string]$Result) {
    try {
        $parent = Split-Path -Parent $InstallerLog
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        $safeAction = $Action -replace '[^A-Za-z0-9_-]', '_'
        $safeVersion = $Version -replace '[^A-Za-z0-9_.+-]', '_'
        $safeResult = $Result -replace '[^A-Za-z0-9_.-]', '_'
        $line = "action=$safeAction version=$safeVersion result=$safeResult"
        $lines = if (Test-Path -LiteralPath $InstallerLog) { @(Get-Content -LiteralPath $InstallerLog) } else { @() }
        @($lines + $line | Select-Object -Last 8) | Set-Content -LiteralPath $InstallerLog -Encoding UTF8
    } catch { }
}

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

function Read-ExternalShortcuts([string]$Root) {
    $path = Join-Path $Root $OwnershipName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $manifest = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    if ($null -eq $manifest.external_shortcuts) { return @() }
    return @($manifest.external_shortcuts | ForEach-Object { [IO.Path]::GetFullPath([string]$_) })
}

function Read-AddRemoveOwned([string]$Root) {
    $path = Join-Path $Root $OwnershipName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $manifest = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    return [bool]$manifest.add_remove_programs
}

function Requested-Shortcuts {
    $paths = @()
    if ($StartMenuShortcut) { $paths += Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Mudds Shipyards.lnk' }
    if ($DesktopShortcut) { $paths += Join-Path $env:USERPROFILE 'Desktop\Mudds Shipyards.lnk' }
    return @($paths | Select-Object -Unique)
}

function New-LauncherShortcut([string]$Path, [string]$Target) {
    if (Test-Path -LiteralPath $Path) { throw "Shortcut target already exists: $Path" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.WorkingDirectory = Split-Path -Parent $Target
    $shortcut.Save()
}

function Remove-ExternalShortcuts([object[]]$Paths) {
    foreach ($path in @($Paths)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
    }
}

function Set-AddRemovePrograms([string]$Root) {
    $manifest = Read-DistributionManifest $Root
    if (Test-Path -LiteralPath $UninstallKey) {
        $existing = Get-ItemProperty -LiteralPath $UninstallKey
        if ([int]$existing.MuddsOwned -ne 1) { throw 'Add/Remove Programs key is owned by another application' }
    } else {
        New-Item -Path $UninstallKey -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $UninstallKey -Name MuddsOwned -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -LiteralPath $UninstallKey -Name DisplayName -PropertyType String -Value 'Mudds Shipyards (Portable)' -Force | Out-Null
    New-ItemProperty -LiteralPath $UninstallKey -Name DisplayVersion -PropertyType String -Value ([string]$manifest.version) -Force | Out-Null
    New-ItemProperty -LiteralPath $UninstallKey -Name InstallLocation -PropertyType String -Value $Root -Force | Out-Null
    $uninstall = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Root\install\windows_portable_installer.ps1`" uninstall -Destination `"$Root`""
    New-ItemProperty -LiteralPath $UninstallKey -Name UninstallString -PropertyType String -Value $uninstall -Force | Out-Null
}

function Remove-AddRemovePrograms {
    if (-not (Test-Path -LiteralPath $UninstallKey)) { return }
    $existing = Get-ItemProperty -LiteralPath $UninstallKey
    if ([int]$existing.MuddsOwned -ne 1) { throw 'Add/Remove Programs key is owned by another application' }
    Remove-Item -LiteralPath $UninstallKey -Recurse -Force
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
    $external = Read-ExternalShortcuts $Root
    foreach ($relative in $owned | Sort-Object { $_.Length } -Descending) {
        $path = Join-Path $Root ($relative -replace '/', '\')
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
    }
    Remove-Item -LiteralPath (Join-Path $Root $OwnershipName) -Force
    Remove-ExternalShortcuts $external
}

function Repair-Owned([string]$Root, [string]$SourceRoot) {
    $sourceManifest = Read-DistributionManifest $SourceRoot
    $currentManifest = Read-DistributionManifest $Root
    if ((Compare-DistributionVersion ([string]$sourceManifest.version) ([string]$currentManifest.version)) -ne 0) {
        throw 'Repair source version must match the installed version'
    }
    $sourceEntries = Get-ChecksumEntries $SourceRoot
    $owned = Read-Owned $Root
    $repairRoot = Join-Path (Split-Path -Parent $Root) ('.' + (Split-Path -Leaf $Root) + '.repair-' + [guid]::NewGuid().ToString('N'))
    $backups = @{}
    $created = @()
    try {
        New-Item -ItemType Directory -Path $repairRoot | Out-Null
        foreach ($relative in $owned) {
            if (-not $sourceEntries.ContainsKey($relative)) { throw "Repair source does not own file: $relative" }
            $source = Join-Path $SourceRoot ($relative -replace '/', '\')
            $target = Join-Path $Root ($relative -replace '/', '\')
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                $backup = Join-Path $repairRoot ($relative -replace '/', '\')
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
                Copy-Item -LiteralPath $target -Destination $backup -Force
                $backups[$relative] = $backup
            } else { $created += $target }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        Get-ChecksumEntries $Root | Out-Null
        Remove-Item -LiteralPath $repairRoot -Recurse -Force
        return @($owned).Count
    } catch {
        foreach ($target in $created) { if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force } }
        foreach ($relative in $backups.Keys) {
            $target = Join-Path $Root ($relative -replace '/', '\')
            Copy-Item -LiteralPath $backups[$relative] -Destination $target -Force
        }
        if (Test-Path -LiteralPath $repairRoot) { Remove-Item -LiteralPath $repairRoot -Recurse -Force }
        throw
    }
}

$destination = Resolve-SafeDestination $Destination
$rollback = "$destination.rollback"
$staging = "$destination.staging"
$createdShortcuts = @()
$operationVersion = 'unknown'
try {
    switch ($Command) {
        'status' {
            if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'Installed package is missing' }
            $operationVersion = [string](Read-DistributionManifest $destination).version
            $owned = Read-Owned $destination
            Get-ChecksumEntries $destination | Out-Null
            Write-OperationLog $Command $operationVersion 'ok'
            [pscustomobject]@{ destination = $destination; owned_file_count = $owned.Count; rollback_present = Test-Path -LiteralPath $rollback -PathType Container } | ConvertTo-Json -Compress
        }
        'uninstall' {
            if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'Installed package is missing' }
            $operationVersion = [string](Read-DistributionManifest $destination).version
            Remove-AddRemovePrograms
            Remove-Owned $destination
            Write-OperationLog $Command $operationVersion 'ok'
            [pscustomobject]@{ destination = $destination; reason = 'uninstalled' } | ConvertTo-Json -Compress
        }
        'rollback' {
            if (-not (Test-Path -LiteralPath $rollback -PathType Container)) { throw 'Rollback package is missing' }
            Get-ChecksumEntries $rollback | Out-Null
            $operationVersion = [string](Read-DistributionManifest $rollback).version
            $rollbackAddRemove = Read-AddRemoveOwned $rollback
            Remove-AddRemovePrograms
            $currentExternal = Read-ExternalShortcuts $destination
            $rollbackExternal = Read-ExternalShortcuts $rollback
            Remove-ExternalShortcuts $currentExternal
            if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination "$destination.current" -Force; Move-Item -LiteralPath "$destination.current" -Destination $rollback -Force }
            Move-Item -LiteralPath $rollback -Destination $destination -Force
            if ($rollbackAddRemove) { Set-AddRemovePrograms $destination }
            foreach ($shortcut in $rollbackExternal) { New-LauncherShortcut $shortcut (Join-Path $destination $LauncherName) }
            Write-OperationLog $Command $operationVersion 'ok'
            [pscustomobject]@{ destination = $destination; reason = 'rolled_back' } | ConvertTo-Json -Compress
        }
        'repair' {
            if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'Installed package is missing' }
            if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw 'Repair source distribution is missing' }
            $repaired = Repair-Owned $destination ([IO.Path]::GetFullPath($Source))
            $operationVersion = [string](Read-DistributionManifest $destination).version
            Write-OperationLog $Command $operationVersion 'ok'
            [pscustomobject]@{ destination = $destination; reason = 'repaired'; owned_files_checked = $repaired } | ConvertTo-Json -Compress
        }
        default {
            $source = [IO.Path]::GetFullPath($Source)
            if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'Source distribution directory is missing' }
            $sourceManifest = Read-DistributionManifest $source
            $operationVersion = [string]$sourceManifest.version
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
            $requestedShortcuts = Requested-Shortcuts
            $existingShortcuts = if (Test-Path -LiteralPath $destination -PathType Container) { Read-ExternalShortcuts $destination } else { @() }
            foreach ($shortcut in $requestedShortcuts) {
                if ((Test-Path -LiteralPath $shortcut) -and ($existingShortcuts -notcontains $shortcut)) { throw "Shortcut target already exists: $shortcut" }
            }
            Copy-Tree $source $staging $entries
            $ownershipPath = Join-Path $staging $OwnershipName
            $ownership = Get-Content -Raw -LiteralPath $ownershipPath | ConvertFrom-Json
            $ownership | Add-Member -NotePropertyName external_shortcuts -NotePropertyValue @($requestedShortcuts) -Force
            $ownership | Add-Member -NotePropertyName add_remove_programs -NotePropertyValue ([bool]$AddRemovePrograms) -Force
            $ownership | ConvertTo-Json -Compress | Set-Content -LiteralPath $ownershipPath -Encoding UTF8
            foreach ($shortcut in @($requestedShortcuts | Where-Object { $existingShortcuts -notcontains $_ })) {
                New-LauncherShortcut $shortcut (Join-Path $destination $LauncherName)
                $createdShortcuts += $shortcut
            }
            if (Test-Path -LiteralPath $rollback) { Remove-Item -LiteralPath $rollback -Recurse -Force }
            if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination $rollback }
            Move-Item -LiteralPath $staging -Destination $destination
            if ($AddRemovePrograms) { Set-AddRemovePrograms $destination }
            Write-OperationLog $Command $operationVersion 'ok'
            [pscustomobject]@{ destination = $destination; reason = 'installed' } | ConvertTo-Json -Compress
        }
    }
} catch {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    Remove-ExternalShortcuts $createdShortcuts
    Write-OperationLog $Command $operationVersion 'failed'
    Write-Error $_
    exit 2
}
