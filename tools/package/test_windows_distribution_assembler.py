import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.package.windows_distribution_assembler import assemble_distribution


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
            self.assertEqual(first["manifest"]["signing"], "NOT_RUN")
            self.assertEqual(first["manifest"]["native_validation"], "NOT_RUN")
            with zipfile.ZipFile(first["archive"]) as bundle:
                self.assertEqual(bundle.namelist(), sorted(bundle.namelist()))
                self.assertIn("MuddsShipyards-v1.2.3-aaaaaaa/MuddsShipyards.exe", bundle.namelist())

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
