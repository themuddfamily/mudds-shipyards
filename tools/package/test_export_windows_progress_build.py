import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

from tools.package.export_windows_progress_build import ExportBlocked, assert_source_clean, dirty_source_paths, export_and_assemble, export_windows


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
