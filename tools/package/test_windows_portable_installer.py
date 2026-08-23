import hashlib
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

try:
    from .windows_portable_installer import InstallError, install_package, main, rollback_package, uninstall_package
except ImportError:
    from windows_portable_installer import InstallError, install_package, main, rollback_package, uninstall_package


class WindowsPortableInstallerTests(unittest.TestCase):
    def _package(self, root: Path, version: str = "MuddsShipyards-v1.2.3-abcdef1", readme: bytes = b"readme", tag: str = "") -> Path:
        payload = {"MuddsShipyards.exe": version.encode(), "README.md": readme, "LICENSE.txt": b"license"}
        sums = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n" for name, data in sorted(payload.items()))
        package = root / f"{version}{tag}.zip"
        with zipfile.ZipFile(package, "w") as archive:
            for name, data in payload.items():
                archive.writestr(f"{version}/{name}", data)
            archive.writestr(f"{version}/SHA256SUMS.txt", sums)
            release_version = version.split("-", 2)[1]
            archive.writestr(f"{version}/distribution-manifest.json", '{"version": "%s", "source_commit": "%s"}' % (release_version, "a" * 40))
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
            self.assertEqual((Path(result["rollback"]) / "MuddsShipyards.exe").read_bytes(), b"MuddsShipyards-v1.2.3-abcdef1")
            rolled = rollback_package(destination)
            self.assertEqual((destination / "MuddsShipyards.exe").read_bytes(), b"MuddsShipyards-v1.2.3-abcdef1")
            self.assertEqual((Path(rolled["rollback"]) / "MuddsShipyards.exe").read_bytes(), b"MuddsShipyards-v1.2.4-fedcba9")
            uninstalled = uninstall_package(destination)
            self.assertIn("MuddsShipyards.exe", uninstalled["removed"])
            self.assertTrue((destination / "user-created.txt").is_file())
            self.assertFalse((destination / ".mudds-owned.json").exists())

    def test_rollback_rejects_tampered_preserved_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            destination = root / "MuddsShipyards"
            install_package(self._package(root, "MuddsShipyards-v1.2.3-abcdef1"), destination)
            install_package(self._package(root, "MuddsShipyards-v1.2.4-fedcba9"), destination)
            (destination.parent / ".MuddsShipyards.rollback" / "MuddsShipyards.exe").write_bytes(b"tampered")
            with self.assertRaises(InstallError):
                rollback_package(destination)

    def test_upgrade_policy_requires_force_for_downgrade_or_same_version_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            destination = root / "MuddsShipyards"
            install_package(self._package(root, "MuddsShipyards-v1.2.4-fedcba9"), destination)
            with self.assertRaises(InstallError):
                install_package(self._package(root, "MuddsShipyards-v1.2.3-abcdef1"), destination)
            same_version = self._package(root, "MuddsShipyards-v1.2.4-fedcba9", b"changed", "-changed")
            with self.assertRaises(InstallError):
                install_package(same_version, destination)
            install_package(same_version, destination, force=True)
            self.assertEqual((destination / "README.md").read_bytes(), b"changed")

    def test_cli_status_and_dry_run_are_explicit_and_non_mutating(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            destination = root / "MuddsShipyards"
            package = self._package(root)
            output = StringIO()
            with redirect_stdout(output):
                self.assertEqual(main(["install", str(package), str(destination)]), 0)
            before = (destination / "MuddsShipyards.exe").read_bytes()
            with redirect_stdout(StringIO()):
                self.assertEqual(main(["upgrade", str(package), str(destination), "--dry-run"]), 0)
                self.assertEqual(main(["status", str(destination)]), 0)
                self.assertEqual(main(["uninstall", str(destination), "--dry-run"]), 0)
            self.assertEqual((destination / "MuddsShipyards.exe").read_bytes(), before)

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
