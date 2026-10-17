#!/usr/bin/env python3
"""Filesystem-only checks; no executable, desktop handler or Godot is launched."""
import importlib.util
import io
import json
from pathlib import Path
import shlex
import tarfile
import tempfile
import unittest
from unittest import mock

try:
    from gi.repository import Gio, GLib
except ImportError:
    Gio = GLib = None


SPEC = importlib.util.spec_from_file_location("installer", Path(__file__).with_name("install_linux_desktop.py"))
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class DesktopInstallTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mudds-desktop-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.install = self.root / 'game folder % " $ ` \\ with spaces'
        self.applications = self.root / "applications folder"
        self.archive = self.bundle("123abcd")

    def bundle(self, revision, extra=None):
        path = self.root / (revision + ".tar.gz")
        root = "MuddsShipyards-" + revision
        with tarfile.open(path, "w:gz") as archive:
            directory = tarfile.TarInfo(root)
            directory.type = tarfile.DIRTYPE
            directory.mode = 0o755
            archive.addfile(directory)
            for name, content, mode in (
                (root + ".x86_64", b"\x7fELF" + revision.encode(), 0o755),
                (installer.ICON, b"\x89PNG\r\n\x1a\nicon", 0o644),
                (installer.DESKTOP, b"[Desktop Entry]\n", 0o755),
                ("install-desktop-entry.sh", b"#!/bin/sh\n", 0o755),
            ):
                member = tarfile.TarInfo(root + "/" + name)
                member.size, member.mode = len(content), mode
                archive.addfile(member, io.BytesIO(content))
            if extra is not None:
                archive.addfile(extra, io.BytesIO(b"x") if extra.isfile() else None)
        return path

    def run_install(self, archive=None):
        installer.install(archive or self.archive, self.install, self.applications)

    def state(self):
        return json.loads((self.install / installer.MANIFEST).read_text())

    def snapshot(self):
        return {str(path.relative_to(self.root)): (path.read_bytes(), path.stat().st_mode)
                for parent in (self.install, self.applications) if parent.exists()
                for path in parent.rglob("*") if path.is_file()}

    def test_install_quoted_launcher_update_and_owned_uninstall(self):
        self.run_install()
        state = self.state()
        runtime = self.install / state["generation"]
        executable = runtime / state["executable"]
        self.assertEqual(executable.read_bytes(), b"\x7fELF123abcd")
        self.assertEqual(executable.stat().st_mode & 0o777, 0o755)
        desktop = (self.applications / installer.DESKTOP).read_text()
        exec_value = next(line[5:] for line in desktop.splitlines() if line.startswith("Exec="))
        # First undo Desktop Entry string escaping, then quoted Exec argument rules.
        string_layer = exec_value.replace("\\\\", "\\")
        # shlex preserves escapes on $/`; no shell expansion is performed.
        arguments = shlex.split(string_layer)
        self.assertEqual(arguments[:2], ["/usr/bin/env", "--"])
        argument = arguments[2].replace(r"\$", "$").replace(r"\`", "`").replace("%%", "%")
        self.assertEqual(argument, str(executable))
        self.assertIn("Path=" + str(runtime).replace("\\", "\\\\") + "\n", desktop)
        self.assertIn("Icon=" + str(runtime / installer.ICON).replace("\\", "\\\\") + "\n", desktop)
        unrelated = self.install / "my-profile" / "save.cfg"
        unrelated.parent.mkdir()
        unrelated.write_text("precious save")
        extra_runtime = runtime / "personal-notes.txt"
        extra_runtime.write_text("retain")
        unrelated_entry = self.applications / "other-game.desktop"
        unrelated_entry.write_text("other game")
        updated = self.bundle("456def0")
        self.run_install(updated)
        self.assertEqual(unrelated.read_text(), "precious save")
        self.assertEqual(extra_runtime.read_text(), "retain")
        self.assertFalse(executable.exists())
        new_state = self.state()
        new_runtime = self.install / new_state["generation"]
        self.assertEqual((new_runtime / new_state["executable"]).read_bytes(), b"\x7fELF456def0")
        installer.uninstall(self.install, self.applications)
        installer.uninstall(self.install, self.applications)
        self.assertFalse((self.applications / installer.DESKTOP).exists())
        self.assertFalse((self.install / installer.MANIFEST).exists())
        self.assertFalse(new_runtime.exists())
        self.assertEqual(unrelated.read_text(), "precious save")
        self.assertEqual(extra_runtime.read_text(), "retain")
        self.assertEqual(unrelated_entry.read_text(), "other game")

    @unittest.skipIf(Gio is None, "optional PyGObject desktop parser is unavailable")
    def test_gio_consumes_reserved_character_launcher_without_launching(self):
        self.run_install()
        state = self.state()
        runtime = self.install / state["generation"]
        executable = runtime / state["executable"]
        app = Gio.DesktopAppInfo.new_from_filename(str(self.applications / installer.DESKTOP))
        self.assertIsNotNone(app)
        success, arguments = GLib.shell_parse_argv(app.get_commandline())
        self.assertTrue(success)
        self.assertEqual(arguments[:2], ["/usr/bin/env", "--"])
        self.assertEqual(arguments[2].replace("%%", "%"), str(executable))
        self.assertEqual(app.get_string("Path"), str(runtime))
        self.assertEqual(app.get_string("Icon"), str(runtime / installer.ICON))

    def test_competing_prefix_cannot_overwrite_launcher_after_preflight(self):
        original = installer.atomic_write
        def competing_entry(path, content, *args, **kwargs):
            if path.name == installer.DESKTOP:
                path.write_text("another installation won the race")
            return original(path, content, *args, **kwargs)
        with mock.patch.object(installer, "atomic_write", side_effect=competing_entry):
            with self.assertRaises(FileExistsError):
                self.run_install()
        self.assertEqual((self.applications / installer.DESKTOP).read_text(),
                         "another installation won the race")
        self.assertEqual(list(self.install.iterdir()), [])

    def test_update_publish_failure_rolls_back(self):
        self.run_install()
        before = self.snapshot()
        original = installer.atomic_write
        def fail_manifest(path, content, *args, **kwargs):
            if path.name == installer.MANIFEST:
                raise OSError("simulated failed manifest publish")
            return original(path, content, *args, **kwargs)
        with mock.patch.object(installer, "atomic_write", side_effect=fail_manifest):
            with self.assertRaisesRegex(OSError, "simulated"):
                self.run_install(self.bundle("456def0"))
        self.assertEqual(before, self.snapshot())

    def test_refuses_unrelated_launcher_and_modified_owned_files(self):
        self.applications.mkdir()
        desktop = self.applications / installer.DESKTOP
        desktop.write_text("unrelated")
        with self.assertRaisesRegex(installer.InstallError, "unrelated"):
            self.run_install()
        self.assertFalse(self.install.exists())
        desktop.unlink()
        self.run_install()
        state = self.state()
        (self.install / state["generation"] / installer.ICON).write_text("user changed icon")
        before = self.snapshot()
        with self.assertRaisesRegex(installer.InstallError, "changed"):
            self.run_install(self.bundle("456def0"))
        with self.assertRaisesRegex(installer.InstallError, "changed"):
            installer.uninstall(self.install, self.applications)
        self.assertEqual(before, self.snapshot())

    def test_archive_refusals_leave_existing_install_unchanged(self):
        self.run_install()
        before = self.snapshot()
        extras = []
        for name, kind in (("../escape", tarfile.REGTYPE),
                           ("MuddsShipyards-123abcd/other.x86_64", tarfile.REGTYPE),
                           ("MuddsShipyards-123abcd/link", tarfile.SYMTYPE),
                           ("MuddsShipyards-123abcd/hardlink", tarfile.LNKTYPE)):
            member = tarfile.TarInfo(name)
            member.type, member.size, member.linkname = kind, (1 if kind == tarfile.REGTYPE else 0), "/tmp"
            extras.append(member)
        for extra in extras:
            with self.subTest(extra=extra.name):
                archive = self.bundle("123abcd", extra)
                with self.assertRaises(installer.InstallError):
                    self.run_install(archive)
                self.assertEqual(before, self.snapshot())
        corrupt = self.root / "corrupt.tar.gz"
        self.bundle("123abcd")
        data = self.archive.read_bytes()
        corrupt.write_bytes(data[:-5])
        with self.assertRaises((EOFError, tarfile.TarError, OSError)):
            self.run_install(corrupt)
        self.assertEqual(before, self.snapshot())

    def test_symlink_destination_and_invalid_manifest_refused(self):
        real = self.root / "real"
        real.mkdir()
        self.install.symlink_to(real, target_is_directory=True)
        with self.assertRaisesRegex(installer.InstallError, "symlink"):
            self.run_install()
        self.assertEqual(list(real.iterdir()), [])
        self.install.unlink()
        self.run_install()
        manifest = self.install / installer.MANIFEST
        manifest.write_text('{"owner": "someone else"}')
        before = self.snapshot()
        with self.assertRaisesRegex(installer.InstallError, "manifest"):
            installer.uninstall(self.install, self.applications)
        self.assertEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main()
