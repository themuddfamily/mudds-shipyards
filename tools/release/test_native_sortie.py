#!/usr/bin/env python3
"""Focused native-driver safety regressions; no Godot or display is launched."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('native_sortie', Path(__file__).with_name('run_native_sortie.py'))
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


class NativeSortieSafetyTests(unittest.TestCase):
    def test_launch_resumes_thrust_when_braking_stops_outside_waypoint(self):
        # Actual e159ac3 route stopped here for 240+ observations: the brake
        # margin is 5.75m but the unchanged waypoint acceptance radius is 5m.
        observation = {
            'frame': 3564, 'phase': 'TARGET_PRACTICE', 'player_id': 1, 'ship_id': 2,
            'default_sampler': True, 'tuning_unchanged': True, 'destroyed': False,
            'shot_accepted': False, 'command_fire': False, 'lease_free': True,
            'landed': False, 'position': [0, 7.50106, -72.49931],
            'parked': [0, 1.15, -10], 'velocity': [0, 0, 0],
            'camera': [0, 8, -69], 'right': [1, 0, 0], 'up': [0, 1, 0],
            'back': [0, 0, 1], 'tuning': {'mouse': .002, 'brake': 20},
        }
        pilot = native.Pilot()
        pilot.stage = 'launch'
        pilot.identities = (1, 2)
        keys, *_ = pilot.update(observation, 0)
        self.assertIn('w', keys)
        self.assertNotIn('Prior', keys)
        self.assertEqual(pilot.stage, 'launch')

        observation['velocity'] = [0, 0, -20]
        keys, *_ = pilot.update(observation, 1)
        self.assertIn('Prior', keys)
        self.assertNotIn('w', keys)
        observation.update(position=[0, 8, -74], velocity=[0, 0, 0])
        keys, *_ = pilot.update(observation, 2)
        self.assertIn('Prior', keys)
        self.assertEqual(pilot.stage, 'range')

    def test_engine_diagnostics_reject_an_otherwise_valid_observation(self):
        observation = native.PREFIX + b'{"frame": 12}'
        self.assertEqual(native.observations_from_lines([observation]), [{'frame': 12}])
        for diagnostic in [b'ERROR: renderer failed', b'WARNING: resource leaked',
                           b'  SCRIPT ERROR: invalid call',
                           b'ObjectDB instances leaked at exit',
                           b'\x1b[33mWARNING:\x1b[0m backend failure']:
            with self.subTest(diagnostic=diagnostic):
                with self.assertRaisesRegex(RuntimeError, 'diagnostic'):
                    native.observations_from_lines([diagnostic, observation])

    def test_shutdown_diagnostics_are_drained_including_unterminated_tail(self):
        with tempfile.TemporaryDirectory() as root:
            log = Path(root)/'game.log'
            log.write_bytes(native.PREFIX + b'{"frame": 12}\n')
            process = subprocess.Popen(
                [sys.executable, '-c', 'import sys; sys.stdout.write("WARNING: shutdown leak")'],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            try:
                process.wait(timeout=5)
                native.drain_game_output(process, log)
            finally:
                native.stop(process)
                process.stdout.close()
            self.assertEqual(native.diagnostic_lines(log.read_bytes().splitlines()),
                             [b'WARNING: shutdown leak'])

    def test_windows_and_symlink_inputs_are_rejected_before_launch(self):
        with tempfile.TemporaryDirectory() as root:
            exe = Path(root)/'game.exe'
            exe.write_bytes(b'MZ'+bytes(100))
            exe.chmod(0o700)
            with self.assertRaisesRegex(ValueError, 'PE/Wine'):
                native.validate_binary(exe)
            link = Path(root)/'game.x86_64'
            link.symlink_to('/bin/true')
            with self.assertRaisesRegex(ValueError, 'regular executable'):
                native.validate_binary(link)

    def test_input_helper_ipc_failure_still_reaps_helper(self):
        # A native Xlib failure may close IPC without a Python exception in the
        # helper. The supervisor must still run the bounded reaping path.
        desktop = object.__new__(native.Desktop)
        with patch.object(desktop, '_send', side_effect=EOFError('native helper exit')), \
                patch.object(desktop, '_reap') as reap:
            with self.assertRaises(EOFError):
                desktop.close()
            reap.assert_called_once()

    def test_failed_cleanup_still_attempts_other_child_and_removes_private_profile(self):
        with tempfile.TemporaryDirectory() as root:
            output = Path(root)/'result'
            profiles = []
            real_temporary = tempfile.TemporaryDirectory
            def private_profile(*args, **kwargs):
                temporary = real_temporary(*args, **kwargs)
                profiles.append(Path(temporary.name))
                return temporary
            with patch.object(native.tempfile, 'TemporaryDirectory', side_effect=private_profile), \
                    patch.object(native.subprocess, 'run', side_effect=RuntimeError('setup fault')), \
                    patch.object(native, 'stop', side_effect=[OSError('first cleanup fault'), None]) as stop:
                result = native.run(Path('/bin/true'), output)
            self.assertEqual(stop.call_count, 2)
            self.assertFalse(result['success'])
            self.assertEqual(result['cleanup_errors'], ['game: first cleanup fault'])
            self.assertTrue(all(not profile.exists() for profile in profiles))
            self.assertEqual(json.loads((output/'result.json').read_text()), result)
            self.assertEqual(result['cap_seconds'], 300)


if __name__ == '__main__':
    unittest.main()
