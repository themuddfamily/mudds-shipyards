"""Focused prelaunch rejection and guest non-injection guards; no engine/device/display.

Run: python3 -m unittest discover -s tests/network -p test_physical_browser_guest_driver.py
This executes the exact embedded preflight using temporary filesystem identities.
A pass is source/config coverage, never physical-controller qualification.
"""
import hashlib
import os
from pathlib import Path
import stat
import struct
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
DRIVER = ROOT / 'tests/network/physical_browser_guest_driver.gd'
HARNESS = ROOT / 'tests/network/game_flow_server_browser_integration_test.gd'
SOURCE = DRIVER.read_text()
PREFLIGHT = SOURCE.split('const PREFLIGHT := r"""', 1)[1].split('"""', 1)[0]
NAMESPACE = {'__name__': 'physical_browser_config_test'}
exec(compile(PREFLIGHT, str(DRIVER), 'exec'), NAMESPACE)


class PhysicalBrowserConfigurationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.auth = self.base / 'auth' / 'Xauthority'
        self.auth.parent.mkdir(mode=0o700)
        self.auth.write_bytes(self.cookie('247'))
        self.auth.chmod(0o600)
        self.exe = self.base / 'godot'
        self.exe.write_bytes(b'bound engine candidate')
        self.proc = self.base / 'proc' / '12345'
        self.proc.mkdir(parents=True)
        self.proc.joinpath('stat').write_text('12345 (Xorg) ' + ' '.join(['S'] + ['0'] * 18 + ['654321']))
        self.proc.joinpath('cmdline').write_bytes(b'/usr/lib/xorg/Xorg\0:247\0-listen\0tcp\0')
        self.proc.joinpath('exe').symlink_to('/usr/lib/xorg/Xorg')
        self.device = self.base / 'devices' / 'pci' / 'usb' / 'input0'
        self.device.mkdir(parents=True)
        self.device.joinpath('id').mkdir()
        self.device.joinpath('id/vendor').write_text('045e\n')
        self.device.joinpath('id/product').write_text('028e\n')
        self.device.joinpath('name').write_text('Physical example controller\n')
        self.sys = self.base / 'sys/class/input/event0'
        self.sys.mkdir(parents=True)
        self.sys.joinpath('device').symlink_to(self.device)
        self.config = dict(display='127.0.0.1:247', xauthority=str(self.auth), display_pid=12345,
                           display_start_ticks='654321', device_node='/dev/input/event0',
                           device_sysfs=str(self.device), device_guid='0' * 32,
                           device_name='Physical example controller', vendor_id=0x045e,
                           product_id=0x028e, backend='SDL3/linux-evdev', source_commit='a' * 40,
                           executable_sha256=hashlib.sha256(self.exe.read_bytes()).hexdigest())
        real_path = Path
        real_stat = Path.stat

        def route_path(value, *args):
            if str(value) == '/proc':
                return self.base / 'proc'
            if str(value) == '/sys/class/input':
                return self.base / 'sys/class/input'
            return real_path(value, *args)

        def route_stat(path, *args, **kwargs):
            if str(path) == '/dev/input/event0':
                return types.SimpleNamespace(st_mode=stat.S_IFCHR | 0o660)
            return real_stat(path, *args, **kwargs)

        for mocker in [patch.object(NAMESPACE['pathlib'], 'Path', side_effect=route_path),
                       patch.object(Path, 'stat', route_stat),
                       patch.object(NAMESPACE['subprocess'], 'check_output', side_effect=lambda argv, **kw: 'a' * 40 + '\n' if 'rev-parse' in argv else ''),
                       patch.dict(os.environ, {}, clear=True)]:
            mocker.start()
            self.addCleanup(mocker.stop)

    @staticmethod
    def cookie(display):
        fields = [b'\x7f\x00\x00\x01', display.encode(), b'MIT-MAGIC-COOKIE-1', b'c' * 16]
        return struct.pack('>H', 0) + b''.join(struct.pack('>H', len(field)) + field for field in fields)

    def check(self, config=None, guest_pid=0):
        return NAMESPACE['check'](self.config if config is None else config, str(self.base), str(self.exe), guest_pid)

    def test_explicit_complete_binding_is_accepted_without_opening_display_or_device(self):
        self.assertEqual(self.check(), self.config)

    def test_each_required_binding_is_mandatory(self):
        for key in self.config:
            with self.subTest(key=key):
                candidate = dict(self.config)
                del candidate[key]
                with self.assertRaisesRegex(ValueError, 'missing'):
                    self.check(candidate)

    def test_active_or_implicit_display_is_rejected(self):
        for display in [':0', ':247', 'localhost:247', '127.0.0.1:0', '127.0.0.1:60000', '']:
            with self.subTest(display=display), self.assertRaisesRegex(ValueError, 'DISPLAY'):
                self.check(dict(self.config, display=display))
        os.environ['DISPLAY'] = self.config['display']
        with self.assertRaisesRegex(ValueError, 'coordinator'):
            self.check()

    def test_unknown_backend_and_missing_real_controller_identity_are_rejected(self):
        for change in [dict(backend='claimed physical'), dict(device_guid=''), dict(device_name=''), dict(vendor_id=0), dict(product_id='654')]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.check(dict(self.config, **change))

    def test_wrong_authority_cookie_and_permissions_are_rejected(self):
        self.auth.write_bytes(self.cookie('248'))
        with self.assertRaisesRegex(ValueError, 'matching display cookie'):
            self.check()
        self.auth.write_bytes(self.cookie('247'))
        self.auth.chmod(0o644)
        with self.assertRaisesRegex(ValueError, '0600'):
            self.check()

    def test_reused_display_pid_and_wrong_event_identity_are_rejected(self):
        for change in [dict(display_start_ticks='654322'), dict(device_sysfs=str(self.base)),
                       dict(device_name='Different controller'), dict(vendor_id=0x1234)]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.check(dict(self.config, **change))

    def test_candidate_executable_source_mismatch_and_dirty_source_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            self.check(dict(self.config, executable_sha256='b' * 64))
        with self.assertRaisesRegex(ValueError, 'clean commit'):
            self.check(dict(self.config, source_commit='b' * 40))
        with patch.object(NAMESPACE['subprocess'], 'check_output', side_effect=['a' * 40, ' M changed.gd']):
            with self.assertRaisesRegex(ValueError, 'clean commit'):
                self.check()

    def test_guest_requires_its_actual_sdl_process_to_hold_bound_event_node(self):
        os.environ.update(DISPLAY=self.config['display'], XAUTHORITY=str(self.auth), SDL_JOYSTICK_HIDAPI='0')
        descriptors = self.base / 'proc/54321/fd'
        descriptors.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, 'no open bound event device'):
            self.check(guest_pid=54321)
        descriptors.joinpath('5').symlink_to('/dev/input/event0')
        self.assertEqual(self.check(guest_pid=54321), self.config)
        os.environ['SDL_JOYSTICK_HIDAPI'] = '1'
        with self.assertRaisesRegex(ValueError, 'Linux event backend'):
            self.check(guest_pid=54321)


class PhysicalBrowserSourceGuardTest(unittest.TestCase):
    def test_passive_guest_has_no_focus_or_input_injection(self):
        for forbidden in ['grab_focus(', 'Input.action_press(', 'Input.action_release(',
                          'Input.parse_input_event(', '.pressed.emit(']:
            self.assertNotIn(forbidden, SOURCE)
        self.assertIn('event is InputEventAction', SOURCE)
        self.assertIn('event is InputEventKey and event.pressed', SOURCE)
        self.assertIn('event is InputEventMouseButton and event.pressed', SOURCE)
        self.assertIn('event.device != device or not identity_matches()', SOURCE)
        self.assertIn('pressed.connect(callback, CONNECT_ONE_SHOT)', SOURCE)

    def test_existing_synthetic_mode_cannot_acquire_physical_label(self):
        harness = HARNESS.read_text()
        release = harness.split('func _live_release_movement() -> void:', 1)[1].split('\n\nfunc ', 1)[0]
        self.assertLess(release.index('if _live_is_physical_guest():'), release.index('Input.parse_input_event('))
        self.assertIn('"--live-menu-physical-controller" in args', harness)
        self.assertIn('SDL_JOYSTICK_BLACKLIST_DEVICES=0x%04x/0x%04x', harness)
        self.assertIn('Input.get_connected_joypads().is_empty()', harness)
        launch = harness.split('func _live_spawn_physical_guest(', 1)[1].split('\n\nfunc ', 1)[0]
        self.assertNotIn('--disable-render-loop', launch)
        self.assertNotIn('"dummy"', launch)
        self.assertIn('"--audio-driver", "Dummy"', launch)
        self.assertIn('"--display-driver", "x11"', launch)


if __name__ == '__main__':
    unittest.main()
