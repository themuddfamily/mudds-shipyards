import subprocess
import unittest
from pathlib import Path
from unittest.mock import Mock

from tools.package.export_windows_progress_build import ExportBlocked, assert_source_clean, dirty_source_paths, export_windows


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


if __name__ == "__main__":
    unittest.main()
