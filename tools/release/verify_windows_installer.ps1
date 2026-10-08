<#
.SYNOPSIS
Exercise silent install, startup, same-build upgrade or old-to-new upgrade and
rollback, uninstall, and cleanup in a private Windows probe location.

.DESCRIPTION
PreviousInstaller, PreviousExpectedExeSha256 and PreviousExpectedCommit must be
supplied together to test different builds. Without them, the existing
same-build reinstall mode remains available. Every tested installation must
match its expected executable hash and source commit, retain seeded player
data, and exit 0 with STARTUP_MENU_READY_OK under Dummy audio and an owned
APPDATA/LOCALAPPDATA profile. Existing user installs are refused. Failed probes
preserve the original diagnostic and attempt cleanup of their owned install.
The JSON result remains schema_version 1; cross-build fields are additive.
#>
param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [Parameter(Mandatory = $true)][string]$ExpectedExeSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedCommit,
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [string]$PreviousInstaller,
    [string]$PreviousExpectedExeSha256,
    [string]$PreviousExpectedCommit,
    [int]$StartupTimeoutMs = 120000
)
$ErrorActionPreference = 'Stop'
$regUninstall = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MuddsShipyards'
$regApp = 'HKCU:\Software\Mudds Shipyards'
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Mudds Shipyards'
$installDir = Join-Path $ProbeRoot 'install'
$profileRoot = Join-Path $ProbeRoot 'profile'
$userData = Join-Path $profileRoot 'Roaming\Godot\app_userdata\Mudds Shipyards'
$marker = Join-Path $userData 'installer-probe-marker.txt'
$markerHash = $null
$ownsInstall = $false
$crossBuild = -not [string]::IsNullOrWhiteSpace($PreviousInstaller)
$steps = New-Object System.Collections.ArrayList
$result = [ordered]@{
    schema_version = 1
    mode = $(if ($crossBuild) { 'cross_build_upgrade_rollback' } else { 'same_build_reinstall' })
    installer = $Installer
    installer_sha256 = $null
    expected_exe_sha256 = $ExpectedExeSha256.ToLowerInvariant()
    expected_commit = $ExpectedCommit
    previous_installer = $PreviousInstaller
    previous_installer_sha256 = $null
    previous_expected_exe_sha256 = $PreviousExpectedExeSha256.ToLowerInvariant()
    previous_expected_commit = $PreviousExpectedCommit
    install_dir = $installDir
    steps = $steps
    cleanup = [ordered]@{ status = 'NOT_RUN'; detail = $null }
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
        if ($script:ownsInstall) {
            try {
                $result.cleanup.detail = Cleanup-OwnedInstallation
                $result.cleanup.status = 'PASS'
            } catch {
                $result.cleanup.status = 'FAIL'
                $result.cleanup.detail = $_.Exception.Message
            }
        }
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
function Assert-UserData {
    if (-not (Test-Path -LiteralPath $marker)) { throw 'installer removed the owned user data' }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $marker).Hash -ne $markerHash) { throw 'installer changed the owned user data' }
}
function Assert-Installed([string]$hash, [string]$commit) {
    foreach ($name in @('MuddsShipyards.exe', 'uninstall.exe', 'source-commit.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $installDir $name))) { throw "missing $name" }
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $installDir 'MuddsShipyards.exe')).Hash.ToLowerInvariant()
    if ($actual -ne $hash.ToLowerInvariant()) {
        $fileCommit = 'missing'
        $registryCommit = 'missing'
        $provenancePath = Join-Path $installDir 'source-commit.txt'
        if (Test-Path -LiteralPath $provenancePath) {
            $fileCommit = (Get-Content -LiteralPath $provenancePath | Where-Object { $_ -like 'source_commit=*' }) -join ','
        }
        if (Test-Path $regApp) { $registryCommit = (Get-ItemProperty -Path $regApp).SourceCommit }
        throw "installed exe sha256 $actual != expected $hash; provenance=$fileCommit registry_source_commit=$registryCommit"
    }
    $provenance = Get-Content -LiteralPath (Join-Path $installDir 'source-commit.txt')
    if (-not ($provenance -contains "source_commit=$commit")) { throw 'source-commit.txt does not record the expected commit' }
    if (-not ($provenance -contains 'signing=unsigned')) { throw 'source-commit.txt does not declare the build unsigned' }
    Assert-UserData
    return "exe_sha256=$actual source_commit=$commit user_data_preserved=True"
}
function Assert-RegistryAndShortcuts([string]$commit, [string]$upgradedFrom) {
    $u = Get-ItemProperty -Path $regUninstall
    if ($u.InstallLocation -ne $installDir) { throw "InstallLocation '$($u.InstallLocation)' != '$installDir'" }
    if ($u.DisplayName -ne 'Mudds Shipyards') { throw "DisplayName '$($u.DisplayName)'" }
    if ($u.QuietUninstallString -ne ('"' + (Join-Path $installDir 'uninstall.exe') + '" /S')) { throw 'QuietUninstallString does not target the owned uninstaller with /S' }
    if ($u.NoModify -ne 1 -or $u.NoRepair -ne 1) { throw 'NoModify/NoRepair not set' }
    $a = Get-ItemProperty -Path $regApp
    if ($a.InstallLocation -ne $installDir) { throw 'application registry InstallLocation changed' }
    if ($a.SourceCommit -ne $commit) { throw "SourceCommit '$($a.SourceCommit)' != '$commit'" }
    if ([string]::IsNullOrEmpty($upgradedFrom)) {
        if ($a.PSObject.Properties.Name -contains 'UpgradedFrom') { throw 'clean install must not record UpgradedFrom' }
    } elseif ($a.UpgradedFrom -ne $upgradedFrom) {
        throw "UpgradedFrom '$($a.UpgradedFrom)' != previous commit '$upgradedFrom'"
    }
    $short = $commit.Substring(0, 7)
    if (-not $u.DisplayVersion.EndsWith("+$short") -or $a.BuildLabel -ne $u.DisplayVersion) { throw 'registry build labels do not identify the expected commit' }
    $shell = New-Object -ComObject WScript.Shell
    foreach ($pair in @(@('Mudds Shipyards.lnk', 'MuddsShipyards.exe'), @('Uninstall Mudds Shipyards.lnk', 'uninstall.exe'))) {
        $link = Join-Path $startMenu $pair[0]
        if (-not (Test-Path -LiteralPath $link)) { throw "missing Start Menu shortcut $($pair[0])" }
        $target = $shell.CreateShortcut($link).TargetPath
        if ($target -ne (Join-Path $installDir $pair[1])) { throw "shortcut targets '$target'" }
    }
    return "display_version=$($u.DisplayVersion) upgraded_from=$($a.UpgradedFrom)"
}
function Run-Startup([string]$stage) {
    $log = Join-Path $ProbeRoot "$stage-startup.log"
    if (Test-Path -LiteralPath $log) { throw "startup log already exists: $log" }
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
    if (-not $proc.WaitForExit($StartupTimeoutMs)) { $proc.Kill(); $proc.WaitForExit(); throw "$stage startup check timed out" }
    $sentinel = (Test-Path -LiteralPath $log) -and [bool](Select-String -LiteralPath $log -SimpleMatch 'STARTUP_MENU_READY_OK')
    if ($proc.ExitCode -ne 0 -or -not $sentinel) { throw "exit=$($proc.ExitCode) sentinel=$sentinel" }
    Assert-UserData
    return "exit=0 sentinel=True wall_ms=$($timer.ElapsedMilliseconds)"
}
function Assert-Uninstalled {
    if (-not (Wait-Gone $installDir 90000)) {
        $left = (Get-ChildItem -LiteralPath $installDir -Force | ForEach-Object { $_.Name }) -join ','
        throw "install directory still present after uninstall: $left"
    }
    if (-not (Wait-Gone $startMenu 30000)) { throw 'Start Menu folder still present' }
    if (Test-Path $regUninstall) { throw 'uninstall registry key still present' }
    if (Test-Path $regApp) { throw 'application registry key still present' }
    Assert-UserData
    return 'install_dir_removed=True start_menu_removed=True registry_removed=True user_data_preserved=True'
}
function Cleanup-OwnedInstallation {
    # The preconditions proved these shared names were absent before this
    # process acquired ownership. Refuse cleanup if another installation has
    # replaced their locations/targets. Never remove the probe's user profile.
    foreach ($key in @($regUninstall, $regApp)) {
        if (Test-Path $key) {
            if ((Get-ItemProperty -Path $key).InstallLocation -ne $installDir) { throw "cleanup refused: $key no longer belongs to this probe" }
        }
    }
    $shell = New-Object -ComObject WScript.Shell
    foreach ($pair in @(@('Mudds Shipyards.lnk', 'MuddsShipyards.exe'), @('Uninstall Mudds Shipyards.lnk', 'uninstall.exe'))) {
        $link = Join-Path $startMenu $pair[0]
        if ((Test-Path -LiteralPath $link) -and $shell.CreateShortcut($link).TargetPath -ne (Join-Path $installDir $pair[1])) { throw "cleanup refused: shortcut $link no longer belongs to this probe" }
    }
    # Limited fallback also handles a partially written install whose
    # uninstaller is missing or cannot run. Do not recursively delete files.
    foreach ($name in @('MuddsShipyards.exe', 'MuddsShipyards.exe.pending', 'uninstall.exe', 'source-commit.txt')) {
        $path = Join-Path $installDir $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    if ((Test-Path -LiteralPath $installDir) -and -not (Get-ChildItem -LiteralPath $installDir -Force)) { Remove-Item -LiteralPath $installDir }
    foreach ($name in @('Mudds Shipyards.lnk', 'Uninstall Mudds Shipyards.lnk')) {
        $path = Join-Path $startMenu $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    if ((Test-Path -LiteralPath $startMenu) -and -not (Get-ChildItem -LiteralPath $startMenu -Force)) { Remove-Item -LiteralPath $startMenu }
    foreach ($key in @($regUninstall, $regApp)) {
        if (Test-Path $key) { Remove-Item -LiteralPath $key -Recurse }
    }
    return Assert-Uninstalled
}

Step 'preconditions' {
    $previousArgs = @($PreviousInstaller, $PreviousExpectedExeSha256, $PreviousExpectedCommit) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($previousArgs.Count -ne 0 -and $previousArgs.Count -ne 3) { throw 'PreviousInstaller, PreviousExpectedExeSha256 and PreviousExpectedCommit must be supplied together' }
    if ($ExpectedExeSha256 -notmatch '^[0-9a-fA-F]{64}$' -or $ExpectedCommit -notmatch '^[0-9a-fA-F]{40}$') { throw 'expected hash must be SHA-256 and expected commit must be a full Git commit' }
    if (-not [IO.Path]::IsPathRooted($ProbeRoot)) { throw 'ProbeRoot must be an absolute private directory' }
    $script:installDir = Join-Path ([IO.Path]::GetFullPath($ProbeRoot)) 'install'
    $result.install_dir = $installDir
    if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) { throw "installer missing: $Installer" }
    if ($crossBuild) {
        if (-not (Test-Path -LiteralPath $PreviousInstaller -PathType Leaf)) { throw "previous installer missing: $PreviousInstaller" }
        if ($PreviousExpectedExeSha256 -notmatch '^[0-9a-fA-F]{64}$' -or $PreviousExpectedCommit -notmatch '^[0-9a-fA-F]{40}$') { throw 'previous hash must be SHA-256 and previous commit must be a full Git commit' }
        if ($PreviousExpectedCommit -eq $ExpectedCommit -or $PreviousExpectedExeSha256 -eq $ExpectedExeSha256) { throw 'cross-build mode requires distinct commits and executable hashes' }
        $result.previous_installer_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PreviousInstaller).Hash.ToLowerInvariant()
    }
    if (Test-Path -LiteralPath $installDir) { throw "install directory already exists: $installDir" }
    if (Test-Path -LiteralPath $profileRoot) { throw "probe profile already exists: $profileRoot" }
    $defaultInstall = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\Mudds Shipyards'
    if (Test-Path -LiteralPath $defaultInstall) { throw "default user installation already exists: $defaultInstall" }
    if (Test-Path $regUninstall) { throw 'an uninstall key for Mudds Shipyards already exists in HKCU; refusing to disturb it' }
    if (Test-Path $regApp) { throw 'HKCU\Software\Mudds Shipyards already exists; refusing to disturb it' }
    if (Test-Path -LiteralPath $startMenu) { throw "Start Menu folder already exists: $startMenu" }
    New-Item -ItemType Directory -Path $ProbeRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'Roaming') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'Local') -Force | Out-Null
    New-Item -ItemType Directory -Path $userData -Force | Out-Null
    [IO.File]::WriteAllText($marker, "seeded before install`n")
    $script:markerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $marker).Hash
    $result.installer_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Installer).Hash.ToLowerInvariant()
    if ($crossBuild -and $result.installer_sha256 -eq $result.previous_installer_sha256) { throw 'cross-build mode requires distinct installers' }
    "installer_sha256=$($result.installer_sha256)"
}

$initialInstaller = $Installer
$initialHash = $ExpectedExeSha256
$initialCommit = $ExpectedCommit
if ($crossBuild) {
    $initialInstaller = $PreviousInstaller
    $initialHash = $PreviousExpectedExeSha256
    $initialCommit = $PreviousExpectedCommit
}
Step 'silent_install' {
    $script:ownsInstall = $true
    $code = Run-Silent $initialInstaller "/S /D=$installDir" 600000
    if ($code -ne 0) { throw "installer exit code $code" }
    "exit=$code source_commit=$initialCommit"
}
Step 'installed_files' { Assert-Installed $initialHash $initialCommit }
Step 'registry_and_shortcuts' { Assert-RegistryAndShortcuts $initialCommit '' }
Step 'installed_startup_check' { Run-Startup 'installed' }

Step 'silent_upgrade_over_existing' {
    $code = Run-Silent $Installer "/S /D=$installDir" 600000
    if ($code -ne 0) { throw "upgrade installer exit code $code" }
    Assert-Installed $ExpectedExeSha256 $ExpectedCommit
    Assert-RegistryAndShortcuts $ExpectedCommit $initialCommit
}
Step 'upgraded_startup_check' { Run-Startup 'upgraded' }

if ($crossBuild) {
    Step 'silent_rollback_to_previous' {
        $code = Run-Silent $PreviousInstaller "/S /D=$installDir" 600000
        if ($code -ne 0) { throw "rollback installer exit code $code" }
        Assert-Installed $PreviousExpectedExeSha256 $PreviousExpectedCommit
        Assert-RegistryAndShortcuts $PreviousExpectedCommit $ExpectedCommit
    }
    Step 'rolled_back_startup_check' { Run-Startup 'rolled-back' }
}

Step 'silent_uninstall' {
    $code = Run-Silent (Join-Path $installDir 'uninstall.exe') '/S' 120000
    if ($code -ne 0) { throw "uninstaller launcher exit code $code" }
    # NSIS hands off to a temporary copy so its own file can be deleted.
    Assert-Uninstalled
}
$result.cleanup.status = 'PASS'
$result.cleanup.detail = 'silent uninstall removed the owned installation; probe profile and logs retained'
$result.status = 'PASS'
Save-Result
Write-Output 'INSTALLER_VERIFICATION_OK'
exit 0
