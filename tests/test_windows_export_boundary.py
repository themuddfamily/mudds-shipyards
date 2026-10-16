from pathlib import Path
import configparser
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WindowsExportBoundaryTest(unittest.TestCase):
    def test_generated_builds_are_ignored_and_excluded_from_exports(self):
        boundary = ROOT / "builds" / ".gdignore"
        self.assertTrue(boundary.is_file())
        self.assertIn("not project resources", boundary.read_text(encoding="utf-8"))

        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("builds/*", gitignore)
        self.assertIn("!builds/.gdignore", gitignore)

        presets = configparser.ConfigParser(interpolation=None)
        presets.read(ROOT / "export_presets.cfg", encoding="utf-8")
        checked_platforms = set()
        for section in presets.sections():
            if not section.startswith("preset.") or section.endswith(".options"):
                continue
            platform = presets[section]["platform"].strip('"')
            with self.subTest(platform=platform):
                exclusions = set(presets[section]["exclude_filter"].strip('"').split(","))
                self.assertTrue(
                    {"tests/**", "artifacts/**", "tools/**", "builds/**", "roadmap-validation/**"}
                    <= exclusions
                )
            checked_platforms.add(platform)
        self.assertTrue({"Windows Desktop", "Linux"} <= checked_platforms)


class AuthoredExportInputTest(unittest.TestCase):
    def test_both_exporters_reject_bad_inputs_before_running_godot_or_writing_builds(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            release = root / "tools/release"
            release.mkdir(parents=True)
            for name in ("check_zenith_export_inputs.py", "export_windows_candidate.sh",
                         "export_linux_candidate.sh"):
                shutil.copy2(ROOT / "tools/release" / name, release / name)
            manifest_path = root / "assets/models/zenith/zenith_authored_asset_manifest.json"
            blend_path = root / "art_source/zenith/zenith_authored_v1.blend"
            glb_path = manifest_path.with_name("zenith_authored_art.glb")
            manifest_path.parent.mkdir(parents=True)
            blend_path.parent.mkdir(parents=True)
            payload = b"known authored bytes"
            digest = hashlib.sha256(payload).hexdigest()
            valid_manifest = json.dumps({"glb_sha256": digest, "blend_sha256": digest})
            marker = root / "godot-ran"
            stub = root / "godot-stub"
            stub.write_text('#!/bin/sh\ntouch "$(dirname "$0")/godot-ran"\nexit 0\n')
            stub.chmod(0o755)
            env = dict(os.environ, GODOT_BIN=str(stub))

            def git(*args):
                subprocess.run(["git", "-C", str(root), *args], check=True,
                               capture_output=True)

            git("init", "-q")
            git("config", "user.name", "Export test")
            git("config", "user.email", "export-test@example.invalid")
            for problem in ("valid", "missing_manifest", "invalid_json", "non_object",
                            "missing_hash", "invalid_hash_type", "missing_glb", "missing_blend",
                            "empty_glb", "empty_blend", "wrong_glb", "wrong_blend"):
                with self.subTest(problem=problem):
                    manifest_path.write_text(valid_manifest)
                    glb_path.write_bytes(payload)
                    blend_path.write_bytes(payload)
                    if problem == "missing_manifest":
                        manifest_path.unlink()
                    elif problem == "invalid_json":
                        manifest_path.write_text("{")
                    elif problem == "non_object":
                        manifest_path.write_text("[]")
                    elif problem == "missing_hash":
                        manifest_path.write_text("{}")
                    elif problem == "invalid_hash_type":
                        manifest_path.write_text('{"glb_sha256": []}')
                    elif problem.startswith("missing_"):
                        (glb_path if problem.endswith("glb") else blend_path).unlink()
                    elif problem.startswith(("empty_", "wrong_")):
                        path = glb_path if problem.endswith("glb") else blend_path
                        path.write_bytes(b"" if problem.startswith("empty_") else b"changed")
                    git("add", ".")
                    git("commit", "-qm", problem)
                    result = subprocess.run(
                        [sys.executable, str(release / "check_zenith_export_inputs.py"), str(root)],
                        capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, 0 if problem == "valid" else 1,
                                     result.stderr)
                    if problem != "valid":
                        for platform in ("windows", "linux"):
                            result = subprocess.run(
                                ["bash", str(release / f"export_{platform}_candidate.sh")],
                                env=env, capture_output=True, text=True, timeout=10,
                            )
                            self.assertEqual(result.returncode, 1, result.stdout)
                            self.assertIn("Zenith authored export input preflight failed", result.stderr)
                    dry_run = subprocess.run(
                        ["bash", str(release / "export_linux_candidate.sh"), "--dry-run"],
                        env=env, capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(dry_run.returncode, 0, dry_run.stderr)
                    self.assertTrue(json.loads(dry_run.stdout)["dry_run"])
                    self.assertFalse(marker.exists(), "preflight and planning must not run Godot")
                    self.assertFalse((root / "builds").exists(), "preflight and planning must not write builds")


if __name__ == "__main__":
    unittest.main()
