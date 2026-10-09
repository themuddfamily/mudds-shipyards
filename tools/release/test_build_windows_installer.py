#!/usr/bin/env python3
"""Focused tests for build_windows_installer.sh and the NSIS script it compiles.

The compile test runs only when makensis is installed; it builds a real
installer from a stub executable and checks the recorded provenance. The
script-content tests always run and pin the contract that matters to players:
per-user install, silent flags honoured, and an uninstaller that never reaches
into %APPDATA% user data.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent.parent
BUILD_SCRIPT = TOOLS_DIR / "build_windows_installer.sh"
NSI = TOOLS_DIR / "installer" / "mudds_shipyards.nsi"
VERIFY_PS1 = TOOLS_DIR / "verify_windows_installer.ps1"
HAVE_MAKENSIS = shutil.which("makensis") is not None


def _head_commit():
    return subprocess.check_output(
        ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"], text=True
    ).strip()


class NsisScriptContract(unittest.TestCase):
    def setUp(self):
        self.text = NSI.read_text(encoding="utf-8")

    def test_installs_per_user_without_elevation(self):
        self.assertIn("RequestExecutionLevel user", self.text)
        self.assertIn('InstallDir "$LOCALAPPDATA\\Programs\\', self.text)
        self.assertNotIn("HKLM", self.text)

    def test_uninstaller_only_removes_what_it_wrote(self):
        uninstall = "\n".join(
            line for line in self.text.split('Section "Uninstall"', 1)[1].splitlines()
            if not line.strip().startswith(";")
        )
        self.assertNotIn("RMDir /r", uninstall)
        self.assertNotIn("APPDATA", uninstall)
        self.assertNotIn("app_userdata", uninstall)
        for required in (
            'Delete "$INSTDIR\\${PRODUCT_EXE}"',
            'Delete "$INSTDIR\\${UNINSTALL_EXE}"',
            'DeleteRegKey HKCU "${REG_UNINSTALL_KEY}"',
            'DeleteRegKey HKCU "${REG_APP_KEY}"',
        ):
            self.assertIn(required, uninstall)

    def test_registry_entry_supports_quiet_uninstall_and_provenance(self):
        self.assertIn('"QuietUninstallString" \'"$INSTDIR\\${UNINSTALL_EXE}" /S\'', self.text)
        self.assertIn('"SourceCommit" "${FULL_COMMIT}"', self.text)
        self.assertIn('"UpgradedFrom"', self.text)
        self.assertIn("signing=unsigned", self.text)

    def test_replacement_is_staged_atomic_and_fatal_before_metadata(self):
        install = self.text.split('Section "Install" SEC_MAIN', 1)[1].split('Section "Uninstall"', 1)[0]
        self.assertIn('File "/oname=${PENDING_EXE}" "${SOURCE_EXE}"', install)
        self.assertIn("SetOverwrite try\n  ClearErrors", install)
        self.assertLess(install.index('IfFileExists "$INSTDIR\\${PENDING_EXE}"'), install.index("StrCpy $OwnsPending 1"))
        failed = self.text.split("Function .onInstFailed", 1)[1].split("FunctionEnd", 1)[0]
        self.assertIn("${If} $OwnsPending == 1", failed)
        self.assertIn("IfErrors 0 payload_staged", install)
        self.assertIn("kernel32::MoveFileExW", install)
        self.assertIn("i 9) i .r0 ?e", install)
        self.assertIn("IntCmp $2 40", install)
        self.assertIn("SetErrorLevel 2", install)
        self.assertLess(install.index("payload_replaced:"), install.index('FileOpen $0'))
        self.assertIn('Delete "$INSTDIR\\${PENDING_EXE}"', self.text)

    def test_every_define_is_required(self):
        for define in ("SOURCE_EXE", "SHORT_COMMIT", "FULL_COMMIT", "PRODUCT_VERSION", "OUTPUT_FILE"):
            self.assertRegex(self.text, rf"!ifndef {define}\n\s+!error")


class VerifierContract(unittest.TestCase):
    def test_verifier_covers_install_startup_upgrade_and_uninstall(self):
        text = VERIFY_PS1.read_text(encoding="utf-8")
        for step in (
            "'silent_install'",
            "'installed_files'",
            "'registry_and_shortcuts'",
            "'installed_startup_check'",
            "'silent_upgrade_over_existing'",
            "'silent_uninstall'",
        ):
            self.assertIn(f"Step {step}", text)
        self.assertIn("STARTUP_MENU_READY_OK", text)
        self.assertIn("--headless --audio-driver Dummy --startup-check", text)
        self.assertIn("user_data_preserved=True", text)
        # The verifier never installs into the real per-user Programs folder.
        self.assertIn("$installDir = Join-Path $ProbeRoot 'install'", text)

    def test_cross_build_mode_verifies_each_transition_and_startup(self):
        text = VERIFY_PS1.read_text(encoding="utf-8")
        for option in ("PreviousInstaller", "PreviousExpectedExeSha256", "PreviousExpectedCommit"):
            self.assertIn(f"[string]${option}", text)
        self.assertIn("must be supplied together", text)
        self.assertIn("distinct commits and executable hashes", text)
        self.assertIn("Assert-Installed $ExpectedExeSha256 $ExpectedCommit", text)
        self.assertIn("Assert-RegistryAndShortcuts $ExpectedCommit $initialCommit", text)
        self.assertIn("Assert-Installed $PreviousExpectedExeSha256 $PreviousExpectedCommit", text)
        self.assertIn("Assert-RegistryAndShortcuts $PreviousExpectedCommit $ExpectedCommit", text)
        for stage in ("installed", "upgraded", "rolled-back"):
            self.assertIn(f"Run-Startup '{stage}'", text)
        self.assertIn("$exitCode -ne 0 -or -not $sentinel", text)
        self.assertIn("startup log already exists", text)
        self.assertIn(".Hash -ne $markerHash", text)
        self.assertIn("if ($crossBuild) {\n    Step 'locked_upgrade_preserves_previous'", text)
        locked = text.split("Step 'locked_upgrade_preserves_previous'", 1)[1].split("Step 'silent_upgrade_over_existing'", 1)[0]
        self.assertIn("[IO.FileShare]::None", locked)
        self.assertIn('try { $code = Run-Silent $Installer "/S /D=$installDir" 120000 }', locked)
        self.assertIn("finally { $lock.Dispose() }", locked)
        self.assertIn("$code -ne 2", locked)
        self.assertIn("Assert-Installed $initialHash $initialCommit", locked)
        self.assertIn("locked upgrade changed provenance bytes", locked)
        self.assertIn("locked upgrade changed registry metadata", locked)
        self.assertIn("failed upgrade left pending payload", locked)

    def test_native_log_and_document_acceptance_rejects_real_regressions(self):
        powershell = shutil.which("powershell.exe") or shutil.which("pwsh")
        if not powershell:
            bridge = Path("/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
            powershell = str(bridge) if bridge.is_file() else None
        if not powershell:
            self.skipTest("PowerShell is required for executable acceptance checks")
        text = VERIFY_PS1.read_text(encoding="utf-8")
        functions = []
        for name, following in (("Run-Silent", "Assert-UserData"),
                                ("Assert-UserData", "Assert-Installed"),
                                ("Assert-StartupLog", "Assert-NewerDocumentDiagnostics"),
                                ("Seed-ForcedKillFixture", "Read-RecoveryDocument"),
                                ("Read-RecoveryDocument", "Assert-RecoveryPayload"),
                                ("Assert-RecoveryPayload", "Wait-OwnedRecoveryMarker"),
                                ("Wait-OwnedRecoveryMarker", "Run-ForcedKillBoot"),
                                ("Run-ForcedKillBoot", "Assert-StartupLog"),
                                ("Assert-InWorldContext", "Start-InWorldOwned")):
            functions.append("function " + name + text.split("function " + name, 1)[1].split("function " + following, 1)[0])
        # Execute the production assertion functions against actual files. A
        # documented application warning is allowed; duplicate/missing menu
        # readiness, nonzero exits, engine faults and changed/lost saves fail.
        script = "$ErrorActionPreference = 'Stop'\n" + "\n".join(functions) + r"""
$root = Join-Path ([IO.Path]::GetTempPath()) ('mudds-verifier-regression-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    # A legacy pilot-only payload must never qualify a requested cabin/rest/crew run.
    foreach ($selected in @('pilot', 'cabin', 'rest', 'crew')) {
        $InWorldRecoveryContext = $selected
        Assert-InWorldContext ([pscustomobject]@{recovery_context=$selected})
        foreach ($reported in @('pilot', 'cabin', 'rest', 'crew', '', 'PILOT', 'CABIN', 'REST', 'CREW')) {
            if ($reported -ceq $selected) { continue }
            $rejected = $false
            try { Assert-InWorldContext ([pscustomobject]@{recovery_context=$reported}) } catch { $rejected = $true }
            if (-not $rejected) { throw "wrong recovery context accepted: $selected/$reported" }
        }
        $rejected = $false
        try { Assert-InWorldContext ([pscustomobject]@{}) } catch { $rejected = $true }
        if ($rejected -ne ($selected -ne 'pilot')) { throw "legacy marker acceptance differs: $selected" }
    }
    $log = Join-Path $root 'startup.log'
    [IO.File]::WriteAllText($log, "WARNING: Atomic runtime settings load retained authored defaults: store_load_failed / newer_schema`nSTARTUP_MENU_READY_OK: {}`n")
    Assert-StartupLog $log 0 | Out-Null
    foreach ($case in @(@('', 0), @("STARTUP_MENU_READY_OK: {}`nSTARTUP_MENU_READY_OK: {}", 0), @('STARTUP_MENU_READY_OK: {}', 1), @("SCRIPT ERROR: broken`nSTARTUP_MENU_READY_OK: {}", 0), @("ERROR: broken`nSTARTUP_MENU_READY_OK: {}", 0), @("WARNING: ObjectDB instances leaked at exit`nSTARTUP_MENU_READY_OK: {}", 0))) {
        [IO.File]::WriteAllText($log, $case[0])
        $rejected = $false
        try { Assert-StartupLog $log $case[1] | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw "invalid startup accepted: $($case[0])" }
    }
    $marker = Join-Path $root 'marker'
    $document = Join-Path $root 'mudds_user_data.json'
    [IO.File]::WriteAllText($marker, 'unchanged marker')
    [IO.File]::WriteAllText($document, 'saved settings and gameplay')
    $markerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $marker).Hash
    $documentHashes = @{}
    $documentHashes[$document] = (Get-FileHash -Algorithm SHA256 -LiteralPath $document).Hash
    Assert-UserData
    [IO.File]::WriteAllText($document, 'silently reset by startup')
    $rejected = $false
    try { Assert-UserData } catch { $rejected = $true }
    if (-not $rejected) { throw 'changed save accepted with unchanged marker' }
    Remove-Item -LiteralPath $document
    $rejected = $false
    try { Assert-UserData } catch { $rejected = $true }
    if (-not $rejected) { throw 'missing save accepted with unchanged marker' }
    $profileRoot = Join-Path $root 'profile'
    $childReport = Join-Path $root 'child-environment.txt'
    $childSource = "[IO.File]::WriteAllText('$childReport', (`$env:APPDATA + '|' + `$env:LOCALAPPDATA + '|' + `$env:USERPROFILE))"
    $childEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childSource))
    $childExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $checkRecovery = $false
    $code = Run-Silent $childExe "-NoProfile -EncodedCommand $childEncoded" 10000
    $inherited = $env:APPDATA + '|' + $env:LOCALAPPDATA + '|' + $env:USERPROFILE
    if ($code -ne 0 -or [IO.File]::ReadAllText($childReport) -ne $inherited) { throw 'default installer environment changed' }
    $checkRecovery = $true
    $code = Run-Silent $childExe "-NoProfile -EncodedCommand $childEncoded" 10000
    $private = (Join-Path $profileRoot 'AppData\Roaming') + '|' + (Join-Path $profileRoot 'AppData\Local') + '|' + $profileRoot
    if ($code -ne 0 -or [IO.File]::ReadAllText($childReport) -ne $private) { throw 'recovery installer environment escaped private profile' }

    # Exercise the existing verifier's OS-kill/abort machinery using an owned
    # real child that commits a document then stays alive. This verifies the
    # harness only; installed-game qualification uses the production executable.
    $ProbeRoot = Join-Path $root 'forced-probe'
    New-Item -ItemType Directory -Path $ProbeRoot | Out-Null
    $document = Join-Path $ProbeRoot 'mudds_user_data.json'
    $UserDataRecoveryFixture = Join-Path $root 'fixture.json'
    $fixture = @{ schema_version = 1; generation = 2; payload = @{ runtime_settings = @{ values = @{ graphics_profile = 'low'; window_mode = 'windowed' } }; tutorial_prompts_seen = @{ seen_ids = @('retained-prompt') } } }
    [IO.File]::WriteAllText($UserDataRecoveryFixture, ($fixture | ConvertTo-Json -Depth 12))
    [IO.File]::WriteAllText($document, 'prior generation 90')
    foreach ($suffix in @('.bak', '.bak.1', '.bak.2', '.bak.3', '.tmp')) {
        [IO.File]::WriteAllText(($document + $suffix), ('prior transaction ' + $suffix))
    }
    [IO.File]::WriteAllText(($document + '.unrelated'), 'retain unrelated user file')
    Seed-ForcedKillFixture
    if ([IO.File]::ReadAllText($document) -ne [IO.File]::ReadAllText($UserDataRecoveryFixture)) { throw 'forced-kill fixture seed changed production document' }
    foreach ($suffix in @('.bak', '.bak.1', '.bak.2', '.bak.3', '.tmp')) {
        if (Test-Path -LiteralPath ($document + $suffix)) { throw 'forced-kill fixture retained incoherent prior transaction sibling' }
        $prior = Join-Path (Join-Path $ProbeRoot 'forced-kill-prior-documents') ('mudds_user_data.json' + $suffix)
        if ([IO.File]::ReadAllText($prior) -ne ('prior transaction ' + $suffix)) { throw 'forced-kill fixture removed prior transaction without witness' }
    }
    if ([IO.File]::ReadAllText(($document + '.unrelated')) -ne 'retain unrelated user file') { throw 'forced-kill fixture seeding changed unrelated file' }
    $interrupted = $fixture | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $interrupted.generation = 3
    $interrupted.payload | Add-Member -NotePropertyName safe_start_recovery -NotePropertyValue @{ state = 'starting'; startup_generation = 1; consecutive_failure_count = 0; safe_settings_recommended = $false }
    $interrupted.payload | Add-Member -NotePropertyName crash_recovery -NotePropertyValue @{ state = 'running'; startup_generation = 1; unclean_start_count = 0 }
    $encodedDocument = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($interrupted | ConvertTo-Json -Depth 12)))
    $childPidPath = Join-Path $ProbeRoot 'child-pid.txt'
    $childLogPath = Join-Path $ProbeRoot 'forced-kill-1-startup.log'
    $childSource = "[IO.File]::WriteAllText('$childPidPath', [string]`$PID); [IO.File]::WriteAllText('$document', [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedDocument'))); [IO.File]::WriteAllText('$childLogPath', 'STARTUP begin'); Start-Sleep -Seconds 60"
    $script:childEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childSource))
    function New-OwnedBootInfo([string]$log, [bool]$startupCheck) {
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $childExe
        $info.Arguments = "-NoProfile -NonInteractive -EncodedCommand $script:childEncoded"
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        return $info
    }
    $StartupTimeoutMs = 10000
    $receipt = Run-ForcedKillBoot 1 $false
    if ($receipt -notmatch 'os_kill_exit=.+interrupted_markers_retained=True') { throw 'owned OS kill receipt missing' }
    $childPid = [int](Get-Content -LiteralPath $childPidPath -Raw)
    if (Get-Process -Id $childPid -ErrorAction SilentlyContinue) { throw 'OS-killed owned child still running' }
    $interrupted.payload.tutorial_prompts_seen.seen_ids = @('reset-prompt')
    $rejected = $false
    try { Assert-RecoveryPayload $interrupted $false } catch { $rejected = $true }
    if (-not $rejected) { throw 'forced-kill lost tutorial progress accepted' }
    # Stale markers must time out, and finally must terminate only this child.
    $StartupTimeoutMs = 500
    $rejected = $false
    try { Run-ForcedKillBoot 2 $false | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'stale interrupted marker accepted as a fresh boot' }
    $childPid = [int](Get-Content -LiteralPath $childPidPath -Raw)
    if (Get-Process -Id $childPid -ErrorAction SilentlyContinue) { throw 'timeout left owned child running' }
    Write-Output 'NATIVE_ACCEPTANCE_REGRESSION_OK'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
"""
        # The executable acceptance now exceeds Windows' command-line limit;
        # pass a real script file, translating its path only for the WSL bridge.
        with tempfile.TemporaryDirectory(prefix="mudds-verifier-regression-") as tmp:
            script_path = Path(tmp) / "acceptance.ps1"
            script_path.write_text(script, encoding="utf-8")
            launch_path = str(script_path)
            if powershell.startswith("/mnt/"):
                launch_path = subprocess.check_output(
                    ["wslpath", "-w", launch_path], text=True
                ).strip()
            proc = subprocess.run(
                [powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", launch_path],
                capture_output=True, text=True, timeout=30
            )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("NATIVE_ACCEPTANCE_REGRESSION_OK", proc.stdout)

    def test_failure_cleanup_is_guarded_and_preserves_original_diagnostic(self):
        text = VERIFY_PS1.read_text(encoding="utf-8")
        self.assertIn("default user installation already exists", text)
        self.assertIn("probe profile already exists", text)
        self.assertLess(text.index("Step 'preconditions'"), text.index("$script:ownsInstall = $true"))
        self.assertIn("if ($script:ownsInstall)", text)
        cleanup = text.split("function Cleanup-OwnedInstallation {", 1)[1].split("Step 'preconditions'", 1)[0]
        self.assertIn("InstallLocation -ne $installDir", cleanup)
        self.assertIn("no longer belongs to this probe", cleanup)
        self.assertNotIn("Remove-Item -LiteralPath $profileRoot", cleanup)
        self.assertNotIn("Remove-Item -LiteralPath $installDir -Recurse", cleanup)
        self.assertNotIn("Remove-Item -LiteralPath $startMenu -Recurse", cleanup)
        failure = text.split("function Step(", 1)[1].split("function Wait-Gone", 1)[0]
        self.assertLess(failure.index("$entry.detail = $_.Exception.Message"), failure.index("Cleanup-OwnedInstallation"))
        self.assertIn("$result.cleanup.detail = $_.Exception.Message", failure)


class BuildScript(unittest.TestCase):
    def _run(self, *args, env=None):
        merged = dict(os.environ)
        if env:
            merged.update(env)
        return subprocess.run(
            [str(BUILD_SCRIPT), *args], capture_output=True, text=True, env=merged
        )

    def _run_without_compiler(self, *args):
        # Keep real input/provenance commands available while excluding NSIS,
        # even on developer machines where makensis is installed.
        with tempfile.TemporaryDirectory() as bin_dir:
            for command in ("bash", "git", "dirname", "basename", "sed", "head"):
                executable = shutil.which(command)
                self.assertIsNotNone(executable, f"test requires {command}")
                (Path(bin_dir) / command).symlink_to(executable)
            return self._run(*args, env={"PATH": bin_dir})

    def test_rejects_unexported_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "game.exe"
            bad.write_bytes(b"x")
            proc = self._run_without_compiler(str(bad))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("must be named MuddsShipyards-<7 hex>.exe", proc.stderr)

    def test_rejects_bare_setup_name_that_windows_shims(self):
        full = _head_commit()
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / f"MuddsShipyards-{full[:7]}.exe"
            source.write_bytes(b"x")
            proc = self._run(str(source), str(Path(tmp) / "setup.exe"))
        if not HAVE_MAKENSIS:
            self.skipTest("makensis not installed")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Insecure filename", proc.stderr)

    def test_rejects_unknown_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "MuddsShipyards-fffffff.exe"
            bad.write_bytes(b"x")
            proc = self._run_without_compiler(str(bad))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("is not a commit", proc.stderr)

    def test_valid_input_reports_missing_compiler_without_writing_artifacts(self):
        full = _head_commit()
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / f"MuddsShipyards-{full[:7]}.exe"
            source.write_bytes(b"payload")
            output = Path(tmp) / f"MuddsShipyards-{full[:7]}-setup.exe"
            proc = self._run_without_compiler(str(source), str(output))
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("makensis (NSIS 3) is not installed", proc.stderr)
            self.assertEqual(source.read_bytes(), b"payload")
            self.assertEqual(list(Path(tmp).iterdir()), [source])

    @unittest.skipUnless(HAVE_MAKENSIS, "makensis not installed")
    def test_compiles_installer_and_records_provenance(self):
        full = _head_commit()
        short = full[:7]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / f"MuddsShipyards-{short}.exe"
            payload = os.urandom(65536)
            source.write_bytes(payload)
            # A bare "setup.exe" trips makensis' insecure-filename warning
            # (Windows loads compatibility shims for it), which -WX rejects.
            output = Path(tmp) / f"MuddsShipyards-{short}-setup.exe"
            proc = self._run(str(source), str(output))
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(output.is_file())
            self.assertGreater(output.stat().st_size, 65536)
            record = json.loads((Path(tmp) / f"MuddsShipyards-{short}-setup.exe.installer-result.json").read_text())
            self.assertEqual(record["schema_version"], 1)
            self.assertEqual(record["source_commit"], full)
            self.assertEqual(record["source_exe_sha256"], hashlib.sha256(payload).hexdigest())
            self.assertEqual(record["installer_sha256"], hashlib.sha256(output.read_bytes()).hexdigest())
            self.assertEqual(record["installer_bytes"], output.stat().st_size)
            self.assertEqual(record["signing"], "unsigned")
            self.assertEqual(record["native_verification"], "NOT_RUN")
            self.assertRegex(record["build_label"], rf"^\d+\.\d+\.\d+\+{short}$")
            digest_line = (Path(tmp) / f"MuddsShipyards-{short}-setup.exe.sha256").read_text().split()
            self.assertEqual(digest_line, [record["installer_sha256"], output.name])
            # A Windows PE with the NSIS uninstaller resource embedded.
            head = output.read_bytes()[:2]
            self.assertEqual(head, b"MZ")
            self.assertTrue(re.search(rb"Nullsoft", output.read_bytes()[:400000]))


if __name__ == "__main__":
    unittest.main()
