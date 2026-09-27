#!/usr/bin/env python3
"""Focused tests for sign_windows_artifacts.sh argument handling and dry run.

These never sign anything and never need a certificate: they pin the refusal
paths (missing PFX, non-PE input, bad timestamp URL, dev mode with a PFX set,
dev directory inside the repository) and the dry-run plan, including the
UNTRUSTED labelling of dev mode. The installer integration is checked by
contract against build_windows_installer.sh and the NSIS script.
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent.parent
SIGN_SCRIPT = TOOLS_DIR / "sign_windows_artifacts.sh"
BUILD_SCRIPT = TOOLS_DIR / "build_windows_installer.sh"
NSI = TOOLS_DIR / "installer" / "mudds_shipyards.nsi"


class SignScriptArguments(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.exe = self.tmp / "MuddsShipyards-abc1234.exe"
        self.exe.write_bytes(b"MZ" + os.urandom(64))

    def tearDown(self):
        self._tmp.cleanup()

    def _run(self, *args, env=None, drop=()):
        merged = {
            key: value for key, value in os.environ.items()
            if not key.startswith("MUDDS_SIGNING") and key not in drop
        }
        merged["MUDDS_DEV_SIGNING_DIR"] = str(self.tmp / "dev-signing")
        if env:
            merged.update(env)
        return subprocess.run(
            [str(SIGN_SCRIPT), *args], capture_output=True, text=True, env=merged
        )

    def test_requires_an_artifact(self):
        proc = self._run()
        self.assertEqual(proc.returncode, 2)
        self.assertIn("usage:", proc.stderr)

    def test_rejects_unknown_option(self):
        proc = self._run("--sign-everything", str(self.exe))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("unknown option", proc.stderr)

    def test_rejects_missing_and_non_pe_artifacts(self):
        proc = self._run("--dry-run", "--dev-self-signed", str(self.tmp / "absent.exe"))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("artifact not found", proc.stderr)
        text_file = self.tmp / "notes.exe"
        text_file.write_text("hello")
        proc = self._run("--dry-run", "--dev-self-signed", str(text_file))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("no MZ header", proc.stderr)
        other = self.tmp / "payload.dll"
        other.write_bytes(b"MZ")
        proc = self._run("--dry-run", "--dev-self-signed", str(other))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("must be a Windows .exe", proc.stderr)

    def test_pfx_mode_requires_pfx_and_password(self):
        proc = self._run("--dry-run", str(self.exe))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("MUDDS_SIGNING_PFX is not set", proc.stderr)
        pfx = self.tmp / "cert.pfx"
        pfx.write_bytes(b"not really a pfx")
        proc = self._run("--dry-run", str(self.exe), env={"MUDDS_SIGNING_PFX": str(pfx)})
        self.assertEqual(proc.returncode, 2)
        self.assertIn("MUDDS_SIGNING_PASSWORD is not set", proc.stderr)
        proc = self._run(
            "--dry-run", str(self.exe),
            env={"MUDDS_SIGNING_PFX": str(self.tmp / "missing.pfx"), "MUDDS_SIGNING_PASSWORD": "x"},
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("not a readable file", proc.stderr)

    def test_pfx_dry_run_plans_without_touching_the_artifact(self):
        pfx = self.tmp / "cert.pfx"
        pfx.write_bytes(b"pfx")
        before = self.exe.read_bytes()
        proc = self._run(
            "--dry-run", "--timestamp-url", "http://timestamp.example.test/rfc3161", str(self.exe),
            env={"MUDDS_SIGNING_PFX": str(pfx), "MUDDS_SIGNING_PASSWORD": "s3cret"},
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("DRY RUN", proc.stdout)
        self.assertIn("mode=pfx", proc.stdout)
        self.assertIn("trust=PFX_SUPPLIED_WINDOWS_TRUST_NOT_RUN", proc.stdout)
        self.assertIn("timestamp_url=http://timestamp.example.test/rfc3161", proc.stdout)
        self.assertIn(f"would_sign={self.exe}", proc.stdout)
        self.assertNotIn("s3cret", proc.stdout + proc.stderr)
        self.assertEqual(self.exe.read_bytes(), before)
        self.assertFalse(Path(f"{self.exe}.signing-result.json").exists())

    def test_rejects_non_http_timestamp_url(self):
        proc = self._run("--dry-run", "--dev-self-signed", "--timestamp-url", "file:///etc/passwd", str(self.exe))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("timestamp URL must be an http(s) URL", proc.stderr)

    def test_dev_mode_is_labelled_untrusted_and_writes_nothing_in_dry_run(self):
        proc = self._run("--dry-run", "--dev-self-signed", str(self.exe))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("mode=dev-self-signed", proc.stdout)
        self.assertIn("trust=UNTRUSTED_DEV_SELF_SIGNED", proc.stdout)
        self.assertFalse((self.tmp / "dev-signing").exists())

    def test_dev_mode_refuses_while_a_real_pfx_is_configured(self):
        proc = self._run(
            "--dry-run", "--dev-self-signed", str(self.exe),
            env={"MUDDS_SIGNING_PFX": "/somewhere/real.pfx"},
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("refuses to run while MUDDS_SIGNING_PFX is set", proc.stderr)

    def test_dev_directory_must_be_outside_the_repository(self):
        proc = self._run(
            "--dry-run", "--dev-self-signed", str(self.exe),
            env={"MUDDS_DEV_SIGNING_DIR": str(REPO_ROOT / "dev-signing")},
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("outside the repository", proc.stderr)

    def test_mode_flags_conflict(self):
        proc = self._run("--verify-only", "--sign-in-place", str(self.exe))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("mutually exclusive", proc.stderr)
        proc = self._run("--sign-in-place", "--result", str(self.tmp / "r.json"), "--dev-self-signed", str(self.exe))
        self.assertEqual(proc.returncode, 2)
        self.assertIn("writes no result", proc.stderr)

    def test_verify_only_dry_run_needs_no_certificate(self):
        proc = self._run("--dry-run", "--verify-only", "--result", str(self.tmp / "v.json"), str(self.exe))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("mode=verify-only", proc.stdout)
        self.assertIn(f"would_verify={self.exe}", proc.stdout)
        self.assertIn(f"result={self.tmp / 'v.json'}", proc.stdout)


class InstallerIntegrationContract(unittest.TestCase):
    def test_build_script_signs_payload_uninstaller_and_installer_only_when_asked(self):
        text = BUILD_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('sign_mode="${MUDDS_INSTALLER_SIGN:-}"', text)
        self.assertIn('--sign-in-place "$source_exe"', text)
        self.assertIn("-DUNINSTALL_SIGN_COMMAND=", text)
        self.assertIn('--result "$signing_result" "$output"', text)
        self.assertIn('--verify-only --result "$source_signing_result" "$source_exe"', text)
        self.assertIn('signing_label="dev-self-signed-UNTRUSTED"', text)
        self.assertIn('record["trusted_signing_claimed"] = False', text)
        # Unsigned remains the default label.
        self.assertIn('signing_label="unsigned"', text)

    def test_nsis_signs_uninstaller_only_with_a_command(self):
        text = NSI.read_text(encoding="utf-8")
        self.assertIn("!ifdef UNINSTALL_SIGN_COMMAND", text)
        self.assertIn("!uninstfinalize '${UNINSTALL_SIGN_COMMAND} \"%1\"' = 0", text)
        self.assertIn("signing=unsigned", text)


if __name__ == "__main__":
    unittest.main()
