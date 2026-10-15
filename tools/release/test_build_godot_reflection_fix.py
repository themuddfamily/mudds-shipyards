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
import tarfile
import tempfile
import unittest
from unittest.mock import Mock, patch


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

    def test_successful_command_rescans_after_residual_session_cleanup(self):
        process = Mock(pid=1234)
        process.wait.return_value = 0
        stat = "1234 (inert tool) " + " ".join(["0"] * 19 + ["5678"])
        with patch.object(builder.subprocess, "Popen", return_value=process), \
                patch.object(builder.Path, "read_text", return_value=stat), \
                patch.object(builder, "session_actors", side_effect=[[("2345", "6789")], []]) as actors, \
                patch.object(builder, "close_session") as close, \
                contextlib.redirect_stdout(io.StringIO()):
            result = builder.run(["inert-tool"], {}, Path(self.tmp.name),
                                 Path(self.tmp.name) / "run.log", 300)
        self.assertEqual(result["exit"], 0)
        self.assertEqual(result["start_ticks"], "5678")
        self.assertEqual(actors.call_count, 2)
        actors.assert_called_with(process.pid)
        close.assert_called_once_with(process)
        process.wait.assert_called_once_with(timeout=300)

    def test_successful_command_rejects_actors_still_present_after_cleanup(self):
        process = Mock(pid=1234)
        process.wait.return_value = 0
        stat = "1234 (inert tool) " + " ".join(["0"] * 19 + ["5678"])
        with patch.object(builder.subprocess, "Popen", return_value=process), \
                patch.object(builder.Path, "read_text", return_value=stat), \
                patch.object(builder, "session_actors", return_value=[("2345", "6789")]) as actors, \
                patch.object(builder, "close_session") as close, \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "Owned session actors remain.*2345"):
                builder.run(["inert-tool"], {}, Path(self.tmp.name),
                            Path(self.tmp.name) / "run.log", 300)
        self.assertEqual(actors.call_count, 2)
        close.assert_called_once_with(process)

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

    def test_mesh_feature_requires_explicit_opt_in_and_separate_artifacts(self):
        for target in ("editor", "template_release"):
            with self.subTest(target=target):
                original = self.plan("--target", target)
                feature = self.plan("--mesh-content-revision", "--target", target)
                for key in ("binary", "custom_build_name", "log", "result"):
                    self.assertNotEqual(original[key], feature[key])
                self.assertEqual(feature["mesh_patch_sha256"], builder.sha(builder.MESH_PATCH))
                self.assertEqual(feature["patch_sha256"], builder.PATCH_SHA)
                self.assertIn("extra_suffix=" + builder.MESH_SUFFIX, feature["options"])
                if target == "template_release":
                    self.assertNotEqual(original["release_template"], feature["release_template"])
                self.assertNotIn("mesh_content_revision", original)

    def test_mesh_patch_rejects_partial_source_before_running_tools(self):
        source = self.cache / builder.SOURCE_NAME
        for index, name in enumerate(builder.MESH_TARGETS):
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"before" if index else b"after")
        hashes = {name: (hashlib.sha256(b"before").hexdigest(), hashlib.sha256(b"after").hexdigest())
                  for name in builder.MESH_TARGETS}
        with patch.object(builder, "MESH_TARGETS", hashes), patch.object(builder, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "Mixed or unexpected mesh revision source"):
                builder.apply_mesh_patch(source, {}, self.cache / "unused.log")
            run.assert_not_called()

    def test_source_verification_only_allows_reviewed_mesh_bytes_with_opt_in(self):
        source = self.cache / builder.SOURCE_NAME
        name = next(iter(builder.MESH_TARGETS))
        path = source / name
        path.parent.mkdir(parents=True)
        archive = self.cache / "fixture.tar.xz"
        original, reviewed = b"official source\n", b"reviewed mesh revision\n"
        with tarfile.open(archive, "w:xz") as tar:
            info = tarfile.TarInfo(builder.SOURCE_NAME + "/" + name)
            info.size = len(original)
            tar.addfile(info, io.BytesIO(original))
        hashes = {name: (hashlib.sha256(original).hexdigest(), hashlib.sha256(reviewed).hexdigest())}
        with patch.object(builder, "MESH_TARGETS", hashes):
            path.write_bytes(original)
            builder.source_tree(archive, source)
            builder.source_tree(archive, source, mesh_content_revision=True)
            path.write_bytes(reviewed)
            builder.source_tree(archive, source, mesh_content_revision=True)
            with self.assertRaisesRegex(RuntimeError, "Changed shipped source"):
                builder.source_tree(archive, source)
            path.write_bytes(b"unreviewed content")
            with self.assertRaisesRegex(RuntimeError, "Unexpected mesh revision target bytes"):
                builder.source_tree(archive, source, mesh_content_revision=True)

    def test_retained_probe_opt_in_keeps_existing_options_and_separates_all_outputs(self):
        for mesh in (False, True):
            for target in ("editor", "template_release"):
                with self.subTest(mesh=mesh, target=target):
                    args = ["--target", target] + (["--mesh-content-revision"] if mesh else [])
                    original = self.plan(*args)
                    feature = self.plan(*args, "--retained-probe-lifecycle")
                    self.assertNotIn("retained_probe_lifecycle", original)
                    self.assertTrue(feature["retained_probe_lifecycle"])
                    self.assertEqual(feature["retained_probe_patch_sha256"], builder.sha(builder.PROBE_PATCH))
                    for key in ("binary", "custom_build_name", "log", "result"):
                        self.assertNotEqual(original[key], feature[key])
                    self.assertEqual(feature["options"][:-1], original["options"][:-1])
                    self.assertEqual(feature["options"][-1], original["options"][-1] + "_retained_probe_lifecycle")
                    if target == "template_release":
                        self.assertNotEqual(original["release_template"], feature["release_template"])
                    self.assertEqual(feature["patch_sha256"], builder.PATCH_SHA)
                    if mesh:
                        self.assertEqual(feature["mesh_patch_sha256"], builder.MESH_PATCH_SHA)

    def test_retained_probe_patch_guards_and_idempotence(self):
        source = self.cache / builder.SOURCE_NAME
        target = source / builder.PROBE_TARGET
        target.parent.mkdir(parents=True)
        before, after = b"official probe lifecycle", b"reviewed probe lifecycle"
        with patch.object(builder, "PROBE_BEFORE_SHA", hashlib.sha256(before).hexdigest()), \
                patch.object(builder, "PROBE_AFTER_SHA", hashlib.sha256(after).hexdigest()), \
                patch.object(builder, "run") as run:
            target.write_bytes(b"unexpected source")
            with self.assertRaisesRegex(RuntimeError, "Unexpected retained probe source bytes"):
                builder.apply_retained_probe_patch(source, {}, self.cache / "unused.log")
            run.assert_not_called()
            target.write_bytes(after)
            self.assertEqual(builder.apply_retained_probe_patch(source, {}, self.cache / "unused.log"), [])
            run.assert_not_called()
            target.write_bytes(before)
            run.side_effect = lambda *args: target.write_bytes(after)
            builder.apply_retained_probe_patch(source, {}, self.cache / "unused.log")
            self.assertEqual(run.call_args.args[0], ["patch", "--batch", "--forward", "--fuzz=0", "-p1", "-i", str(builder.PROBE_PATCH)])
            self.assertEqual(target.read_bytes(), after)

    def test_retained_probe_source_verification_requires_opt_in(self):
        source = self.cache / builder.SOURCE_NAME
        target = source / builder.PROBE_TARGET
        target.parent.mkdir(parents=True)
        before, after = b"official probe lifecycle", b"reviewed probe lifecycle"
        archive = self.cache / "probe-fixture.tar.xz"
        with tarfile.open(archive, "w:xz") as tar:
            info = tarfile.TarInfo(builder.SOURCE_NAME + "/" + builder.PROBE_TARGET)
            info.size = len(before)
            tar.addfile(info, io.BytesIO(before))
        with patch.object(builder, "PROBE_BEFORE_SHA", hashlib.sha256(before).hexdigest()), \
                patch.object(builder, "PROBE_AFTER_SHA", hashlib.sha256(after).hexdigest()):
            target.write_bytes(before)
            builder.source_tree(archive, source)
            target.write_bytes(after)
            builder.source_tree(archive, source, retained_probe_lifecycle=True)
            with self.assertRaisesRegex(RuntimeError, "Changed shipped source"):
                builder.source_tree(archive, source, mesh_content_revision=True)
            target.write_bytes(b"unexpected source")
            with self.assertRaisesRegex(RuntimeError, "Unexpected retained probe target bytes"):
                builder.source_tree(archive, source, retained_probe_lifecycle=True)

    def simulate_release(self, stale_template=False, mesh_content_revision=False, retained_probe_lifecycle=False):
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
        if mesh_content_revision:
            protected.extend([
                source / "bin/godot.linuxbsd.template_release.x86_64.mudds_reflection_atlas",
                self.cache / "build-template_release.log", self.cache / "build-result-template_release.json",
                self.cache / "export_templates/4.7.1.stable/linux_release.x86_64",
            ])
        if retained_probe_lifecycle:
            for previous_mode, previous_suffix, previous_templates in (
                ("", builder.SUFFIX, "export_templates"),
                ("-mesh-content-revision", builder.MESH_SUFFIX, "export_templates-mesh-content-revision"),
            ):
                for previous_target, target_suffix in (("editor", ""), ("template_release", "-template_release")):
                    protected.extend([
                        source / (f"bin/godot.linuxbsd.{previous_target}.x86_64." + previous_suffix),
                        self.cache / f"build{previous_mode}{target_suffix}.log",
                        self.cache / f"build-result{previous_mode}{target_suffix}.json",
                    ])
                protected.append(self.cache / previous_templates / "4.7.1.stable/linux_release.x86_64")
        for path in protected:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"accepted editor artifact")
        template_dir = "export_templates-mesh-content-revision" if mesh_content_revision else "export_templates"
        if retained_probe_lifecycle:
            template_dir += "-retained-probe-lifecycle"
        template = self.cache / template_dir / "4.7.1.stable/linux_release.x86_64"
        if stale_template:
            template.parent.mkdir(parents=True)
            template.write_bytes(b"previous different release")
        calls = []
        mode = "-mesh-content-revision" if mesh_content_revision else ""
        suffix = builder.MESH_SUFFIX if mesh_content_revision else builder.SUFFIX
        expected_build_name = builder.MESH_BUILD_NAME if mesh_content_revision else builder.BUILD_NAME
        if retained_probe_lifecycle:
            mode += "-retained-probe-lifecycle"
            suffix += "_retained_probe_lifecycle"
            expected_build_name += "_retained_probe_lifecycle"

        def inert_run(command, env, cwd, log, timeout):
            calls.append(command)
            self.assertEqual(log, self.cache / f"build{mode}-template_release.log")
            self.assertEqual(env["BUILD_NAME"], expected_build_name)
            self.assertEqual(env.get("HOME"), os.environ.get("HOME"))
            self.assertNotIn("DISPLAY", env)
            self.assertNotIn("WAYLAND_DISPLAY", env)
            log.write_text("inert tool fixture\n")
            if "SCons" in command:
                self.assertIn("target=template_release", command)
                self.assertEqual(timeout, 3600)
                (source / ("bin/godot.linuxbsd.template_release.x86_64." + suffix)).write_bytes(b"\x7fELFrelease fixture")
            return {"command": command, "exit": 0}

        old_umask = os.umask(0o077)
        try:
            with patch.object(builder, "CACHE", self.cache), \
                    patch.object(builder, "AFTER_SHA", hashlib.sha256(target.read_bytes()).hexdigest()), \
                    patch.object(builder, "install_cancellation"), patch.object(builder, "download"), \
                    patch.object(builder, "source_tree"), patch.object(builder, "apply_mesh_patch", return_value=[]) as mesh_patch, \
                    patch.object(builder, "apply_retained_probe_patch", return_value=[]) as probe_patch, \
                    patch.object(builder, "run", side_effect=inert_run), \
                    patch.object(sys, "argv", [str(SCRIPT), "--build", "--target", "template_release"] +
                                 (["--mesh-content-revision"] if mesh_content_revision else []) +
                                 (["--retained-probe-lifecycle"] if retained_probe_lifecycle else [])), \
                    contextlib.redirect_stdout(io.StringIO()):
                if stale_template:
                    with self.assertRaisesRegex(RuntimeError, "Existing private release template differs"):
                        builder.main()
                else:
                    builder.main()
                self.assertEqual(mesh_patch.call_count, int(mesh_content_revision))
                self.assertEqual(probe_patch.call_count, int(retained_probe_lifecycle))
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

    def test_mesh_release_staging_preserves_all_accepted_artifacts(self):
        template, calls = self.simulate_release(mesh_content_revision=True)
        self.assertEqual(template.read_bytes(), b"\x7fELFrelease fixture")
        record = json.loads((self.cache / "build-result-mesh-content-revision-template_release.json").read_text())
        self.assertEqual(record["release_template_sha256"], hashlib.sha256(template.read_bytes()).hexdigest())
        self.assertEqual(len(calls), 3)


    def test_retained_probe_release_staging_preserves_all_existing_artifacts(self):
        for mesh in (False, True):
            with self.subTest(mesh=mesh):
                # Each simulated target has an independent cache, as with a
                # clean fixture; the real recipe uses one common build lock.
                self.cache = Path(self.tmp.name) / ("probe-mesh" if mesh else "probe-only")
                template, calls = self.simulate_release(mesh_content_revision=mesh, retained_probe_lifecycle=True)
                self.assertEqual(template.read_bytes(), b"\x7fELFrelease fixture")
                mode = "-mesh-content-revision" if mesh else ""
                record = json.loads((self.cache / f"build-result{mode}-retained-probe-lifecycle-template_release.json").read_text())
                self.assertEqual(record["release_template_sha256"], hashlib.sha256(template.read_bytes()).hexdigest())
                self.assertEqual(len(calls), 3)


if __name__ == "__main__":
    unittest.main()
