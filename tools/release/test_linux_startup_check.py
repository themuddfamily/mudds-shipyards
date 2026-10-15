#!/usr/bin/env python3
"""Exercise startup-check isolation with inert executable stubs, never Godot."""

import hashlib
import json
import os
import socket
import stat
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("run_linux_startup_check.sh")
RENDERED_ARGS = [
    "--startup-check", "--audio-driver", "Dummy", "--display-driver", "x11",
    "--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
]


class LinuxStartupCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(
            prefix="linux-startup-check-", dir=os.environ.get("TMPDIR")
        )
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.base.chmod(0o700)
        self.binary = self.base / "stub.x86_64"
        self.results = self.base / "results"
        self.tmp = self.base / "private-tmp"
        self.tmp.mkdir(mode=0o700)
        self.auth = self.base / "Xauthority"
        fields = [b"\x7f\0\0\1", b"241", b"MIT-MAGIC-COOKIE-1", b"a" * 16]
        self.auth.write_bytes(struct.pack(">H", 0) + b"".join(
            struct.pack(">H", len(field)) + field for field in fields
        ))
        self.auth.chmod(0o600)
        self.driver = self.base / "software-icd.json"
        self.driver.write_text('{"ICD":{"library_path":"/inert-test-only.so"}}\n')
        self.env = dict(
            os.environ, TMPDIR=str(self.tmp), STARTUP_CHECK_RESULT_DIR=str(self.results),
            DISPLAY="127.0.0.1:241", XAUTHORITY=str(self.auth),
            VK_DRIVER_FILES=str(self.driver),
            STARTUP_CHECK_VK_DRIVER_SHA256=hashlib.sha256(self.driver.read_bytes()).hexdigest(),
            WAYLAND_DISPLAY="must-not-inherit", WAYLAND_SOCKET="must-not-inherit",
            VK_ICD_FILENAMES="must-not-inherit", TEST_SECRET="must-not-inherit",
        )
        self.stub()

    def stub(self, tail="print('STARTUP_MENU_READY_OK')"):
        self.binary.write_text(
            "#!/usr/bin/python3\nimport json, os, sys\n"
            "print('STUB_STATE: ' + json.dumps({'argv': sys.argv[1:], 'env': dict(os.environ)}))\n"
            + tail + "\n"
        )
        self.binary.chmod(0o755)

    def run_check(self, *options, env=None):
        return subprocess.run(
            [str(SCRIPT), *options, str(self.binary)], env=env or self.env,
            text=True, capture_output=True, timeout=15,
        )

    def record(self):
        return json.loads((self.results / "stub.x86_64.startup-check.json").read_text())

    def state(self):
        log = (self.results / "stub.x86_64.startup-check.log").read_text()
        return json.loads(next(line.removeprefix("STUB_STATE: ")
                               for line in log.splitlines() if line.startswith("STUB_STATE: ")))

    def test_default_retains_headless_dummy_and_private_environment(self):
        result = self.run_check("--keep-profile")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.state()
        self.assertEqual(state["argv"], ["--headless", "--audio-driver", "Dummy", "--startup-check"])
        self.assertEqual(state["env"].get("HOME"), self.env.get("HOME"))
        for key in ("DISPLAY", "XAUTHORITY", "VK_DRIVER_FILES", "WAYLAND_DISPLAY",
                    "WAYLAND_SOCKET", "VK_ICD_FILENAMES", "TEST_SECRET"):
            self.assertNotIn(key, state["env"])
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME",
                    "XDG_RUNTIME_DIR", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS", "TMPDIR"):
            path = Path(state["env"][key])
            self.assertTrue(path.is_relative_to(self.tmp))
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o700)
        self.assertEqual(self.record()["launch_mode"], "headless")
        self.assertEqual(self.record()["native_gpu"], "NOT_RUN")

    def test_rendered_passes_only_authenticated_explicit_render_inputs(self):
        result = self.run_check("--rendered")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.state()
        self.assertEqual(state["argv"], RENDERED_ARGS)
        for key in ("DISPLAY", "XAUTHORITY", "VK_DRIVER_FILES", "HOME"):
            self.assertEqual(state["env"].get(key), self.env.get(key))
        for key in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "VK_ICD_FILENAMES", "TEST_SECRET"):
            self.assertNotIn(key, state["env"])
        record = self.record()
        self.assertEqual(record["launch_mode"], "rendered")
        self.assertEqual(record["display"], "127.0.0.1:241")
        self.assertEqual(record["native_gpu"], "NOT_RUN")

    def test_rendered_accepts_real_xauth_loopback_record(self):
        self.auth.write_bytes(b"")
        subprocess.run(
            ["xauth", "-f", str(self.auth), "add", "127.0.0.1:241",
             "MIT-MAGIC-COOKIE-1", "62" * 16],
            check=True, capture_output=True, timeout=5,
        )
        self.assertIn(struct.unpack_from(">H", self.auth.read_bytes())[0], (0, 256))
        result = self.run_check("--rendered")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()["env"]["DISPLAY"], "127.0.0.1:241")

    def test_rendered_accepts_only_exact_family_local_hostname_not_wildcards(self):
        hostname = socket.gethostname().encode()
        for family, address, allowed in ((256, hostname, True),
                                          (256, hostname + b"-foreign", False),
                                          (65535, hostname, False)):
            fields = [address, b"241", b"MIT-MAGIC-COOKIE-1", b"b" * 16]
            self.auth.write_bytes(struct.pack(">H", family) + b"".join(
                struct.pack(">H", len(field)) + field for field in fields
            ))
            result = self.run_check("--rendered", "--dry-run")
            self.assertEqual(result.returncode == 0, allowed, result.stderr)
            self.assertFalse(self.results.exists())

    def test_dry_run_reports_mode_actual_arguments_and_original_cap_without_writes(self):
        for options, expected in (([], ["--headless", "--audio-driver", "Dummy", "--startup-check"]),
                                  (["--rendered"], RENDERED_ARGS)):
            result = self.run_check("--dry-run", *options)
            self.assertEqual(result.returncode, 0, result.stderr)
            plan = json.loads(result.stdout)
            self.assertEqual(plan["arguments"], expected)
            self.assertEqual(plan["timeout_seconds"], 300)
            self.assertEqual(plan["display"], "127.0.0.1:241" if options else None)
            self.assertFalse(self.results.exists())
            self.assertEqual(list(self.tmp.iterdir()), [])

    def test_rendered_denies_missing_local_or_non_loopback_display_before_outputs(self):
        for value in ("", ":0", "localhost:241", "192.0.2.1:241", "127.0.0.1:0",
                      "127.0.0.1:65535", "127.0.0.1:241.1"):
            with self.subTest(display=value):
                result = self.run_check("--rendered", env=dict(self.env, DISPLAY=value))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.results.exists())

    def test_rendered_requires_private_matching_authority(self):
        original = self.auth.read_bytes()
        for contents, mode in ((b"", 0o600), (b"truncated", 0o600),
                               (original.replace(b"241", b"242"), 0o600), (original, 0o644)):
            with self.subTest(mode=mode, contents=contents[:10]):
                self.auth.write_bytes(contents)
                self.auth.chmod(mode)
                result = self.run_check("--rendered")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.results.exists())
        result = self.run_check("--rendered", env=dict(self.env, XAUTHORITY=""))
        self.assertNotEqual(result.returncode, 0)

    def test_rendered_requires_driver_file_and_matching_explicit_pin(self):
        for change in ({"VK_DRIVER_FILES": ""}, {"VK_DRIVER_FILES": "relative.json"},
                       {"STARTUP_CHECK_VK_DRIVER_SHA256": ""},
                       {"STARTUP_CHECK_VK_DRIVER_SHA256": "0" * 64}):
            with self.subTest(change=change):
                result = self.run_check("--rendered", env=dict(self.env, **change))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.results.exists())

    def test_failure_is_recorded_and_existing_results_are_never_overwritten(self):
        self.stub("print('STARTUP_MENU_READY_OK')\nsys.exit(7)")
        result = self.run_check("--rendered")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.record()["exit_code"], 7)
        original = {p.name: p.read_bytes() for p in self.results.iterdir()}
        self.stub()
        result = self.run_check("--rendered")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to overwrite", result.stderr)
        self.assertEqual({p.name: p.read_bytes() for p in self.results.iterdir()}, original)

    def test_rendered_refuses_diagnostics_and_duplicate_readiness(self):
        self.stub("print('STARTUP_MENU_READY_OK')\nprint('STARTUP_MENU_READY_OK')\nprint('ERROR: simulated')")
        result = self.run_check("--rendered")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.record()["status"], "FAIL")
        self.assertEqual(self.record()["sentinel_count"], 2)

    def test_rendered_detects_driver_mutation_during_launch(self):
        self.stub(f"open({str(self.driver)!r}, 'w').write('changed')\nprint('STARTUP_MENU_READY_OK')")
        result = self.run_check("--rendered")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rendered Vulkan driver file changed", self.record()["reasons"])


if __name__ == "__main__":
    unittest.main()
