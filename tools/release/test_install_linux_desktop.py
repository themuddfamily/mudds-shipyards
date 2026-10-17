#!/usr/bin/env python3
"""Filesystem-only checks; no executable, desktop handler or Godot is launched."""
import importlib.util
import io
import json
import os
from pathlib import Path
import select
import shlex
import signal
import subprocess
import sys
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

    def bundle(self, revision, extra=None, *, managed=False):
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
            if managed:
                content = Path(installer.__file__).read_bytes()
                member = tarfile.TarInfo(root + "/" + installer.BUNDLED_INSTALLER)
                member.size, member.mode = len(content), 0o755
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
        self.check_lifecycle(managed=False)

    def test_managed_bundle_quoted_launcher_update_and_owned_uninstall(self):
        self.check_lifecycle(managed=True)

    def check_lifecycle(self, *, managed):
        self.run_install(self.bundle("123abcd", managed=managed))
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
        updated = self.bundle("456def0", managed=managed)
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

    def test_manifest_publish_failure_rolls_back_first_install_and_update(self):
        original = installer.atomic_write
        def fail_manifest(path, content, *args, **kwargs):
            if path.name == installer.MANIFEST:
                raise OSError("simulated failed manifest publish")
            return original(path, content, *args, **kwargs)
        for updating in (False, True):
            with self.subTest(updating=updating):
                if updating:
                    self.run_install()
                before = self.snapshot()
                with mock.patch.object(installer, "atomic_write", side_effect=fail_manifest):
                    with self.assertRaisesRegex(OSError, "simulated"):
                        self.run_install(self.bundle("456def0"))
                self.assertEqual(before, self.snapshot())

    def cli_install(self, archive):
        return subprocess.run(
            [sys.executable, installer.__file__, "install", "--archive", str(archive),
             "--install-dir", str(self.install), "--applications-dir", str(self.applications)],
            capture_output=True, text=True, timeout=10)

    def kill_update_before_manifest(self, archive):
        # Only the child imports/runs the production manager. The wrapper blocks
        # at the exact cut after desktop replacement, before manifest publication.
        code = """import importlib.util, signal, sys
spec = importlib.util.spec_from_file_location("manager", sys.argv[1])
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)
original = manager.atomic_write
def cut(path, content, *args, **kwargs):
    if path.name == manager.MANIFEST:
        print("DESKTOP_PUBLISHED_MANIFEST_PENDING", flush=True)
        signal.pause()
    return original(path, content, *args, **kwargs)
manager.atomic_write = cut
raise SystemExit(manager.main(sys.argv[2:]))
"""
        child = subprocess.Popen(
            [sys.executable, "-c", code, installer.__file__, "install", "--archive", str(archive),
             "--install-dir", str(self.install), "--applications-dir", str(self.applications)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertTrue(select.select([child.stdout], [], [], 10)[0], "install cut timed out")
            self.assertEqual(child.stdout.readline().strip(), "DESKTOP_PUBLISHED_MANIFEST_PENDING")
            os.kill(child.pid, signal.SIGKILL)
            stdout, stderr = child.communicate(timeout=10)
            self.assertEqual(child.returncode, -signal.SIGKILL, (stdout, stderr))
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate(timeout=10)
            child.stdout.close()
            child.stderr.close()

    def cli_uninstall(self):
        return subprocess.run(
            [sys.executable, installer.__file__, "uninstall",
             "--install-dir", str(self.install), "--applications-dir", str(self.applications)],
            capture_output=True, text=True, timeout=10,
            env=dict(os.environ, XDG_DATA_HOME=str(self.root / "xdg-data")))

    def kill_uninstall_after_desktop(self):
        # The child performs a real unlink, then waits before any payload removal.
        code = """import importlib.util, signal, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("manager", sys.argv[1])
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)
original = Path.unlink
def cut(path, *args, **kwargs):
    result = original(path, *args, **kwargs)
    if path == Path(sys.argv[-1]) / manager.DESKTOP:
        print("DESKTOP_REMOVED_PAYLOAD_PENDING", flush=True)
        signal.pause()
    return result
Path.unlink = cut
raise SystemExit(manager.main(sys.argv[2:]))
"""
        child = subprocess.Popen(
            [sys.executable, "-c", code, installer.__file__, "uninstall",
             "--install-dir", str(self.install), "--applications-dir", str(self.applications)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            env=dict(os.environ, XDG_DATA_HOME=str(self.root / "xdg-data")))
        try:
            self.assertTrue(select.select([child.stdout], [], [], 10)[0], "uninstall cut timed out")
            self.assertEqual(child.stdout.readline().strip(), "DESKTOP_REMOVED_PAYLOAD_PENDING")
            os.kill(child.pid, signal.SIGKILL)
            stdout, stderr = child.communicate(timeout=10)
            self.assertEqual(child.returncode, -signal.SIGKILL, (stdout, stderr))
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate(timeout=10)
            child.stdout.close()
            child.stderr.close()

    def test_sigkill_uninstall_fresh_cli_retry_preserves_unrelated_files(self):
        self.run_install()
        state = self.state()
        runtime = self.install / state["generation"]
        root_notes = self.install / "personal-notes.txt"
        runtime_notes = runtime / "personal-notes.txt"
        other_entry = self.applications / "other-game.desktop"
        save = self.root / "xdg-data/godot/app_userdata/Mudds Shipyards/save.cfg"
        save.parent.mkdir(parents=True)
        retained = ((root_notes, "root notes"), (runtime_notes, "runtime notes"),
                    (other_entry, "other game"), (save, "precious save"))
        for path, content in retained:
            path.write_text(content)
        payload = {name: (runtime / name).read_bytes() for name in state["files"]}
        self.kill_uninstall_after_desktop()
        self.assertFalse((self.applications / installer.DESKTOP).exists())
        self.assertEqual(self.state(), state)
        self.assertEqual(json.loads((self.install / installer.UNINSTALL).read_text()),
                         {"owner": installer.OWNER, "state": state})
        for name, content in payload.items():
            self.assertEqual((runtime / name).read_bytes(), content)
        for _ in range(2):
            result = self.cli_uninstall()
            self.assertEqual(result.returncode, 0, result.stderr)
        for name in state["files"]:
            self.assertFalse((runtime / name).exists())
        for name in (installer.MANIFEST, installer.UNINSTALL, installer.UPDATE):
            self.assertFalse((self.install / name).exists())
        for path, content in retained:
            self.assertEqual(path.read_text(), content)

    def test_interrupted_uninstall_refuses_tampering_before_further_mutation(self):
        self.run_install()
        state = self.state()
        runtime = self.install / state["generation"]
        self.kill_uninstall_after_desktop()
        record = self.install / installer.UNINSTALL
        removal = json.loads(record.read_text())
        manifest = self.install / installer.MANIFEST
        desktop = self.applications / installer.DESKTOP
        invalid = dict(removal, state=dict(state, generation="../unrelated"))
        for path, changed, error in (
                (record, json.dumps(dict(removal, owner="someone else")).encode(),
                 "invalid uninstall ownership"),
                (record, json.dumps(invalid).encode(), "invalid installation manifest"),
                (manifest, b'{"owner": "someone else"}', "invalid installation manifest"),
                (manifest, None, "installation manifest missing"),
                (self.install / installer.UPDATE, b"{}", "pending install/update recovery"),
                (runtime / installer.ICON, b"changed surviving icon", "owned file changed"),
                (desktop, b"foreign launcher", "owned desktop entry changed")):
            with self.subTest(path=path, error=error):
                original = path.read_bytes() if path.exists() else None
                try:
                    if changed is None:
                        path.unlink()
                    else:
                        path.write_bytes(changed)
                    before = self.snapshot()
                    result = self.cli_uninstall()
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn(error, result.stderr)
                    self.assertEqual(self.snapshot(), before)
                finally:
                    if original is None:
                        path.unlink(missing_ok=True)
                    else:
                        path.write_bytes(original)
        before = self.snapshot()
        result = self.cli_install(self.bundle("456def0"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("pending uninstall recovery", result.stderr)
        self.assertEqual(self.snapshot(), before)
        # Without the verified intent, a missing launcher remains an error.
        saved = self.root / "saved-uninstall.json"
        record.rename(saved)
        before = self.snapshot()
        result = self.cli_uninstall()
        self.assertEqual(result.returncode, 1)
        self.assertIn("owned desktop entry changed or missing", result.stderr)
        self.assertEqual(self.snapshot(), before)
        record.symlink_to(saved)
        before = self.snapshot()
        result = self.cli_uninstall()
        self.assertEqual(result.returncode, 1)
        self.assertIn("refusing symlink path", result.stderr)
        self.assertEqual(self.snapshot(), before)
        record.unlink()
        saved.rename(record)
        # A valid intent also covers payload files removed before a second death.
        (runtime / state["executable"]).unlink()
        icon = runtime / installer.ICON
        original_icon = icon.read_bytes()
        icon.write_bytes(b"changed last surviving icon")
        before = self.snapshot()
        result = self.cli_uninstall()
        self.assertEqual(result.returncode, 1)
        self.assertIn("owned file changed", result.stderr)
        self.assertEqual(self.snapshot(), before)
        icon.write_bytes(original_icon)
        result = self.cli_uninstall()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.install.exists())

    def test_sigkill_first_install_fresh_cli_retry_preserves_saves_and_untracked_files(self):
        self.install.mkdir()
        save = self.install / "profiles" / "save.cfg"
        save.parent.mkdir()
        save.write_text("precious save")
        self.applications.mkdir()
        unrelated = self.applications / "other-game.desktop"
        unrelated.write_text("other game")
        self.kill_update_before_manifest(self.archive)
        self.assertFalse((self.install / installer.MANIFEST).exists())
        update = json.loads((self.install / installer.UPDATE).read_text())
        self.assertIsNone(update["previous"])
        pending = update["pending"]
        pending_runtime = self.install / pending["generation"]
        self.assertEqual((self.applications / installer.DESKTOP).read_bytes(),
                         installer.desktop_bytes(pending_runtime, pending["executable"]))
        notes = pending_runtime / "personal-notes.txt"
        notes.write_text("interrupted install notes")
        result = self.cli_install(self.bundle("a7b8c9d"))
        self.assertEqual(result.returncode, 0, result.stderr)
        current = installer.read_install(self.install, self.applications)
        self.assertEqual(current["executable"], "MuddsShipyards-a7b8c9d.x86_64")
        self.assertEqual((self.install / current["generation"] / current["executable"]).read_bytes(),
                         b"\x7fELFa7b8c9d")
        self.assertFalse((self.install / installer.UPDATE).exists())
        for name in pending["files"]:
            self.assertFalse((pending_runtime / name).exists())
        for path, content in ((save, "precious save"), (notes, "interrupted install notes"),
                              (unrelated, "other game")):
            self.assertEqual(path.read_text(), content)

    def test_interrupted_first_install_refuses_tampered_recovery_inputs_without_mutation(self):
        self.kill_update_before_manifest(self.archive)
        record = self.install / installer.UPDATE
        update = json.loads(record.read_text())
        invalid = dict(update, pending=dict(update["pending"], generation="../unrelated"))
        pending_icon = self.install / update["pending"]["generation"] / installer.ICON
        for path, changed, error in (
                (record, json.dumps(dict(update, owner="someone else")).encode(), "invalid update ownership"),
                (record, json.dumps(invalid).encode(), "invalid installation manifest"),
                (pending_icon, b"changed pending icon", "owned file changed"),
                (self.applications / installer.DESKTOP, b"unrelated launcher", "owned desktop entry changed")):
            with self.subTest(path=path, error=error):
                original = path.read_bytes()
                try:
                    path.write_bytes(changed)
                    before = self.snapshot()
                    result = self.cli_install(self.bundle("a7b8c9d"))
                    self.assertEqual(result.returncode, 1)
                    self.assertIn(error, result.stderr)
                    self.assertEqual(self.snapshot(), before)
                finally:
                    path.write_bytes(original)
        saved_record = self.root / "saved-install.json"
        record.rename(saved_record)
        record.symlink_to(saved_record)
        before = self.snapshot()
        result = self.cli_install(self.bundle("a7b8c9d"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("refusing symlink path", result.stderr)
        self.assertTrue(record.is_symlink())
        self.assertEqual(self.snapshot(), before)

    def test_sigkill_update_fresh_cli_retry_preserves_saves_and_untracked_files(self):
        self.run_install()
        previous = self.state()
        previous_runtime = self.install / previous["generation"]
        save = self.install / "profiles" / "save.cfg"
        save.parent.mkdir()
        save.write_text("precious save")
        previous_notes = previous_runtime / "personal-notes.txt"
        previous_notes.write_text("old notes")
        unrelated = self.applications / "other-game.desktop"
        unrelated.write_text("other game")
        self.kill_update_before_manifest(self.bundle("456def0"))
        self.assertEqual(self.state(), previous)
        update = json.loads((self.install / installer.UPDATE).read_text())
        pending = update["pending"]
        pending_runtime = self.install / pending["generation"]
        self.assertEqual((self.applications / installer.DESKTOP).read_bytes(),
                         installer.desktop_bytes(pending_runtime, pending["executable"]))
        pending_notes = pending_runtime / "user-notes.txt"
        pending_notes.write_text("interrupted update notes")
        # Retry with an even newer checkpoint: recovery must not pin the killed version.
        result = self.cli_install(self.bundle("a7b8c9d"))
        self.assertEqual(result.returncode, 0, result.stderr)
        current = installer.read_install(self.install, self.applications)
        self.assertEqual(current["executable"], "MuddsShipyards-a7b8c9d.x86_64")
        self.assertEqual((self.install / current["generation"] / current["executable"]).read_bytes(),
                         b"\x7fELFa7b8c9d")
        self.assertFalse((self.install / installer.UPDATE).exists())
        for state in (previous, pending):
            for name in state["files"]:
                self.assertFalse((self.install / state["generation"] / name).exists())
        for path, content in ((save, "precious save"), (previous_notes, "old notes"),
                              (pending_notes, "interrupted update notes"), (unrelated, "other game")):
            self.assertEqual(path.read_text(), content)

    def test_interrupted_update_refuses_tampered_recovery_inputs_without_mutation(self):
        self.run_install()
        self.kill_update_before_manifest(self.bundle("456def0"))
        record = self.install / installer.UPDATE
        update = json.loads(record.read_text())
        invalid = dict(update, pending=dict(update["pending"], generation="../unrelated"))
        pending_icon = self.install / update["pending"]["generation"] / installer.ICON
        previous_icon = self.install / update["previous"]["generation"] / installer.ICON
        for path, changed, error in (
                (record, json.dumps(invalid).encode(), "invalid installation manifest"),
                (pending_icon, b"changed pending icon", "owned file changed"),
                (previous_icon, b"changed old icon", "owned file changed"),
                (self.applications / installer.DESKTOP, b"user edited launcher", "owned desktop entry changed")):
            with self.subTest(path=path):
                original = path.read_bytes()
                try:
                    path.write_bytes(changed)
                    before = self.snapshot()
                    result = self.cli_install(self.bundle("a7b8c9d"))
                    self.assertEqual(result.returncode, 1)
                    self.assertIn(error, result.stderr)
                    self.assertEqual(self.snapshot(), before)
                finally:
                    path.write_bytes(original)
        # A recovery record symlink is refused even when it contains valid data.
        saved_record = self.root / "saved-update.json"
        record.rename(saved_record)
        record.symlink_to(saved_record)
        before = self.snapshot()
        result = self.cli_install(self.bundle("a7b8c9d"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("refusing symlink path", result.stderr)
        self.assertTrue(record.is_symlink())
        self.assertEqual(self.snapshot(), before)

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
                           ("MuddsShipyards-123abcd/install_linux_desktop.py.bak", tarfile.REGTYPE),
                           ("MuddsShipyards-123abcd/install-desktop-entry.sh", tarfile.REGTYPE),
                           ("MuddsShipyards-123abcd/link", tarfile.SYMTYPE),
                           ("MuddsShipyards-123abcd/hardlink", tarfile.LNKTYPE)):
            member = tarfile.TarInfo(name)
            member.type, member.size, member.linkname = kind, (1 if kind == tarfile.REGTYPE else 0), "/tmp"
            extras.append(member)
        for managed in (False, True):
            for extra in extras:
                with self.subTest(extra=extra.name, managed=managed):
                    archive = self.bundle("123abcd", extra, managed=managed)
                    with self.assertRaises(installer.InstallError):
                        self.run_install(archive)
                    self.assertEqual(before, self.snapshot())
        duplicate = tarfile.TarInfo("MuddsShipyards-123abcd/" + installer.BUNDLED_INSTALLER)
        duplicate.size = 1
        with self.assertRaisesRegex(installer.InstallError, "five or six|duplicate"):
            self.run_install(self.bundle("123abcd", duplicate, managed=True))
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
