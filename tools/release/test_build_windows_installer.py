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


class BuildScript(unittest.TestCase):
    def _run(self, *args, env=None):
        merged = dict(os.environ)
        if env:
            merged.update(env)
        return subprocess.run(
            [str(BUILD_SCRIPT), *args], capture_output=True, text=True, env=merged
        )

    def test_rejects_unexported_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "game.exe"
            bad.write_bytes(b"x")
            proc = self._run(str(bad))
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
            proc = self._run(str(bad))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("is not a commit", proc.stderr)

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
