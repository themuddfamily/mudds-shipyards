import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.package.windows_distribution_assembler import assemble_distribution
from tools.package.windows_portable_installer import install_package


class WindowsDistributionAssemblerTest(unittest.TestCase):
    def _inputs(self, root):
        files = {}
        for name, data in {
            "export.exe": b"PE-export\0\x01",
            "export.pck": b"GDPC-payload\0\x02",
            "README.md": b"Run the exported game.\n",
            "LICENSE.txt": b"Project license.\n",
            "project.godot": b"[application]\nconfig/name=Fixture\n",
        }.items():
            path = root / name
            path.write_bytes(data)
            files[name] = path
        return files

    def test_assembles_payload_manifest_and_reproducible_zip(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self._inputs(root)
            commit = "a" * 40
            first = assemble_distribution(
                source["export.exe"], root / "one", "v1.2.3", commit,
                source["README.md"], source["LICENSE.txt"], source["project.godot"], source["export.pck"]
            )
            second = assemble_distribution(
                source["export.exe"], root / "two", "v1.2.3", commit,
                source["README.md"], source["LICENSE.txt"], source["project.godot"], source["export.pck"]
            )
            self.assertEqual(first["archive"].read_bytes(), second["archive"].read_bytes())
            stage = first["directory"]
            self.assertTrue((stage / "README.md").is_file())
            self.assertTrue((stage / "LICENSE.txt").is_file())
            self.assertTrue((stage / "config/project.godot").is_file())
            self.assertTrue((stage / "SHA256SUMS.txt").is_file())
            self.assertTrue((stage / "Start Mudds Shipyards.cmd").is_file())
            self.assertTrue((stage / "install/windows_portable_installer.py").is_file())
            self.assertTrue((stage / "install/windows_portable_installer.ps1").is_file())
            self.assertTrue((stage / "install/verify_distribution.ps1").is_file())
            self.assertTrue((stage / "install/collect_support_bundle.ps1").is_file())
            collector = (stage / "install/collect_support_bundle.ps1").read_text(encoding="utf-8")
            self.assertIn("crash-log.json", collector)
            self.assertIn("save files", collector)
            self.assertIn("[REDACTED]", collector)
            self.assertIn("native_status = 'NOT_RUN'", collector)
            verifier = (stage / "install/verify_distribution.ps1").read_text(encoding="utf-8")
            self.assertIn("Get-FileHash", verifier)
            self.assertIn("native_validation -ne 'NOT_RUN'", verifier)
            instructions = (stage / "INSTALL-WINDOWS.txt").read_text(encoding="utf-8")
            self.assertIn("powershell -NoProfile -ExecutionPolicy Bypass -File .\\install\\windows_portable_installer.ps1 install", instructions)
            self.assertIn("status -Destination", instructions)
            self.assertIn("rollback -Destination", instructions)
            self.assertIn("uninstall -Destination", instructions)
            self.assertIn("%APPDATA%\\Godot\\app_userdata\\Mudds Shipyards", instructions)
            self.assertIn("Signing: NOT_RUN (this package is unsigned).", instructions)
            self.assertIn("Native validation: NOT_RUN.", instructions)
            self.assertIn("-StartMenuShortcut", instructions)
            self.assertIn("-DesktopShortcut", instructions)
            self.assertIn("-AddRemovePrograms", instructions)
            self.assertIn(" repair -Destination", instructions)
            powershell = (stage / "install/windows_portable_installer.ps1").read_text(encoding="utf-8")
            self.assertIn("ValidateSet('install', 'upgrade', 'status', 'rollback', 'uninstall', 'repair')", powershell)
            self.assertIn("Get-FileHash", powershell)
            self.assertIn("Same-version replacement requires -Force", powershell)
            self.assertIn("Downgrade requires -Force", powershell)
            self.assertIn("StartMenuShortcut", powershell)
            self.assertIn("DesktopShortcut", powershell)
            self.assertIn("external_shortcuts", powershell)
            self.assertIn("'repair'", powershell)
            self.assertIn("Repair source version must match", powershell)
            self.assertIn("$repairRoot", powershell)
            self.assertIn("AddRemovePrograms", powershell)
            self.assertIn("MuddsOwned", powershell)
            self.assertIn("HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\MuddsShipyardsPortable", powershell)
            self.assertEqual(first["manifest"]["signing"], "NOT_RUN")
            self.assertEqual(first["manifest"]["native_validation"], "NOT_RUN")
            self.assertEqual(first["manifest"]["portable_installer"]["launcher"], "Start Mudds Shipyards.cmd")
            with zipfile.ZipFile(first["archive"]) as bundle:
                self.assertEqual(bundle.namelist(), sorted(bundle.namelist()))
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/MuddsShipyards.exe", bundle.namelist())
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/Start Mudds Shipyards.cmd", bundle.namelist())
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/install/windows_portable_installer.py", bundle.namelist())
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/install/windows_portable_installer.ps1", bundle.namelist())
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/install/verify_distribution.ps1", bundle.namelist())
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/install/collect_support_bundle.ps1", bundle.namelist())
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/INSTALL-WINDOWS.txt", bundle.namelist())
            installed = install_package(first["archive"], root / "installed")
            self.assertTrue((Path(installed["destination"]) / "Start Mudds Shipyards.cmd").is_file())
            self.assertTrue((Path(installed["destination"]) / "install/windows_portable_installer.py").is_file())
            self.assertTrue((Path(installed["destination"]) / "install/windows_portable_installer.ps1").is_file())
            self.assertTrue((Path(installed["destination"]) / "install/verify_distribution.ps1").is_file())
            self.assertTrue((Path(installed["destination"]) / "install/collect_support_bundle.ps1").is_file())

    def test_checksum_manifest_matches_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self._inputs(root)
            result = assemble_distribution(
                source["export.pck"], root / "out", "1.0.0", "b" * 40,
                source["README.md"], source["LICENSE.txt"], source["project.godot"]
            )
            lines = result["directory"].joinpath("SHA256SUMS.txt").read_text().splitlines()
            self.assertIn(
                f"{hashlib.sha256(source['export.pck'].read_bytes()).hexdigest()}  MuddsShipyards.pck",
                lines,
            )

    def test_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self._inputs(root)
            kwargs = (source["export.exe"], root / "out", "1.0.0", "c" * 40, source["README.md"], source["LICENSE.txt"], source["project.godot"])
            assemble_distribution(*kwargs)
            with self.assertRaises(ValueError):
                assemble_distribution(*kwargs)


if __name__ == "__main__":
    unittest.main()
