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
        self.assertIn("$proc.ExitCode -ne 0 -or -not $sentinel", text)
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
