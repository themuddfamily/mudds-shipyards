<#
.SYNOPSIS
Natively exercise a Mudds Shipyards installer: silent clean install, installed
startup check, silent upgrade over itself, silent uninstall, clean-up proof.

.DESCRIPTION
Run on Windows (from WSL: powershell.exe -NoProfile -NonInteractive
-ExecutionPolicy Bypass -File verify_windows_installer.ps1 ...). Everything the
installer writes is checked against what the build recorded, the installed
executable must print STARTUP_MENU_READY_OK with exit 0 under an owned
APPDATA/LOCALAPPDATA profile (so the real user profile is never touched), and
after the silent uninstall the install directory, Start Menu folder and both
HKCU keys must be gone while the owned user-data profile survives. The install
location is a private directory under -ProbeRoot, never the default per-user
Programs folder, so a developer's own install is not disturbed. Writes a JSON
result (schema_version 1) and exits non-zero on the first failed step.
#>
param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [Parameter(Mandatory = $true)][string]$ExpectedExeSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedCommit,
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [int]$StartupTimeoutMs = 120000
)
$ErrorActionPreference = 'Stop'
$regUninstall = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MuddsShipyards'
$regApp = 'HKCU:\Software\Mudds Shipyards'
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Mudds Shipyards'
$installDir = Join-Path $ProbeRoot 'install'
$profileRoot = Join-Path $ProbeRoot 'profile'
$steps = New-Object System.Collections.ArrayList
$result = [ordered]@{
    schema_version = 1
    installer = $Installer
    installer_sha256 = $null
    expected_exe_sha256 = $ExpectedExeSha256.ToLowerInvariant()
    expected_commit = $ExpectedCommit
    install_dir = $installDir
    steps = $steps
    status = 'FAIL'
}
function Save-Result {
    $result.steps = @($steps)
    $json = $result | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($ResultPath, $json + "`n")
}
function Step([string]$name, [scriptblock]$body) {
    $entry = [ordered]@{ name = $name; status = 'FAIL'; detail = $null }
    try {
        $detail = & $body
        $entry.status = 'PASS'
        $entry.detail = $detail
        [void]$steps.Add($entry)
        Write-Output "STEP PASS $name $detail"
    } catch {
        $entry.detail = $_.Exception.Message
        [void]$steps.Add($entry)
        Write-Output "STEP FAIL $name $($entry.detail)"
        Save-Result
        exit 1
    }
}
function Wait-Gone([string]$path, [int]$timeoutMs) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (Test-Path -LiteralPath $path) {
        if ($timer.ElapsedMilliseconds -gt $timeoutMs) { return $false }
        Start-Sleep -Milliseconds 250
    }
    return $true
}
function Run-Silent([string]$file, [string]$arguments, [int]$timeoutMs) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $file
    $info.Arguments = $arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($info)
    if (-not $proc.WaitForExit($timeoutMs)) { $proc.Kill(); $proc.WaitForExit(); throw "$file timed out after $timeoutMs ms" }
    return $proc.ExitCode
}

Step 'preconditions' {
    if (-not (Test-Path -LiteralPath $Installer)) { throw "installer missing: $Installer" }
    if (Test-Path -LiteralPath $installDir) { throw "install directory already exists: $installDir" }
    if (Test-Path $regUninstall) { throw 'an uninstall key for Mudds Shipyards already exists in HKCU; refusing to disturb it' }
    if (Test-Path $regApp) { throw 'HKCU\Software\Mudds Shipyards already exists; refusing to disturb it' }
    if (Test-Path -LiteralPath $startMenu) { throw "Start Menu folder already exists: $startMenu" }
    New-Item -ItemType Directory -Path $ProbeRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'Roaming') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'Local') -Force | Out-Null
    # Seed the owned profile with player data so upgrade and uninstall can prove
    # they leave it alone (the game itself may not write anything during a
    # headless startup check).
    $userData = Join-Path $profileRoot 'Roaming\Godot\app_userdata\Mudds Shipyards'
    New-Item -ItemType Directory -Path $userData -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $userData 'installer-probe-marker.txt'), "seeded before install`n")
    $result.installer_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Installer).Hash.ToLowerInvariant()
    "installer_sha256=$($result.installer_sha256)"
}

Step 'silent_install' {
    $code = Run-Silent $Installer "/S /D=$installDir" 600000
    if ($code -ne 0) { throw "installer exit code $code" }
    "exit=$code"
}

Step 'installed_files' {
    $exe = Join-Path $installDir 'MuddsShipyards.exe'
    foreach ($name in @('MuddsShipyards.exe', 'uninstall.exe', 'source-commit.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $installDir $name))) { throw "missing $name" }
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLowerInvariant()
    if ($hash -ne $result.expected_exe_sha256) { throw "installed exe sha256 $hash != expected $($result.expected_exe_sha256)" }
    $provenance = Get-Content -LiteralPath (Join-Path $installDir 'source-commit.txt')
    if (-not ($provenance -contains "source_commit=$ExpectedCommit")) { throw 'source-commit.txt does not record the expected commit' }
    if (-not ($provenance -contains 'signing=unsigned')) { throw 'source-commit.txt does not declare the build unsigned' }
    "exe_sha256=$hash"
}

Step 'registry_and_shortcuts' {
    $u = Get-ItemProperty -Path $regUninstall
    if ($u.InstallLocation -ne $installDir) { throw "InstallLocation '$($u.InstallLocation)' != '$installDir'" }
    if ($u.DisplayName -ne 'Mudds Shipyards') { throw "DisplayName '$($u.DisplayName)'" }
    if (-not $u.QuietUninstallString.EndsWith('/S')) { throw 'QuietUninstallString lacks /S' }
    if ($u.NoModify -ne 1 -or $u.NoRepair -ne 1) { throw 'NoModify/NoRepair not set' }
    $a = Get-ItemProperty -Path $regApp
    if ($a.SourceCommit -ne $ExpectedCommit) { throw "SourceCommit '$($a.SourceCommit)'" }
    if ($a.PSObject.Properties.Name -contains 'UpgradedFrom') { throw 'clean install must not record UpgradedFrom' }
    foreach ($lnk in @('Mudds Shipyards.lnk', 'Uninstall Mudds Shipyards.lnk')) {
        if (-not (Test-Path -LiteralPath (Join-Path $startMenu $lnk))) { throw "missing Start Menu shortcut $lnk" }
    }
    $shell = New-Object -ComObject WScript.Shell
    $target = $shell.CreateShortcut((Join-Path $startMenu 'Mudds Shipyards.lnk')).TargetPath
    if ($target -ne (Join-Path $installDir 'MuddsShipyards.exe')) { throw "shortcut targets '$target'" }
    "display_version=$($u.DisplayVersion) estimated_size_kb=$($u.EstimatedSize)"
}

Step 'installed_startup_check' {
    $log = Join-Path $ProbeRoot 'installed-startup.log'
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $installDir 'MuddsShipyards.exe'
    $info.Arguments = '--headless --audio-driver Dummy --startup-check --log-file "' + $log + '"'
    $info.WorkingDirectory = $installDir
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.EnvironmentVariables['APPDATA'] = (Join-Path $profileRoot 'Roaming')
    $info.EnvironmentVariables['LOCALAPPDATA'] = (Join-Path $profileRoot 'Local')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($info)
    if (-not $proc.WaitForExit($StartupTimeoutMs)) { $proc.Kill(); $proc.WaitForExit(); throw 'installed startup check timed out' }
    $sentinel = [bool](Select-String -Path $log -SimpleMatch 'STARTUP_MENU_READY_OK')
    if ($proc.ExitCode -ne 0 -or -not $sentinel) { throw "exit=$($proc.ExitCode) sentinel=$sentinel" }
    "exit=0 sentinel=True wall_ms=$($timer.ElapsedMilliseconds)"
}

Step 'silent_upgrade_over_existing' {
    $before = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $installDir 'MuddsShipyards.exe')).Hash
    $code = Run-Silent $Installer "/S /D=$installDir" 600000
    if ($code -ne 0) { throw "upgrade installer exit code $code" }
    $after = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $installDir 'MuddsShipyards.exe')).Hash
    if ($after -ne $before) { throw 'upgrade over the same build changed the executable' }
    $a = Get-ItemProperty -Path $regApp
    if ($a.UpgradedFrom -ne $ExpectedCommit) { throw "UpgradedFrom '$($a.UpgradedFrom)' != previous commit" }
    $userData = Join-Path $profileRoot 'Roaming\Godot\app_userdata\Mudds Shipyards'
    if (-not (Test-Path -LiteralPath (Join-Path $userData 'installer-probe-marker.txt'))) { throw 'upgrade removed the owned user data' }
    "upgraded_from=$($a.UpgradedFrom)"
}

Step 'silent_uninstall' {
    $code = Run-Silent (Join-Path $installDir 'uninstall.exe') '/S' 120000
    if ($code -ne 0) { throw "uninstaller launcher exit code $code" }
    # The launcher hands off to a copy of itself in %TEMP% so it can delete its
    # own file; wait for the install directory to disappear.
    if (-not (Wait-Gone $installDir 90000)) {
        $left = (Get-ChildItem -LiteralPath $installDir -Force | ForEach-Object { $_.Name }) -join ','
        throw "install directory still present after uninstall: $left"
    }
    if (-not (Wait-Gone $startMenu 30000)) { throw 'Start Menu folder still present' }
    if (Test-Path $regUninstall) { throw 'uninstall registry key still present' }
    if (Test-Path $regApp) { throw 'application registry key still present' }
    $userData = Join-Path $profileRoot 'Roaming\Godot\app_userdata\Mudds Shipyards'
    if (-not (Test-Path -LiteralPath (Join-Path $userData 'installer-probe-marker.txt'))) { throw 'uninstall removed user data; it must be preserved' }
    'install_dir_removed=True start_menu_removed=True registry_removed=True user_data_preserved=True'
}

$result.status = 'PASS'
Save-Result
Write-Output 'INSTALLER_VERIFICATION_OK'
exit 0
