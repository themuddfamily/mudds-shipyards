<#
.SYNOPSIS
Interrupt and recover a pinned exported Windows EXE in a disposable profile.
.DESCRIPTION
Requires a pinned EXE SHA-256 and explicit fresh result directory. Two native
headless processes share one private profile: arm, owned OS termination, resume.
The default game deadline is 300 seconds. No installation, GUI, input or real user
data is involved. HOME and USERPROFILE are inherited unchanged. To abort from a
second terminal, invoke this same script with -Abort -ResultDirectory <directory>.
#>
[CmdletBinding(DefaultParameterSetName='Run')]
param(
    [Parameter(Mandatory=$true, ParameterSetName='Run')][string]$Artifact,
    [Parameter(Mandatory=$true, ParameterSetName='Run')][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedExeSha256,
    [Parameter(Mandatory=$true)][string]$ResultDirectory,
    [Parameter(ParameterSetName='Run')][ValidateSet('pilot','cabin','rest','crew')][string]$RecoveryContext='pilot',
    [Parameter(ParameterSetName='Run')][ValidateRange(1,300)][int]$TimeoutSeconds=300,
    [Parameter(Mandatory=$true, ParameterSetName='Abort')][switch]$Abort
)
$ErrorActionPreference='Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This command requires native Windows PowerShell.' }
$utf8=New-Object Text.UTF8Encoding($false)
function Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$path, $value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 12)+"`n", $utf8) }
function Assert-NoReparse([string]$path) {
    $cursor=[IO.Path]::GetFullPath($path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse path refused: $cursor" }
        }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor=$parent
    }
}
function Owned-Actors([string]$root) {
    @(Get-CimInstance Win32_Process | Where-Object {
        ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) -or
        ($_.CommandLine -and $_.CommandLine.Contains($root))
    } | Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine)
}
function Assert-LiveOwned($record) {
    if ($null -eq $record.pid) { return $false }
    $actor=Get-CimInstance Win32_Process -Filter ('ProcessId = '+$record.pid)
    if ($null -eq $actor) { return $false }
    $live=Get-Process -Id $record.pid -ErrorAction SilentlyContinue
    if ($null -eq $live) { return $false }
    try {
        if ($live.HasExited) { return $false }
        try { $started=$live.StartTime.ToUniversalTime().ToString('o') } catch { if ($live.HasExited) { return $false }; throw }
        if ($actor.ExecutablePath -ne $record.exe -or
            -not $record.exe.StartsWith($record.private_root+'\package\',[StringComparison]::OrdinalIgnoreCase) -or
            $started -ne $record.start_time_utc) { throw 'Owned PID/start-time/executable identity differs; refusing abort.' }
        return $true
    } finally { $live.Dispose() }
}
function Assert-AbortOwnership($record) {
    $root=[IO.Path]::GetFullPath($record.private_root).TrimEnd('\')
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ($root -cne $record.private_root -or [IO.Path]::GetDirectoryName($root) -ine $temp -or
        [IO.Path]::GetFileName($root) -cnotmatch '^Mudds interruption [0-9a-f]{32}$' -or
        $record.result_directory -ine $ResultDirectory -or $record.run_token -cnotmatch '^[0-9a-f]{32}$' -or $record.job_token -cnotmatch '^[0-9a-f]{32}$') {
        throw 'Abort ownership/root/result-directory binding is invalid.'
    }
    Assert-NoReparse $root
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $false }
    $binding=Get-Content -LiteralPath (Join-Path $root 'run-owner.json') -Raw | ConvertFrom-Json
    if ($binding.run_token -cne $record.run_token -or $binding.result_directory -ine $ResultDirectory -or $binding.private_root -cne $root -or $binding.job_token -cne $record.job_token) {
        throw 'Private run ownership marker differs; refusing abort.'
    }
    return (Assert-LiveOwned $record)
}
$ResultDirectory=[IO.Path]::GetFullPath($ResultDirectory)
Assert-NoReparse $ResultDirectory
if ($Abort) {
    $owned=Get-Content -LiteralPath (Join-Path $ResultDirectory 'owned-process.json') -Raw | ConvertFrom-Json
    if (Assert-AbortOwnership $owned) {
        # Open only the bound run's named Job after live identity validation.
        Add-Type -Path (Join-Path $PSScriptRoot 'windows_startup_process.cs')
        [WindowsStartupProcess]::Abort($owned.job_token,(Join-Path $owned.private_root 'abort.request'),10000)
    } elseif (Test-Path -LiteralPath $owned.private_root -PathType Container) {
        # Between legs the old parent is reaped; the verified owner marker still
        # authorizes cancellation of the next leg, without a PID-based kill.
        [IO.File]::WriteAllText((Join-Path $owned.private_root 'abort.request'),'abort')
    }
    Write-Output 'Owned interruption abort requested.'
    exit 0
}
function Require([bool]$condition,[string]$message) { if (-not $condition) { throw $message } }
function Canonical($value) {
    if ($null -eq $value) { return 'null' }
    if ($value -is [Management.Automation.PSCustomObject] -or $value -is [Collections.IDictionary]) {
        $names=if ($value -is [Collections.IDictionary]) { @($value.Keys | Sort-Object) } else { @($value.PSObject.Properties.Name | Sort-Object) }
        $parts=@(foreach ($name in $names) { ($name | ConvertTo-Json -Compress)+':'+(Canonical $value.$name) })
        return '{'+($parts -join ',')+'}'
    }
    if ($value -is [Array]) { return '['+(@(foreach ($item in $value) { Canonical $item }) -join ',')+']' }
    return ($value | ConvertTo-Json -Compress -Depth 32)
}
function Read-Shared([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    $stream=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader=New-Object IO.StreamReader($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Token([string]$content,[string]$name,[bool]$required=$true) {
    $found=[regex]::Matches($content,'(?m)^'+$name+': ([^\r\n]+)\r?$')
    Require ($found.Count -le 1) "Duplicate $name marker."
    if ($found.Count -eq 0) { if ($required) { throw "Missing $name marker." }; return $null }
    return ($found[0].Groups[1].Value | ConvertFrom-Json)
}
function Diagnostics([string]$content) {
    @([regex]::Matches($content,'(?im)^(?:ERROR:|WARNING:|SCRIPT ERROR:|Parse Error:|.*IN_WORLD_RECOVERY_FAILED.*|.*ObjectDB instances leaked.*|.*resources still in use.*).*$') | ForEach-Object {$_.Value})
}
function Protected-Snapshot {
    $snapshot=[ordered]@{}
    foreach ($path in $protectedGamePaths) {
        Assert-NoReparse $path
        $files=[ordered]@{}
        if (Test-Path -LiteralPath $path) {
            $items=@(Get-ChildItem -LiteralPath $path -Recurse -Force)
            Require (@($items | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count -eq 0) 'Real game data contains a reparse point; refusing trial.'
            foreach ($file in @($items | Where-Object {-not $_.PSIsContainer} | Sort-Object FullName)) { $files[$file.FullName.Substring($path.Length)]=@{bytes=$file.Length;sha256=(Hash $file.FullName)} }
        }
        $snapshot[$path]=@{exists=(Test-Path -LiteralPath $path);files=$files}
    }
    return $snapshot
}
foreach ($protected in @($env:APPDATA,$env:LOCALAPPDATA,$env:XDG_DATA_HOME,$env:XDG_CONFIG_HOME,(Join-Path $env:USERPROFILE 'Downloads'))) {
    if (-not [string]::IsNullOrEmpty($protected)) {
        $protected=[IO.Path]::GetFullPath($protected).TrimEnd('\')
        if ($ResultDirectory -eq $protected -or $ResultDirectory.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Result directory is a protected real-user location.' }
    }
}
Require (-not (Test-Path -LiteralPath $ResultDirectory)) 'ResultDirectory must be fresh; refusing to overwrite results.'
$Artifact=[IO.Path]::GetFullPath($Artifact)
Assert-NoReparse $Artifact
Require ((Test-Path -LiteralPath $Artifact -PathType Leaf) -and [IO.Path]::GetExtension($Artifact) -ieq '.exe') 'Artifact must be a regular Windows EXE.'
New-Item -ItemType Directory -Path $ResultDirectory | Out-Null
$ownedRoot=Join-Path ([IO.Path]::GetTempPath()) ('Mudds interruption '+[Guid]::NewGuid().ToString('N'))
Assert-NoReparse $ownedRoot
$inherited=@{}
foreach ($name in @('HOME','USERPROFILE','APPDATA','LOCALAPPDATA','TEMP','TMP','TMPDIR','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CONFIG_DIRS','XDG_DATA_DIRS','XDG_RUNTIME_DIR')) { $inherited[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
$protectedGamePaths=@(@($inherited.APPDATA,$inherited.LOCALAPPDATA) | Where-Object {$_} | ForEach-Object {Join-Path $_ 'Godot\app_userdata\Mudds Shipyards'} | Sort-Object -Unique)
foreach ($base in @($inherited.XDG_DATA_HOME,$inherited.XDG_CONFIG_HOME)) { if ($base) { $protectedGamePaths+=Join-Path $base 'godot\app_userdata\Mudds Shipyards' } }
$result=[ordered]@{
    status='RUNNING'; artifact=$Artifact; expected_exe_sha256=$ExpectedExeSha256.ToLowerInvariant(); timeout_seconds=$TimeoutSeconds
    recovery_context=$RecoveryContext; activity='convoy'; harness_pid=$PID; windows_version=[Environment]::OSVersion.VersionString; private_root=$ownedRoot
    scope='native Windows headless compiled Boot convoy fixture OS interruption and safe-home recovery'
    native_gpu='NOT_RUN'; normal_controls='NOT_RUN'; original_flight_pose_restore='NOT_SUPPORTED'; audible_audio='NOT_RUN'; remote_crew='NOT_RUN'; human_review='NOT_RUN'; full_release='NOT_RUN'; processes=@()
}
$resultPath=Join-Path $ResultDirectory 'result.json'
$jobs=New-Object Collections.ArrayList
$exeLock=$null; $binding=$null; $protectedBefore=$null
function Start-Leg([string]$stage) {
    Require (-not (Test-Path -LiteralPath (Join-Path $ownedRoot 'abort.request'))) 'Interruption aborted by operator.'
    $log=Join-Path $ownedRoot ($stage+'-godot.log')
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$exe; $info.WorkingDirectory=$package
    $info.Arguments='--headless --audio-driver Dummy --in-world-interruption-stage='+$stage+' --in-world-interruption-context='+$RecoveryContext+' --in-world-interruption-activity=convoy --log-file "'+$log+'"'
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    foreach ($entry in $environment.GetEnumerator()) { $info.EnvironmentVariables[$entry.Key]=$entry.Value }
    Require ($info.EnvironmentVariables['HOME'] -eq $inherited.HOME -and $info.EnvironmentVariables['USERPROFILE'] -eq $inherited.USERPROFILE) 'Inherited HOME/USERPROFILE differ.'
    $jobToken=[Guid]::NewGuid().ToString('N')
    $job=New-Object WindowsStartupProcess($info,$jobToken)
    $leg=@{stage=$stage;job=$job;log=$log;timer=[Diagnostics.Stopwatch]::StartNew()}
    [void]$jobs.Add($leg)
    $identity=$binding+@{job_token=$jobToken;pid=$job.Process.Id;exe=$exe;start_time_utc=$job.Process.StartTime.ToUniversalTime().ToString('o');stage=$stage}
    $leg.record=$identity+@{arguments=$info.Arguments}
    $result.processes+=@($leg.record)
    Write-Json (Join-Path $ownedRoot 'run-owner.json') ($binding+@{job_token=$jobToken})
    Write-Json (Join-Path $ResultDirectory 'owned-process.json') $identity
    Write-Json $resultPath $result
    Require (-not (Test-Path -LiteralPath (Join-Path $ownedRoot 'abort.request'))) 'Interruption aborted by operator.'
    $job.Resume()
    return $leg
}
function Check-Live($leg) {
    Require (-not (Test-Path -LiteralPath (Join-Path $ownedRoot 'abort.request'))) 'Interruption aborted by operator.'
    Require ($leg.timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) ($leg.stage+' deadline exceeded.')
    $leg.job.Process.Refresh()
    Require ($leg.job.Process.HasExited -or $leg.job.Process.MainWindowHandle.ToInt64() -eq 0) 'Headless process unexpectedly reports a window.'
}
function Finish-Leg($leg) {
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while ($leg.job.ActiveProcesses -ne 0 -and $watch.ElapsedMilliseconds -lt 1000) { Start-Sleep -Milliseconds 20 }
    Require ($leg.job.ActiveProcesses -eq 0) 'Owned descendants remain after parent exit.'
    Require ($leg.job.Drain(10000)) 'Stream drain deadline exceeded.'
    $leg.record.exit_code=$leg.job.ExitCode; $leg.record.wall_ms=$leg.timer.ElapsedMilliseconds
    $stdout=$leg.job.Stdout.Result; $stderr=$leg.job.Stderr.Result; $gameLog=Read-Shared $leg.log
    [IO.File]::WriteAllText((Join-Path $ResultDirectory ($leg.stage+'-stdout.log')),$stdout,$utf8)
    [IO.File]::WriteAllText((Join-Path $ResultDirectory ($leg.stage+'-stderr.log')),$stderr,$utf8)
    [IO.File]::WriteAllText((Join-Path $ResultDirectory ($leg.stage+'-godot.log')),$gameLog,$utf8)
    $leg.record.diagnostics=@(Diagnostics ($stdout+"`n"+$stderr+"`n"+$gameLog))
    Require ($leg.record.diagnostics.Count -eq 0) ($leg.stage+' engine/script diagnostics.')
    Require (-not (Test-Path -LiteralPath (Join-Path $ownedRoot 'abort.request'))) 'Interruption aborted by operator.'
    return @{stdout=$stdout;log=$gameLog}
}
try {
    New-Item -ItemType Directory -Path $ownedRoot | Out-Null
    $binding=@{private_root=$ownedRoot;result_directory=$ResultDirectory;run_token=[Guid]::NewGuid().ToString('N')}
    $initialJobToken=[Guid]::NewGuid().ToString('N')
    Write-Json (Join-Path $ownedRoot 'run-owner.json') ($binding+@{job_token=$initialJobToken})
    Write-Json (Join-Path $ResultDirectory 'owned-process.json') ($binding+@{pid=$null;job_token=$initialJobToken})
    $result.source_sha256=Hash $Artifact
    Require ($result.source_sha256 -eq $ExpectedExeSha256.ToLowerInvariant()) 'EXE SHA-256 differs from the required pin.'
    $package=Join-Path $ownedRoot 'package'; New-Item -ItemType Directory -Path $package | Out-Null
    $exe=Join-Path $package ([IO.Path]::GetFileName($Artifact)); Copy-Item -LiteralPath $Artifact -Destination $exe
    $result.exe_sha256=Hash $exe; Require ($result.exe_sha256 -eq $result.source_sha256) 'Copied EXE hash differs.'
    $exeLock=[IO.File]::Open($exe,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $profile=Join-Path $ownedRoot 'profile'
    $environment=[ordered]@{
        APPDATA=(Join-Path $profile 'AppData\Roaming'); LOCALAPPDATA=(Join-Path $profile 'AppData\Local')
        TEMP=(Join-Path $profile 'Temp'); TMP=(Join-Path $profile 'Temp'); TMPDIR=(Join-Path $profile 'TmpDir')
        XDG_CONFIG_HOME=(Join-Path $profile 'XDG\Config'); XDG_CACHE_HOME=(Join-Path $profile 'XDG\Cache'); XDG_DATA_HOME=(Join-Path $profile 'XDG\Data'); XDG_STATE_HOME=(Join-Path $profile 'XDG\State')
        XDG_CONFIG_DIRS=(Join-Path $profile 'XDG\ConfigDirs'); XDG_DATA_DIRS=(Join-Path $profile 'XDG\DataDirs'); XDG_RUNTIME_DIR=(Join-Path $profile 'XDG\Runtime')
    }
    foreach ($dir in $environment.Values) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $result.environment=$environment; $result.HOME_preserved=$true; $result.USERPROFILE_preserved=$true
    $document=Join-Path $environment.APPDATA 'Godot\app_userdata\Mudds Shipyards\mudds_user_data.json'
    $protectedBefore=Protected-Snapshot; Write-Json (Join-Path $ResultDirectory 'protected-before.json') $protectedBefore
    Add-Type -Path (Join-Path $PSScriptRoot 'windows_startup_process.cs')
    $arm=Start-Leg 'arm'; $ready=$null
    while ($null -eq $ready) {
        Check-Live $arm
        Require (-not $arm.job.WaitForExit(100)) 'Arm process exited before durable readiness.'
        $content=Read-Shared $arm.log
        Require (@(Diagnostics $content).Count -eq 0) 'Arm engine/script diagnostics before readiness.'
        $ready=Token $content 'IN_WORLD_INTERRUPTION_READY' $false
    }
    Require ($ready.recovery_context -ceq $RecoveryContext -and $ready.entry -ceq 'startup_completed' -and $ready.loaded_main_instance_id -gt 0) 'Arm ignored compiled Boot/context contract.'
    $before=[IO.File]::ReadAllBytes($document); $saved=[Text.Encoding]::UTF8.GetString($before) | ConvertFrom-Json
    Require ((Canonical $saved.payload.cinder_convoy_session.activities[0].progress.convoy_session_state) -ceq (Canonical $ready.boundary)) 'Readiness differs from real durable document.'
    Require ($saved.payload.crash_recovery.state -ceq 'running' -and $ready.receipts -eq 1 -and $saved.payload.game_flow_reward_store.reward_counts.return_convoy_credit_to_shipyard -eq 1) 'Missing durable running marker or first paid receipt.'
    Require ($saved.payload.solo_safe_recovery.mode -ceq $RecoveryContext -and $saved.payload.solo_safe_recovery.craft_id -ceq $ready.runtime_observation.craft_id) 'Durable safe recovery preference differs.'
    [IO.File]::WriteAllBytes((Join-Path $ResultDirectory 'interrupted-document.json'),$before)
    Require (Assert-LiveOwned $arm.record) 'Owned arm identity no longer live.'
    $arm.job.Stop(10000); Require ($arm.job.WaitForExit(1000) -and $arm.job.ExitCode -eq 1) 'Owned OS interruption did not reap with Job termination code 1.'
    $arm.record.termination='TerminateJobObject'; $armOutput=Finish-Leg $arm
    Require ((Canonical (Token $armOutput.stdout 'IN_WORLD_INTERRUPTION_READY')) -ceq (Canonical $ready)) 'Arm stdout readiness differs from log.'
    Require ((Hash $document) -ceq (Hash (Join-Path $ResultDirectory 'interrupted-document.json'))) 'OS termination changed durable document.'
    $result.ready=$ready
    $resume=Start-Leg 'resume'
    while (-not $resume.job.WaitForExit(100)) { Check-Live $resume }
    $resumeOutput=Finish-Leg $resume
    $recovered=Token $resumeOutput.stdout 'IN_WORLD_RECOVERY_OK'
    Require ($resume.job.ExitCode -eq 0 -and (Canonical (Token $resumeOutput.log 'IN_WORLD_RECOVERY_OK')) -ceq (Canonical $recovered)) 'Restart exit/readiness contract failed.'
    Require ($resumeOutput.log.TrimEnd().Split("`n")[-1].StartsWith('IN_WORLD_RECOVERY_OK: ')) 'Recovery token is not terminal.'
    Require ($arm.record.pid -ne $resume.record.pid -or $arm.record.start_time_utc -cne $resume.record.start_time_utc) 'Restart did not use a distinct process.'
    Require ($recovered.recovery_context -ceq $RecoveryContext -and $recovered.entry -ceq 'startup_completed' -and $recovered.loaded_main_instance_id -gt 0) 'Restart ignored compiled Boot/context contract.'
    Require ((Canonical $recovered.boundary) -ceq (Canonical $ready.boundary)) 'Fresh process changed durable convoy boundary.'
    Require ($recovered.receipts_before -eq 1 -and $recovered.receipts_after -eq 2 -and $recovered.crash_events -eq 1) 'Recovery lost or duplicated receipts/crash event.'
    $safe=$recovered.safe_recovery_observation
    Require ($safe.craft_id -ceq $ready.runtime_observation.craft_id -and $safe.player_sleeping -eq $false) 'Recovery craft/awake flags differ.'
    if ($RecoveryContext -eq 'pilot') {
        Require ($safe.piloting -eq $true -and $safe.player_seated -eq $true -and $safe.craft_piloted -eq $true -and $safe.cabin_containment -eq $false) 'Safe-home pilot ownership missing.'
        Require ($recovered.continuation_method -ceq 'real_safe_home_berth_boarding_then_escort_motion_fixture') 'Pilot continuation disclosure differs.'
    } else {
        Require ($safe.piloting -eq $false -and $safe.player_seated -eq $false -and $safe.craft_piloted -eq $false -and $safe.player_on_floor -eq $true -and $safe.player_control_enabled -eq $true -and $safe.cabin_containment -eq $true) 'Usable awake safe-home cabin ownership missing.'
        Require ($recovered.continuation_method -ceq 'real_awake_home_cabin_walk_then_pilot_retake_new_convoy_escort_motion_fixture') 'Cabin continuation disclosure differs.'
    }
    $after=[IO.File]::ReadAllBytes($document); $final=[Text.Encoding]::UTF8.GetString($after) | ConvertFrom-Json
    Require ($final.payload.crash_recovery.state -ceq 'clean' -and $final.payload.safe_start_recovery.state -ceq 'clean_shutdown' -and $final.payload.game_flow_reward_store.reward_counts.return_convoy_credit_to_shipyard -eq 2) 'Recovered document did not close marker owners/pay second receipt.'
    [IO.File]::WriteAllBytes((Join-Path $ResultDirectory 'recovered-document.json'),$after)
    $result.recovered=$recovered; $result.status='PASS'
} catch { $result.status='FAIL'; $result.failure=$_.Exception.Message }
finally {
    try {
        foreach ($leg in $jobs) {
            if ($leg.job.ActiveProcesses -ne 0) { $leg.job.Stop(10000) }
            Require ($leg.job.WaitForExit(1000) -and $leg.job.Drain(10000)) 'Cleanup reap/stream deadline exceeded.'
            $leg.record.exit_code=$leg.job.ExitCode; $leg.record.final_job_active_processes=$leg.job.ActiveProcesses
            [IO.File]::WriteAllText((Join-Path $ResultDirectory ($leg.stage+'-stdout.log')),$leg.job.Stdout.Result,$utf8)
            [IO.File]::WriteAllText((Join-Path $ResultDirectory ($leg.stage+'-stderr.log')),$leg.job.Stderr.Result,$utf8)
            if (Test-Path -LiteralPath $leg.log) { Copy-Item -LiteralPath $leg.log -Destination (Join-Path $ResultDirectory ($leg.stage+'-godot.log')) }
        }
        $result.final_owned_actors=@(Owned-Actors $ownedRoot)
        Require ($result.final_owned_actors.Count -eq 0) 'Owned actors remain; refusing private deletion.'
        if ($null -ne $protectedBefore) {
            $protectedAfter=Protected-Snapshot; Write-Json (Join-Path $ResultDirectory 'protected-after.json') $protectedAfter
            $result.protected_real_game_data_unchanged=((Canonical $protectedBefore) -ceq (Canonical $protectedAfter))
            Require $result.protected_real_game_data_unchanged 'Protected real game data changed.'
        }
        if ($null -ne $exeLock) { $exeLock.Dispose(); $exeLock=$null }
        if (Test-Path -LiteralPath $ownedRoot) {
            Assert-NoReparse $ownedRoot
            $owner=Get-Content -LiteralPath (Join-Path $ownedRoot 'run-owner.json') -Raw | ConvertFrom-Json
            Require ($owner.run_token -ceq $binding.run_token -and $owner.private_root -ceq $ownedRoot -and $owner.result_directory -ceq $ResultDirectory) 'Cleanup ownership binding differs.'
            Require (@(Get-ChildItem -LiteralPath $ownedRoot -Recurse -Force | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count -eq 0) 'Private reparse point; refusing deletion.'
            Remove-Item -LiteralPath $ownedRoot -Recurse -Force
        }
        $result.private_root_removed=-not (Test-Path -LiteralPath $ownedRoot)
        $result.source_unchanged=((Hash $Artifact) -ceq $result.source_sha256)
        $result.parent_environment_preserved=$true
        foreach ($name in $inherited.Keys) { if ([Environment]::GetEnvironmentVariable($name,'Process') -cne $inherited[$name]) { $result.parent_environment_preserved=$false } }
        Require ($result.source_unchanged -and $result.parent_environment_preserved) 'Source artifact or parent environment changed.'
    } catch { $result.status='FAIL'; $result.cleanup_failure=$_.Exception.Message }
    finally {
        if ($null -ne $exeLock) { $exeLock.Dispose() }
        foreach ($leg in $jobs) { $leg.job.Dispose(); $leg.job.Process.Dispose() }
        Write-Json $resultPath $result
    }
}
$result | ConvertTo-Json -Depth 12
if ($result.status -ne 'PASS') { exit 1 }
