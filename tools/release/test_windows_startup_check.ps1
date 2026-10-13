<# Run on native Windows. Uses only short-lived harmless managed EXEs and malformed ZIPs. #>
param([Parameter(Mandatory=$true)][string]$TestDirectory)
$ErrorActionPreference='Stop'
$TestDirectory=[IO.Path]::GetFullPath($TestDirectory)
if (Test-Path -LiteralPath $TestDirectory) { throw 'Use a fresh TestDirectory.' }
New-Item -ItemType Directory -Path $TestDirectory | Out-Null
$runner=Join-Path $PSScriptRoot 'run_windows_startup_check.ps1'
$fixture=Join-Path $TestDirectory 'failure.exe'
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
using System.Diagnostics;
public class StartupFailureFixture {
    public static int Main(string[] args) {
        string name=Path.GetFileNameWithoutExtension(System.Reflection.Assembly.GetExecutingAssembly().Location);
        if (name=="timeout" || name=="abort") { Thread.Sleep(60000); return 0; }
        string log=null;
        for (int i=0; i<args.Length-1; i++) if (args[i]=="--log-file") log=args[i+1];
        string output="STARTUP_MENU_READY_OK: harmless fixture\n";
        if (name=="duplicate") output+=output;
        if (name=="diagnostic") output+="SCRIPT ERROR: deliberate fixture diagnostic\n";
        if (name=="descendant") {
            ProcessStartInfo child=new ProcessStartInfo(Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"),"System32\\WindowsPowerShell\\v1.0\\powershell.exe"),"-NoProfile -NonInteractive -Command Start-Sleep -Seconds 60");
            child.UseShellExecute=false; child.CreateNoWindow=true;
            Process retained=Process.Start(child);
            output+="RETAINED_PIPE_CHILD_PID="+retained.Id+"\n";
        }
        Console.Write(output);
        if (log!=null) File.WriteAllText(log,output);
        return name=="failure" ? 7 : 0;
    }
}
'@ -OutputAssembly $fixture -OutputType ConsoleApplication
$pin=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$results=New-Object Collections.ArrayList
function Invoke-Case([string]$name,[string]$artifact,[string]$expectedFailure,[bool]$abortCase=$false) {
    $directory=Join-Path $TestDirectory ($name+'-result')
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $info.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$runner+'" -Artifact "'+$artifact+'" -ExpectedExeSha256 '+$pin+' -ResultDirectory "'+$directory+'" -TimeoutSeconds '+$(if ($abortCase) {'30'} else {'2'})
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $process=[Diagnostics.Process]::Start($info)
    $out=$process.StandardOutput.ReadToEndAsync(); $err=$process.StandardError.ReadToEndAsync()
    try {
        if ($abortCase) {
            $watch=[Diagnostics.Stopwatch]::StartNew()
            do {
                Start-Sleep -Milliseconds 100
                $ownedFile=Join-Path $directory 'owned-process.json'
                $owned=$null
                if (Test-Path -LiteralPath $ownedFile) { try { $owned=Get-Content -LiteralPath $ownedFile -Raw | ConvertFrom-Json } catch {} }
            } while (($null -eq $owned -or $null -eq $owned.pid) -and $watch.Elapsed.TotalSeconds -lt 15 -and -not $process.HasExited)
            if ($null -eq $owned -or $null -eq $owned.pid) { throw 'Abort fixture failed to start.' }
            $abortInfo=New-Object Diagnostics.ProcessStartInfo
            $abortInfo.FileName=$info.FileName; $abortInfo.UseShellExecute=$false; $abortInfo.CreateNoWindow=$true
            $abortInfo.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$runner+'" -Abort -ResultDirectory "'+$directory+'"'
            $abortProc=[Diagnostics.Process]::Start($abortInfo)
            try { if (-not $abortProc.WaitForExit(30000) -or $abortProc.ExitCode -ne 0) { throw 'Independent abort failed.' } } finally { $abortProc.Dispose() }
        }
        if (-not $process.WaitForExit(30000)) { throw 'Failure fixture runner exceeded bounded test deadline.' }
        $process.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $TestDirectory ($name+'-harness.log')),$out.Result+"`n"+$err.Result)
        $record=Get-Content -LiteralPath (Join-Path $directory 'result.json') -Raw | ConvertFrom-Json
        if ($process.ExitCode -ne 1 -or $record.status -ne 'FAIL' -or $record.failure -notmatch $expectedFailure -or
            -not $record.private_root_removed -or -not $record.source_unchanged -or -not $record.parent_environment_preserved -or $record.final_owned_actors.Count -ne 0) {
            throw "Case $name did not fail safely: $($record | ConvertTo-Json -Depth 4)"
        }
        if ($name -eq 'failure' -and $record.exit_code -ne 7) { throw 'Nonzero fixture exit was not retained.' }
        if ($name -eq 'descendant' -and ($record.descendants_at_parent_exit -lt 1 -or $record.streams_complete_at_parent_exit -or $record.final_job_active_processes -ne 0)) { throw 'Retained-pipe descendant fixture did not prove bounded Job cleanup.' }
        [void]$results.Add(@{name=$name;status='PASS';actual_failure=$record.failure;exit_code=$record.exit_code})
    } finally {
        if (-not $process.HasExited) { & $runner -Abort -ResultDirectory $directory; if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() } }
        $process.Dispose()
    }
}
foreach ($name in @('failure','duplicate','diagnostic','timeout','abort','descendant')) {
    $path=Join-Path $TestDirectory ($name+'.exe')
    if ($path -ne $fixture) { Copy-Item -LiteralPath $fixture -Destination $path }
    $reason=if ($name -eq 'timeout') {'deadline exceeded'} elseif ($name -eq 'abort') {'aborted by operator'} elseif ($name -eq 'descendant') {'Owned descendants remain'} else {'contract failed'}
    Invoke-Case $name $path $reason ($name -eq 'abort')
}
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
foreach ($case in @(
    @{name='traversal';members=@('../fixture.exe','fixture-notes.txt');attribute=0},
    @{name='duplicate-member';members=@('fixture.exe','fixture.exe');attribute=0},
    @{name='unexpected-exe';members=@('other.exe','fixture-notes.txt');attribute=0},
    @{name='symlink';members=@('fixture.exe','fixture-notes.txt');attribute=-1577058304}
)) {
    $folder=Join-Path $TestDirectory $case.name
    New-Item -ItemType Directory -Path $folder | Out-Null
    $zip=Join-Path $folder 'fixture-checkpoint.zip'
    $archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $case.members) {
            $entry=$archive.CreateEntry($name)
            $entry.ExternalAttributes=$case.attribute
            $stream=$entry.Open()
            try { $bytes=[Text.Encoding]::UTF8.GetBytes('harmless invalid archive'); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
        }
    } finally { $archive.Dispose() }
    Invoke-Case $case.name $zip 'ZIP member'
}
# An untrusted abort record must never create abort.request outside its owned native TEMP run.
$unowned=Join-Path $TestDirectory 'unowned directory'
New-Item -ItemType Directory -Path $unowned | Out-Null
$malformed=Join-Path $TestDirectory 'malformed-abort'
New-Item -ItemType Directory -Path $malformed | Out-Null
@{private_root=$unowned;pid=$null;result_directory=$malformed;run_token=('a'*32)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $malformed 'owned-process.json') -Encoding UTF8
$abortInfo=New-Object Diagnostics.ProcessStartInfo
$abortInfo.FileName=Join-Path $PSHOME 'powershell.exe'; $abortInfo.UseShellExecute=$false; $abortInfo.CreateNoWindow=$true
$abortInfo.RedirectStandardOutput=$true; $abortInfo.RedirectStandardError=$true
$abortInfo.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$runner+'" -Abort -ResultDirectory "'+$malformed+'"'
$badAbort=[Diagnostics.Process]::Start($abortInfo)
$badOut=$badAbort.StandardOutput.ReadToEndAsync(); $badErr=$badAbort.StandardError.ReadToEndAsync()
try {
    if (-not $badAbort.WaitForExit(10000)) { $badAbort.Kill(); throw 'Malformed abort exceeded test deadline.' }
    if ($badAbort.ExitCode -ne 1 -or (Get-ChildItem -LiteralPath $unowned -Force).Count -ne 0 -or $badErr.Result -notmatch 'ownership/root/result-directory binding is invalid') { throw 'Malformed abort did not reject without writing.' }
    [IO.File]::WriteAllText((Join-Path $TestDirectory 'malformed-abort.log'),$badOut.Result+"`n"+$badErr.Result)
    [void]$results.Add(@{name='malformed-abort-no-write';status='PASS'})
} finally { $badAbort.Dispose() }
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $TestDirectory 'test-results.json') -Encoding UTF8
Write-Output "PASS: $($results.Count) native Windows failure/abort/archive cases."
