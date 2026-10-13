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
import time
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
        ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"], text=True,
        env=dict(os.environ, GIT_OPTIONAL_LOCKS="0")
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

    def _check(self, target, *flags, extra_env=None):
        env = dict(os.environ, TMPDIR=str(self.dir), **(extra_env or {}))
        return _run([str(STARTUP_SCRIPT), *flags, str(target)], env=env, cwd=self.dir)

    def test_dry_run_reports_exact_arguments(self):
        stub = self._stub("MuddsShipyards-abcdef0.x86_64", "exit 0\n")
        result = self._check(stub, "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["arguments"], ["--headless", "--audio-driver", "Dummy", "--startup-check"])
        self.assertEqual(plan["required_sentinel"], "STARTUP_MENU_READY_OK")
        self.assertFalse((self.dir / (stub.name + ".startup-check.json")).exists())

    def test_graphical_dry_run_reports_rendering_and_private_display(self):
        stub = self._stub("MuddsShipyards-abcdef0.x86_64", "exit 0\n")
        result = self._check(stub, "--dry-run", "--graphical")
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["arguments"], ["--display-driver", "x11", "--audio-driver", "Dummy",
                                              "--rendering-method", "gl_compatibility", "--startup-check"])
        self.assertEqual(plan["xvfb_arguments"], ["-a", "-s",
                                                "-screen 0 1280x720x24 -nolisten tcp -nolisten unix"])
        self.assertEqual(plan["timeout_seconds"], 300)
        self.assertEqual(plan["native_gpu"], "NOT_RUN")
        self.assertIn("env -i", plan["isolation"])
        self.assertFalse((self.dir / (stub.name + ".startup-check.json")).exists())

    def _fake_display(self):
        # This fake executes the actor supervisor/stub, never Xvfb or Godot.
        commands = self.dir / "commands"
        commands.mkdir()
        wrapper = commands / "xvfb-run"
        wrapper.write_text(
            '#!/bin/sh\n'
            'test "$1" = -a && test "$2" = -s || exit 9\n'
            'test "$3" = "-screen 0 1280x720x24 -nolisten tcp -nolisten unix" || exit 9\n'
            'shift 3\nexport DISPLAY=:19999\nexec "$@"\n', encoding="utf-8")
        wrapper.chmod(0o755)
        return {"PATH": str(commands) + os.pathsep + os.environ["PATH"],
                "DISPLAY": ":0", "WAYLAND_DISPLAY": "wayland-0", "WAYLAND_SOCKET": "10",
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=/user/bus", "PULSE_SERVER": "user-audio",
                "XAUTHORITY": "/user/authority", "SDL_AUDIODRIVER": "user-audio"}

    def test_graphical_executes_exact_actor_args_and_scrubs_user_environment(self):
        stub = self._stub(
            "MuddsShipyards-abcdef0.x86_64",
            'echo "ARGS $*"\necho "HOME $HOME"\necho "DISPLAY $DISPLAY"\n'
            'echo "WAYLAND ${WAYLAND_DISPLAY:-unset} ${WAYLAND_SOCKET:-unset}"\n'
            'echo "BUS ${DBUS_SESSION_BUS_ADDRESS:-unset}"\n'
            'echo "AUDIO ${PULSE_SERVER:-unset} ${SDL_AUDIODRIVER:-unset}"\n'
            'echo "AUTH ${XAUTHORITY:-unset}"\necho "SOFTWARE $LIBGL_ALWAYS_SOFTWARE"\n'
            'echo "STARTUP_MENU_READY_OK: {}"\n',
        )
        result = self._check(stub, "--graphical", extra_env=self._fake_display())
        self.assertEqual(result.returncode, 0, result.stderr)
        record = json.loads((self.dir / (stub.name + ".startup-check.json")).read_text())
        self.assertEqual(record["schema_version"], 1)
        self.assertEqual(record["status"], "PASS")
        self.assertIn("software GL compatibility", record["environment"])
        self.assertEqual(record["native_gpu"], "NOT_RUN")
        processes = record["graphical_processes"]
        self.assertEqual(processes["actor_exit"], 0)
        self.assertTrue(processes["reaped"])
        self.assertEqual({p["role"] for p in processes["owned"]}, {"actor", "xvfb-run"})
        self.assertTrue(all(p["absent"] and int(p["start"]) > 0 for p in processes["owned"]))
        log = (self.dir / (stub.name + ".startup-check.log")).read_text()
        self.assertIn("ARGS --display-driver x11 --audio-driver Dummy --rendering-method gl_compatibility --startup-check", log)
        self.assertNotIn("--headless", log)
        for expected in ("DISPLAY :19999", "WAYLAND unset unset", "BUS unset", "AUDIO unset unset",
                         "AUTH unset", "SOFTWARE 1", "mudds-linux-startup-check."):
            self.assertIn(expected, log)

    def test_graphical_rejects_engine_errors_and_inexact_ready_sentinel(self):
        environment = self._fake_display()
        for index, output in enumerate(("STARTUP_MENU_READY_OK_BOGUS", "STARTUP_MENU_READY_OK\nSCRIPT ERROR: invalid")):
            with self.subTest(output=output):
                stub = self._stub(f"MuddsShipyards-case{index}.x86_64", f"printf '%s\\n' '{output}'\n")
                result = self._check(stub, "--graphical", extra_env=environment)
                self.assertEqual(result.returncode, 1, result.stderr)
                record = json.loads((self.dir / (stub.name + ".startup-check.json")).read_text())
                self.assertEqual(record["status"], "FAIL")
                self.assertIn("missing STARTUP_MENU_READY_OK" if index == 0 else "engine/script errors printed",
                              record["reasons"])

    def test_graphical_timeout_reaps_owned_stub_processes(self):
        stub = self._stub("MuddsShipyards-timeout.x86_64", "sleep 30\n")
        environment = self._fake_display()
        environment["STARTUP_CHECK_TIMEOUT_SECONDS"] = "1"
        result = self._check(stub, "--graphical", extra_env=environment)
        self.assertEqual(result.returncode, 1, result.stderr)
        record = json.loads((self.dir / (stub.name + ".startup-check.json")).read_text())
        self.assertEqual(record["exit_code"], 124)
        self.assertTrue(record["graphical_processes"]["reaped"])
        self.assertTrue(all(p["absent"] for p in record["graphical_processes"]["owned"]))

    def test_graphical_external_abort_cleans_up_without_game_input(self):
        stub = self._stub("MuddsShipyards-abort.x86_64", "sleep 30\n")
        environment = dict(os.environ, TMPDIR=str(self.dir), **self._fake_display())
        runner = subprocess.Popen([str(STARTUP_SCRIPT), "--graphical", "--keep-profile", str(stub)],
                                  env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record_path = None
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                matches = list(self.dir.glob("mudds-linux-startup-check.*/processes.json"))
                if matches:
                    record_path = matches[0]
                    break
                time.sleep(0.01)
            self.assertIsNotNone(record_path, "stub actor must start before the independent abort")
        finally:
            runner.terminate()
            _stdout, stderr = runner.communicate(timeout=20)
        self.assertEqual(runner.returncode, 143, stderr)
        processes = json.loads(record_path.read_text())
        self.assertTrue(processes["reaped"])
        self.assertTrue(all(p["absent"] for p in processes["owned"]))

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
