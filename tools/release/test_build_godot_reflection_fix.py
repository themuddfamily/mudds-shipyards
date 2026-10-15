#!/usr/bin/env python3
"""Target selection/staging tests; no compiler, downloader or Godot is run."""

import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("build_godot_reflection_fix.py")
spec = importlib.util.spec_from_file_location("reflection_builder", SCRIPT)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class BuildTargets(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cache = Path(self.tmp.name) / "engine-cache"

    def plan(self, *args):
        output = io.StringIO()
        with patch.object(builder, "CACHE", self.cache), patch.object(sys, "argv", [str(SCRIPT), *args]), \
                patch.object(builder, "run") as run, contextlib.redirect_stdout(output):
            builder.main()
            run.assert_not_called()
        self.assertFalse(self.cache.exists())
        return json.loads(output.getvalue())

    def test_default_editor_plan_keeps_accepted_paths(self):
        p = self.plan()
        self.assertEqual(p["target"], "editor")
        self.assertIn("target=editor", p["options"])
        self.assertEqual(p["log"], str(self.cache / "build.log"))
        self.assertEqual(p["result"], str(self.cache / "build-result.json"))
        self.assertTrue(p["binary"].endswith("godot.linuxbsd.editor.x86_64.mudds_reflection_atlas"))
        self.assertIsNone(p["release_template"])

    def test_release_plan_is_separate_and_does_not_build(self):
        p = self.plan("--target", "template_release")
        self.assertIn("target=template_release", p["options"])
        self.assertNotIn("target=editor", p["options"])
        self.assertEqual(p["log"], str(self.cache / "build-template_release.log"))
        self.assertEqual(p["result"], str(self.cache / "build-result-template_release.json"))
        self.assertTrue(p["binary"].endswith("godot.linuxbsd.template_release.x86_64.mudds_reflection_atlas"))
        self.assertEqual(p["release_template"], str(self.cache / "export_templates/4.7.1.stable/linux_release.x86_64"))

    def simulate_release(self, stale_template=False):
        source = self.cache / builder.SOURCE_NAME
        target = source / builder.TARGET
        target.parent.mkdir(parents=True)
        target.write_bytes(b"reviewed patched fixture")
        python = self.cache / "venv/bin/python"
        python.parent.mkdir(parents=True)
        python.touch()
        editor = source / "bin/godot.linuxbsd.editor.x86_64.mudds_reflection_atlas"
        editor.parent.mkdir()
        protected = [editor, self.cache / "build.log", self.cache / "build-result.json"]
        for path in protected:
            path.write_bytes(b"accepted editor artifact")
        template = self.cache / "export_templates/4.7.1.stable/linux_release.x86_64"
        if stale_template:
            template.parent.mkdir(parents=True)
            template.write_bytes(b"previous different release")
        calls = []

        def inert_run(command, env, cwd, log, timeout):
            calls.append(command)
            self.assertEqual(log, self.cache / "build-template_release.log")
            self.assertEqual(env.get("HOME"), os.environ.get("HOME"))
            self.assertNotIn("DISPLAY", env)
            self.assertNotIn("WAYLAND_DISPLAY", env)
            log.write_text("inert tool fixture\n")
            if "SCons" in command:
                self.assertIn("target=template_release", command)
                self.assertEqual(timeout, 3600)
                (source / "bin/godot.linuxbsd.template_release.x86_64.mudds_reflection_atlas").write_bytes(b"\x7fELFrelease fixture")
            return {"command": command, "exit": 0}

        old_umask = os.umask(0o077)
        try:
            with patch.object(builder, "CACHE", self.cache), \
                    patch.object(builder, "AFTER_SHA", hashlib.sha256(target.read_bytes()).hexdigest()), \
                    patch.object(builder, "install_cancellation"), patch.object(builder, "download"), \
                    patch.object(builder, "source_tree"), patch.object(builder, "run", side_effect=inert_run), \
                    patch.object(sys, "argv", [str(SCRIPT), "--build", "--target", "template_release"]), \
                    contextlib.redirect_stdout(io.StringIO()):
                if stale_template:
                    with self.assertRaisesRegex(RuntimeError, "Existing private release template differs"):
                        builder.main()
                else:
                    builder.main()
        finally:
            os.umask(old_umask)
        for path in protected:
            self.assertEqual(path.read_bytes(), b"accepted editor artifact")
        return template, calls

    def test_release_staging_preserves_editor_binary_result_and_log(self):
        template, calls = self.simulate_release()
        self.assertEqual(template.read_bytes(), b"\x7fELFrelease fixture")
        self.assertEqual(template.stat().st_mode & 0o777, 0o755)
        self.assertFalse(template.with_name("linux_debug.x86_64").exists())
        record = json.loads((self.cache / "build-result-template_release.json").read_text())
        self.assertEqual(record["release_template_sha256"], hashlib.sha256(template.read_bytes()).hexdigest())
        self.assertEqual(len(calls), 3)  # Inert pip, SCons and headless/Dummy version stand-ins.

    def test_different_existing_private_template_is_not_overwritten(self):
        template, _ = self.simulate_release(stale_template=True)
        self.assertEqual(template.read_bytes(), b"previous different release")
        self.assertFalse((self.cache / "build-result-template_release.json").exists())


if __name__ == "__main__":
    unittest.main()
