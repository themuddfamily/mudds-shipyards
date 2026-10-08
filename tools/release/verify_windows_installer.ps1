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
Supply UserDataRecoveryFixture to exercise corrupt-primary/valid-backup startup
and unsupported-newer document preservation on the target build before rollback.
The fixture must be a production UserDataStore document with low graphics settings
and tutorial progress (generate it through RuntimeSettings/UserDataStore APIs).
Recovery mode also isolates installer environment and Start Menu within the probe.
Corrupt bytes and recovered settings/tutorial identity are checked; newer-schema
primary, backup, pending and history bytes are hash checked;
logs and corrupt witness remain available after uninstall. Application recovery
warnings are retained; engine/script errors, leaks and duplicate readiness fail.
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
    [string]$UserDataRecoveryFixture,
    [int]$StartupTimeoutMs = 120000
)
$ErrorActionPreference = 'Stop'
$regUninstall = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\MuddsShipyards'
$regApp = 'HKCU:\Software\Mudds Shipyards'
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Mudds Shipyards'
$installDir = Join-Path $ProbeRoot 'install'
$profileRoot = Join-Path $ProbeRoot 'profile'
$userData = Join-Path $profileRoot 'AppData\Roaming\Godot\app_userdata\Mudds Shipyards'
$marker = Join-Path $userData 'installer-probe-marker.txt'
$markerHash = $null
$documentHashes = @{}
$document = Join-Path $userData 'mudds_user_data.json'
$checkRecovery = -not [string]::IsNullOrWhiteSpace($UserDataRecoveryFixture)
$realStartMenu = $startMenu
if ($checkRecovery) { $startMenu = Join-Path $profileRoot 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Mudds Shipyards' }
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
    user_data_recovery = $(if ($checkRecovery) { 'REQUESTED' } else { 'NOT_RUN' })
    recovery_tested_commit = $(if ($checkRecovery) { $ExpectedCommit } else { $null })
    user_data_path = $userData
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
    if ($checkRecovery) {
        $info.EnvironmentVariables['APPDATA'] = (Join-Path $profileRoot 'AppData\Roaming')
        $info.EnvironmentVariables['LOCALAPPDATA'] = (Join-Path $profileRoot 'AppData\Local')
        $info.EnvironmentVariables['USERPROFILE'] = $profileRoot
        $info.EnvironmentVariables['TEMP'] = (Join-Path $profileRoot 'Temp')
        $info.EnvironmentVariables['TMP'] = (Join-Path $profileRoot 'Temp')
    }
    $proc = [System.Diagnostics.Process]::Start($info)
    if (-not $proc.WaitForExit($timeoutMs)) { $proc.Kill(); $proc.WaitForExit(); throw "$file timed out after $timeoutMs ms" }
    return $proc.ExitCode
}
function Assert-UserData {
    if (-not (Test-Path -LiteralPath $marker)) { throw 'installer removed the owned user data' }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $marker).Hash -ne $markerHash) { throw 'installer changed the owned user data' }
    foreach ($path in $documentHashes.Keys) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -ne $documentHashes[$path]) { throw "installed startup/transition changed protected document: $path" }
    }
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
    $info.EnvironmentVariables['APPDATA'] = (Join-Path $profileRoot 'AppData\Roaming')
    $info.EnvironmentVariables['LOCALAPPDATA'] = (Join-Path $profileRoot 'AppData\Local')
    $info.EnvironmentVariables['USERPROFILE'] = $profileRoot
    $info.EnvironmentVariables['TEMP'] = (Join-Path $profileRoot 'Temp')
    $info.EnvironmentVariables['TMP'] = (Join-Path $profileRoot 'Temp')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($info)
    if (-not $proc.WaitForExit($StartupTimeoutMs)) { $proc.Kill(); $proc.WaitForExit(); throw "$stage startup check timed out" }
    Assert-StartupLog $log $proc.ExitCode | Out-Null
    Assert-UserData
    return "exit=0 sentinel=True wall_ms=$($timer.ElapsedMilliseconds)"
}
function Assert-StartupLog([string]$log, [int]$exitCode) {
    $sentinelCount = 0
    if (Test-Path -LiteralPath $log) { $sentinelCount = @(Select-String -LiteralPath $log -Pattern '^STARTUP_MENU_READY_OK:').Count }
    $sentinel = $sentinelCount -eq 1
    if ($exitCode -ne 0 -or -not $sentinel) { throw "exit=$($exitCode) sentinel=$sentinel" }
    if (Select-String -LiteralPath $log -Pattern '(^|\s)(SCRIPT ERROR|ERROR):|ObjectDB instances leaked|resources still in use|RID allocations.*leaked') { throw "engine/script/leak diagnostic in $log" }
    return 'exit=0 sentinel_count=1 engine_script_leak_diagnostics=0'
}
function Assert-NewerDocumentDiagnostics([string]$stage) {
    $log = Join-Path $ProbeRoot "$stage-startup.log"
    if (-not (Select-String -LiteralPath $log -SimpleMatch 'Atomic runtime settings load retained authored defaults: store_load_failed / newer_schema')) { throw "missing application newer-schema diagnostic in $log" }
    if (Test-Path -LiteralPath ($document + '.recovery')) { throw 'newer document was quarantined as corrupt' }
    return 'application_newer_schema_diagnostic_retained=True'
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
    if (Test-Path -LiteralPath $realStartMenu) { throw "Start Menu folder already exists: $realStartMenu" }
    if (Test-Path -LiteralPath $startMenu) { throw "private Start Menu folder already exists: $startMenu" }
    New-Item -ItemType Directory -Path $ProbeRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'AppData\Roaming') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'AppData\Local') -Force | Out-Null
    New-Item -ItemType Directory -Path $userData -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $profileRoot 'Temp') -Force | Out-Null
    if ($checkRecovery) {
        if (-not (Test-Path -LiteralPath $UserDataRecoveryFixture -PathType Leaf)) { throw 'recovery fixture missing' }
        $fixture = Get-Content -LiteralPath $UserDataRecoveryFixture -Raw | ConvertFrom-Json
        if ($fixture.schema_version -ne 1 -or $fixture.payload.runtime_settings.values.graphics_profile -ne 'low' -or $fixture.payload.tutorial_prompts_seen.seen_ids.Count -lt 1) { throw 'recovery fixture must contain schema 1, low runtime settings and retained tutorial progress' }
    }
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

if ($crossBuild) {
    Step 'locked_upgrade_preserves_previous' {
        $path = Join-Path $installDir 'MuddsShipyards.exe'
        $provenancePath = Join-Path $installDir 'source-commit.txt'
        $beforeProvenance = [IO.File]::ReadAllBytes($provenancePath)
        $beforeRegistry = @(Get-ItemProperty -Path $regApp; Get-ItemProperty -Path $regUninstall) | ConvertTo-Json -Depth 3 -Compress
        # Hold an exclusive read handle: the new installer must fail without
        # publishing its build identity or modifying the previous executable.
        # Release even on timeout/exception before Step attempts owned cleanup.
        $lock = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        try { $code = Run-Silent $Installer "/S /D=$installDir" 120000 }
        finally { $lock.Dispose() }
        if ($code -ne 2) { throw "locked upgrade exit=$code expected=2" }
        Assert-Installed $initialHash $initialCommit
        Assert-RegistryAndShortcuts $initialCommit ''
        $afterProvenance = [IO.File]::ReadAllBytes($provenancePath)
        if ([Convert]::ToBase64String($beforeProvenance) -ne [Convert]::ToBase64String($afterProvenance)) { throw 'locked upgrade changed provenance bytes' }
        $afterRegistry = @(Get-ItemProperty -Path $regApp; Get-ItemProperty -Path $regUninstall) | ConvertTo-Json -Depth 3 -Compress
        if ($beforeRegistry -ne $afterRegistry) { throw 'locked upgrade changed registry metadata' }
        if (Test-Path -LiteralPath (Join-Path $installDir 'MuddsShipyards.exe.pending')) { throw 'failed upgrade left pending payload' }
        'exit=2 previous_exe_metadata_and_user_data_preserved=True pending_removed=True'
    }
}

Step 'silent_upgrade_over_existing' {
    $code = Run-Silent $Installer "/S /D=$installDir" 600000
    if ($code -ne 0) { throw "upgrade installer exit code $code" }
    Assert-Installed $ExpectedExeSha256 $ExpectedCommit
    Assert-RegistryAndShortcuts $ExpectedCommit $initialCommit
}
Step 'upgraded_startup_check' { Run-Startup 'upgraded' }

# Optional installed-document acceptance: use a production-API generated fixture,
# not a marker masquerading as settings or saved gameplay. A distinctive low
# graphics profile proves the boot preview actually selected the valid backup.
if ($checkRecovery) {
    Step 'installed_corrupt_document_backup_recovery' {
        Assert-Installed $ExpectedExeSha256 $ExpectedCommit
        if (Test-Path -LiteralPath $document) { Copy-Item -LiteralPath $document -Destination (Join-Path $ProbeRoot 'ordinary-startup-document-witness.json') }
        [IO.File]::WriteAllText($document, '{broken-installed-primary')
        Copy-Item -LiteralPath $UserDataRecoveryFixture -Destination ($document + '.bak')
        Copy-Item -LiteralPath $document -Destination (Join-Path $ProbeRoot 'corrupt-primary-witness.json')
        $corruptHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $document).Hash
        Run-Startup 'corrupt-backup'
        $log = Join-Path $ProbeRoot 'corrupt-backup-startup.log'
        if (-not (Select-String -LiteralPath $log -SimpleMatch 'STARTUP graphics profile=low')) { throw 'backup settings were not selected by startup' }
        $quarantine = $document + '.recovery'
        if (-not (Test-Path -LiteralPath $quarantine) -or (Get-FileHash -Algorithm SHA256 -LiteralPath $quarantine).Hash -ne $corruptHash) { throw 'corrupt primary was not retained byte-for-byte in recovery quarantine' }
        $fixture = Get-Content -LiteralPath $UserDataRecoveryFixture -Raw | ConvertFrom-Json
        $recovered = Get-Content -LiteralPath $document -Raw | ConvertFrom-Json
        foreach ($namespace in @('runtime_settings', 'tutorial_prompts_seen')) {
            $expected = $fixture.payload.$namespace | ConvertTo-Json -Depth 12 -Compress
            $actual = $recovered.payload.$namespace | ConvertTo-Json -Depth 12 -Compress
            if ($expected -ne $actual) { throw "backup recovery changed retained $namespace identity" }
        }
        if ($recovered.schema_version -ne 1 -or $recovered.generation -lt $fixture.generation) { throw 'backup recovery lost document generation' }
        $documentHashes[$quarantine] = $corruptHash
        "backup_settings_loaded=True recovered_settings_and_tutorial_identity_preserved=True corrupt_quarantine_sha256=$corruptHash generation=$($recovered.generation)"

    }
    Step 'installed_unsupported_newer_document_preserved' {
        # Preserve the corrupt witness before replacing only probe-owned bytes.
        Copy-Item -LiteralPath $document -Destination (Join-Path $ProbeRoot 'recovered-document-witness.json')
        $documentHashes.Clear()
        Remove-Item -LiteralPath ($document + '.recovery')
        [IO.File]::WriteAllText($document, '{"schema_version":999,"future_player_progress":"retain exactly"}')
        [IO.File]::WriteAllText(($document + '.tmp'), '{"schema_version":999,"future_pending_progress":"retain exactly"}')
        foreach ($file in (Get-ChildItem -LiteralPath $userData -Filter 'mudds_user_data.json*' -File)) { $documentHashes[$file.FullName] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash }
        Run-Startup 'unsupported-newer'
        Assert-NewerDocumentDiagnostics 'unsupported-newer'
        'newer_primary_pending_and_valid_backup_bytes_preserved=True'
    }
}

if ($crossBuild) {
    Step 'silent_rollback_to_previous' {
        $code = Run-Silent $PreviousInstaller "/S /D=$installDir" 600000
        if ($code -ne 0) { throw "rollback installer exit code $code" }
        Assert-Installed $PreviousExpectedExeSha256 $PreviousExpectedCommit
        Assert-RegistryAndShortcuts $PreviousExpectedCommit $ExpectedCommit
    }
    Step 'rolled_back_startup_check' { Run-Startup 'rolled-back'; if ($checkRecovery) { Assert-NewerDocumentDiagnostics 'rolled-back' } }
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
if ($checkRecovery) { $result.user_data_recovery = 'PASS'; $result.protected_document_sha256 = $documentHashes }
Save-Result
Write-Output 'INSTALLER_VERIFICATION_OK'
exit 0
