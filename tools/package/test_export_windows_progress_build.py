import subprocess
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from tools.package.export_windows_progress_build import ExportBlocked, assert_source_clean, dirty_source_paths, export_and_assemble, export_windows
from tools.package.windows_distribution_assembler import assemble_distribution
from tools.package.windows_portable_installer import _read_archive


class ExportWindowsProgressBuildTest(unittest.TestCase):
    def test_ignores_only_generated_build_outputs(self):
        status = " M builds/windows/MuddsShipyards.exe\n?? builds/distributions/new.zip\n M scripts/game/game_flow.gd\n?? tests/new_test.gd\n"
        self.assertEqual(dirty_source_paths(status), ["scripts/game/game_flow.gd", "tests/new_test.gd"])

    def test_blocks_tracked_and_untracked_source_changes(self):
        runner = Mock(return_value=subprocess.CompletedProcess([], 0, stdout=" M scripts/game/game_flow.gd\n", stderr=""))
        with self.assertRaises(ExportBlocked):
            assert_source_clean(Path("."), runner)

    def test_clean_preflight_invokes_only_windows_export_under_builds(self):
        runner = Mock(side_effect=[
            subprocess.CompletedProcess([], 0, stdout="?? builds/generated.exe\n", stderr=""),
            subprocess.CompletedProcess([], 0, stdout="", stderr=""),
        ])
        result = export_windows(Path("/repo"), Path("builds/windows/fresh.exe"), runner)
        self.assertEqual(result, 0)
        self.assertEqual(runner.call_args_list[1].args[0], ["godot", "--headless", "--export-release", "Windows Desktop", "/repo/builds/windows/fresh.exe"])

    def _git_fixture(self, root):
        for name, content in {
            "README.md": "readme", "LICENSE.txt": "license", "project.godot": "config",
        }.items():
            (root / name).write_text(content)
        def git(*args):
            return subprocess.run(
                ["git", *args], cwd=root, check=True, capture_output=True, text=True,
            )
        git("init")
        git("config", "user.name", "Package Test")
        git("config", "user.email", "package@example.invalid")
        git("add", ".")
        git("commit", "-m", "fixture")
        return git

    def test_real_assembly_rejects_source_and_head_drift_and_cleans_outputs(self):
        for phase in ("export", "assembly", "verification", "copy", "publication"):
            for mutation in ("source", "head"):
                with self.subTest(phase=phase, mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    git = self._git_fixture(root)
                    def change_source():
                        if mutation == "source":
                            (root / "project.godot").write_text("changed config")
                        else:
                            git("commit", "--allow-empty", "-m", "new HEAD")
                    def runner(command, **kwargs):
                        if command[0] != "godot":
                            return subprocess.run(command, **kwargs)
                        Path(command[-1]).write_bytes(b"exe")
                        if phase == "export":
                            change_source()
                        return subprocess.CompletedProcess(command, 0)
                    def assembler(*args):
                        result = assemble_distribution(*args)
                        if phase == "assembly":
                            change_source()
                        return result
                    def verify(archive):
                        _read_archive(archive)
                        if phase == "verification":
                            change_source()
                    original_copytree = shutil.copytree
                    def copytree(source, destination, *args, **kwargs):
                        result = original_copytree(source, destination, *args, **kwargs)
                        if phase == "copy" and str(destination).endswith(".publishing"):
                            change_source()
                        return result
                    original_replace = Path.replace
                    def replace(path, destination):
                        result = original_replace(path, destination)
                        if phase == "publication" and str(destination).endswith("fresh.exe"):
                            change_source()
                        return result
                    with patch("tools.package.export_windows_progress_build.shutil.copytree", copytree), patch.object(Path, "replace", replace):
                        with self.assertRaises(ExportBlocked):
                            export_and_assemble(
                                root, Path("builds/windows/fresh.exe"), "v1.0.0",
                                root / "README.md", root / "LICENSE.txt", root / "project.godot",
                                runner, assembler, verify,
                            )
                    self.assertEqual([p for p in (root / "builds").rglob("*") if p.is_file()], [])
                    self.assertFalse(list((root / "builds").glob(".progress-export-*")))
                    self.assertFalse(list((root / "builds").rglob("*.publishing")))

    def test_clean_git_source_publishes_real_verified_assembly_without_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            git = self._git_fixture(root)
            def runner(command, **kwargs):
                if command[0] != "godot":
                    return subprocess.run(command, **kwargs)
                Path(command[-1]).write_bytes(b"exe")
                return subprocess.CompletedProcess(command, 0)
            args = (
                root, Path("builds/windows/fresh.exe"), "v1.0.0",
                root / "README.md", root / "LICENSE.txt", root / "project.godot", runner,
            )
            result = export_and_assemble(*args)
            self.assertEqual(result["commit"], git("rev-parse", "HEAD").stdout.strip())
            _read_archive(Path(result["archive"]))
            previous_files = {p: p.read_bytes() for p in (root / "builds").rglob("*") if p.is_file()}
            with self.assertRaises(FileExistsError):
                export_and_assemble(*args)
            self.assertEqual(previous_files, {p: p.read_bytes() for p in (root / "builds").rglob("*") if p.is_file()})

    def test_atomic_workflow_reports_hashes_and_preserves_existing_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "builds").mkdir()
            readme = root / "README.md"; readme.write_text("readme")
            license_file = root / "LICENSE.txt"; license_file.write_text("license")
            config = root / "project.godot"; config.write_text("config")
            def runner(command, **_kwargs):
                if command[:3] == ["git", "status", "--porcelain"]:
                    return subprocess.CompletedProcess(command, 0, stdout="", stderr="")
                if command[:3] == ["git", "rev-parse", "HEAD"]:
                    return subprocess.CompletedProcess(command, 0, stdout="a" * 40 + "\n", stderr="")
                Path(command[-1]).write_bytes(b"exe")
                return subprocess.CompletedProcess(command, 0, stdout="", stderr="")
            def fake_assembler(artifact, output_root, version, commit, readme_path, license_path, config_path):
                directory = output_root / "MuddsShipyards-v1.0.0-aaaaaaa"
                directory.mkdir(parents=True)
                archive = output_root / (directory.name + ".zip")
                (directory / "distribution-manifest.json").write_text("manifest")
                archive.write_bytes(b"zip")
                return {"directory": directory, "archive": archive}
            result = export_and_assemble(root, root / "builds/windows/fresh.exe", "v1.0.0", readme, license_file, config, runner, fake_assembler, lambda _archive: None)
            self.assertEqual(result["commit"], "a" * 40)
            self.assertEqual(result["exe_size"], 3)
            self.assertEqual(len(result["exe_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
