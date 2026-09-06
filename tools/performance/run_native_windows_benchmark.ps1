# Run from Windows PowerShell 5.1+ against a clean, imported checkout on Windows.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$Project,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$TargetProfile,
    [switch]$Smoke,
    [switch]$Headless,
    [switch]$PreflightOnly,
    [int]$TimeoutSeconds = 3600
)
$ErrorActionPreference = 'Stop'
if ($Headless -and -not $Smoke) { throw 'Headless is permitted only for readiness smoke.' }
$Godot = (Resolve-Path $Godot).Path
$Project = (Resolve-Path $Project).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if ($OutputDirectory.StartsWith($Project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or $OutputDirectory -eq $Project) {
    throw 'OutputDirectory must be outside the source checkout.'
}
if (Test-Path $OutputDirectory) { throw 'Choose a new output directory; existing results are never overwritten.' }
$git = (Get-Command git -ErrorAction Stop).Source
$sha = (& $git -C $Project rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot read source revision.' }
$status = & $git -C $Project status --porcelain=v1
if ($LASTEXITCODE -ne 0 -or $status) { throw 'The source checkout must be clean.' }
if (-not $PreflightOnly -and -not (Test-Path "$Project\.godot\global_script_class_cache.cfg")) {
    throw 'Import this checkout with a matching Godot editor first (see benchmark documentation).'
}
if ($TargetProfile) { $TargetProfile = (Resolve-Path $TargetProfile).Path }
if (-not $Smoke -and -not $PreflightOnly -and -not $TargetProfile) { throw 'A reviewed target profile is required for a full run.' }
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
$hardware = [ordered]@{
    captured_utc = [DateTime]::UtcNow.ToString('o')
    source_git_sha = $sha
    source_git_dirty = $false
    engine_path = $Godot
    engine_sha256 = (Get-FileHash $Godot -Algorithm SHA256).Hash
    os = @(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber)
    cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors)
    computer = @(Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,TotalPhysicalMemory)
    gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,PNPDeviceID)
    classification = 'Observed host only; this does not validate minimum hardware or the RTX 3060 target.'
    gpu_frame_time_ms = @{available=$false;value=$null;reason='No per-frame GPU timing collector attached.'}
    dedicated_process_vram_bytes = @{available=$false;value=$null;reason='Board-wide nvidia-smi memory is not process VRAM.'}
    human_play_review = 'NOT_RUN'
    audible_review = 'NOT_RUN'
}
$hardware | ConvertTo-Json -Depth 8 | Set-Content "$OutputDirectory\hardware.json" -Encoding UTF8
$nvidia = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($nvidia) {
    & $nvidia.Source '--query-gpu=timestamp,index,name,driver_version,memory.total,memory.used,utilization.gpu' '--format=csv' |
        Set-Content "$OutputDirectory\gpu-before.csv" -Encoding UTF8
}
if ($TargetProfile) { Copy-Item $TargetProfile "$OutputDirectory\target-profile.json" }
if ($PreflightOnly) { Write-Output "Native preflight recorded: $OutputDirectory"; return }
$variables = @('KETH_BENCHMARK_JSON','KETH_BENCHMARK_TARGET_PROFILE','KETH_BENCHMARK_SMOKE',
    'KETH_BENCHMARK_RESOLUTION','KETH_BENCHMARK_QUALITY_LEVEL','KETH_BENCHMARK_WARMUP_FRAMES','KETH_BENCHMARK_SAMPLE_FRAMES','APPDATA')
$saved = @{}
foreach ($name in $variables) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$process = $null
try {
    # Clear inherited protocol overrides; full runs retain the runner's defaults.
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    $env:APPDATA = "$OutputDirectory\userdata"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $env:KETH_BENCHMARK_JSON = "$OutputDirectory\benchmark.json"
    if ($TargetProfile) { $env:KETH_BENCHMARK_TARGET_PROFILE = "$OutputDirectory\target-profile.json" }
    if ($Smoke) { $env:KETH_BENCHMARK_SMOKE = '1' }
    $arguments = @('--audio-driver', 'Dummy', '--path', ('"' + $Project + '"'), '--script', 'res://tools/performance/benchmark_runner.gd')
    if ($Headless) { $arguments += '--headless' }
    @{executable=$Godot;arguments=$arguments;working_directory=$Project;source_git_sha=$sha;smoke=[bool]$Smoke;headless=[bool]$Headless} |
        ConvertTo-Json -Depth 4 | Set-Content "$OutputDirectory\invocation.json" -Encoding UTF8
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WorkingDirectory $Project -PassThru `
        -RedirectStandardOutput "$OutputDirectory\stdout.log" -RedirectStandardError "$OutputDirectory\stderr.log"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $peakWorkingSet = 0L
    'elapsed_seconds,working_set_bytes,peak_working_set_bytes' | Set-Content "$OutputDirectory\process-memory.csv"
    while (-not $process.HasExited) {
        $process.Refresh()
        if ($process.HasExited) { break }
        $peakWorkingSet = [Math]::Max($peakWorkingSet, $process.PeakWorkingSet64)
        ('{0:F3},{1},{2}' -f $timer.Elapsed.TotalSeconds,$process.WorkingSet64,$process.PeakWorkingSet64) |
            Add-Content "$OutputDirectory\process-memory.csv"
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds) { throw "Benchmark exceeded timeout ($TimeoutSeconds seconds)." }
        Start-Sleep -Milliseconds 1000
    }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Godot exited $($process.ExitCode); inspect stderr.log." }
    if (-not (Test-Path "$OutputDirectory\benchmark.json")) { throw 'Godot wrote no benchmark report; inspect logs.' }
    $report = Get-Content "$OutputDirectory\benchmark.json" -Raw | ConvertFrom-Json
    $afterStatus = & $git -C $Project status --porcelain=v1
    if ($LASTEXITCODE -ne 0 -or $afterStatus) { throw 'Source became dirty during benchmark.' }
    $afterSha = (& $git -C $Project rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $afterSha -ne $sha -or $report.source.git_sha -ne $sha -or $report.source.git_dirty) {
        throw 'Benchmark source identity differs from the clean checkout.'
    }
    @{elapsed_seconds=$timer.Elapsed.TotalSeconds;peak_working_set_bytes_observed=$peakWorkingSet;
      sampling_interval_ms=1000;scope='OS process peak sampled during whole invocation; not per scenario';
      performance_budget_pass=$null;reason='Review scenario frame budgets and protocol duration; GPU timing and process VRAM remain unavailable.'} |
        ConvertTo-Json | Set-Content "$OutputDirectory\process-summary.json" -Encoding UTF8
    if ($nvidia) {
        & $nvidia.Source '--query-gpu=timestamp,index,name,driver_version,memory.total,memory.used,utilization.gpu' '--format=csv' |
            Set-Content "$OutputDirectory\gpu-after.csv" -Encoding UTF8
    }
    Write-Output "Native benchmark recorded: $OutputDirectory"
    if (@($report.scenarios | Where-Object { -not $_.completed }).Count) { throw 'A benchmark route did not complete; inspect benchmark.json.' }
} finally {
    if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
