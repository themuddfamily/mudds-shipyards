<#
.SYNOPSIS
Silently check an exported Windows EXE or checkpoint ZIP in a disposable profile.
.DESCRIPTION
Requires a pinned EXE SHA-256, explicit fresh result directory, exit zero and exactly
one STARTUP_MENU_READY_OK line in stdout and Godot's log without diagnostics.
The default game deadline is 300 seconds. No installation, GUI, input or real user
data is involved. HOME and USERPROFILE are inherited unchanged. To abort from a
second terminal, invoke this same script with -Abort -ResultDirectory <directory>.
#>
[CmdletBinding(DefaultParameterSetName='Run')]
param(
    [Parameter(Mandatory=$true, ParameterSetName='Run')][string]$Artifact,
    [Parameter(Mandatory=$true, ParameterSetName='Run')][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedExeSha256,
    [Parameter(Mandatory=$true)][string]$ResultDirectory,
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
        [IO.Path]::GetFileName($root) -cnotmatch '^Mudds startup [0-9a-f]{32}$' -or
        $record.result_directory -ine $ResultDirectory -or $record.run_token -cnotmatch '^[0-9a-f]{32}$') {
        throw 'Abort ownership/root/result-directory binding is invalid.'
    }
    Assert-NoReparse $root
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $false }
    $binding=Get-Content -LiteralPath (Join-Path $root 'run-owner.json') -Raw | ConvertFrom-Json
    if ($binding.run_token -cne $record.run_token -or $binding.result_directory -ine $ResultDirectory -or $binding.private_root -cne $root) {
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
        [WindowsStartupProcess]::Abort($owned.run_token,(Join-Path $owned.private_root 'abort.request'),10000)
    }
    Write-Output 'Owned startup abort requested.'
    exit 0
}
# Explicit output must not point into real application data or Downloads.
foreach ($protected in @($env:APPDATA,$env:LOCALAPPDATA,(Join-Path $env:USERPROFILE 'Downloads'))) {
    if (-not [string]::IsNullOrEmpty($protected)) {
        $protected=[IO.Path]::GetFullPath($protected).TrimEnd('\')
        if ($ResultDirectory -eq $protected -or $ResultDirectory.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)) { throw "Result directory is a protected real-user location: $ResultDirectory" }
    }
}
if (Test-Path -LiteralPath $ResultDirectory) { throw 'ResultDirectory must be fresh; refusing to overwrite results.' }
$Artifact=[IO.Path]::GetFullPath($Artifact)
Assert-NoReparse $Artifact
if (-not (Test-Path -LiteralPath $Artifact -PathType Leaf)) { throw 'Artifact must be a regular file.' }
$extension=[IO.Path]::GetExtension($Artifact).ToLowerInvariant()
if ($extension -notin @('.exe','.zip')) { throw 'Artifact must be an EXE or a checkpoint ZIP.' }
New-Item -ItemType Directory -Path $ResultDirectory | Out-Null
$ownedRoot=Join-Path ([IO.Path]::GetTempPath()) ('Mudds startup '+[Guid]::NewGuid().ToString('N'))
Assert-NoReparse $ownedRoot
$inherited=@{}
foreach ($name in @('HOME','USERPROFILE','APPDATA','LOCALAPPDATA','TEMP','TMP','TMPDIR','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CONFIG_DIRS','XDG_DATA_DIRS','XDG_RUNTIME_DIR')) { $inherited[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
$result=[ordered]@{
    status='RUNNING'; artifact=$Artifact; expected_exe_sha256=$ExpectedExeSha256.ToLowerInvariant(); timeout_seconds=$TimeoutSeconds
    arguments='--headless --audio-driver Dummy --startup-check'; harness_pid=$PID; windows_version=[Environment]::OSVersion.VersionString
    private_root=$ownedRoot; scope='native Windows headless title-menu startup only'; native_gpu='NOT_RUN'; gameplay='NOT_RUN'; audible_audio='NOT_RUN'; human_review='NOT_RUN'
}
$resultPath=Join-Path $ResultDirectory 'result.json'
$proc=$null; $owned=$null; $ownedJob=$null; $exeLock=$null; $stdoutTask=$null; $stderrTask=$null
$log=Join-Path $ownedRoot 'godot.log'
try {
    New-Item -ItemType Directory -Path $ownedRoot | Out-Null
    $binding=@{private_root=$ownedRoot; result_directory=$ResultDirectory; run_token=[Guid]::NewGuid().ToString('N')}
    Write-Json (Join-Path $ownedRoot 'run-owner.json') $binding
    Write-Json (Join-Path $ResultDirectory 'owned-process.json') ($binding+@{pid=$null})
    $result.source_sha256=Hash $Artifact
    $package=Join-Path $ownedRoot 'package'
    New-Item -ItemType Directory -Path $package | Out-Null
    if ($extension -eq '.zip') {
        $base=[IO.Path]::GetFileName($Artifact)
        if ($base -cnotmatch '^(.+)-checkpoint\.zip$') { throw 'ZIP name must be <build>-checkpoint.zip.' }
        $build=$Matches[1]
        $expectedMembers=@(($build+'.exe'),($build+'-notes.txt'))
        $localZip=Join-Path $ownedRoot 'checkpoint.zip'
        Copy-Item -LiteralPath $Artifact -Destination $localZip
        if ((Hash $localZip) -ne $result.source_sha256) { throw 'Copied ZIP hash differs from source.' }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive=[IO.Compression.ZipFile]::OpenRead($localZip)
        try {
            $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            if ($archive.Entries.Count -ne 2) { throw 'Checkpoint ZIP must contain exactly the expected EXE and notes.' }
            foreach ($entry in $archive.Entries) {
                $name=$entry.FullName
                $unixType=([int64]$entry.ExternalAttributes -shr 16) -band 0xF000
                if (-not $seen.Add($name) -or $expectedMembers -cnotcontains $name -or
                    $name.IndexOfAny([char[]]'\/:') -ge 0 -or
                    ($unixType -ne 0 -and $unixType -ne 0x8000) -or
                    ($entry.ExternalAttributes -band 0x410) -ne 0 -or
                    $entry.Length -le 0 -or $entry.Length -gt 1073741824 -or
                    ($name.EndsWith('-notes.txt') -and $entry.Length -gt 1048576)) {
                    throw "Unsafe, duplicate, non-regular or unexpected ZIP member: $name"
                }
            }
            # All entries are validated before the first byte is extracted.
            foreach ($entry in $archive.Entries) {
                $target=Join-Path $package $entry.FullName
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
            }
        } finally { $archive.Dispose() }
        $exe=Join-Path $package ($build+'.exe')
        $result.zip_members=$expectedMembers
    } else {
        $exe=Join-Path $package ([IO.Path]::GetFileName($Artifact))
        Copy-Item -LiteralPath $Artifact -Destination $exe
    }
    $result.exe_sha256=Hash $exe
    if ($result.exe_sha256 -ne $ExpectedExeSha256.ToLowerInvariant()) { throw 'EXE SHA-256 differs from the required pin.' }
    # Hold the tested copy read-only for the entire invocation.
    $exeLock=[IO.File]::Open($exe,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $profile=Join-Path $ownedRoot 'profile'
    $environment=[ordered]@{
        APPDATA=(Join-Path $profile 'AppData\Roaming'); LOCALAPPDATA=(Join-Path $profile 'AppData\Local')
        TEMP=(Join-Path $profile 'Temp'); TMP=(Join-Path $profile 'Temp'); TMPDIR=(Join-Path $profile 'TmpDir')
        XDG_CONFIG_HOME=(Join-Path $profile 'XDG\Config'); XDG_CACHE_HOME=(Join-Path $profile 'XDG\Cache')
        XDG_DATA_HOME=(Join-Path $profile 'XDG\Data'); XDG_STATE_HOME=(Join-Path $profile 'XDG\State')
        XDG_CONFIG_DIRS=(Join-Path $profile 'XDG\ConfigDirs'); XDG_DATA_DIRS=(Join-Path $profile 'XDG\DataDirs'); XDG_RUNTIME_DIR=(Join-Path $profile 'XDG\Runtime')
    }
    foreach ($dir in $environment.Values) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $result.environment=$environment; $result.profile=$profile
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$exe; $info.WorkingDirectory=$package
    $info.Arguments=$result.arguments+' --log-file "'+$log+'"'
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    foreach ($entry in $environment.GetEnumerator()) { $info.EnvironmentVariables[$entry.Key]=$entry.Value }
    if ($info.EnvironmentVariables['HOME'] -ne $inherited.HOME -or $info.EnvironmentVariables['USERPROFILE'] -ne $inherited.USERPROFILE) { throw 'Inherited HOME/USERPROFILE differ.' }
    $result.HOME_preserved=$true; $result.USERPROFILE_preserved=$true
    $timer=[Diagnostics.Stopwatch]::StartNew()
    Add-Type -Path (Join-Path $PSScriptRoot 'windows_startup_process.cs')
    $ownedJob=New-Object WindowsStartupProcess($info,$binding.run_token)
    $proc=$ownedJob.Process
    $stdoutTask=$ownedJob.Stdout; $stderrTask=$ownedJob.Stderr
    $owned=$binding+@{pid=$proc.Id; exe=$exe; start_time_utc=$proc.StartTime.ToUniversalTime().ToString('o')}
    $result.process=$owned
    Write-Json (Join-Path $ResultDirectory 'owned-process.json') $owned
    Write-Json $resultPath $result
    $ownedJob.Resume()
    while (-not $ownedJob.WaitForExit(100)) {
        if (Test-Path -LiteralPath (Join-Path $ownedRoot 'abort.request')) { throw 'Startup aborted by operator.' }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) { throw 'Startup deadline exceeded.' }
        $proc.Refresh()
        if (-not $proc.HasExited -and $proc.MainWindowHandle.ToInt64() -ne 0) { throw 'Headless process unexpectedly reports a window.' }
    }
    # Job accounting may trail the parent exit signal briefly.
    $jobExitWatch=[Diagnostics.Stopwatch]::StartNew()
    while ($ownedJob.ActiveProcesses -ne 0 -and $jobExitWatch.ElapsedMilliseconds -lt 1000) { Start-Sleep -Milliseconds 20 }
    $result.descendants_at_parent_exit=$ownedJob.ActiveProcesses
    $result.streams_complete_at_parent_exit=($stdoutTask.IsCompleted -and $stderrTask.IsCompleted)
    if ($result.descendants_at_parent_exit -ne 0) { throw 'Owned descendants remain after startup parent exit.' }
    if (-not $ownedJob.Drain(10000)) { throw 'Startup stream drain deadline exceeded.' }
    if (Test-Path -LiteralPath (Join-Path $ownedRoot 'abort.request')) { throw 'Startup aborted by operator.' }
    $result.exit_code=$ownedJob.ExitCode; $result.wall_ms=$timer.ElapsedMilliseconds
    $stdout=$stdoutTask.Result; $stderr=$stderrTask.Result
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { throw 'Godot log is missing.' }
    $gameLog=[IO.File]::ReadAllText($log)
    $result.stdout_sentinel_count=[regex]::Matches($stdout,'(?m)^STARTUP_MENU_READY_OK: [^\r\n]+\r?$').Count
    $result.game_log_sentinel_count=[regex]::Matches($gameLog,'(?m)^STARTUP_MENU_READY_OK: [^\r\n]+\r?$').Count
    $result.diagnostics=@([regex]::Matches(($stdout+"`n"+$stderr+"`n"+$gameLog),'(?im)^(?:ERROR:|WARNING:|SCRIPT ERROR:|Parse Error:|.*STARTUP_MENU_READY_FAILED.*|.*ObjectDB instances leaked.*|.*resources still in use.*).*$') | ForEach-Object {$_.Value})
    if ($result.exit_code -ne 0 -or $result.stdout_sentinel_count -ne 1 -or $result.game_log_sentinel_count -ne 1 -or $result.diagnostics.Count -ne 0) { throw 'Startup exit/readiness/diagnostics contract failed.' }
    $result.user_data_path=Join-Path $environment.APPDATA 'Godot\app_userdata\Mudds Shipyards'
    if (-not (Test-Path -LiteralPath $result.user_data_path -PathType Container)) { throw 'Private Windows game data directory missing.' }
    $result.status='PASS'
} catch { $result.status='FAIL'; $result.failure=$_.Exception.Message }
finally {
    try {
        if ($null -ne $ownedJob) { $ownedJob.Stop(10000); $result.final_job_active_processes=$ownedJob.ActiveProcesses }
        if ($null -ne $proc) { if (-not $ownedJob.WaitForExit(1000)) { throw 'Owned parent failed to reap.' }; $result.exit_code=$ownedJob.ExitCode }
        if ($null -ne $ownedJob -and -not $ownedJob.Drain(10000)) { throw 'Cleanup stream drain deadline exceeded.' }
        if ($null -ne $stdoutTask) { [IO.File]::WriteAllText((Join-Path $ResultDirectory 'stdout.log'),$stdoutTask.Result,$utf8) }
        if ($null -ne $stderrTask) { [IO.File]::WriteAllText((Join-Path $ResultDirectory 'stderr.log'),$stderrTask.Result,$utf8) }
        if (Test-Path -LiteralPath $log -PathType Leaf) { Copy-Item -LiteralPath $log -Destination (Join-Path $ResultDirectory 'godot.log') }
        $result.final_owned_actors=@(Owned-Actors $ownedRoot)
        if ($result.final_owned_actors.Count -ne 0) { throw 'Owned namespace actors remain; refusing private directory deletion.' }
        if ($null -ne $exeLock) { $exeLock.Dispose(); $exeLock=$null }
        if (Test-Path -LiteralPath $ownedRoot) {
            Assert-NoReparse $ownedRoot
            if (@(Get-ChildItem -LiteralPath $ownedRoot -Recurse -Force | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }).Count -ne 0) { throw 'Private tree contains a reparse point; refusing recursive deletion.' }
            $result.profile_files=@(Get-ChildItem -LiteralPath (Join-Path $ownedRoot 'profile') -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { @{path=$_.FullName; bytes=$_.Length; sha256=(Hash $_.FullName)} })
            Remove-Item -LiteralPath $ownedRoot -Recurse -Force
        }
        $result.private_root_removed=-not (Test-Path -LiteralPath $ownedRoot)
        $result.source_unchanged=((Hash $Artifact) -eq $result.source_sha256)
        $result.parent_environment_preserved=$true
        foreach ($name in $inherited.Keys) { if ([Environment]::GetEnvironmentVariable($name,'Process') -ne $inherited[$name]) { $result.parent_environment_preserved=$false } }
        if (-not $result.source_unchanged -or -not $result.parent_environment_preserved) { throw 'Source artifact or parent environment changed.' }
    } catch { $result.status='FAIL'; $result.cleanup_failure=$_.Exception.Message }
    finally {
        if ($null -ne $exeLock) { $exeLock.Dispose() }
        if ($null -ne $ownedJob) { $ownedJob.Dispose() }
        if ($null -ne $proc) { $proc.Dispose() }
        Write-Json $resultPath $result
    }
}
$result | ConvertTo-Json -Depth 12
if ($result.status -ne 'PASS') { exit 1 }
