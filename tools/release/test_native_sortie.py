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
    def walk_observation(self):
        return {'frame': 100, 'phase': 'APPROACH_SHIP', 'player_id': 1,
                'position': [0, 1.15, -10], 'player': [0, 0, 15.5],
                'seated': False, 'control_enabled': True,
                'walk_right': [1, 0, 0], 'walk_forward': [0, 0, -1],
                'sandbox': {'fleet': {key: {'ship_id': index + 2, 'piloted': False,
                    'destroyed': False, 'parked_exact': True, 'default_sampler': True,
                    'tuning_unchanged': True} for index, key in enumerate(sorted(native.SandboxWalkPilot.FLEET))},
                    'doors': [], 'grounded': True, 'walk_mouse': .0025}}

    def full_observation(self):
        s = self.walk_observation()
        s.update(transition_busy=False, back=[0, 0, 1], menu_ready=False)
        s['sandbox']['station_candidate'] = {}
        for craft in s['sandbox']['fleet'].values():
            craft.update(position=[0, 1, 0], parked=[0, 1, 0], velocity=[0, 0, 0],
                         capture_position=[0, 10, -18], back=[0, 0, 1],
                         boarding=[0, 0, 0], exit=[0, 0, 0],
                         telemetry={'engine': 'OFFLINE', 'hull': 100}, landed=True,
                         lease=True, lease_free=False, contract=True, capture=True,
                         active_ship=False, candidate=False, regeneration_pending=False)
        return s

    def test_full_route_acknowledges_mouse_before_repeating_sweep(self):
        pilot = native.SandboxPilot()
        pilot.stage = 'walk_station'
        s = self.full_observation()
        s['player'] = [-8.5, 0, 11]
        first = pilot.update(s, 1)
        self.assertNotEqual(first[1], 0)
        s = dict(s, frame=s['frame']+1)
        self.assertEqual(pilot.update(s, 1.02)[1], 0)
        s = dict(s, frame=s['frame']+1)
        s['walk_forward'] = [.3, 0, -.95]
        self.assertNotEqual(pilot.update(s, 1.04)[1], 0)

    def test_full_route_boarding_press_does_not_activate_a_station_prompt(self):
        pilot = native.SandboxPilot()
        s = self.full_observation()
        pilot.update(s, 1)
        pilot.stage = 'craft_approach'
        pilot.craft_key = 'arrow_provisional'
        s['sandbox']['fleet'][pilot.craft_key]['candidate'] = True
        s['sandbox']['station_candidate'] = {'position': [1, 0, 15.5]}
        keys, dx, *_ = pilot.update(dict(s, frame=101), 1.02)
        self.assertNotIn('e', keys)
        self.assertNotEqual(dx, 0)
        self.assertEqual(pilot.stage, 'craft_approach')
        s['sandbox']['station_candidate'] = {}
        keys, *_ = pilot.update(dict(s, frame=102), 1.04)
        self.assertIn('e', keys)
        self.assertEqual(pilot.stage, 'craft_board')

    def test_full_route_does_not_exempt_unplanned_recovery_during_a_foot_leg(self):
        pilot = native.SandboxPilot()
        s = self.full_observation()
        pilot.update(s, 1)
        pilot.stage = 'craft_approach'
        with self.assertRaisesRegex(AssertionError, 'unplanned control or recovery'):
            pilot.update(dict(s, frame=101, control_enabled=False, transition_busy=True,
                              phase='RECOVERING'), 1.02)

    def test_full_route_rejects_replaced_or_cached_active_craft_during_acceptance(self):
        pilot = native.SandboxPilot()
        s = self.full_observation()
        pilot.update(s, 1)
        pilot.stage = 'craft_shutdown'
        pilot.craft_key = 'arrow_provisional'
        with self.assertRaisesRegex(AssertionError, 'same active craft'):
            pilot.update(dict(s, frame=101), 1.02)
        s['sandbox']['fleet'][pilot.craft_key].update(active_ship=True, details_current=False)
        with self.assertRaisesRegex(AssertionError, 'fresh live active-craft'):
            pilot.update(dict(s, frame=102), 1.04)

    def test_full_route_rejects_teleport_between_ordinary_foot_sublegs(self):
        pilot = native.SandboxPilot()
        s = self.full_observation()
        pilot.update(s, 1)
        # A distinct full-route leg must not bypass the walk continuity fence.
        pilot.stage = 'recovery_walk'
        s['frame'] += 1
        s['player'] = [100, 0, 15.5]
        with self.assertRaisesRegex(AssertionError, 'recovery teleport'):
            pilot.update(s, 1.02)

    def test_full_route_continues_after_fleet_dock_instead_of_claiming_walk_success(self):
        pilot = native.SandboxPilot()
        s = self.full_observation()
        pilot.update(s, 1)
        pilot.stage = 'return_walk'
        pilot.index = len(pilot.WAYPOINTS)
        pilot.craft_key = 'bulwark_heavy_gunship'
        s['sandbox']['fleet'][pilot.craft_key].update(active_ship=True, details_current=True)
        pilot.resume_target = pilot.WAYPOINTS[-1][1]
        pilot.update(dict(s, frame=101), 1.02)
        self.assertEqual(pilot.stage, 'craft_approach')
        self.assertEqual(pilot.craft_key, 'cinder_cargo_hauler')
        self.assertIsNone(pilot.result)

    def test_scoped_walk_cannot_claim_full_sandbox_gate(self):
        pilot = native.SandboxWalkPilot()
        pilot.stage = 'walk_station'
        pilot.index = len(pilot.WAYPOINTS) - 1
        pilot.door_opened = True
        observation = self.walk_observation()
        observation['player'] = pilot.WAYPOINTS[-1][1]
        keys, dx, dy, fire = pilot.update(observation, 1)
        self.assertEqual((keys, dx, dy, fire), (set(), 0, 0, False))
        self.assertEqual(pilot.result['gate_c_sandbox'], 'NOT_COMPLETED')
        self.assertIn('deliberate crash', pilot.result['remaining'])
        self.assertEqual(native.CAP, 300)

    def test_walk_uses_clear_deck_around_parked_tow_tractor(self):
        points = dict(native.SandboxWalkPilot.WAYPOINTS)
        self.assertEqual(points['tractor_forward_clearance'], [6, 0, 12.5])
        self.assertEqual(points['tractor_return_forward'], [6, 0, 12.5])
        # The actual package stopped against the tractor at this position.
        observation = self.walk_observation()
        observation['player'] = [.217133, -.019863, 15.594910]
        observation['walk_forward'] = [0, 0, -1]
        pilot = native.SandboxWalkPilot()
        pilot.stage = 'walk_station'
        pilot.index = 1
        keys, *_ = pilot.update(observation, 1)
        self.assertIn('w', keys)
        self.assertIsNone(pilot.result)

    def test_walk_rejects_unobserved_or_mutated_fleet_and_recovery_teleport(self):
        pilot = native.SandboxWalkPilot()
        observation = self.walk_observation()
        del observation['sandbox']
        with self.assertRaisesRegex(AssertionError, 'observer available'):
            pilot.update(observation, 1)
        observation = self.walk_observation()
        observation['sandbox']['fleet']['arrow_provisional']['default_sampler'] = False
        with self.assertRaisesRegex(AssertionError, 'authored controls'):
            pilot.update(observation, 1)
        pilot = native.SandboxWalkPilot()
        pilot.stage = 'walk_station'
        observation = self.walk_observation()
        pilot.update(observation, 1)
        observation = self.walk_observation()
        observation.update(frame=101, player=[100, 0, 15.5])
        with self.assertRaisesRegex(AssertionError, 'recovery teleport'):
            pilot.update(observation, 2)

    def test_walk_opens_only_the_actual_closed_door_candidate(self):
        observation = self.walk_observation()
        observation['player'] = [46, 0, 15.5]
        observation['walk_forward'] = [1, 0, 0]
        observation['walk_right'] = [0, 0, 1]
        observation['sandbox']['doors'] = [{'position': [49, 0, 15.5],
                                          'open': False, 'candidate': False}]
        for candidate, expected in [(False, False), (True, True)]:
            pilot = native.SandboxWalkPilot()
            pilot.stage = 'walk_station'
            pilot.index = next(i for i, point in enumerate(pilot.WAYPOINTS) if point[0] == 'habitat_threshold')
            observation['sandbox']['doors'][0]['candidate'] = candidate
            observation['sandbox']['doors'][0]['position'] = [48.9, 0, 15.5]
            keys, *_ = pilot.update(observation, 1)
            self.assertEqual('e' in keys, expected)
            if candidate:
                # The actual package repeatedly reversed its .8s opening:
                # the driver used to send E again after its .3s cooldown.
                for frame, now in [(110, 2), (130, 3)]:
                    observation = json.loads(json.dumps(observation))
                    observation['frame'] = frame
                    keys, *_ = pilot.update(observation, now)
                    self.assertNotIn('e', keys)
                observation = json.loads(json.dumps(observation))
                observation['frame'] = 140
                observation['sandbox']['doors'][0]['open'] = True
                keys, *_ = pilot.update(observation, 4)
                self.assertNotIn('e', keys)
                self.assertTrue(pilot.door_opened)

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
