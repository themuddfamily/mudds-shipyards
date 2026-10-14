<# Run on native Windows. Uses only short-lived harmless managed EXEs to exercise interruption-specific protocol failures. #>
param([Parameter(Mandatory=$true)][string]$TestDirectory)
$ErrorActionPreference='Stop'
$TestDirectory=[IO.Path]::GetFullPath($TestDirectory)
if (Test-Path -LiteralPath $TestDirectory) { throw 'Use a fresh TestDirectory.' }
New-Item -ItemType Directory -Path $TestDirectory | Out-Null
$runner=Join-Path $PSScriptRoot 'run_windows_interruption_check.ps1'
$fixture=Join-Path $TestDirectory 'failure.exe'
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
public class InterruptionFailureFixture {
    public static int Main(string[] args) {
        string name=Path.GetFileNameWithoutExtension(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string log=null; bool arm=false;
        for (int i=0;i<args.Length;i++) {
            if (args[i]=="--log-file" && i+1<args.Length) log=args[++i];
            else if (args[i]=="--in-world-interruption-stage=arm") arm=true;
        }
        string data=Path.Combine(Environment.GetEnvironmentVariable("APPDATA"),"Godot\\app_userdata\\Mudds Shipyards");
        Directory.CreateDirectory(data);
        string boundary="{\"escort_ship_id\":\"fixture\",\"clock\":1}";
        string document="{\"payload\":{\"cinder_convoy_session\":{\"activities\":[{\"progress\":{\"convoy_session_state\":"+boundary+"}}]},\"crash_recovery\":{\"state\":\"running\"},\"game_flow_reward_store\":{\"reward_counts\":{\"return_convoy_credit_to_shipyard\":1}},\"solo_safe_recovery\":{\"mode\":\"pilot\",\"craft_id\":\"fixture\"}}}";
        if (arm) {
            File.WriteAllText(Path.Combine(data,"mudds_user_data.json"),document);
            string ready="IN_WORLD_INTERRUPTION_READY: {\"boundary\":"+(name=="wrong-boundary"?"{}":boundary)+",\"receipts\":1,\"runtime_observation\":{\"craft_id\":\"fixture\"},\"entry\":\"startup_completed\",\"loaded_main_instance_id\":1,\"recovery_context\":\"pilot\"}\n";
            if (name=="duplicate-arm") ready+=ready;
            Console.Write(ready); Console.Out.Flush(); File.WriteAllText(log,ready);
            Thread.Sleep(60000); return 0;
        }
        if (name=="abort-resume") { Thread.Sleep(60000); return 0; }
        string recovered="IN_WORLD_RECOVERY_OK: {\"boundary\":"+boundary+",\"receipts_before\":1,\"receipts_after\":2,\"crash_events\":1,\"entry\":\"startup_completed\",\"loaded_main_instance_id\":2,\"recovery_context\":\"pilot\"}\n";
        if (name=="duplicate-resume") recovered+=recovered;
        Console.Write(recovered); File.WriteAllText(log,recovered);
        return 7;
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
            } while (($null -eq $owned -or $null -eq $owned.pid -or $owned.stage -ne 'resume') -and $watch.Elapsed.TotalSeconds -lt 15 -and -not $process.HasExited)
            if ($null -eq $owned -or $null -eq $owned.pid -or $owned.stage -ne 'resume') { throw 'Abort fixture failed to start.' }
            $abortInfo=New-Object Diagnostics.ProcessStartInfo
            $abortInfo.FileName=$info.FileName; $abortInfo.UseShellExecute=$false; $abortInfo.CreateNoWindow=$true
            $abortInfo.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$runner+'" -Abort -ResultDirectory "'+$directory+'"'
            # A valid-looking Job token in the public result must also match the
            # private owner marker; reject tampering without stopping the leg.
            $original=[IO.File]::ReadAllText($ownedFile)
            $owned.job_token=('a'*32)
            [IO.File]::WriteAllText($ownedFile,($owned | ConvertTo-Json -Depth 8))
            $abortInfo.RedirectStandardOutput=$true; $abortInfo.RedirectStandardError=$true
            $badAbort=[Diagnostics.Process]::Start($abortInfo)
            $badOut=$badAbort.StandardOutput.ReadToEndAsync(); $badErr=$badAbort.StandardError.ReadToEndAsync()
            try {
                if (-not $badAbort.WaitForExit(10000)) { $badAbort.Kill(); throw 'Tampered Job abort exceeded deadline.' }
                if ($badAbort.ExitCode -ne 1 -or $badErr.Result -notmatch 'Private run ownership marker differs' -or $process.HasExited -or -not (Get-Process -Id $owned.pid -ErrorAction SilentlyContinue)) { throw 'Tampered Job token did not reject without stopping the bound leg.' }
                [IO.File]::WriteAllText((Join-Path $TestDirectory 'tampered-job-abort.log'),$badOut.Result+"`n"+$badErr.Result)
                [void]$results.Add(@{name='tampered-job-token-no-kill';status='PASS'})
            } finally { $badAbort.Dispose(); [IO.File]::WriteAllText($ownedFile,$original) }
            $abortProc=[Diagnostics.Process]::Start($abortInfo)
            try { if (-not $abortProc.WaitForExit(30000) -or $abortProc.ExitCode -ne 0) { throw 'Independent abort failed.' } } finally { $abortProc.Dispose() }
        }
        if (-not $process.WaitForExit(30000)) { throw 'Failure fixture runner exceeded bounded test deadline.' }
        $process.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $TestDirectory ($name+'-harness.log')),$out.Result+"`n"+$err.Result)
        $record=Get-Content -LiteralPath (Join-Path $directory 'result.json') -Raw | ConvertFrom-Json
        if ($process.ExitCode -ne 1 -or $record.status -ne 'FAIL' -or $record.failure -notmatch $expectedFailure -or
            -not $record.private_root_removed -or -not $record.source_unchanged -or -not $record.parent_environment_preserved -or $record.final_owned_actors.Count -ne 0 -or -not $record.protected_real_game_data_unchanged) {
            throw "Case $name did not fail safely: $($record | ConvertTo-Json -Depth 4)"
        }
        if ($name -eq 'resume-failure' -and $record.processes[-1].exit_code -ne 7) { throw 'Nonzero fixture exit was not retained.' }
        [void]$results.Add(@{name=$name;status='PASS';actual_failure=$record.failure;exit_code=$record.processes[-1].exit_code})
    } finally {
        if (-not $process.HasExited) { & $runner -Abort -ResultDirectory $directory; if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() } }
        $process.Dispose()
    }
}
foreach ($name in @('duplicate-arm','wrong-boundary','duplicate-resume','resume-failure','abort-resume')) {
    $path=Join-Path $TestDirectory ($name+'.exe')
    Copy-Item -LiteralPath $fixture -Destination $path
    $reason=if ($name -eq 'duplicate-arm') {'Duplicate IN_WORLD_INTERRUPTION_READY'} elseif ($name -eq 'wrong-boundary') {'Readiness differs'} elseif ($name -eq 'duplicate-resume') {'Duplicate IN_WORLD_RECOVERY_OK'} elseif ($name -eq 'abort-resume') {'aborted by operator'} else {'Restart exit/readiness contract failed'}
    Invoke-Case $name $path $reason ($name -eq 'abort-resume')
}
# A protected inherited XDG game-data destination must fail before creation.
$xdg=Join-Path $TestDirectory 'inherited-xdg'
$protectedResult=Join-Path $xdg 'godot\app_userdata\Mudds Shipyards\results'
$info=New-Object Diagnostics.ProcessStartInfo
$info.FileName=Join-Path $PSHOME 'powershell.exe'; $info.UseShellExecute=$false; $info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
$info.EnvironmentVariables['XDG_DATA_HOME']=$xdg
$info.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$runner+'" -Artifact "'+$fixture+'" -ExpectedExeSha256 '+$pin+' -ResultDirectory "'+$protectedResult+'"'
$process=[Diagnostics.Process]::Start($info)
$out=$process.StandardOutput.ReadToEndAsync(); $err=$process.StandardError.ReadToEndAsync()
try {
    if (-not $process.WaitForExit(10000)) { $process.Kill(); throw 'Protected destination check exceeded deadline.' }
    if ($process.ExitCode -ne 1 -or (Test-Path -LiteralPath $xdg) -or $err.Result -notmatch 'protected real-user location') { throw 'Protected XDG destination did not reject before creating any files.' }
    [IO.File]::WriteAllText((Join-Path $TestDirectory 'protected-xdg-harness.log'),$out.Result+"`n"+$err.Result)
    [void]$results.Add(@{name='protected-xdg-no-write';status='PASS'})
} finally { $process.Dispose() }
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $TestDirectory 'test-results.json') -Encoding UTF8
Write-Output "PASS: $($results.Count) native Windows interruption protocol/second-leg abort cases."
