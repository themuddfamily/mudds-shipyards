#!/usr/bin/env python3
"""Focused tests for the Linux export pipeline.

Covers export_linux_candidate.sh argument handling and --dry-run planning,
run_linux_startup_check.sh's pass/fail contract against stub binaries (exit 0
AND STARTUP_MENU_READY_OK, private HOME/XDG, Dummy audio), and the Linux preset
in export_presets.cfg. No test runs Godot or exports anything.
"""

import configparser
import json
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent.parent
EXPORT_SCRIPT = TOOLS_DIR / "export_linux_candidate.sh"
STARTUP_SCRIPT = TOOLS_DIR / "run_linux_startup_check.sh"
PRESETS = REPO_ROOT / "export_presets.cfg"


def _run(args, env=None, cwd=None):
    return subprocess.run(
        args, cwd=cwd or REPO_ROOT, env=env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60,
    )


def _head():
    return subprocess.check_output(
        ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"], text=True
    ).strip()


class ExportArguments(unittest.TestCase):
    def test_dry_run_plans_stamped_names_without_writing(self):
        builds = REPO_ROOT / "builds" / "linux"
        before = sorted(builds.iterdir()) if builds.exists() else None
        result = _run([str(EXPORT_SCRIPT), "--dry-run"])
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        head = _head()
        short = head[:7]
        self.assertTrue(plan["dry_run"])
        self.assertEqual(plan["source_commit"], head)
        self.assertEqual(plan["preset"], "Linux")
        self.assertEqual(plan["binary"], f"{builds}/MuddsShipyards-{short}.x86_64")
        self.assertEqual(plan["tarball"], f"{builds}/MuddsShipyards-{short}-linux-x86_64.tar.gz")
        self.assertEqual(
            plan["result"], f"{builds}/MuddsShipyards-{short}.x86_64.export-result.json"
        )
        self.assertEqual(plan["tarball_root"], f"MuddsShipyards-{short}")
        self.assertTrue(plan["export_templates"].endswith("/4.7.1.stable"))
        after = sorted(builds.iterdir()) if builds.exists() else None
        self.assertEqual(before, after, "dry run must not write into builds/linux")

    def test_dry_run_accepts_explicit_basename(self):
        result = _run([str(EXPORT_SCRIPT), "--dry-run", "MuddsShipyards-custom.x86_64"])
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertTrue(plan["binary"].endswith("/builds/linux/MuddsShipyards-custom.x86_64"))
        self.assertTrue(plan["tarball"].endswith("/MuddsShipyards-custom-linux-x86_64.tar.gz"))

    def test_templates_directory_is_overridable(self):
        env = dict(os.environ, GODOT_EXPORT_TEMPLATES_DIR="/opt/templates")
        result = _run([str(EXPORT_SCRIPT), "--dry-run"], env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["export_templates"], "/opt/templates/4.7.1.stable")

    def test_rejects_bad_output_names(self):
        for bad in ("MuddsShipyards.exe", "sub/MuddsShipyards.x86_64", ".x86_64",
                    "..", "Mudds Shipyards.x86_64", "MuddsShipyards"):
            with self.subTest(bad=bad):
                result = _run([str(EXPORT_SCRIPT), "--dry-run", bad])
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn("export-linux-candidate: ERROR", result.stderr)

    def test_rejects_extra_and_unknown_arguments(self):
        extra = _run([str(EXPORT_SCRIPT), "--dry-run", "a.x86_64", "b.x86_64"])
        self.assertEqual(extra.returncode, 2)
        unknown = _run([str(EXPORT_SCRIPT), "--force"])
        self.assertEqual(unknown.returncode, 2)
        self.assertIn("unknown option", unknown.stderr)

    def test_rejects_invalid_timeout(self):
        env = dict(os.environ, EXPORT_TIMEOUT_SECONDS="0")
        result = _run([str(EXPORT_SCRIPT), "--dry-run"], env=env)
        self.assertEqual(result.returncode, 1)

    def test_export_runs_godot_silently_in_a_private_profile(self):
        text = EXPORT_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("--audio-driver Dummy", text)
        self.assertIn("--headless", text)
        self.assertIn('--export-release "$PRESET_NAME"', text)
        for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"):
            self.assertIn(f'{variable}="$profile/', text)
        self.assertIn("env -u DISPLAY -u WAYLAND_DISPLAY", text)
        self.assertIn("worktree must be clean", text)
        self.assertIn("refusing to overwrite existing output", text)


class LinuxPreset(unittest.TestCase):
    def setUp(self):
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        parser.read(PRESETS, encoding="utf-8")
        self.parser = parser
        self.linux = next(
            name for name in parser.sections()
            if parser.get(name, "name", fallback="") == '"Linux"'
        )

    def test_linux_preset_mirrors_windows_filters_and_embeds_the_pack(self):
        windows = self.parser["preset.0"]
        linux = self.parser[self.linux]
        self.assertEqual(linux["platform"], '"Linux"')
        for key in ("export_filter", "include_filter", "exclude_filter", "script_export_mode"):
            self.assertEqual(linux[key], windows[key], key)
        self.assertEqual(linux["export_path"], '"builds/linux/MuddsShipyards.x86_64"')
        options = self.parser[self.linux + ".options"]
        self.assertEqual(options["binary_format/embed_pck"], "true")
        self.assertEqual(options["binary_format/architecture"], '"x86_64"')
        self.assertEqual(options["texture_format/s3tc_bptc"], "true")

    def test_windows_preset_stays_first(self):
        self.assertEqual(self.parser["preset.0"]["name"], '"Windows Desktop"')


class StartupCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _stub(self, name, body):
        path = self.dir / name
        path.write_text("#!/bin/sh\n" + body, encoding="utf-8")
        path.chmod(0o755)
        return path

    def _check(self, target, *flags):
        env = dict(os.environ, TMPDIR=str(self.dir))
        return _run([str(STARTUP_SCRIPT), *flags, str(target)], env=env, cwd=self.dir)

    def test_dry_run_reports_exact_arguments(self):
        stub = self._stub("MuddsShipyards-abcdef0.x86_64", "exit 0\n")
        result = self._check(stub, "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["arguments"], ["--headless", "--audio-driver", "Dummy", "--startup-check"])
        self.assertEqual(plan["required_sentinel"], "STARTUP_MENU_READY_OK")
        self.assertFalse((self.dir / (stub.name + ".startup-check.json")).exists())

    def test_passes_only_with_exit_zero_and_sentinel_in_private_profile(self):
        stub = self._stub(
            "MuddsShipyards-abcdef0.x86_64",
            'echo "ARGS $*"\necho "HOME $HOME"\necho "DATA $XDG_DATA_HOME"\n'
            'echo "DISPLAY ${DISPLAY:-unset}"\necho "STARTUP_MENU_READY_OK: {}"\nexit 0\n',
        )
        result = self._check(stub)
        self.assertEqual(result.returncode, 0, result.stderr)
        record = json.loads((self.dir / (stub.name + ".startup-check.json")).read_text())
        self.assertEqual(record["status"], "PASS")
        self.assertEqual(record["native_gpu"], "NOT_RUN")
        log = (self.dir / (stub.name + ".startup-check.log")).read_text()
        self.assertIn("ARGS --headless --audio-driver Dummy --startup-check", log)
        self.assertIn("DISPLAY unset", log)
        home = next(line for line in log.splitlines() if line.startswith("HOME "))
        self.assertNotEqual(home.split(" ", 1)[1], os.environ.get("HOME"))
        self.assertIn("mudds-linux-startup-check.", home)

    def test_fails_without_sentinel(self):
        stub = self._stub("MuddsShipyards-abcdef0.x86_64", "echo booted\nexit 0\n")
        result = self._check(stub)
        self.assertEqual(result.returncode, 1)
        record = json.loads((self.dir / (stub.name + ".startup-check.json")).read_text())
        self.assertEqual(record["status"], "FAIL")
        self.assertIn("missing STARTUP_MENU_READY_OK", record["reasons"])

    def test_fails_on_nonzero_exit_even_with_sentinel(self):
        stub = self._stub("MuddsShipyards-abcdef0.x86_64", 'echo "STARTUP_MENU_READY_OK: {}"\nexit 3\n')
        self.assertEqual(self._check(stub).returncode, 1)

    def test_refuses_to_overwrite_an_earlier_result(self):
        stub = self._stub("MuddsShipyards-abcdef0.x86_64", 'echo "STARTUP_MENU_READY_OK"\n')
        self.assertEqual(self._check(stub).returncode, 0)
        self.assertEqual(self._check(stub).returncode, 1)

    def test_checks_the_binary_inside_a_package(self):
        package = self.dir / "MuddsShipyards-abcdef0"
        package.mkdir()
        binary = package / "MuddsShipyards-abcdef0.x86_64"
        binary.write_text('#!/bin/sh\necho "STARTUP_MENU_READY_OK: {}"\n', encoding="utf-8")
        binary.chmod(0o755)
        for member in ("mudds-shipyards.desktop", "mudds-shipyards.png", "install-desktop-entry.sh"):
            (package / member).write_text("x", encoding="utf-8")
        tarball = self.dir / "MuddsShipyards-abcdef0-linux-x86_64.tar.gz"
        with tarfile.open(tarball, "w:gz") as archive:
            archive.add(package, arcname=package.name)
        result = self._check(tarball)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_wrong_input_types(self):
        other = self.dir / "MuddsShipyards.exe"
        other.write_text("x", encoding="utf-8")
        self.assertEqual(self._check(other).returncode, 2)
        self.assertEqual(self._check(self.dir / "missing.x86_64").returncode, 2)


if __name__ == "__main__":
    unittest.main()
