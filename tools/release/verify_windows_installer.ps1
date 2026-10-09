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
ForceKillRecovery additionally kills three owned installed boots after their real
starting/running markers commit, observes the fourth boot's safe-start recommendation
and crash journal, then requires menu readiness and orderly shutdown. It requires
UserDataRecoveryFixture; it never fabricates interrupted markers or crash events.
InWorldRecovery additionally exercises the target installed payload's ordinary
Boot entry in a separate throwaway profile. It kills one owned process after
actual durable activity readiness, then restarts that profile to prove exact
boundary, one new receipt and its crash journal. InWorldRecoveryContext selects
pilot (default), cabin, rest or crew. Cabin/rest/crew require a matching context
in both Boot markers; older pilot-only payloads cannot qualify those selections.
InWorldRecoveryActivity selects convoy (default), beacon, mining, stationdefense or hulk.
Beacon/mining/stationdefense/hulk require pilot context and verify the genuine
unpaid terminal and safe-home pilot Resume. Beacon/mining/stationdefense also
verify ordinary throttle, HUD Start payment and the saved acknowledgement without
duplicates.
Stationdefense verifies only the earned unpaid report and atomic paid acknowledgement;
combat actors, elapsed timers, leases, damage and airborne claims are not restored.
Mining verifies the schema 2 unpaid extraction, one atomic capacity acknowledgement
with existing non-granting metadata, and unchanged production settings/cargo.
Hulk verifies genuinely earned unpaid breaker completion, the unchanged terminal
and exactly one permanent cell ledger receipt through automatic Boot/running
retry, plus real safe-home Resume/throttle and unchanged settings/cargo.
InWorldCancelPath (default:
ProbeRoot\in-world-recovery.cancel) provides an independent owned-child abort.
The activity profile is removed; logs/documents remain in ProbeRoot. This does
not qualify normal controls, pilot-seat/world restoration or native GPU work.
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
    [switch]$ForceKillRecovery,
    [switch]$InWorldRecovery,
    [ValidateSet('pilot','cabin','rest','crew')][string]$InWorldRecoveryContext = 'pilot',
    [ValidateSet('convoy','beacon','mining','stationdefense','hulk')][string]$InWorldRecoveryActivity = 'convoy',
    [string]$InWorldCancelPath,
    [int]$StartupTimeoutMs = 120000
)
$ErrorActionPreference = 'Stop'
$InWorldRecoveryContext = $InWorldRecoveryContext.ToLowerInvariant()
$InWorldRecoveryActivity = $InWorldRecoveryActivity.ToLowerInvariant()
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
$isolateInstaller = $checkRecovery -or $InWorldRecovery
$realStartMenu = $startMenu
if ($isolateInstaller) { $startMenu = Join-Path $profileRoot 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Mudds Shipyards' }
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
    forced_kill_recovery = $(if ($ForceKillRecovery) { 'REQUESTED' } else { 'NOT_RUN' })
    in_world_recovery = $(if ($InWorldRecovery) { 'REQUESTED' } else { 'NOT_RUN' })
    recovery_tested_commit = $(if ($checkRecovery) { $ExpectedCommit } else { $null })
    user_data_path = $userData
    status = 'FAIL'
}
function Save-Result {
    $result.steps = @($steps)
    $json = $result | ConvertTo-Json -Depth $(if ($InWorldRecovery) { 60 } else { 6 })
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
    if ($checkRecovery -or $InWorldRecovery) {
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
    $info = New-OwnedBootInfo $log $true
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($info)
    if (-not $proc.WaitForExit($StartupTimeoutMs)) { $proc.Kill(); $proc.WaitForExit(); throw "$stage startup check timed out" }
    Assert-StartupLog $log $proc.ExitCode | Out-Null
    Assert-UserData
    return "exit=0 sentinel=True wall_ms=$($timer.ElapsedMilliseconds)"
}
function New-OwnedBootInfo([string]$log, [bool]$startupCheck, [string]$ownedProfileRoot = '') {
    if ([string]::IsNullOrEmpty($ownedProfileRoot)) { $ownedProfileRoot = $profileRoot }
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $installDir 'MuddsShipyards.exe'
    $info.Arguments = '--headless --audio-driver Dummy --log-file "' + $log + '"'
    if ($startupCheck) { $info.Arguments = '--headless --audio-driver Dummy --startup-check --log-file "' + $log + '"' }
    $info.WorkingDirectory = $installDir
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.EnvironmentVariables['APPDATA'] = (Join-Path $ownedProfileRoot 'AppData\Roaming')
    $info.EnvironmentVariables['LOCALAPPDATA'] = (Join-Path $ownedProfileRoot 'AppData\Local')
    $info.EnvironmentVariables['USERPROFILE'] = $ownedProfileRoot
    $info.EnvironmentVariables['TEMP'] = (Join-Path $ownedProfileRoot 'Temp')
    $info.EnvironmentVariables['TMP'] = (Join-Path $ownedProfileRoot 'Temp')
    return $info
}
function Seed-ForcedKillFixture {
    # Replace the complete private transaction chain, not only its primary.
    # Keeping an unrelated old backup would make the production store refuse
    # this deliberately reset fixture as incoherent_primary_backup.
    $prior = Join-Path $ProbeRoot 'forced-kill-prior-documents'
    if (Test-Path -LiteralPath $prior) { throw 'forced-kill prior-document witness already exists' }
    New-Item -ItemType Directory -Path $prior | Out-Null
    foreach ($suffix in @('', '.bak', '.bak.1', '.bak.2', '.bak.3', '.tmp')) {
        $path = $document + $suffix
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Copy-Item -LiteralPath $path -Destination (Join-Path $prior ([IO.Path]::GetFileName($path)))
            Remove-Item -LiteralPath $path
        }
    }
    Copy-Item -LiteralPath $UserDataRecoveryFixture -Destination $document
}
function Read-RecoveryDocument {
    # Atomic rotation can briefly remove the primary; retry only the read.
    # Share deletion as well as writes so polling cannot block the game's
    # production rename/replace transaction on Windows.
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($document, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = New-Object IO.StreamReader($stream)
        return ($reader.ReadToEnd() | ConvertFrom-Json)
    } catch { return $null }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}
function Assert-RecoveryPayload($snapshot, [bool]$recommended) {
    if ($null -eq $snapshot -or $snapshot.schema_version -ne 1) { throw 'missing valid recovery document' }
    $fixture = Get-Content -LiteralPath $UserDataRecoveryFixture -Raw | ConvertFrom-Json
    if ($recommended) { $fixture.payload.runtime_settings.values.window_mode = 'windowed' }
    foreach ($namespace in @('runtime_settings', 'tutorial_prompts_seen')) {
        $expected = $fixture.payload.$namespace | ConvertTo-Json -Depth 12 -Compress
        $actual = $snapshot.payload.$namespace | ConvertTo-Json -Depth 12 -Compress
        if ($actual -ne $expected) { throw "forced-kill recovery changed retained $namespace" }
    }
    if ($snapshot.generation -le $fixture.generation) { throw 'forced-kill boot did not commit production state' }
}
function Wait-OwnedRecoveryMarker($proc, [int]$cycle, [string]$witness) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (-not $proc.HasExited -and $timer.ElapsedMilliseconds -lt $StartupTimeoutMs) {
        $snapshot = Read-RecoveryDocument
        $safe = $snapshot.payload.safe_start_recovery
        $crash = $snapshot.payload.crash_recovery
        if ($null -ne $safe -and $null -ne $crash -and
            $safe.state -eq 'starting' -and $crash.state -eq 'running' -and
            $safe.startup_generation -eq $cycle -and $crash.startup_generation -eq $cycle) {
            if ($safe.consecutive_failure_count -ne ($cycle - 1) -or
                $crash.unclean_start_count -ne ($cycle - 1) -or
                $safe.safe_settings_recommended -ne ($cycle -eq 4)) { throw 'incorrect forced-kill recovery counters/recommendation' }
            Assert-RecoveryPayload $snapshot ($cycle -eq 4)
            [IO.File]::WriteAllText($witness, ($snapshot | ConvertTo-Json -Depth 20))
            return $snapshot
        }
        Start-Sleep -Milliseconds 10
    }
    throw "owned boot PID=$($proc.Id) did not commit starting/running generation=$cycle before exit/timeout"
}
function Run-ForcedKillBoot([int]$cycle, [bool]$startupCheck) {
    $log = Join-Path $ProbeRoot "forced-kill-$cycle-startup.log"
    $witness = Join-Path $ProbeRoot "forced-kill-$cycle-running-document.json"
    if ((Test-Path -LiteralPath $log) -or (Test-Path -LiteralPath $witness)) { throw 'forced-kill log/witness already exists' }
    $proc = $null
    try {
        $proc = [Diagnostics.Process]::Start((New-OwnedBootInfo $log $startupCheck))
        $snapshot = Wait-OwnedRecoveryMarker $proc $cycle $witness
        if ($startupCheck) {
            if (-not $proc.WaitForExit($StartupTimeoutMs)) { throw 'forced-kill recovery startup timed out' }
            Assert-StartupLog $log $proc.ExitCode | Out-Null
            Assert-UserData
            $closed = Read-RecoveryDocument
            Assert-RecoveryPayload $closed $true
            if ($closed.payload.crash_recovery.state -ne 'clean' -or $closed.payload.crash_recovery.unclean_start_count -ne 0 -or
                $closed.payload.safe_start_recovery.state -ne 'clean_shutdown' -or
                $closed.payload.crash_recovery.startup_generation -ne $cycle -or $closed.payload.safe_start_recovery.startup_generation -ne $cycle) { throw 'recovered installed startup did not commit orderly shutdown' }
            $journal = Get-Content -LiteralPath (Join-Path $userData 'diagnostics\crash-log.json') -Raw | ConvertFrom-Json
            $events = @($journal | ForEach-Object { $_.events } | Where-Object { $_.event_code -eq 'crash_detected' -and $_.session_id -eq $snapshot.payload.crash_recovery.session_id -and $_.fields.recovered -eq $true -and $_.fields.attempt_count -eq 3 })
            if ($events.Count -lt 1) { throw 'recovered installed startup did not publish its actual crash_detected journal event' }
            Copy-Item -LiteralPath $document -Destination (Join-Path $ProbeRoot 'forced-kill-recovered-document.json')
            Copy-Item -LiteralPath (Join-Path $userData 'diagnostics\crash-log.json') -Destination (Join-Path $ProbeRoot 'forced-kill-recovered-journal.json')
            return "exit=0 sentinel=True safe_start_recommended=True recovered_journal_session=$($snapshot.payload.crash_recovery.session_id) orderly_shutdown=True settings_tutorial_retained=True"
        }
        if ($proc.HasExited) { throw 'owned boot exited before OS kill' }
        $pidKilled = $proc.Id
        $proc.Kill()
        if (-not $proc.WaitForExit(10000)) { throw 'owned OS-killed process did not terminate' }
        if ($proc.ExitCode -eq 0) { throw 'OS-killed process reported orderly exit' }
        $interrupted = Read-RecoveryDocument
        Assert-RecoveryPayload $interrupted $false
        if ($interrupted.payload.safe_start_recovery.state -ne 'starting' -or $interrupted.payload.crash_recovery.state -ne 'running' -or
            $interrupted.payload.safe_start_recovery.startup_generation -ne $cycle -or $interrupted.payload.crash_recovery.startup_generation -ne $cycle) { throw 'OS kill did not retain actual interrupted startup markers' }
        Copy-Item -LiteralPath $document -Destination (Join-Path $ProbeRoot "forced-kill-$cycle-interrupted-document.json")
        if (Select-String -LiteralPath $log -Pattern '(^|\s)(SCRIPT ERROR|ERROR):|STARTUP_MENU_READY_OK:') { throw 'forced-kill boot failed or completed its check before kill' }
        return "owned_pid=$pidKilled os_kill_exit=$($proc.ExitCode) startup_generation=$cycle interrupted_markers_retained=True"
    } finally {
        # Only this Process object can be aborted; no process-name/global kill.
        if ($null -ne $proc) {
            if (-not $proc.HasExited) { $proc.Kill(); $proc.WaitForExit(10000) | Out-Null }
            $proc.Dispose()
        }
    }
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

function Read-InWorldLog([string]$log) {
    $stream = [IO.File]::Open($log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = New-Object System.IO.StreamReader($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Read-InWorldToken([string]$log,[string]$name) {
    if (-not (Test-Path -LiteralPath $log)) { return $null }
    $text = (Read-InWorldLog $log)
    # Do not interpret a partially flushed last line as a completed handshake.
    $lines = @($text -split '\r?\n')
    if ($lines.Count -lt 2) { return $null }
    $matches = @($lines[0..($lines.Count-2)] | Where-Object { $_.StartsWith($name + ': ') })
    if ($matches.Count -gt 1) { throw "duplicate $name" }
    if ($matches.Count -eq 1) { return ($matches[0].Substring($name.Length+2) | ConvertFrom-Json) }
    return $null
}
function Sorted-InWorldValue($value) {
    if ($null -eq $value) { return $null }
    if ($value -is [System.Management.Automation.PSCustomObject]) {
        $ordered = [ordered]@{}
        foreach ($property in @($value.PSObject.Properties | Sort-Object Name)) { $ordered[$property.Name] = Sorted-InWorldValue $property.Value }
        return [pscustomobject]$ordered
    }
    if ($value -is [Array]) {
        $items = @(); foreach ($item in $value) { $items += ,(Sorted-InWorldValue $item) }; return ,$items
    }
    return $value
}
function InWorld-Canonical($value) { return (Sorted-InWorldValue $value | ConvertTo-Json -Depth 60 -Compress) }
function InWorld-LogCounts([string]$log) {
    $text = (Read-InWorldLog $log)
    return [ordered]@{
        diagnostic_count=[regex]::Matches($text,'(?im)^\s*(?:SCRIPT\s+ERROR|ERROR:|FAIL:)|\b(?:FATAL ERROR|ObjectDB|Orphaned|Leaked)\b|Resource.*still in use').Count
        warning_count=[regex]::Matches($text,'(?im)^\s*WARNING:').Count
    }
}
function Check-InWorldCancel {
    if (Test-Path -LiteralPath $InWorldCancelPath) { throw 'installed in-world probe cancelled through its independent abort file' }
}
function Stop-InWorldOwned($proc, $entry, [string]$termination) {
    if (-not $proc.HasExited) {
        $proc.Kill()
        $entry.kill_called = $true
        $entry.termination = $termination
    }
    if (-not $proc.WaitForExit(15000)) { throw 'owned in-world process did not reap after Kill' }
}
function Assert-InWorldSelection {
    if (-not $InWorldRecovery -and $InWorldRecoveryActivity -ne 'convoy') { throw 'InWorldRecoveryActivity requires InWorldRecovery' }
    if ($InWorldRecoveryActivity -in @('beacon','mining','stationdefense','hulk') -and $InWorldRecoveryContext -ne 'pilot') { throw "$InWorldRecoveryActivity in-world recovery supports only pilot context" }
}
function InWorld-BeaconCount($payload) {
    if ($null -eq $payload.game_flow_reward_store.reward_counts.debris_route_navigation_data) { return 0 }
    return [int]$payload.game_flow_reward_store.reward_counts.debris_route_navigation_data
}
function Assert-InWorldBeaconArm($saved, $ready) {
    $terminal = $saved.payload.cinder_beacon_session
    if ((InWorld-Canonical $terminal) -ne (InWorld-Canonical $ready.boundary) -or $saved.payload.crash_recovery.state -ne 'running') { throw 'installed beacon readiness differs from actual durable document/running marker' }
    if ($terminal.schema_version -ne 1 -or @($terminal.activities).Count -ne 1) { throw 'invalid installed durable beacon record' }
    $activity = $terminal.activities[0]
    if ($activity.activity_id -ne 'cinder_debris_beacon_traversal' -or $activity.generation -le 0 -or $activity.state -ne 2 -or $activity.reward_granted -ne $false -or $activity.reward_requested -ne $true) { throw 'installed beacon is not a durable unpaid terminal' }
    if ($activity.progress.generation -ne $activity.generation -or $activity.progress.state -ne 2 -or $activity.progress.next_beacon_index -ne 4 -or $activity.progress.beacon_count -ne 4 -or $activity.progress.reward_requested -ne $false) { throw 'installed beacon terminal generation/cursor/payment boundary differs' }
    if ($ready.receipts -ne 0 -or (InWorld-BeaconCount $saved.payload) -ne $ready.receipts) { throw 'fresh installed beacon profile has incorrect receipt baseline' }
    $pilot = $ready.runtime_observation
    if ($pilot.player_seated -ne $true -or $pilot.craft_piloted -ne $true -or $pilot.craft_id -ne 'bulwark_heavy_gunship' -or $saved.payload.solo_safe_recovery.craft_id -ne $pilot.craft_id) { throw 'installed beacon arm did not retain its real safe pilot owner' }
}
function Assert-InWorldBeaconRecovered($final, $ready, $recovered, [string]$log) {
    if ((InWorld-Canonical $final.payload.cinder_beacon_session) -ne (InWorld-Canonical $recovered.paid_boundary)) { throw 'installed saved beacon acknowledgement differs from recovered paid boundary' }
    if ($final.payload.cinder_beacon_session.schema_version -ne 1 -or @($final.payload.cinder_beacon_session.activities).Count -ne 1) { throw 'invalid installed paid beacon record' }
    $activity = $ready.boundary.activities[0]
    $paid = $final.payload.cinder_beacon_session.activities[0]
    if ($paid.activity_id -ne $activity.activity_id -or $paid.generation -ne $activity.generation -or $paid.state -ne 2 -or $paid.reward_requested -ne $true -or $paid.reward_granted -ne $true -or $paid.progress.reward_requested -ne $true -or $paid.progress.next_beacon_index -ne 4 -or $paid.progress.beacon_count -ne 4 -or $paid.progress.state -ne 2 -or $paid.progress.generation -ne $activity.generation) { throw 'installed paid beacon acknowledgement changed terminal identity or cursor' }
    if ((InWorld-BeaconCount $final.payload) -ne ($ready.receipts + 1)) { throw 'installed saved beacon reward store lost or duplicated payment' }
    $receipt = $final.payload.game_flow_reward_store.last_receipt
    if ($receipt.activity_id -ne $activity.activity_id -or $receipt.activity_generation -ne $activity.generation -or $receipt.granted -ne $true) { throw 'installed saved beacon receipt differs from completed activity' }
    $pilot = $recovered.safe_recovery_observation
    if ($pilot.player_seated -ne $true -or $pilot.craft_piloted -ne $true -or $pilot.piloting -ne $true -or $pilot.craft_id -ne 'bulwark_heavy_gunship') { throw 'installed beacon cold Resume did not reacquire real safe-home pilot' }
    if ($recovered.continuation_method -ne 'real_safe_home_pilot_resume_then_ordinary_beacon_start_retry') { throw 'installed beacon continuation method differs' }
    $raw = Read-InWorldLog $log
    $last = -1
    foreach ($assertion in @(
        'PASS: a fresh Boot process restores only the genuine unpaid beacon checkpoint and one crash event',
        'PASS: ordinary Resume reacquires the real safe-home pilot and preserves the exact unpaid boundary before retry',
        'PASS: the recovered real pilot accepts ordinary flight input without mutating unpaid beacon progress',
        'PASS: ordinary HUD Start publishes one beacon payment and its existing atomic acknowledgement',
        'PASS: duplicate and late terminal callbacks cannot pay again or change the saved beacon acknowledgement',
        'PASS: beacon restart closes both existing recovery marker owners'
    )) {
        $index = $raw.IndexOf($assertion)
        if ($index -le $last) { throw "missing ordered installed beacon recovery assertion: $assertion" }
        $last = $index
    }
}
function Assert-InWorldMiningSession($session, [bool]$paid, $generation, $elapsed) {
    if ($session -isnot [System.Management.Automation.PSCustomObject] -or @($session.PSObject.Properties).Count -ne 5) { throw 'installed mining session must contain exactly five fields' }
    foreach ($name in @('state','generation','elapsed_seconds','reward_requested','capacity_paid')) {
        if ($session.PSObject.Properties.Name -cnotcontains $name) { throw 'installed mining session field names differ' }
    }
    foreach ($pair in @(@('state',2), @('generation',$generation), @('elapsed_seconds',$elapsed))) {
        $value = $session.($pair[0])
        if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value) -or $value -ne $pair[1]) { throw 'installed mining session numeric boundary differs' }
    }
    if ($session.reward_requested -isnot [bool] -or $session.capacity_paid -isnot [bool] -or $session.reward_requested -ne $paid -or $session.capacity_paid -ne $paid) { throw 'installed mining session payment flags differ' }
}
function Assert-InWorldMiningArm($saved, $ready) {
    $terminal = $saved.payload.cinder_mining_capacity
    if ((InWorld-Canonical $terminal) -ne (InWorld-Canonical $ready.boundary) -or $saved.payload.crash_recovery.state -ne 'running') { throw 'installed mining readiness differs from actual durable document/running marker' }
    if ($terminal.schema_version -ne 2 -or $terminal.payload_kind -ne 'cinder_mining_capacity_receipt' -or $terminal.slot_id -ne 'cinder_mining_capacity') { throw 'invalid installed durable mining record identity' }
    Assert-InWorldMiningSession $terminal.session $false 1 6
    if ( $terminal.capacity -isnot [System.Management.Automation.PSCustomObject] -or @($terminal.capacity.PSObject.Properties).Count -ne 0 -or $ready.receipts -ne 0) { throw 'installed mining is not a genuine generation-one full unpaid extraction' }
    $pilot = $ready.runtime_observation
    if ($pilot.player_seated -ne $true -or $pilot.craft_piloted -ne $true -or $pilot.craft_id -ne 'bulwark_heavy_gunship' -or $saved.payload.solo_safe_recovery.craft_id -ne $pilot.craft_id) { throw 'installed mining arm did not retain its real safe pilot owner' }
    if (@($ready.foreign_settings.PSObject.Properties).Count -eq 0 -or @($ready.foreign_cargo.PSObject.Properties).Count -eq 0 -or (InWorld-Canonical $saved.payload.runtime_settings) -ne (InWorld-Canonical $ready.foreign_settings) -or (InWorld-Canonical $saved.payload.mining_probe_foreign_cargo) -ne (InWorld-Canonical $ready.foreign_cargo)) { throw 'installed mining arm lost production settings or unrelated cargo' }
}
function Assert-InWorldMiningRecovered($final, $ready, $recovered, [string]$log) {
    $paid = $final.payload.cinder_mining_capacity
    $boundary = $ready.boundary
    if ((InWorld-Canonical $paid) -ne (InWorld-Canonical $recovered.paid_boundary)) { throw 'installed saved mining acknowledgement differs from recovered paid boundary' }
    Assert-InWorldMiningSession $paid.session $true $boundary.session.generation $boundary.session.elapsed_seconds
    if ($paid.schema_version -ne $boundary.schema_version -or $paid.payload_kind -ne $boundary.payload_kind -or $paid.slot_id -ne $boundary.slot_id) { throw 'installed paid mining acknowledgement changed extraction identity or progress' }
    if ($recovered.capacity_commits -ne 1 -or @($paid.capacity.PSObject.Properties).Count -ne 5 -or $paid.capacity.activity_id -ne 'cinder_platform_mining_run' -or $paid.capacity.content_class -ne 'NEW' -or $paid.capacity.evidence_status -ne 'modern_interpretation' -or $paid.capacity.extraction_seconds -ne 6) { throw 'installed mining did not publish exactly one genuine capacity record' }
    $expectedReceipt = [pscustomobject]@{activity_id='cinder_platform_mining_run'; reward_id='cinder_raw_ore_sample'; granted=$false; replay_allowed=$false}
    if ((InWorld-Canonical $paid.capacity.reward_receipt) -ne (InWorld-Canonical $expectedReceipt)) { throw 'installed mining metadata invented a granted or replayable receipt' }
    foreach ($namespace in @('runtime_settings','mining_probe_foreign_cargo')) {
        $expected = $(if ($namespace -eq 'runtime_settings') { $ready.foreign_settings } else { $ready.foreign_cargo })
        $reported = $(if ($namespace -eq 'runtime_settings') { $recovered.foreign_settings } else { $recovered.foreign_cargo })
        if ((InWorld-Canonical $final.payload.$namespace) -ne (InWorld-Canonical $expected) -or (InWorld-Canonical $reported) -ne (InWorld-Canonical $expected)) { throw 'installed mining recovery changed production settings or unrelated cargo' }
    }
    $pilot = $recovered.safe_recovery_observation
    if ($pilot.player_seated -ne $true -or $pilot.craft_piloted -ne $true -or $pilot.piloting -ne $true -or $pilot.craft_id -ne 'bulwark_heavy_gunship' -or $pilot.craft_id -ne $ready.runtime_observation.craft_id) { throw 'installed mining cold Resume did not reacquire real safe-home pilot' }
    if ($recovered.continuation_method -ne 'real_safe_home_pilot_resume_then_ordinary_mining_start_retry') { throw 'installed mining continuation method differs' }
    $raw = Read-InWorldLog $log
    $last = -1
    foreach ($assertion in @(
        'PASS: a fresh Boot process restores the genuine unpaid mining completion and one crash event',
        'PASS: ordinary Resume reacquires the real safe-home pilot and preserves exact unpaid mining progress',
        'PASS: the recovered real pilot accepts ordinary throttle without mutating unpaid mining progress',
        'PASS: ordinary HUD Start atomically publishes capacity and the same generation paid acknowledgement once',
        'PASS: duplicate and genuine late unpaid callbacks are refused without another capacity commit',
        'PASS: mining recovery preserves production settings and unrelated cargo fields',
        'PASS: mining restart closes both existing recovery marker owners'
    )) {
        $index = $raw.IndexOf($assertion)
        if ($index -le $last) { throw "missing ordered installed mining recovery assertion: $assertion" }
        $last = $index
    }
}
function Assert-InWorldStationKeys($value, [string[]]$names) {
    if ($value -isnot [System.Management.Automation.PSCustomObject] -or @($value.PSObject.Properties).Count -ne $names.Count) { throw 'installed defense record shape differs' }
    foreach ($name in $names) { if ($value.PSObject.Properties.Name -cnotcontains $name) { throw 'installed defense record keys differ' } }
}
function Assert-InWorldStationInteger($value, [double]$minimum = 0) {
    if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value) -or $value -lt $minimum -or $value -gt 9007199254740991 -or [math]::Floor([double]$value) -ne $value) { throw 'installed defense numeric cursor differs' }
}
function Assert-InWorldStationRecord($record, [bool]$paid) {
    Assert-InWorldStationKeys $record @('schema_version','payload_kind','slot_id','activity_generation','session')
    Assert-InWorldStationInteger $record.schema_version
    Assert-InWorldStationInteger $record.activity_generation
    if ($record.schema_version -ne 1 -or $record.payload_kind -cne 'nearby_sector_activity_session' -or $record.slot_id -cne 'station_defense_session') { throw 'unsupported installed defense envelope' }
    $session = $record.session
    Assert-InWorldStationKeys $session @('schema_version','history','completion')
    Assert-InWorldStationInteger $session.schema_version
    if ($session.schema_version -ne 2) { throw 'unsupported installed defense session' }
    $history = $session.history; $completion = $session.completion
    Assert-InWorldStationKeys $history @('activity_id','state_id','generation','failure_reason','reward_handoff_generation','reward_replayable')
    Assert-InWorldStationKeys $completion @('activity_id','generation','reward_requested','reward_granted')
    Assert-InWorldStationInteger $history.generation 1
    Assert-InWorldStationInteger $history.reward_handoff_generation
    Assert-InWorldStationInteger $completion.generation 1
    if ($history.activity_id -cne 'shipyard_perimeter_defense' -or $completion.activity_id -cne $history.activity_id -or $history.state_id -cne 'completed' -or $history.failure_reason -cne '' -or $completion.generation -ne $history.generation -or $history.reward_handoff_generation -ne $(if ($paid) { $completion.generation } else { 0 })) { throw 'installed defense earned terminal identity differs' }
    if ($history.reward_replayable -isnot [bool] -or $history.reward_replayable -ne $false -or $completion.reward_requested -isnot [bool] -or $completion.reward_requested -ne $true -or $completion.reward_granted -isnot [bool] -or $completion.reward_granted -ne $paid) { throw 'installed defense payment flags differ' }
}
function Assert-InWorldStationForeign($payload, $ready) {
    foreach ($pair in @(@('runtime_settings','foreign_settings'),@('jovian_cargo_session','foreign_cargo'))) {
        $expected = $ready.($pair[1])
        if ($expected -isnot [System.Management.Automation.PSCustomObject] -or @($expected.PSObject.Properties).Count -eq 0 -or (InWorld-Canonical $payload.($pair[0])) -ne (InWorld-Canonical $expected)) { throw 'installed defense changed actual production settings or cargo' }
    }
    $counts = $payload.game_flow_reward_store.reward_counts
    if ($ready.foreign_reward_counts -isnot [System.Management.Automation.PSCustomObject] -or $ready.foreign_reward_counts.debris_route_navigation_data -ne 1) { throw 'installed defense lacks genuinely earned unrelated beacon reward' }
    foreach ($entry in $ready.foreign_reward_counts.PSObject.Properties) {
        Assert-InWorldStationInteger $entry.Value
        Assert-InWorldStationInteger $counts.($entry.Name)
        if ($counts.($entry.Name) -ne $entry.Value) { throw 'installed defense changed unrelated earned reward count' }
    }
}
function Assert-InWorldStationArm($saved, $ready) {
    $record = $saved.payload.station_defense_session
    Assert-InWorldStationRecord $record $false
    if ((InWorld-Canonical $record) -ne (InWorld-Canonical $ready.boundary) -or $saved.payload.crash_recovery.state -ne 'running' -or $ready.receipts -ne 0) { throw 'installed defense readiness differs from actual durable running document' }
    $pilot = $ready.runtime_observation
    if ($pilot.player_seated -ne $true -or $pilot.craft_piloted -ne $true -or $pilot.craft_id -cne 'bulwark_heavy_gunship' -or $saved.payload.solo_safe_recovery.craft_id -cne $pilot.craft_id) { throw 'installed defense arm lacks real safe pilot owner' }
    if ($ready.armed_elapsed_seconds -isnot [double] -and $ready.armed_elapsed_seconds -isnot [decimal]) { throw 'installed defense elapsed observation is not numeric' }
    if ($ready.armed_elapsed_seconds -ne 10.5) { throw 'installed defense authored-wave elapsed observation differs' }
    Assert-InWorldStationForeign $saved.payload $ready
    Assert-InWorldStationInteger $ready.receipts
    Assert-InWorldStationKeys $saved.payload.game_flow_reward_store.reward_counts @($ready.foreign_reward_counts.PSObject.Properties.Name)
    $count = $saved.payload.game_flow_reward_store.reward_counts.return_defense_report_to_shipyard
    if ($null -ne $count -and $count -ne 0) { throw 'installed defense fresh receipt baseline differs' }
}
function Assert-InWorldStationRecovered($final, $ready, $recovered, [string]$log) {
    $paid = $final.payload.station_defense_session
    Assert-InWorldStationRecord $paid $true
    if ((InWorld-Canonical $paid) -ne (InWorld-Canonical $recovered.paid_boundary)) { throw 'installed defense saved paid boundary differs' }
    $expected = $ready.boundary.session | ConvertTo-Json -Depth 60 | ConvertFrom-Json
    $expected.completion.reward_granted = $true
    $expected.history.reward_handoff_generation = $expected.completion.generation
    if ((InWorld-Canonical $paid.session) -ne (InWorld-Canonical $expected)) { throw 'installed defense paid acknowledgement changed exact earned history or generation' }
    foreach ($entry in $final.payload.game_flow_reward_store.reward_counts.PSObject.Properties) {
        Assert-InWorldStationInteger $entry.Value
        if ($entry.Name -cne 'return_defense_report_to_shipyard' -and $ready.foreign_reward_counts.PSObject.Properties.Name -cnotcontains $entry.Name) { throw 'installed defense invented an unrelated reward count' }
    }
    $receipt = $final.payload.game_flow_reward_store.last_receipt
    Assert-InWorldStationInteger $receipt.activity_generation 1
    if ($final.payload.game_flow_reward_store.reward_counts.return_defense_report_to_shipyard -ne 1 -or $receipt.activity_id -cne 'shipyard_perimeter_defense' -or $receipt.activity_generation -ne $expected.completion.generation -or $receipt.reward_id -cne 'return_defense_report_to_shipyard' -or $receipt.granted -isnot [bool] -or $receipt.granted -ne $true -or $receipt.replay_allowed -isnot [bool] -or $receipt.replay_allowed -ne $false -or -not ([string]$recovered.payment_commit.id).StartsWith('game-flow-reward-')) { throw 'installed defense lost atomic single receipt acknowledgement' }
    Assert-InWorldStationForeign $final.payload $ready
    if ((InWorld-Canonical $recovered.foreign_settings) -ne (InWorld-Canonical $ready.foreign_settings) -or (InWorld-Canonical $recovered.foreign_cargo) -ne (InWorld-Canonical $ready.foreign_cargo)) { throw 'installed defense recovered foreign fields differ' }
    Assert-InWorldStationKeys $recovered.foreign_reward_counts @($ready.foreign_reward_counts.PSObject.Properties.Name)
    foreach ($entry in $recovered.foreign_reward_counts.PSObject.Properties) {
        Assert-InWorldStationInteger $entry.Value
        if ($entry.Value -ne $ready.foreign_reward_counts.($entry.Name)) { throw 'installed defense recovered reward counts differ' }
    }
    $pilot = $recovered.safe_recovery_observation
    if ($pilot.player_seated -ne $true -or $pilot.craft_piloted -ne $true -or $pilot.piloting -ne $true -or $pilot.craft_id -cne $ready.runtime_observation.craft_id) { throw 'installed defense Resume did not reacquire actual safe-home pilot' }
    if ($recovered.continuation_method -cne 'real_safe_home_pilot_resume_throttle_idle_pilot_exit_then_on_foot_physical_board_HUD_retry' -or $recovered.active_combat_restore -cne 'NOT_SUPPORTED' -or $recovered.elapsed_timer_restore -cne 'NOT_SUPPORTED') { throw 'installed defense continuation/restoration scope differs' }
    $raw = Read-InWorldLog $log; $last = -1
    foreach ($assertion in @(
        'PASS: fresh Boot restores only the exact owed report into safe idle content without old combat, elapsed timer or pilot-claim replay',
        'PASS: ordinary cold Resume reacquires the real safe-home pilot and preserves the unpaid defense report',
        'PASS: the recovered real pilot accepts ordinary throttle while the defense report stays unpaid',
        'PASS: the ordinary idle propulsion and production pilot exit release real seat ownership before the board retry',
        'PASS: the ordinary on-foot physical board HUD retry atomically publishes one reward receipt and the exact earned report acknowledgement',
        'PASS: duplicate reward, stale physical reset and genuine late unpaid checkpoint cannot repay or downgrade the acknowledged defense report',
        'PASS: the existing unrelated earned reward count is preserved',
        'PASS: the report retry preserves actual production settings and cargo progress',
        'PASS: defense restart closes both existing recovery marker owners'
    )) {
        $index = $raw.IndexOf($assertion)
        if ($index -le $last) { throw "missing ordered installed defense recovery assertion: $assertion" }; $last = $index
    }
}
function Assert-InWorldHulkNumber($value, [double]$expected) {
    if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [double] -and $value -isnot [decimal]) -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value) -or $value -ne $expected) { throw 'installed hulk numeric boundary differs' }
}
function Assert-InWorldHulkRecord($record) {
    if ($record -isnot [System.Management.Automation.PSCustomObject] -or @($record.PSObject.Properties).Count -ne 5) { throw 'installed hulk terminal shape differs' }
    foreach ($name in @('schema_version','activity_id','state','generation','elapsed_seconds')) {
        if ($record.PSObject.Properties.Name -cnotcontains $name) { throw 'installed hulk terminal keys differ' }
    }
    Assert-InWorldHulkNumber $record.schema_version 1
    Assert-InWorldHulkNumber $record.state 2
    Assert-InWorldHulkNumber $record.generation 1
    Assert-InWorldHulkNumber $record.elapsed_seconds 3
    if ($record.activity_id -cne 'cinder_hulk_power_restoration') { throw 'installed hulk terminal identity differs' }
}
function Assert-InWorldHulkForeign($payload, $ready) {
    foreach ($pair in @(@('runtime_settings','foreign_settings'),@('jovian_cargo_session','foreign_cargo'))) {
        $expected = $ready.($pair[1])
        if ($expected -isnot [System.Management.Automation.PSCustomObject] -or @($expected.PSObject.Properties).Count -eq 0 -or (InWorld-Canonical $payload.($pair[0])) -ne (InWorld-Canonical $expected)) { throw 'installed hulk changed production settings or cargo' }
    }
}
function Assert-InWorldHulkArm($saved, $ready) {
    $terminal = $saved.payload.cinder_hulk_power_session
    Assert-InWorldHulkRecord $terminal
    Assert-InWorldHulkNumber $ready.receipts 0
    if ((InWorld-Canonical $terminal) -ne (InWorld-Canonical $ready.boundary) -or $saved.payload.crash_recovery.state -cne 'running') { throw 'installed hulk readiness differs from actual durable running document' }
    $ledger = $saved.payload.game_flow_reward_store
    if ($null -ne $ledger) {
        Assert-InWorldHulkNumber $ledger.total_receipts 0
        Assert-InWorldHulkNumber $ledger.receipt_serial 0
        if ($ledger.reward_counts -isnot [System.Management.Automation.PSCustomObject] -or @($ledger.reward_counts.PSObject.Properties).Count -ne 0 -or $ledger.last_receipt -isnot [System.Management.Automation.PSCustomObject] -or @($ledger.last_receipt.PSObject.Properties).Count -ne 0) { throw 'installed hulk arm already has a paid receipt' }
    }
    $pilot = $ready.runtime_observation
    if ($pilot.player_seated -isnot [bool] -or $pilot.player_seated -ne $true -or $pilot.craft_piloted -isnot [bool] -or $pilot.craft_piloted -ne $true -or $pilot.craft_id -cne 'bulwark_heavy_gunship' -or $saved.payload.solo_safe_recovery.mode -cne 'pilot' -or $saved.payload.solo_safe_recovery.craft_id -cne $pilot.craft_id) { throw 'installed hulk arm lacks its actual safe pilot owner' }
    if ($ready.fixture_method -cne 'on_foot_route_positioning_real_breaker_and_180_owner_physics_ticks_then_real_pilot_boarding') { throw 'installed hulk arm lacks the genuine breaker/tick completion method' }
    Assert-InWorldHulkForeign $saved.payload $ready
}
function Assert-InWorldHulkRecovered($final, $ready, $recovered, [string]$log) {
    $terminal = $final.payload.cinder_hulk_power_session
    Assert-InWorldHulkRecord $terminal
    if ((InWorld-Canonical $terminal) -ne (InWorld-Canonical $ready.boundary) -or (InWorld-Canonical $terminal) -ne (InWorld-Canonical $recovered.paid_boundary)) { throw 'installed hulk retry changed the exact earned terminal' }
    $ledger = $final.payload.game_flow_reward_store
    Assert-InWorldHulkNumber $ledger.total_receipts 1
    Assert-InWorldHulkNumber $ledger.receipt_serial 1
    if ($ledger.reward_counts -isnot [System.Management.Automation.PSCustomObject] -or @($ledger.reward_counts.PSObject.Properties).Count -ne 1 -or $ledger.reward_counts.PSObject.Properties.Name -cnotcontains 'hulk_auxiliary_power_cell') { throw 'installed hulk lost or invented reward counts' }
    Assert-InWorldHulkNumber $ledger.reward_counts.hulk_auxiliary_power_cell 1
    $receipt = $ledger.last_receipt
    Assert-InWorldHulkNumber $receipt.receipt_id 1
    Assert-InWorldHulkNumber $receipt.activity_generation $terminal.generation
    if ($receipt.activity_id -cne 'cinder_hulk_power_restoration' -or $receipt.reward_id -cne 'hulk_auxiliary_power_cell' -or $receipt.granted -isnot [bool] -or $receipt.granted -ne $true -or $receipt.replay_allowed -isnot [bool] -or $receipt.replay_allowed -ne $false -or -not ([string]$recovered.payment_commit.id).StartsWith('game-flow-reward-')) { throw 'installed hulk lacks its single permanent cell receipt' }
    if ($recovered.receipts_at_boot -ne 0 -and $recovered.receipts_at_boot -ne 1) { throw 'installed hulk Boot receipt baseline differs' }
    Assert-InWorldHulkNumber $recovered.receipts_at_boot ([double]$recovered.receipts_at_boot)
    if ($recovered.payment_stage -cne $(if ($recovered.receipts_at_boot -eq 1) { 'boot' } else { 'running_retry' }) -or $recovered.continuation_method -cne 'production_automatic_hulk_retry_and_real_safe_home_pilot_resume') { throw 'installed hulk production payment stage or continuation differs' }
    Assert-InWorldHulkForeign $final.payload $ready
    if ((InWorld-Canonical $recovered.foreign_settings) -ne (InWorld-Canonical $ready.foreign_settings) -or (InWorld-Canonical $recovered.foreign_cargo) -ne (InWorld-Canonical $ready.foreign_cargo)) { throw 'installed hulk recovered foreign fields differ' }
    $pilot = $recovered.safe_recovery_observation
    foreach ($name in @('player_seated','craft_piloted','piloting')) {
        if ($pilot.$name -isnot [bool] -or $pilot.$name -ne $true) { throw 'installed hulk Resume did not reacquire its actual safe-home pilot' }
    }
    if ($pilot.craft_id -cne 'bulwark_heavy_gunship' -or $pilot.craft_id -cne $ready.runtime_observation.craft_id) { throw 'installed hulk Resume changed its actual pilot craft' }
    $raw = Read-InWorldLog $log; $last = -1
    foreach ($assertion in @(
        'PASS: fresh Boot restores exact earned hulk completion or its legitimately paid ledger and one crash event without replaying the breaker timer',
        'PASS: ordinary Resume reacquires the exact safe-home pilot while preserving the earned hulk terminal',
        'PASS: the recovered real pilot accepts ordinary throttle while preserving the exact earned terminal and current receipt count',
        'PASS: the actual production Boot or running retry owner pays exactly one cell and preserves its exact earned terminal',
        'PASS: late reward callback and production tick cannot repay the permanently claimed hulk cell',
        'PASS: hulk recovery preserves unrelated production settings and cargo fields',
        'PASS: hulk recovery closes both existing crash marker owners',
        "PASS: hulk recovery retains Boot's exact supplied Main owner"
    )) {
        $index = $raw.IndexOf($assertion)
        if ($index -le $last) { throw "missing ordered installed hulk recovery assertion: $assertion" }; $last = $index
    }
}
function Assert-InWorldContext($token) {
    $activity = $token.PSObject.Properties['activity']
    if ($null -eq $activity) {
        if ($InWorldRecoveryActivity -ne 'convoy') { throw 'installed payload did not report the requested recovery activity' }
    } elseif ([string]$activity.Value -cne $InWorldRecoveryActivity) { throw 'installed payload recovery activity differs from the requested activity' }
    $context = $token.PSObject.Properties['recovery_context']
    if ($null -eq $context) {
        if ($InWorldRecoveryActivity -ne 'convoy' -or $InWorldRecoveryContext -ne 'pilot') { throw 'installed payload did not report the requested recovery context' }
        return
    }
    if ([string]$context.Value -cne $InWorldRecoveryContext) { throw 'installed payload recovery context differs from the requested context' }
}
function Start-InWorldOwned([string]$stage, [string]$ownedProfile, $children) {
    Check-InWorldCancel
    $log = Join-Path $ProbeRoot ("in-world-$stage.log")
    if (Test-Path -LiteralPath $log) { throw "in-world log already exists: $log" }
    $info = New-OwnedBootInfo $log $false $ownedProfile
    $info.Arguments += ' --in-world-interruption-stage=' + $stage
    # Older qualified payloads support the implicit pilot mode only.
    if ($InWorldRecoveryContext -ne 'pilot') { $info.Arguments += ' --in-world-interruption-context=' + $InWorldRecoveryContext }
    if ($InWorldRecoveryActivity -ne 'convoy') { $info.Arguments += ' --in-world-interruption-activity=' + $InWorldRecoveryActivity }
    $info.EnvironmentVariables.Remove('DISPLAY')
    $info.EnvironmentVariables.Remove('WAYLAND_DISPLAY')
    $proc = [Diagnostics.Process]::Start($info)
    # Cancellation is polled only outside successful spawn/handle registration.
    [void]$children.Add([pscustomobject]@{Process=$proc; Entry=[ordered]@{
        stage=$stage; pid=$proc.Id; arguments=$info.Arguments; log=$log; exit_code=$null; reaped=$false; kill_called=$false; termination=$null
    }})
    Write-Host ("OWNED_IN_WORLD_PID=$($proc.Id) stage=$stage")
    return $proc
}
function Run-InWorldRecovery {
    Assert-Installed $ExpectedExeSha256 $ExpectedCommit | Out-Null
    Assert-UserData
    $ownedProfile = Join-Path $ProbeRoot 'in-world-profile'
    if (Test-Path -LiteralPath $ownedProfile) { throw 'in-world profile already exists; refusing to overwrite it' }
    $probe = [ordered]@{status='FAIL'; activity=$InWorldRecoveryActivity; recovery_context=$InWorldRecoveryContext; parent_windows_pid=$PID; tested_commit=$ExpectedCommit; installed_exe_sha256=$ExpectedExeSha256.ToLowerInvariant(); private_profile=$ownedProfile; cancel_path=$InWorldCancelPath; processes=@(); profile_removed=$false; normal_controls='NOT_RUN'; pilot_seat_world_restore='NOT_RUN'; native_gpu='NOT_RUN'}
    $result.in_world_probe = $probe
    $children = New-Object System.Collections.ArrayList
    $completed = $false
    try {
        New-Item -ItemType Directory -Path (Join-Path $ownedProfile 'AppData\Roaming'),(Join-Path $ownedProfile 'AppData\Local'),(Join-Path $ownedProfile 'Temp') -Force | Out-Null
        $ownedDocument = Join-Path $ownedProfile 'AppData\Roaming\Godot\app_userdata\Mudds Shipyards\mudds_user_data.json'
        $arm = Start-InWorldOwned 'arm' $ownedProfile $children
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $ready = $null
        while (-not $arm.HasExited -and $timer.ElapsedMilliseconds -lt $StartupTimeoutMs) {
            Check-InWorldCancel
            $ready = Read-InWorldToken (Join-Path $ProbeRoot 'in-world-arm.log') 'IN_WORLD_INTERRUPTION_READY'
            if ($null -ne $ready) { break }
            Start-Sleep -Milliseconds 100
        }
        $probe.handshake_ms = $timer.ElapsedMilliseconds
        if ($null -eq $ready -or $arm.HasExited) { throw 'missing live installed in-world readiness before exit/timeout' }
        if ($ready.entry -ne 'startup_completed' -or $ready.loaded_main_instance_id -le 0 -or $ready.receipts -ne $(if ($InWorldRecoveryActivity -ne 'convoy') { 0 } else { 1 })) { throw 'installed arm did not use its Boot-loaded Main and expected genuine receipt baseline' }
        Assert-InWorldContext $ready
        if ((InWorld-LogCounts (Join-Path $ProbeRoot 'in-world-arm.log')).diagnostic_count -ne 0) { throw 'installed arm engine/script/leak diagnostics' }
        $probe.ready = $ready
        $beforeHash = (Get-FileHash -LiteralPath $ownedDocument -Algorithm SHA256).Hash.ToLowerInvariant()
        Copy-Item -LiteralPath $ownedDocument -Destination (Join-Path $ProbeRoot 'in-world-interrupted-document.json')
        $probe.interrupted_document_sha256 = $beforeHash
        $saved = Get-Content -LiteralPath $ownedDocument -Raw | ConvertFrom-Json
        if ($InWorldRecoveryActivity -eq 'beacon') { Assert-InWorldBeaconArm $saved $ready }
        elseif ($InWorldRecoveryActivity -eq 'mining') {
            Assert-InWorldMiningArm $saved $ready
            if (Test-Path -LiteralPath ($ownedDocument + '.tmp')) { throw 'installed mining blockage remains at kill boundary' }
        }
        elseif ($InWorldRecoveryActivity -eq 'stationdefense') { Assert-InWorldStationArm $saved $ready }
        elseif ($InWorldRecoveryActivity -eq 'hulk') { Assert-InWorldHulkArm $saved $ready }
        elseif ((InWorld-Canonical $saved.payload.cinder_convoy_session.activities[0].progress.convoy_session_state) -ne (InWorld-Canonical $ready.boundary) -or $saved.payload.crash_recovery.state -ne 'running') { throw 'installed readiness differs from actual durable document/running marker' }
        Check-InWorldCancel
        if ($arm.HasExited) { throw 'installed arm exited before owned OS kill' }
        $probe.arm_live_before_kill = $true
        Stop-InWorldOwned $arm $children[0].Entry 'Windows Process.Kill exact owned handle after durable in-world readiness'
        if (-not $children[0].Entry.kill_called) { throw 'installed arm exited without the required owned OS kill' }
        if ($arm.ExitCode -eq 0) { throw 'installed OS kill unexpectedly reported orderly exit' }
        if ($InWorldRecoveryActivity -ne 'convoy' -and $arm.ExitCode -ne -1) { throw "installed $InWorldRecoveryActivity owned Windows OS kill did not reap exit -1" }
        $probe.after_kill_document_sha256 = (Get-FileHash -LiteralPath $ownedDocument -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($probe.after_kill_document_sha256 -ne $beforeHash) { throw 'installed OS kill performed an orderly save' }
        $resume = Start-InWorldOwned 'resume' $ownedProfile $children
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (-not $resume.HasExited -and $timer.ElapsedMilliseconds -lt $StartupTimeoutMs) { Check-InWorldCancel; Start-Sleep -Milliseconds 100 }
        $probe.resume_ms = $timer.ElapsedMilliseconds
        if (-not $resume.HasExited) { throw 'installed recovery restart timed out' }
        $resume.WaitForExit()
        Copy-Item -LiteralPath $ownedDocument -Destination (Join-Path $ProbeRoot 'in-world-recovered-document.json')
        $probe.recovered_document_sha256 = (Get-FileHash -LiteralPath $ownedDocument -Algorithm SHA256).Hash.ToLowerInvariant()
        $recovered = Read-InWorldToken (Join-Path $ProbeRoot 'in-world-resume.log') 'IN_WORLD_RECOVERY_OK'
        if ($resume.ExitCode -ne 0 -or $null -eq $recovered -or $recovered.entry -ne 'startup_completed' -or $recovered.loaded_main_instance_id -le 0) { throw 'installed restart did not exit0 with its Boot-loaded Main recovery token' }
        Assert-InWorldContext $recovered
        if ((InWorld-LogCounts (Join-Path $ProbeRoot 'in-world-resume.log')).diagnostic_count -ne 0) { throw 'installed restart engine/script/leak diagnostics' }
        $lines = @((Read-InWorldLog (Join-Path $ProbeRoot 'in-world-resume.log')) -split '\r?\n' | Where-Object { $_.Trim().Length -gt 0 })
        if (-not $lines[-1].StartsWith('IN_WORLD_RECOVERY_OK: ')) { throw 'installed recovery token is not terminal' }
        if ((InWorld-Canonical $recovered.boundary) -ne (InWorld-Canonical $ready.boundary) -or $recovered.receipts_before -ne $ready.receipts -or $recovered.receipts_after -ne ($ready.receipts + 1) -or $recovered.crash_events -ne 1) { throw 'installed restart lost durable boundary or lost/duplicated activity payout/crash event' }
        $final = Get-Content -LiteralPath $ownedDocument -Raw | ConvertFrom-Json
        if ($final.payload.crash_recovery.state -ne 'clean' -or $final.payload.safe_start_recovery.state -ne 'clean_shutdown') { throw 'installed recovered process did not close both marker owners' }
        if ($InWorldRecoveryActivity -eq 'beacon') {
            Assert-InWorldBeaconRecovered $final $ready $recovered (Join-Path $ProbeRoot 'in-world-resume.log')
            $probe.automated_safe_home_berth_boarding = 'PASS'
            $probe.automated_ordinary_throttle_before_retry = 'PASS'
            $probe.ordinary_hud_start_payment_once = 'PASS'
            $probe.duplicate_late_callback_refusal = 'PASS'
            $probe.durable_unpaid_boundary_held_until_retry = 'PASS'
        }
        elseif ($InWorldRecoveryActivity -eq 'mining') {
            Assert-InWorldMiningRecovered $final $ready $recovered (Join-Path $ProbeRoot 'in-world-resume.log')
            $probe.automated_safe_home_berth_boarding = 'PASS'
            $probe.automated_ordinary_throttle_before_retry = 'PASS'
            $probe.ordinary_hud_start_capacity_once = 'PASS'
            $probe.duplicate_late_callback_refusal = 'PASS'
            $probe.durable_unpaid_boundary_held_until_retry = 'PASS'
            $probe.foreign_settings_cargo_preserved = 'PASS'
        }
        elseif ($InWorldRecoveryActivity -eq 'stationdefense') {
            Assert-InWorldStationRecovered $final $ready $recovered (Join-Path $ProbeRoot 'in-world-resume.log')
            $probe.earned_report_atomic_payment_once = 'PASS'
            $probe.foreign_settings_cargo_rewards_preserved = 'PASS'
            $probe.active_combat_restore = 'NOT_SUPPORTED'
            $probe.elapsed_timer_restore = 'NOT_SUPPORTED'
        }
        elseif ($InWorldRecoveryActivity -eq 'hulk') {
            Assert-InWorldHulkRecovered $final $ready $recovered (Join-Path $ProbeRoot 'in-world-resume.log')
            $probe.automated_safe_home_berth_boarding = 'PASS'
            $probe.automated_ordinary_throttle = 'PASS'
            $probe.earned_terminal_preserved = 'PASS'
            $probe.production_automatic_cell_payment_once = 'PASS'
            $probe.payment_stage = $recovered.payment_stage
            $probe.duplicate_late_callback_refusal = 'PASS'
            $probe.foreign_settings_cargo_preserved = 'PASS'
        }
        $probe.recovered = $recovered
        Assert-Installed $ExpectedExeSha256 $ExpectedCommit | Out-Null
        Assert-UserData
        $completed = $true
    } finally {
        $cleanupFailure = $null
        foreach ($child in $children) {
            try {
                Stop-InWorldOwned $child.Process $child.Entry 'Windows Process.Kill exact owned handle during cleanup'
                $child.Entry.exit_code = $child.Process.ExitCode
                $child.Entry.reaped = $child.Process.HasExited
                if (Test-Path -LiteralPath $child.Entry.log) {
                    $child.Entry.log_sha256 = (Get-FileHash -LiteralPath $child.Entry.log -Algorithm SHA256).Hash.ToLowerInvariant()
                    $counts = InWorld-LogCounts $child.Entry.log
                    $child.Entry.diagnostic_count = $counts.diagnostic_count
                    $child.Entry.warning_count = $counts.warning_count
                }
            } catch { $cleanupFailure = $_.Exception.Message }
            finally { $child.Process.Dispose() }
        }
        $probe.processes = @($children | ForEach-Object { $_.Entry })
        if (@($children | Where-Object { -not $_.Entry.reaped }).Count -eq 0) {
            try { if (Test-Path -LiteralPath $ownedProfile) { Remove-Item -LiteralPath $ownedProfile -Recurse -Force } } catch { $cleanupFailure = $_.Exception.Message }
        } else { $cleanupFailure = 'owned process not reaped; private profile retained' }
        $probe.profile_removed = -not (Test-Path -LiteralPath $ownedProfile)
        if ($null -ne $cleanupFailure -or -not $probe.profile_removed) {
            $probe.cleanup_failure = $cleanupFailure
            $completed = $false
        }
        $probe.status = $(if ($completed) { 'PASS' } else { 'FAIL' })
        $result.in_world_recovery = $probe.status
        if ($null -ne $cleanupFailure -and $completed -eq $false) { Write-Warning "in-world cleanup: $cleanupFailure" }
    }
    if (-not $completed) { throw 'installed in-world cleanup failed' }
    return ('exact_installed_boot_main=True os_kill_reaped=True exact_durable_boundary=True receipts=' + $ready.receipts + '_to_' + ($ready.receipts + 1) + ' crash_events=1 markers_clean=True private_profile_removed=True')
}

Step 'preconditions' {
    Assert-InWorldSelection
    if (-not $InWorldRecovery -and $InWorldRecoveryContext -ne 'pilot') { throw 'InWorldRecoveryContext requires InWorldRecovery' }
    if (-not $InWorldRecovery -and -not [string]::IsNullOrWhiteSpace($InWorldCancelPath)) { throw 'InWorldCancelPath requires InWorldRecovery' }
    if ($InWorldRecovery) {
        if ([string]::IsNullOrWhiteSpace($InWorldCancelPath)) { $script:InWorldCancelPath = Join-Path $ProbeRoot 'in-world-recovery.cancel' }
        if (-not [IO.Path]::IsPathRooted($InWorldCancelPath) -or (Test-Path -LiteralPath $InWorldCancelPath)) { throw 'in-world abort path must be an absolute unused file path' }
    }
    if ($ForceKillRecovery -and -not $checkRecovery) { throw 'ForceKillRecovery requires UserDataRecoveryFixture' }
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

if ($InWorldRecovery) {
    Step 'installed_in_world_os_interruption_recovery' { Run-InWorldRecovery }
}

if ($ForceKillRecovery) {
    Step 'installed_owned_os_kill_startup_cycles' {
        Assert-Installed $ExpectedExeSha256 $ExpectedCommit
        Seed-ForcedKillFixture
        for ($cycle = 1; $cycle -le 3; $cycle++) { Run-ForcedKillBoot $cycle $false }
    }
    Step 'installed_forced_kill_safe_start_and_journal_recovery' { Run-ForcedKillBoot 4 $true }
    $result.forced_kill_recovery = 'PASS'
}

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
