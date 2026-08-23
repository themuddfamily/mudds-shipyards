import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

try:
    from .windows_portable_installer import InstallError, install_package, uninstall_package
except ImportError:
    from windows_portable_installer import InstallError, install_package, uninstall_package


class WindowsPortableInstallerTests(unittest.TestCase):
    def _package(self, root: Path, version: str = "MuddsShipyards-v1.2.3-abcdef1") -> Path:
        payload = {"MuddsShipyards.exe": b"exe", "README.md": b"readme", "LICENSE.txt": b"license"}
        sums = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n" for name, data in sorted(payload.items()))
        package = root / f"{version}.zip"
        with zipfile.ZipFile(package, "w") as archive:
            for name, data in payload.items():
                archive.writestr(f"{version}/{name}", data)
            archive.writestr(f"{version}/SHA256SUMS.txt", sums)
        return package

    def test_install_upgrade_rollback_and_owned_uninstall(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            package = self._package(root)
            destination = root / "MuddsShipyards"
            first = install_package(package, destination)
            self.assertTrue((destination / "MuddsShipyards.exe").is_file())
            (destination / "user-created.txt").write_text("keep", encoding="utf-8")
            upgraded = self._package(root, "MuddsShipyards-v1.2.4-fedcba9")
            result = install_package(upgraded, destination)
            self.assertTrue(Path(result["rollback"]).is_dir())
            self.assertEqual((Path(result["rollback"]) / "MuddsShipyards.exe").read_bytes(), b"exe")
            uninstalled = uninstall_package(destination)
            self.assertIn("MuddsShipyards.exe", uninstalled["removed"])
            self.assertTrue((destination / "user-created.txt").is_file())
            self.assertFalse((destination / ".mudds-owned.json").exists())

    def test_checksum_and_traversal_rejected_before_install(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            package = self._package(root)
            with zipfile.ZipFile(package, "a") as archive:
                archive.writestr("MuddsShipyards-v1.2.3-abcdef1/extra.bin", b"tampered")
            with self.assertRaises(InstallError):
                install_package(package, root / "destination")
            traversal = root / "traversal.zip"
            with zipfile.ZipFile(traversal, "w") as archive:
                archive.writestr("root/../escape.txt", b"escape")
            with self.assertRaises(InstallError):
                install_package(traversal, root / "destination")


if __name__ == "__main__":
    unittest.main()
