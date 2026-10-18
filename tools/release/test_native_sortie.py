#!/usr/bin/env python3
"""Focused native-driver safety regressions; no Godot or display is launched."""
import copy
import importlib.util
import json
import math
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
    def habitat_observation(self):
        return {'mode': 'habitat-loop', 'actors_current': True, 'frame': 100, 'phase': 'INTRO',
                'main_id': 1, 'world_id': 2, 'player_id': 3, 'capsule_id': 4, 'shape_id': 5,
                'player': [-8.5, .18, 11], 'position': [-8.5, .18, 11], 'spawn': [-8.5, .18, 11],
                'menu_ready': False, 'walk_forward': [1, 0, 0], 'walk_right': [0, 0, 1],
                'velocity': [0, 0, 0], 'walk_tuning': {'walk': 5.8, 'sprint': 9.2,
                    'deceleration': 42, 'mouse': .0025}, 'physics_ticks': 60, 'time_scale': 1,
                'control_enabled': True, 'seated': False, 'station_seated': False,
                'game_station_seated': False, 'sleeping': False, 'transition_busy': False,
                'mouse_captured': True, 'capsule_enabled': True, 'native_interact': False,
                'grounded': True, 'supported': True, 'support_collider': '/Main/World/Deck',
                'door': {'id': 6, 'position': [49.72, 0, 15.5], 'state': 0,
                         'open': False, 'candidate': False},
                'bunk': {'id': 7, 'position': [54.1, 1.14, 18.15], 'wake': [54.1, .04, 17.5],
                         'candidate': False, 'occupant_id': 0, 'reserved': False,
                         'available': True, 'active': False, 'active_seat_id': 0,
                         'seated_at_bunk': False, 'transitioning': False}, 'common_occupied': False}

    def habitat_pilot(self, stage):
        pilot = native.HabitatLoopPilot()
        s = self.habitat_observation()
        pilot.update(copy.deepcopy(s), 0)
        s.update(frame=110, phase='APPROACH_SHIP')
        pilot.stage = stage
        pilot.previous = dict(s, frame=109)
        return pilot, s

    def habitat_sleep_state(self, s):
        s.update(sleeping=True, seated=True, station_seated=True, game_station_seated=True,
                 grounded=False, supported=False, support_collider='')
        s['door'].update(open=True, state=2)
        s['bunk'].update(reserved=True, occupant_id=s['player_id'], active=True,
                         active_seat_id=s['bunk']['id'], seated_at_bunk=True, available=False)

    def test_habitat_requires_fresh_start_and_current_same_actor(self):
        for change in ({'actors_current': False}, {'phase': 'APPROACH_SHIP'},
                       {'player': [54.1, .04, 17.5]}):
            with self.subTest(change=change):
                s = self.habitat_observation()
                s.update(change)
                with self.assertRaises(AssertionError): native.HabitatLoopPilot().update(s, 0)
        pilot, s = self.habitat_pilot('begin_shift')
        s['player_id'] += 1
        with self.assertRaisesRegex(AssertionError, 'same current Main'):
            pilot.update(copy.deepcopy(s), 1)

    def test_habitat_rejects_pose_only_or_unsupported_common_arrival(self):
        for field in ('supported', 'grounded', 'common_occupied'):
            with self.subTest(field=field):
                pilot, s = self.habitat_pilot('walk_common')
                pilot.route = [('common_occupied', [67.8, 0, 15.5])]
                s.update(player=[67.8, 0, 15.5], position=[67.8, 0, 15.5], common_occupied=True)
                s['door'].update(open=True, state=2)
                pilot.previous = dict(s, frame=109)
                s[field] = False
                with self.assertRaises(AssertionError): pilot.update(copy.deepcopy(s), 1)
                self.assertIsNone(pilot.result)

    def test_habitat_walking_rejects_teleport(self):
        pilot, s = self.habitat_pilot('walk_outbound')
        pilot.route = list(pilot.OUTBOUND)
        s['player'] = [48, 0, 15.5]
        with self.assertRaisesRegex(AssertionError, 'without placement'):
            pilot.update(copy.deepcopy(s), 1)

    def test_habitat_door_press_requires_exact_current_candidate(self):
        pilot, s = self.habitat_pilot('door_aim')
        s.update(player=[48, 0, 15.5], position=[48, 0, 15.5])
        pilot.previous = dict(s, frame=109)
        keys, *_ = pilot.update(copy.deepcopy(s), 1)
        self.assertNotIn('e', keys)
        s.update(frame=111)
        s['door']['candidate'] = True
        keys, *_ = pilot.update(copy.deepcopy(s), 1.1)
        self.assertIn('e', keys)
        self.assertEqual(pilot.stage, 'door_wait')
        s.update(frame=120, native_interact=True)
        keys, *_ = pilot.update(copy.deepcopy(s), 1.3)
        self.assertNotIn('e', keys)
        self.assertEqual(pilot.stage, 'door_wait')
        self.assertIsNone(pilot.result)

    def test_habitat_sleep_requires_real_exact_reservation_and_anchor(self):
        for field, value in (('reserved', False), ('occupant_id', 99),
                             ('active', False), ('seated_at_bunk', False), ('transitioning', True)):
            with self.subTest(field=field):
                pilot, s = self.habitat_pilot('sleep_wait')
                self.habitat_sleep_state(s)
                s['bunk'][field] = value
                with self.assertRaisesRegex(AssertionError, 'actual sleep on exact'):
                    pilot.update(copy.deepcopy(s), 1)

    def test_habitat_wake_waits_for_observed_release_then_distinct_press(self):
        pilot, s = self.habitat_pilot('sleep_release')
        self.habitat_sleep_state(s)
        s['native_interact'] = True
        keys, *_ = pilot.update(copy.deepcopy(s), 1)
        self.assertNotIn('e', keys)
        self.assertIsNone(pilot.sleep_release_frame)
        s.update(frame=111, native_interact=False)
        keys, *_ = pilot.update(copy.deepcopy(s), 1.1)
        self.assertNotIn('e', keys)
        self.assertEqual(pilot.sleep_release_frame, 111)
        s.update(frame=116)
        keys, *_ = pilot.update(copy.deepcopy(s), 1.2)
        self.assertNotIn('e', keys)
        s.update(frame=117)
        keys, *_ = pilot.update(copy.deepcopy(s), 1.3)
        self.assertIn('e', keys)
        self.assertEqual(pilot.stage, 'wake_wait')
        self.assertIsNone(pilot.result)

    def test_habitat_start_and_wake_wait_for_natural_floor_contact(self):
        for stage in ('begin_shift', 'wake_wait'):
            with self.subTest(stage=stage):
                pilot, s = self.habitat_pilot(stage)
                if stage == 'wake_wait':
                    s['door'].update(open=True, state=2)
                    s['player'] = s['bunk']['wake']
                    pilot.sleep_release_frame = 95
                    pilot.native_edges = [{'pressed': True, 'stage': 'wake_wait'}]
                s.update(grounded=False, supported=False)
                keys, *_ = pilot.update(copy.deepcopy(s), 1)
                self.assertEqual(pilot.stage, stage)
                self.assertNotIn('w', keys)
                s.update(frame=111, grounded=True, supported=True)
                pilot.update(copy.deepcopy(s), 1.1)
                self.assertEqual(pilot.stage, 'walk_outbound' if stage == 'begin_shift' else 'walk_common')

    def test_habitat_wake_rejects_retained_claim_or_missing_repress(self):
        for retained in (False, True):
            with self.subTest(retained=retained):
                pilot, s = self.habitat_pilot('wake_wait')
                s['door'].update(open=True, state=2)
                s['player'] = s['bunk']['wake']
                if retained: s['bunk'].update(reserved=True, occupant_id=s['player_id'])
                with self.assertRaises(AssertionError): pilot.update(copy.deepcopy(s), 1)
                self.assertIsNone(pilot.result)

    def restart_observation(self):
        s = self.habitat_observation()
        s.update(mode='habitat-restart', sequence=s['frame'], pid=101, paused=False,
                 camera_current=True, piloting=False, driving=False, crew_claim=False,
                 cabin_claim=False, recovery_pending=False,
                 save={'path': '/private/data/mudds_user_data.json', 'generation': 3,
                       'source': 'primary', 'context': {'mode': 'unavailable'},
                       'context_generation': 3, 'retry_seconds': 0},
                 tractor={'current': True, 'id': 8, 'station_id': 9,
                          'station_path': '/Main/World/Tractor/DriverStation',
                          'position': [2.1, 1.25, 17.35], 'approach': [2.1, 0, 18.6],
                          'candidate': False, 'available': True,
                          'driven': False, 'seated_at_driver': False})
        return s

    def restart_pilot(self, stage, cold=False):
        pilot = native.HabitatRestartPilot(cold=cold)
        s = self.restart_observation()
        pilot.update(copy.deepcopy(s), 0)
        s.update(frame=110, sequence=110, phase='APPROACH_SHIP')
        pilot.stage = stage
        pilot.previous = copy.deepcopy(dict(s, frame=109))
        return pilot, s

    def test_restart_reuses_exact_sleep_admission_and_waits_for_independent_file_read(self):
        pilot, s = self.restart_pilot('sleep_wait')
        self.habitat_sleep_state(s)
        pilot.native_edges = [{'pressed': True, 'stage': 'sleep_wait'}]
        keys, *_ = pilot.update(copy.deepcopy(s), 1)
        self.assertEqual(pilot.stage, 'restart_context')
        self.assertNotIn('e', keys)
        self.assertIn('sleep', pilot.receipts)
        s.update(frame=111, sequence=111)
        self.assertFalse(pilot.file_context_accepted)
        self.assertNotIn('Escape', pilot.update(copy.deepcopy(s), 1.1)[0])
        self.assertEqual(pilot.stage, 'restart_context')
        pilot.file_context_accepted = True
        s.update(frame=112, sequence=112)
        pilot.update(copy.deepcopy(s), 1.2)
        self.assertEqual(pilot.stage, 'restart_pause')
        self.assertNotIn('wake_press', pilot.receipts)
        s.update(frame=113, sequence=113)
        self.assertIn('Escape', pilot.update(copy.deepcopy(s), 1.3)[0])
        for mutation in ({'sleeping': False}, {'pid': 102}, {'player_id': 50}):
            other, sample = self.restart_pilot('restart_context')
            self.habitat_sleep_state(sample)
            sample.update(mutation)
            with self.assertRaises(AssertionError): other.update(copy.deepcopy(sample), 2)

    def paused_restart_observation(self, sequence=111, exit_focus=False):
        return {'mode': 'habitat-restart', 'sequence': sequence, 'pid': 101,
                'frame': 110, 'main_id': 1, 'paused': True, 'rest_retained': True,
                'native_keys': {'escape': False, 'tab': False, 'return': False},
                'ui': {'main_visible': True, 'focus_is_exit': exit_focus,
                       'focus_path': '/Main/HUD/Pause/ExitButton' if exit_focus else '/Main/HUD/Pause/ResumeButton',
                       'focus_name': 'ExitButton' if exit_focus else 'ResumeButton',
                       'exit_path': '/Main/HUD/Pause/ExitButton', 'exit_visible': True,
                       'exit_enabled': True, 'exit_text': 'EXIT TO DESKTOP'}}

    def test_restart_ui_keys_release_with_frozen_physics_and_require_actual_exit_focus(self):
        pilot, _ = self.restart_pilot('restart_pause')
        s = self.paused_restart_observation()
        self.assertEqual(pilot.update(copy.deepcopy(s), 1)[0], {'Tab'})
        s.update(sequence=112)
        s['native_keys']['tab'] = True
        self.assertEqual(pilot.update(copy.deepcopy(s), 1.1)[0], set())
        # Even an exit focus cannot bypass the actual release observation.
        s = self.paused_restart_observation(113, exit_focus=True)
        s['native_keys']['tab'] = True
        self.assertEqual(pilot.update(copy.deepcopy(s), 1.25)[0], set())
        self.assertFalse(pilot.quit_requested)
        s['sequence'] = 114
        s['native_keys']['tab'] = False
        self.assertEqual(pilot.update(copy.deepcopy(s), 1.3)[0], {'Return'})
        self.assertTrue(pilot.quit_requested)
        self.assertEqual(pilot.receipts['exit_ui']['frame'], 110)
        s['sequence'] = 115
        self.assertEqual(pilot.update(copy.deepcopy(s), 1.4)[0], set())
        s['sequence'] = 116
        self.assertEqual(pilot.update(copy.deepcopy(s), 2)[0], set())
        for key, value in [('exit_enabled', False), ('exit_text', 'RESTART SHIFT'), ('main_visible', False)]:
            other, _ = self.restart_pilot('restart_pause')
            sample = self.paused_restart_observation(exit_focus=True)
            sample['ui'][key] = value
            with self.assertRaisesRegex(AssertionError, 'actual enabled EXIT'):
                other.update(copy.deepcopy(sample), 1)

    def test_restart_cold_begin_shift_allows_repeated_object_ids_but_rejects_old_claims(self):
        # IDs are process-local. A separate pilot starts its own stable roster;
        # the driver proves the distinct OS PID, never inequality of ObjectIDs.
        first = native.HabitatRestartPilot()
        cold = native.HabitatRestartPilot(cold=True)
        s = self.restart_observation()
        first.update(copy.deepcopy(s), 0)
        s['pid'] = 202
        cold.update(copy.deepcopy(s), 0)
        s.update(frame=101, sequence=101, menu_ready=True)
        self.assertIn('e', cold.update(copy.deepcopy(s), .1)[0])
        s.update(frame=110, sequence=110, phase='APPROACH_SHIP')
        keys, dx, *_ = cold.update(copy.deepcopy(s), .3)
        self.assertEqual(cold.stage, 'restart_look')
        self.assertEqual(keys, set())
        self.assertNotEqual(dx, 0)
        self.assertEqual(first.initial['player_id'], cold.initial['player_id'])
        # Godot resource ObjectIDs can use the signed high bit. Nonzero IDs
        # must remain exact within the leg, regardless of their sign.
        negative_id = -9223371935302285411
        for field in ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id'):
            for replacement in (0, negative_id - 1):
                with self.subTest(field=field, replacement=replacement):
                    actor = native.HabitatRestartPilot(cold=True)
                    sample = self.restart_observation()
                    sample[field] = negative_id
                    actor.update(copy.deepcopy(sample), 0)
                    actor.stage = 'begin_shift'
                    sample.update(frame=110, sequence=110, phase='APPROACH_SHIP')
                    actor.update(copy.deepcopy(sample), 1)
                    self.assertEqual(actor.stage, 'restart_look')
                    sample.update(frame=111, sequence=111)
                    sample[field] = replacement
                    with self.assertRaisesRegex(AssertionError, 'stable current actors'):
                        actor.update(copy.deepcopy(sample), 1.1)
        for key in ('crew_claim', 'cabin_claim', 'recovery_pending', 'piloting', 'sleeping'):
            other, sample = self.restart_pilot('begin_shift', cold=True)
            sample[key] = True
            with self.assertRaises(AssertionError): other.update(copy.deepcopy(sample), 1)

    def test_restart_requires_observed_look_supported_displacement_and_current_interaction(self):
        pilot, s = self.restart_pilot('begin_shift', cold=True)
        pilot.update(copy.deepcopy(s), 1)
        s.update(frame=111, sequence=111)
        self.assertEqual(pilot.update(copy.deepcopy(s), 1.1)[0], set())
        self.assertEqual(pilot.stage, 'restart_look')
        s.update(frame=112, sequence=112, walk_forward=[.98, 0, .2], walk_right=[-.2, 0, .98])
        pilot.update(copy.deepcopy(s), 1.2)
        self.assertEqual(pilot.stage, 'restart_walk')
        # Settled actual walking reaches the live approach, with >.6m motion.
        s.update(frame=232, sequence=232, player=[2.1, .02, 18.6], position=[2.1, .02, 18.6],
                 walk_forward=[0, 0, -1], walk_right=[1, 0, 0])
        pilot.update(copy.deepcopy(s), 3.2)
        self.assertEqual(pilot.stage, 'restart_aim')
        self.assertGreater(pilot.walk_displacement, .6)
        s.update(frame=233, sequence=233)
        self.assertNotIn('e', pilot.update(copy.deepcopy(s), 3.3)[0])
        s.update(frame=234, sequence=234)
        s['tractor']['candidate'] = True
        self.assertIn('e', pilot.update(copy.deepcopy(s), 3.4)[0])
        self.assertEqual(pilot.stage, 'restart_board')
        self.assertFalse(pilot.interaction_complete)
        s.update(frame=235, sequence=235, native_interact=True, transition_busy=True)
        pilot.update(copy.deepcopy(s), 3.42)
        s.update(frame=270, sequence=270, seated=True, driving=True, transition_busy=False,
                 native_interact=False, capsule_enabled=False, camera_current=False)
        s['tractor'].update(driven=True, seated_at_driver=True)
        pilot.update(copy.deepcopy(s), 4)
        self.assertEqual(pilot.stage, 'restart_driver_release')
        s.update(frame=271, sequence=271)
        pilot.update(copy.deepcopy(s), 4.1)
        s.update(frame=290, sequence=290)
        self.assertIn('e', pilot.update(copy.deepcopy(s), 4.5)[0])
        self.assertEqual(pilot.stage, 'restart_dismount')
        s.update(frame=291, sequence=291, native_interact=True, transition_busy=True)
        pilot.update(copy.deepcopy(s), 4.52)
        s.update(frame=330, sequence=330, native_interact=False, transition_busy=False,
                 seated=False, driving=False, capsule_enabled=True, camera_current=True)
        s['tractor'].update(driven=False, seated_at_driver=False)
        pilot.update(copy.deepcopy(s), 5.2)
        self.assertTrue(pilot.interaction_complete)
        self.assertEqual(pilot.stage, 'restart_pause')
        self.assertIn('cold_exit', pilot.receipts)
        self.assertFalse(pilot.quit_requested)
        for key in ('supported', 'camera_current', 'actors_current'):
            other, sample = self.restart_pilot('begin_shift', cold=True)
            other.update(copy.deepcopy(sample), 1)
            sample.update(frame=111, sequence=111)
            sample[key] = False
            with self.assertRaises(AssertionError): other.update(copy.deepcopy(sample), 1.1)

    def restart_document(self, generation=3):
        return {'schema_version': 1, 'generation': generation,
                'commit': {'id': 'test-commit', 'parent_generation': generation-1,
                           'parent_id': 'test-parent', 'payload_sha256': '0'*64},
                'payload': {'solo_safe_recovery': {'mode': 'unavailable'},
                            'runtime_settings': {'values': {'master_volume': .5}},
                            'unrelated': {'progress': [1, 2]},
                            'crash_recovery': {'state': 'running', 'unclean_start_count': 0,
                                               'session_id': 1, 'startup_generation': 1},
                            'safe_start_recovery': {'state': 'stable', 'startup_generation': 1,
                                                    'consecutive_failure_count': 0,
                                                    'safe_settings_recommended': False},
                            'session_diagnostics': {'events': []}}}

    def test_restart_real_file_capture_refuses_changed_profile_and_preserves_unrelated_payload(self):
        with tempfile.TemporaryDirectory() as root:
            profile, output = Path(root)/'profile', Path(root)/'result'
            (profile/'data').mkdir(parents=True)
            output.mkdir()
            path = profile/'data'/'mudds_user_data.json'
            document = self.restart_document()
            raw = (json.dumps(document)+'\n').encode()
            path.write_bytes(raw)
            files = native.HabitatRestartFiles(profile, output)
            sample = {'path': str(path), 'generation': 3, 'source': 'primary'}
            first = files.capture('resting', sample)
            self.assertEqual(path.read_bytes(), raw)
            self.assertEqual((output/'resting.json').read_bytes(), raw)
            self.assertEqual(first, document)
            changed = copy.deepcopy(first)
            changed['payload']['unrelated']['progress'].append(3)
            with self.assertRaisesRegex(AssertionError, 'unrelated actual-file'):
                files.require_preserved(first, changed)
            other = profile/'data'/'replacement'/'mudds_user_data.json'
            other.parent.mkdir()
            other.write_bytes(raw)
            with self.assertRaisesRegex(AssertionError, 'same actual save path'):
                files.capture('wrong-path', dict(sample, path=str(other)))
            other.unlink()
            files.profile_identity = [-1, -1]
            with self.assertRaisesRegex(AssertionError, 'same original private profile'):
                files.capture('wrong-profile', sample)

    def test_restart_requires_actual_clean_markers_and_new_session_generations(self):
        running = self.restart_document()
        closed = copy.deepcopy(running)
        closed['generation'] += 3
        closed['payload']['crash_recovery']['state'] = 'clean'
        closed['payload']['safe_start_recovery']['state'] = 'clean_shutdown'
        closed['payload']['session_diagnostics']['events'].append({'event_code': 'session_ended', 'session_id': 1})
        native.HabitatRestartFiles.require_orderly(closed, running)
        for section, field, value in [('crash_recovery', 'state', 'running'),
                                      ('safe_start_recovery', 'state', 'stable'),
                                      ('crash_recovery', 'session_id', 2),
                                      ('session_diagnostics', 'events', [])]:
            changed = copy.deepcopy(closed)
            changed['payload'][section][field] = value
            with self.assertRaises(AssertionError): native.HabitatRestartFiles.require_orderly(changed, running)
        cold = copy.deepcopy(running)
        cold['generation'] = 9
        cold['payload']['crash_recovery'].update(session_id=2, startup_generation=2)
        cold['payload']['safe_start_recovery'].update(state='starting', startup_generation=2)
        native.HabitatRestartFiles.require_cold(cold, closed)
        for section, field, value in [('crash_recovery', 'unclean_start_count', 1),
                                      ('safe_start_recovery', 'startup_generation', 1),
                                      ('solo_safe_recovery', 'mode', 'rest')]:
            changed = copy.deepcopy(cold)
            changed['payload'][section][field] = value
            with self.assertRaises(AssertionError): native.HabitatRestartFiles.require_cold(changed, closed)
        self.assertEqual(native.CAP, 300)

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

    def mining_record(self):
        return {'schema_version': 2, 'payload_kind': 'cinder_mining_capacity_receipt',
                'slot_id': 'cinder_mining_capacity',
                'session': {'state': 2, 'generation': 1, 'elapsed_seconds': 6,
                            'reward_requested': True, 'capacity_paid': True},
                'capacity': {'activity_id': 'cinder_platform_mining_run', 'content_class': 'NEW',
                    'evidence_status': 'modern_interpretation', 'extraction_seconds': 6,
                    'reward_receipt': {'activity_id': 'cinder_platform_mining_run',
                        'reward_id': 'cinder_raw_ore_sample', 'granted': False, 'replay_allowed': False}}}

    def mining_observation(self):
        s = self.hulk_observation()
        s.pop('hulk')
        s.update(mode='mining-first-play', sequence=100, pid=101, main_id=102,
                 current=True, paused=False, physics_seconds=100,
                 position=[60, -66, -605], camera=[60, -65, -605])
        s['mining'] = {'available': True, 'coordinate_space': 'common_world',
            'target': [60, -66, -605], 'marker_position': [60, -66, -605],
            'binding_id': 103, 'marker_id': 104, 'bootstrap_id': 105,
            'capsule_id': 106, 'shape_id': 107, 'capsule_enabled': True,
            'physics_ticks': 60, 'time_scale': 1,
            'walk_tuning': {'walk': 5.8, 'sprint': 9.2}, 'capacity_paid': False,
            'activity': {'state_id': 'idle', 'generation': 0, 'elapsed_seconds': 0,
                         'extraction_seconds': 6, 'reward_requested': False},
            'save': {'path': '/private/data/mudds_user_data.json', 'generation': 10,
                     'source': 'primary', 'record': {}, 'record_valid': False},
            'streaming': {'loaded': True, 'loading': False, 'loaded_instance_id': 108,
                'generation': 1, 'loaded_generation': 1, 'load_request_count': 1,
                'load_failure_count': 0, 'unload_count': 0, 'unload_radius_m': 650},
            'home': {'berth_id': 'central', 'berth_instance_id': 109, 'approach': [0, 2, -18],
                'dock': [0, 1.15, -10], 'dock_forward': [0, 0, -1],
                'selected_berth_id': 'central', 'capture': False, 'contract': False,
                'lease': False, 'parked_exact': False, 'occupant_id': 0,
                'landing_abort_reason': '', 'grounded': False, 'supported': False, 'support_collider': ''}}
        return s

    def mining_pilot(self, stage='mining_extract'):
        pilot = self.hulk_pilot(native.MiningFirstPlayPilot)
        pilot.stage, pilot.start_clock = stage, 100
        return pilot

    def mining_paid_state(self, s):
        s['mining']['activity'].update(state_id='complete', generation=1, elapsed_seconds=6,
                                      reward_requested=True, capacity_persisted=True)
        s['mining']['capacity_paid'] = True
        s['mining']['save'].update(record=self.mining_record(), record_valid=True, generation=25)
        s['physics_seconds'] = 106
        s['frame'] = 460
        s['sequence'] = 460

    def mining_ui(self, target='select'):
        buttons = {key: {'available': True, 'id': index+200, 'path': '/HUD/'+key,
                        'text': label, 'visible': True, 'enabled': True, 'focused': key == target,
                        'focus_mode': 2, 'rect': [10, 20, 100, 32]}
                   for index, (key, label) in enumerate((('activity_board', 'ACTIVITY BOARD'),
                       ('nearby_open', 'CINDER SECTOR ACTIVITIES'), ('select', 'SELECT'),
                       ('start', 'START'), ('reset', 'RESET')))}
        return {'available': True, 'focus_path': buttons[target]['path'], 'buttons': buttons,
                'main_visible': target == 'activity_board', 'activity_visible': target == 'nearby_open',
                'nearby_visible': target in ('select', 'start', 'reset'), 'row_id': 300,
                'row_activity_id': 'cinder_platform_mining_run', 'selected_activity': '',
                'native_keys': {'escape': False, 'tab': False, 'return': False},
                'activity': {'state_id': 'idle', 'generation': 0, 'elapsed_seconds': 0,
                             'reward_requested': False}}

    def test_mining_requires_normal_prelude_and_physical_live_marker_arrival(self):
        for field in ('departed', 'shot', 'fired'):
            pilot, s = self.hulk_pilot(native.MiningFirstPlayPilot), self.mining_observation()
            setattr(pilot, field, False)
            with self.assertRaisesRegex(AssertionError, 'normal Guided'):
                pilot.update(s, 1)
        pilot, s = self.hulk_pilot(native.MiningFirstPlayPilot), self.mining_observation()
        pilot.update(s, 1)
        self.assertEqual(pilot.stage, 'mining_ui_pause')
        self.assertEqual(pilot.receipts['guided_prelude']['destroyed_targets'], 4)
        self.assertLessEqual(pilot.receipts['physical_arrival']['distance_m'], 1)
        self.assertIsNone(pilot.result)
        for change in ({'marker_position': [60, -66, -606]},
                       {'activity': {'generation': 1, 'state_id': 'idle', 'reward_requested': False}}):
            pilot, s = self.hulk_pilot(native.MiningFirstPlayPilot), self.mining_observation()
            s['mining'].update(change)
            with self.assertRaises(AssertionError): pilot.update(s, 1)
        self.assertEqual(native.CAP, 300)

    def test_mining_preserves_original_prelude_commands_before_branch(self):
        pilot, s = native.MiningFirstPlayPilot(), self.mining_observation()
        with patch.object(native.Pilot, 'update', return_value=({'Prior'}, 4, -3, True)) as parent:
            self.assertEqual(pilot.update(s, 1), ({'Prior'}, 4, -3, True))
            parent.assert_called_once_with(s, 1)
        s['sequence'] += 1
        s['current'] = False
        self.assertEqual(pilot.update(s, 2), (set(), 0, 0, False))
        pilot.stage = 'walk'
        s['sequence'] += 1
        with self.assertRaisesRegex(AssertionError, 'current live mining owners'):
            pilot.update(s, 3)

    def test_mining_real_keyboard_page_select_start_and_pause_time_are_distinct(self):
        pilot, s = self.mining_pilot('mining_ui_board'), self.mining_observation()
        s.update(paused=True, ui=self.mining_ui('activity_board'))
        now = 1
        def step():
            nonlocal now
            s['sequence'] += 1
            now += .2
            return pilot.update(copy.deepcopy(s), now)
        def release():
            self.assertEqual(step()[0], set())
        self.assertEqual(step()[0], {'Return'})
        self.assertEqual(pilot.stage, 'mining_ui_board_wait')
        release()
        s['ui'] = self.mining_ui('nearby_open')
        self.assertEqual(step()[0], {'Return'})
        release()
        s['ui'] = self.mining_ui('select')
        self.assertEqual(step()[0], {'Return'})
        self.assertEqual(pilot.stage, 'mining_ui_select_wait')
        release()
        s['ui'] = self.mining_ui('start')
        s['ui']['selected_activity'] = pilot.ACTIVITY
        self.assertEqual(step()[0], {'Return'})
        self.assertEqual(pilot.stage, 'mining_ui_start_wait')
        release()
        s['ui']['activity'].update(state_id='active', generation=1)
        self.assertEqual(step()[0], {'Escape'})
        self.assertEqual(pilot.stage, 'mining_ui_back_wait')
        self.assertEqual(pilot.start_clock, 100)
        release()
        s['ui'].update(nearby_visible=False, activity_visible=True)
        self.assertEqual(step()[0], {'Escape'})
        release()
        s['ui'].update(activity_visible=False, main_visible=True)
        self.assertEqual(step()[0], {'Escape'})
        release()
        s.update(paused=False, frame=101, physics_seconds=100+1/60)
        self.assertEqual(step()[0], set())
        self.assertEqual(pilot.stage, 'mining_extract')
        self.assertEqual(len(pilot.receipts['ui_activation']), 4)
        self.assertIsNone(pilot.result)

    def test_mining_ui_rejects_wrong_row_geometry_focus_and_unacknowledged_start(self):
        mutations = [lambda ui: ui.update(row_activity_id='other'),
                     lambda ui: ui['buttons']['start'].update(enabled=False),
                     lambda ui: ui['buttons']['start'].update(rect=[0, 0, 0, 0]),
                     lambda ui: ui['buttons']['start'].update(text='RESTART'),
                     lambda ui: ui.update(focus_path='/HUD/other')]
        for mutation in mutations:
            pilot, s = self.mining_pilot('mining_ui_start'), self.mining_observation()
            s.update(paused=True, ui=self.mining_ui('start'))
            mutation(s['ui'])
            with self.assertRaises(AssertionError): pilot.update(s, 1)
        pilot, s = self.mining_pilot('mining_ui_start_wait'), self.mining_observation()
        s.update(paused=True, ui=self.mining_ui('start'))
        with self.assertRaisesRegex(AssertionError, 'no retry'): pilot.update(s, 1)
        pilot, s = self.mining_pilot('mining_ui_resume'), self.mining_observation()
        s.update(paused=True, ui=self.mining_ui('start'))
        s['ui']['activity'].update(state_id='active', generation=1, elapsed_seconds=.1)
        with self.assertRaisesRegex(AssertionError, 'paused menu never'): pilot.update(s, 1)

    def test_mining_six_seconds_and_independent_paid_file_precede_home_return(self):
        pilot, s = self.mining_pilot(), self.mining_observation()
        s.update(frame=280, sequence=280, physics_seconds=103)
        s['mining']['activity'].update(state_id='active', generation=1, elapsed_seconds=3)
        self.assertIn('Prior', pilot.update(copy.deepcopy(s), 1)[0])
        self.assertIsNone(pilot.result)
        self.mining_paid_state(s)
        pilot.update(copy.deepcopy(s), 2)
        self.assertEqual(pilot.stage, 'mining_capacity_file')
        self.assertFalse(pilot.file_receipt_accepted)
        self.assertIsNone(pilot.result)
        pilot.file_receipt_accepted = True
        s.update(frame=461, sequence=461, physics_seconds=106+1/60)
        pilot.update(copy.deepcopy(s), 3)
        self.assertEqual(pilot.stage, 'mining_home_flight')
        self.assertEqual(pilot.home_clearance_target, [0, 2.7, -150])
        self.assertEqual(pilot.paid_record, self.mining_record())
        self.assertIsNone(pilot.result)

    def test_mining_rejects_synthetic_time_recovery_reset_replacement_and_fake_receipts(self):
        mutations = [lambda s: s.update(physics_seconds=105), lambda s: s.update(phase='RECOVERING'),
            lambda s: s.update(player_id=999), lambda s: s.update(position=[60, -66, -574]),
            lambda s: s['mining'].update(time_scale=2), lambda s: s['mining'].update(capacity_paid=False),
            lambda s: s['mining'].update(marker_id=0),
            lambda s: s['mining']['activity'].update(generation=2),
            lambda s: s['mining']['activity'].update(state_id='reset'),
            lambda s: s['mining']['save'].update(record_valid=False),
            lambda s: s['mining']['save'].update(source='backup'),
            lambda s: s['mining']['save']['record']['capacity']['reward_receipt'].update(granted=True),
            lambda s: s['mining']['save']['record']['capacity']['reward_receipt'].update(replay_allowed=True)]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                pilot, s = self.mining_pilot(), self.mining_observation()
                self.mining_paid_state(s)
                mutation(s)
                with self.assertRaises(AssertionError): pilot.update(s, 1)
                self.assertIsNone(pilot.result)
        pilot, s = self.mining_pilot(), self.mining_observation()
        s.update(frame=220, sequence=220, physics_seconds=102)
        s['mining']['activity'].update(state_id='active', generation=1, elapsed_seconds=2)
        pilot.update(copy.deepcopy(s), 1)
        s.update(frame=221, sequence=221, physics_seconds=102+1/60)
        s['mining']['activity']['elapsed_seconds'] = 4
        with self.assertRaisesRegex(AssertionError, 'only real unpaused physics'): pilot.update(s, 2)

    def test_mining_strict_home_landing_neutral_shutdown_and_supported_exit_walk(self):
        pilot, s = self.mining_pilot('mining_home_land'), self.mining_observation()
        self.mining_paid_state(s)
        pilot.paid_record = self.mining_record()
        pilot.home_clearance_target = [0, 2.7, -150]
        pilot.home_previous = dict(s, position=[0, 2, -18])
        pilot.request_frame = 450
        s.update(position=[0, 1.15, -10], landing_active=True)
        pilot.update(copy.deepcopy(s), 1)
        self.assertTrue(pilot.home_landing_seen)
        s.update(frame=470, sequence=470, physics_seconds=107, landing_active=False,
                 landed=True, lease_free=False, phase='SHUT_DOWN')
        s['mining']['home'].update(contract=True, lease=True, parked_exact=True, occupant_id=2)
        pilot.update(copy.deepcopy(s), 2)
        self.assertEqual(pilot.stage, 'mining_home_shutdown')
        s.update(frame=560, sequence=560, physics_seconds=108.5)
        s['telemetry']['engine'] = 'OFFLINE'
        self.assertIn('e', pilot.update(copy.deepcopy(s), 3)[0])
        self.assertEqual(pilot.stage, 'mining_home_exit')
        s.update(frame=580, sequence=580, physics_seconds=109, phase='COMPLETE', guided_complete=True,
                 piloted=False, seated=False, control_enabled=True, player=[-8, .1, -10])
        s['mining']['home'].update(grounded=True, supported=True, support_collider='HomeDeck')
        pilot.update(copy.deepcopy(s), 4)
        self.assertEqual(pilot.stage, 'mining_home_walk')
        self.assertIsNone(pilot.result)
        s.update(frame=600, sequence=600, physics_seconds=109+20/60, player=[-7.5, .1, -10])
        pilot.update(copy.deepcopy(s), 5)
        self.assertEqual(pilot.result['completion_marker'], native.MiningFirstPlayPilot.MARKER)
        self.assertEqual(pilot.result['home_walk_ticks'], 20)
        self.assertEqual(pilot.result['capacity_record'], self.mining_record())

    def test_mining_never_retries_failed_landing_or_accepts_unsupported_home_exit(self):
        pilot, s = self.mining_pilot('mining_home_land'), self.mining_observation()
        self.mining_paid_state(s)
        pilot.paid_record = self.mining_record()
        pilot.home_clearance_target = [0, 2.7, -150]
        pilot.home_previous = dict(s, position=[0, 2, -18])
        pilot.request_frame = 300
        s['position'] = [0, 2, -18]
        with self.assertRaisesRegex(AssertionError, 'no retry'): pilot.update(copy.deepcopy(s), 1)
        pilot = self.mining_pilot('mining_home_exit')
        pilot.paid_record = self.mining_record()
        pilot.home_clearance_target = [0, 2.7, -150]
        pilot.home_previous = copy.deepcopy(s)
        pilot.request_frame = 450
        s.update(landed=True, piloted=False, seated=False, control_enabled=True,
                 phase='COMPLETE', guided_complete=True)
        s['telemetry']['engine'] = 'OFFLINE'
        s['mining']['home'].update(contract=True, lease=True, parked_exact=True, occupant_id=2,
                                  grounded=True, supported=False)
        with self.assertRaisesRegex(AssertionError, 'supported home exit'): pilot.update(s, 1)

    def test_mining_archives_actual_capacity_files_and_rejects_unrelated_namespace_changes(self):
        with tempfile.TemporaryDirectory() as root:
            profile, output = Path(root)/'profile', Path(root)/'result'
            (profile/'data').mkdir(parents=True)
            output.mkdir()
            path = profile/'data'/'mudds_user_data.json'
            before = self.restart_document()
            before['payload']['input_bindings'] = {'interact': 'E'}
            path.write_text(json.dumps(before))
            files = native.MiningFirstPlayFiles(profile, output)
            sample = {'path': str(path), 'source': 'primary', 'generation': before['generation'], 'record': {}}
            files.capture('before-mining', sample)
            after = copy.deepcopy(before)
            after['generation'] += 1
            after['payload']['cinder_mining_capacity'] = self.mining_record()
            after['payload']['tutorial_prompts_seen'] = {'schema_version': 1,
                                                        'seen_ids': ['cinder_platform_mining_run']}
            path.write_text(json.dumps(after))
            path.with_name(path.name+'.bak').write_text(json.dumps(before))
            sample.update(generation=after['generation'], record=self.mining_record())
            captured = files.capture('mining-paid', sample)
            files.require_preserved(before, captured)
            self.assertEqual(json.loads((output/'mining-paid.json').read_text()), after)
            self.assertEqual(json.loads((output/'mining-paid-mudds_user_data.json.bak').read_text()), before)
            self.assertIn('input_bindings', files.snapshots['preservation'][0]['exact_preserved_namespaces'])
            for namespace in ('input_bindings', 'runtime_settings'):
                corrupted = copy.deepcopy(after)
                corrupted['payload'][namespace] = {'changed': True}
                with self.assertRaisesRegex(AssertionError, 'unrelated actual-file'):
                    files.require_preserved(before, corrupted)
            corrupted = copy.deepcopy(after)
            corrupted['payload']['tutorial_prompts_seen']['seen_ids'].append('unrelated_activity')
            with self.assertRaisesRegex(AssertionError, 'tutorial persistence'):
                files.require_preserved(before, corrupted)
            missing_receipt = copy.deepcopy(after)
            missing_receipt['payload'].pop('cinder_mining_capacity')
            path.write_text(json.dumps(missing_receipt))
            with self.assertRaisesRegex(AssertionError, 'record matches observed'):
                files.capture('fabricated-paid', sample)

    def hulk_observation(self):
        return {'frame': 100, 'phase': 'RETURN_TO_YARD', 'player_id': 1, 'ship_id': 2,
                'position': [-96, 32.4, -432], 'player': [-88, 22, -450],
                'parked': [0, 1.15, -10], 'velocity': [0, 0, 0],
                'camera': [-96, 33, -432], 'right': [-1, 0, 0], 'up': [0, 1, 0],
                'back': [0, 0, -1], 'upright': 1,
                'walk_forward': [0, 0, -1], 'walk_right': [1, 0, 0],
                'seated': True, 'control_enabled': False, 'piloted': True, 'active_ship': True,
                'default_sampler': True, 'tuning_unchanged': True, 'destroyed': False,
                'lease_free': True, 'landed': False, 'landing_active': False,
                'destroyed_targets': 4, 'opponent_active': False, 'guided_complete': False,
                'transition_busy': False, 'native_interact': False, 'telemetry': {'engine': 'ONLINE', 'hull': 100},
                'tuning': {'mouse': .002, 'brake': 20},
                'hulk': {'available': True, 'hulk_id': 3, 'berth_instance_id': 4,
                         'berth_id': 'cinder_hulk_dock', 'selected_berth_id': 'cinder_hulk_dock',
                         'approach': [-96, 32.4, -432], 'dock': [-96, 24.4, -450],
                         'dock_forward': [0, 0, 1], 'capture': True, 'contract': False,
                         'lease': False, 'parked_exact': False, 'occupant_id': 0,
                         'landing_abort_reason': '', 'grounded': False,
                         'shelf_supported': False, 'support_collider': ''}}

    def hulk_pilot(self, pilot_type=native.HulkArrivalPilot):
        pilot = pilot_type()
        pilot.stage = 'return_align'
        pilot.identities = (1, 2)
        pilot.departed = pilot.shot = pilot.fired = True
        pilot.max_walk = 11
        pilot.phases = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                        'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD']
        return pilot

    def test_hulk_route_requires_normal_guided_prelude_before_diverging(self):
        pilot = self.hulk_pilot()
        s = self.hulk_observation()
        pilot.shot = False
        with self.assertRaisesRegex(AssertionError, 'Guided range and interceptor'):
            pilot.update(s, 1)
        pilot.shot = True
        pilot.update(s, 1)
        self.assertEqual(pilot.stage, 'hulk_align')
        self.assertEqual(pilot.departure_receipt['destroyed_targets'], 4)
        self.assertTrue(pilot.departure_receipt['home_lease_free'])
        self.assertIsNone(pilot.result)
        self.assertEqual(native.CAP, 300)

    def test_hulk_preserves_guided_prelude_commands_with_unchanged_facing(self):
        for pilot_type, stage in ((kind, stage) for kind in (native.HulkArrivalPilot, native.HulkBreakerPilot)
                                  for stage in ('launch', 'interceptor')):
            with self.subTest(pilot=pilot_type.__name__, stage=stage):
                guided, hulk = native.Pilot(), self.hulk_pilot(pilot_type)
                for pilot in (guided, hulk):
                    pilot.stage = stage
                    pilot.identities = (1, 2)
                    pilot.departed = pilot.shot = pilot.fired = True
                s = self.breaker_observation() if pilot_type is native.HulkBreakerPilot else self.hulk_observation()
                s.update(position=[-5, 14, -50], back=[0, 0, 1],
                         shot_accepted=True, command_fire=True, opponent=[10, 20, -100],
                         phase='LAUNCH' if stage == 'launch' else 'RETURN_TO_YARD')
                for frame in (100, 101):
                    s['frame'] = frame
                    expected = guided.update(s, 1 + (frame - 100) / 60)
                    self.assertNotEqual(expected[1:3], (0, 0))
                    self.assertEqual(hulk.update(s, 1 + (frame - 100) / 60), expected)
                    self.assertIsNone(hulk.mouse_pending)
                    # The transition tick still belongs to Guided; the next
                    # update performs the explicit HULK diversion.
                    if stage == 'interceptor':
                        self.assertEqual(hulk.stage, 'return_align')
                        self.assertIsNone(hulk.departure_receipt)
                        break

    def test_hulk_stages_acknowledge_mouse_before_repeating_sweep(self):
        pilot, s = self.hulk_pilot(), self.hulk_observation()
        s['position'] = [-80, 40, -400]
        first = pilot.update(s, 1)
        self.assertNotEqual(first[1:3], (0, 0))
        self.assertEqual(pilot.stage, 'hulk_transit')
        s['frame'] += 1
        self.assertEqual(pilot.update(s, 1.02)[1:3], (0, 0))
        s.update(frame=s['frame'] + 1, back=[.1, 0, -.995])
        self.assertNotEqual(pilot.update(s, 1.04)[1:3], (0, 0))

    def test_hulk_arrival_requires_live_exact_contract_and_supported_normal_exit(self):
        pilot, s = self.hulk_pilot(), self.hulk_observation()
        pilot.update(s, 1)
        s['frame'] += 6
        keys, *_ = pilot.update(s, 1.1)
        self.assertIn('l', keys)
        self.assertEqual(pilot.stage, 'hulk_land')
        s.update(frame=120, landing_active=True)
        pilot.update(s, 1.3)
        s.update(frame=200, landed=True, landing_active=False, phase='SHUT_DOWN',
                 position=s['hulk']['dock'])
        s['hulk'].update(contract=True, lease=True, parked_exact=True, occupant_id=2)
        keys, *_ = pilot.update(s, 2)
        self.assertEqual(keys, set())
        self.assertEqual(pilot.stage, 'hulk_shutdown')
        s.update(frame=289)
        s['telemetry']['engine'] = 'OFFLINE'
        self.assertNotIn('e', pilot.update(s, 3)[0])
        s.update(frame=290)
        self.assertIn('e', pilot.update(s, 3.1)[0])
        self.assertEqual(pilot.stage, 'hulk_exit')
        # Generic Guided completion is insufficient, even with a normal actor.
        s.update(frame=310, phase='COMPLETE', guided_complete=True, piloted=False,
                 seated=False, control_enabled=True)
        pilot.update(s, 3.5)
        self.assertIsNone(pilot.result)
        s['hulk'].update(grounded=True, shelf_supported=True,
                         support_collider='Exterior/DockShelf')
        s['frame'] += 1
        keys, *_ = pilot.update(s, 3.6)
        self.assertFalse(keys)
        self.assertEqual(pilot.result['completion_marker'], 'NATIVE_HULK_ARRIVAL_OK')
        self.assertEqual(pilot.result['arrival']['occupant_id'], pilot.result['same_ship_id'])
        self.assertEqual(pilot.result['shelf_support_collider'], 'Exterior/DockShelf')
        self.assertIn('breaker and reward', pilot.result['remaining'])
        self.assertEqual(pilot.result['guided_prelude']['destroyed_targets'], 4)

    def test_hulk_rejects_wrong_berth_replaced_world_and_non_shelf_ground(self):
        for change, message in [({'berth_id': 'central_berth'}, 'exact destination berth'),
                                ({'berth_instance_id': 99}, 'same live streamed HULK')]:
            pilot, s = self.hulk_pilot(), self.hulk_observation()
            pilot.update(s, 1)
            s['hulk'].update(change)
            s['frame'] += 6
            with self.subTest(change=change), self.assertRaisesRegex(AssertionError, message):
                pilot.update(s, 1.1)
        pilot, s = self.hulk_pilot(), self.hulk_observation()
        pilot.update(s, 1)
        pilot.stage = 'hulk_exit'
        pilot.request_frame = s['frame']
        s.update(frame=110, phase='COMPLETE', piloted=False, seated=False, control_enabled=True)
        s['telemetry']['engine'] = 'OFFLINE'
        s['hulk'].update(contract=True, lease=True, parked_exact=True, occupant_id=2,
                         grounded=True, shelf_supported=False, support_collider='Exterior/Hull')
        pilot.update(s, 1.2)
        self.assertIsNone(pilot.result)
        s['frame'] = pilot.request_frame + 601
        with self.assertRaisesRegex(AssertionError, 'supported HULK exit; no retry'):
            pilot.update(s, 12)

    def test_hulk_landing_failure_stops_without_an_automatic_second_press(self):
        pilot, s = self.hulk_pilot(), self.hulk_observation()
        pilot.update(s, 1)
        s['frame'] += 6
        pilot.update(s, 1.1)
        s['frame'] += 12
        self.assertNotIn('l', pilot.update(s, 1.4)[0])
        s['frame'] += 121
        with self.assertRaisesRegex(AssertionError, 'no retry'):
            pilot.update(s, 4)
        self.assertIsNone(pilot.result)
        pilot, s = self.hulk_pilot(), self.hulk_observation()
        pilot.update(s, 1)
        pilot.stage = 'hulk_land'
        pilot.request_frame = s['frame']
        s['landing_active'] = True
        pilot.update(s, 1.1)
        s.update(frame=101, landing_active=False)
        s['hulk']['landing_abort_reason'] = 'collision_blocked'
        with self.assertRaisesRegex(AssertionError, 'collision_blocked'):
            pilot.update(s, 1.2)

    def breaker_observation(self):
        s = self.hulk_observation()
        s['hulk']['interior'] = {
            'route': [[-96, 23, -450], [-96, 23, -466], [-93.5, 23, -470],
                      [-118, 23, -470], [-144.5, 23, -468], [-146, 23, -469.2]],
            'space_ids': list(native.HulkBreakerPilot.SPACES), 'support_owned': True,
            'capsule_id': 5, 'shape_id': 6, 'capsule_enabled': True,
            'player_velocity': [0, 0, 0],
            'walk_tuning': {'walk': 5.8, 'sprint': 9.2, 'deceleration': 42, 'mouse': .0025},
            'physics_ticks': 60, 'time_scale': 1, 'breaker_id': 7,
            'breaker_position': [-146, 23.8, -467], 'breaker_candidate': False,
            'breaker_engaged': False, 'last_breaker_result': {},
            'activity': {'state_id': 'idle', 'generation': 0, 'elapsed_seconds': 0,
                         'restore_seconds': 3, 'reward_claimed': False, 'claimed_receipts': 0},
            'reward_count': 0, 'reward_receipt': {}, 'power_restored': False,
            'lights': [{'name': 'fixture light'}]*8,
            'bus_lights_restored': False, 'emergency_lights': True}
        return s

    def breaker_at_exit(self, supported=True, pilot_type=native.HulkBreakerPilot):
        pilot, s = self.hulk_pilot(pilot_type), self.breaker_observation()
        pilot.update(s, 1)
        pilot.stage, pilot.request_frame = 'hulk_exit', s['frame']
        s = json.loads(json.dumps(s))
        s.update(frame=110, phase='COMPLETE', piloted=False, seated=False,
                 control_enabled=True, landed=True, position=s['hulk']['dock'])
        s['telemetry']['engine'] = 'OFFLINE'
        s['hulk'].update(contract=True, lease=True, parked_exact=True, occupant_id=2,
                         grounded=True, shelf_supported=supported,
                         support_collider='Exterior/DockShelf' if supported else 'Exterior/Hull')
        pilot.update(s, s['frame']/60)
        return pilot, s

    def walk_breaker_interior(self, pilot_type=native.HulkBreakerPilot):
        pilot, s = self.breaker_at_exit(pilot_type=pilot_type)
        # Sample an uninterrupted physical path at normal walking speed. The
        # driver still decides its own waypoint acceptance and key commands.
        while pilot.stage == 'hulk_walk':
            target = pilot.route[len(pilot.visited)]
            direction = native.sub([target[0], s['player'][1], target[2]], s['player'])
            distance = native.norm(direction)
            amount = min(.09, distance)
            direction = native.unit(direction)
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            s['player'] = [p + d*amount for p, d in zip(s['player'], direction)]
            if distance > 0:
                s['walk_forward'] = direction
                s['walk_right'] = [-direction[2], 0, direction[0]]
            s['hulk']['support_collider'] = 'Hull/Deck'
            pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'hulk_breaker_aim')
        return pilot, s

    def press_breaker_and_restore(self, claimed_elapsed=3, pilot_type=native.HulkBreakerPilot):
        pilot, s = self.walk_breaker_interior(pilot_type=pilot_type)
        s = json.loads(json.dumps(s))
        s['frame'] += 30
        s['hulk']['interior']['breaker_candidate'] = True
        direction = native.unit(native.sub(s['hulk']['interior']['breaker_position'], s['player']))
        direction[1] = 0
        s['walk_forward'] = native.unit(direction)
        s['walk_right'] = [-s['walk_forward'][2], 0, s['walk_forward'][0]]
        self.assertIn('e', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.stage, 'hulk_breaker_press')
        for ticks in range(1, 182):
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            s['native_interact'] = ticks < 12
            interior = s['hulk']['interior']
            interior['activity'].update(state_id='active', generation=1,
                                        elapsed_seconds=min(ticks/60, 3))
            interior['breaker_engaged'] = True
            if ticks == 181:
                interior['activity'].update(state_id='claimed', reward_claimed=True, claimed_receipts=1,
                                            elapsed_seconds=claimed_elapsed)
                interior.update(reward_count=1, power_restored=True, emergency_lights=False,
                                bus_lights_restored=True,
                                reward_receipt={'activity_id': 'cinder_hulk_power_restoration',
                                                'reward_id': 'hulk_auxiliary_power_cell',
                                                'activity_generation': 1, 'granted': True,
                                                'receipt_id': 1})
            pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'hulk_repeat_release')
        return pilot, s

    def test_breaker_starts_only_from_actual_supported_exit_then_keeps_all_authored_interior_points(self):
        pilot, s = self.breaker_at_exit(supported=False)
        self.assertEqual(pilot.stage, 'hulk_exit')
        self.assertIsNone(pilot.result)
        self.assertIsNone(pilot.route)
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        s['hulk'].update(shelf_supported=True, support_collider='Exterior/DockShelf')
        self.assertEqual(pilot.update(s, 2), (set(), 0, 0, False))
        self.assertEqual(pilot.stage, 'hulk_walk')
        self.assertEqual(pilot.route[0], [-88, 23, -450])
        self.assertEqual(pilot.route[1:], s['hulk']['interior']['route'][1:])
        self.assertEqual(pilot.arrival_result['completion_marker'], 'NATIVE_HULK_ARRIVAL_OK')
        self.assertEqual(pilot.arrival_result['stages'][-1]['stage'], 'complete')
        self.assertIsNone(pilot.result)

    def test_breaker_walk_rejects_wrong_support_identity_capsule_and_teleport(self):
        for mutation, error in [
            (lambda s: s['hulk']['interior'].update(support_owned=False), 'actual HULK support'),
            (lambda s: s['hulk'].update(hulk_id=99), 'same Player Torrent'),
            (lambda s: s['hulk']['interior'].update(shape_id=99), 'same enabled Player collision'),
            (lambda s: s.update(player=[100, 22, 0]), 'without placement'),
            (lambda s: s.update(transition_busy=True), 'without recovery'),
        ]:
            with self.subTest(error=error):
                pilot, s = self.breaker_at_exit()
                s = json.loads(json.dumps(s))
                s['frame'] += 1
                mutation(s)
                with self.assertRaisesRegex(AssertionError, error):
                    pilot.update(s, 2)

    def test_breaker_refuses_premature_reward_or_engagement_during_walk(self):
        for mutation in [lambda i: i.update(reward_count=1),
                         lambda i: i['activity'].update(state_id='active', generation=1),
                         lambda i: i.update(power_restored=True)]:
            pilot, s = self.breaker_at_exit()
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            mutation(s['hulk']['interior'])
            with self.assertRaisesRegex(AssertionError, 'untouched before the complete ordinary interior walk'):
                pilot.update(s, 2)

    def test_breaker_visits_every_interior_point_and_requires_live_candidate_before_E(self):
        pilot, s = self.walk_breaker_interior()
        self.assertEqual([v['index'] for v in pilot.visited], list(range(6)))
        self.assertGreater(pilot.walked_interior, 70)
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        self.assertNotIn('e', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.stage, 'hulk_breaker_aim')
        self.assertEqual(len(pilot.arrival_result['stages']), 3)

    def test_breaker_completes_only_after_normal_restoration_and_separate_repeat_E_dispatch(self):
        pilot, s = self.press_breaker_and_restore()
        self.assertIsNone(pilot.result)
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        self.assertIn('e', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.stage, 'hulk_repeat_press')
        for ticks in range(1, 15):
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            s['native_interact'] = ticks < 12
            # The live activity refusal proves dispatch, unlike a count that
            # merely stays one while the OS key was never handled.
            s['hulk']['interior']['last_breaker_result'] = {
                'accepted': False, 'reason': 'power_already_restored'}
            pilot.update(s, s['frame']/60)
            if pilot.result: break
        result = pilot.result
        self.assertEqual(result['completion_marker'], 'NATIVE_HULK_BREAKER_OK')
        self.assertEqual((result['initial_reward_count'], result['final_reward_count']), (0, 1))
        self.assertEqual(result['final_generation'], 1)
        self.assertEqual([e['pressed'] for e in result['native_interact_edges']], [True, False, True, False])
        self.assertEqual(result['arrival']['completion_marker'], 'NATIVE_HULK_ARRIVAL_OK')
        self.assertEqual(native.CAP, 300)

    def home_at_breaker(self):
        pilot, s = self.press_breaker_and_restore(pilot_type=native.HulkHomePilot)
        interior = s['hulk']['interior']
        s = json.loads(json.dumps(s))
        s['guided_complete'] = True
        s['walk_offset'] = [0, 0, 0]
        s['candidate'] = False
        s['hulk']['lease_free'] = False
        s['hulk_home'] = {
            'activity': interior['activity'], 'reward_count': 1,
            'reward_receipt': interior['reward_receipt'],
            'capsule_id': 5, 'shape_id': 6, 'capsule_enabled': True,
            'player_velocity': [0, 0, 0], 'walk_tuning': interior['walk_tuning'],
            'physics_ticks': 60, 'time_scale': 1,
            'boarding': [-88, 22, -450], 'station_candidate': '',
            'streaming': {'loaded': True, 'loading': False, 'loaded_instance_id': 8,
                          'loaded_generation': 1, 'generation': 1, 'load_request_count': 1,
                          'load_failure_count': 0, 'unload_count': 0, 'presentation': {},
                          'distance_m': 300, 'unload_radius_m': 650},
            'home': {'berth_id': 'central', 'berth_instance_id': 9,
                     'approach': [0, 2, -18], 'dock': [0, 1.15, -10],
                     'dock_forward': [0, 0, -1], 'selected_berth_id': 'central',
                     'capture': False, 'contract': False, 'landing_abort_reason': '',
                     'lease': False, 'occupant_id': 0, 'parked_exact': False,
                     'grounded': False, 'supported': False, 'support_collider': ''}}
        for ticks in range(15):
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            s['native_interact'] = 0 < ticks < 12
            s['hulk']['interior']['last_breaker_result'] = {
                'accepted': False, 'reason': 'power_already_restored'}
            pilot.update(s, s['frame']/60)
            if pilot.stage == 'home_reverse_walk': break
        self.assertEqual(pilot.stage, 'home_reverse_walk')
        return pilot, s

    def home_at_boarding(self):
        pilot, s = self.home_at_breaker()
        while pilot.stage == 'home_reverse_walk':
            target = pilot.reverse_route[len(pilot.reverse_visited)]
            direction = native.sub([target[0], s['player'][1], target[2]], s['player'])
            distance = native.norm(direction)
            direction = native.unit(direction)
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            s['player'] = [p + d*min(.09, distance) for p, d in zip(s['player'], direction)]
            if distance > 0:
                s['walk_forward'] = direction
                s['walk_right'] = [-direction[2], 0, direction[0]]
            s['hulk']['shelf_supported'] = len(pilot.reverse_visited) == 5
            pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_board_approach')
        self.assertIsNone(pilot.result)
        return pilot, s

    def home_in_flight(self):
        pilot, s = self.home_at_boarding()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+30, candidate=True)
        self.assertIn('e', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.stage, 'home_board')
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+90, phase='START_ENGINES', piloted=True, seated=True,
                 control_enabled=False)
        s['hulk_home']['capsule_enabled'] = False
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_flight')
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+60, phase='FREE_FLIGHT', landed=False,
                 position=[-96, 33, -450])
        s['hulk'].update(lease=False, lease_free=True, occupant_id=0, parked_exact=False)
        pilot.update(s, s['frame']/60)
        self.assertIsNotNone(pilot.hulk_departure)
        return pilot, s

    def home_at_staging(self):
        pilot, s = self.home_in_flight()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+600, position=[0, 2.7, -150], velocity=[0, 0, 0])
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_approach')
        self.assertIsNone(pilot.home_clearance_ready)
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        self.face_home(s)
        self.assertIn('w', pilot.update(s, s['frame']/60)[0])
        self.assertIsNotNone(pilot.home_clearance_ready)
        return pilot, s

    def face_home(self, s, pitch_error=0, yaw_error=0):
        direction = native.unit(native.sub(s['hulk_home']['home']['approach'], s['position']))
        pitch = math.asin(direction[1]) + math.radians(pitch_error)
        yaw = math.atan2(direction[0], direction[2]) + math.radians(yaw_error)
        s['back'] = [-math.sin(yaw)*math.cos(pitch), -math.sin(pitch),
                     -math.cos(yaw)*math.cos(pitch)]
        s['right'] = [-math.cos(yaw), 0, math.sin(yaw)]
        s['up'] = [-math.sin(yaw)*math.sin(pitch), math.cos(pitch),
                   -math.cos(yaw)*math.sin(pitch)]

    def home_across_header(self):
        pilot, s = self.home_at_staging()
        for position in ([0, 2.6, -125], [0, 2.5, -109]):
            s = json.loads(json.dumps(s))
            s.update(frame=s['frame']+30, position=position)
            pilot.update(s, s['frame']/60)
        self.assertIsNotNone(pilot.home_header_crossing)
        return pilot, s

    def home_after_unload(self):
        pilot, s = self.home_across_header()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+1200, position=[0, 2, -18])
        s['hulk'] = {'available': False}
        s['hulk_home']['streaming'].update(loaded=False, loaded_instance_id=0,
            loaded_generation=-1, generation=2, unload_count=1, distance_m=688,
            presentation={'accepted': True, 'generation': 1, 'phase': 'fade_out_complete',
                          'opacity': 0, 'retire_ready': True})
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_align')
        return pilot, s

    def home_at_exit(self):
        pilot, s = self.home_after_unload()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+30, camera=[0, 2, -18], back=[0, 0, -1],
                 right=[-1, 0, 0])
        s['hulk_home']['home'].update(capture=True, dock=[0, 2, -10])
        self.assertIn('l', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.stage, 'home_land')
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+1, landing_active=True)
        pilot.update(s, s['frame']/60)
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+90, landing_active=False, landed=True, phase='SHUT_DOWN',
                 position=s['parked'], lease_free=False)
        s['hulk_home']['home'].update(contract=True, lease=True, parked_exact=True, occupant_id=2)
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_shutdown')
        s = json.loads(json.dumps(s))
        s['frame'] += 89
        s['telemetry']['engine'] = 'OFFLINE'
        self.assertNotIn('e', pilot.update(s, s['frame']/60)[0])
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        self.assertIn('e', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.stage, 'home_exit')
        return pilot, s

    def test_home_retains_full_breaker_prefix_and_reverses_actual_exit_route(self):
        pilot, s = self.home_at_boarding()
        self.assertEqual(pilot.reverse_route, list(reversed(pilot.route)))
        self.assertEqual([v['index'] for v in pilot.reverse_visited], [5, 4, 3, 2, 1, 0])
        self.assertEqual(pilot.reverse_route[-1], pilot.breaker_result['walk_route'][0])
        self.assertNotEqual(pilot.reverse_route[-1], pilot.breaker_result['authored_route'][0])
        self.assertEqual(pilot.breaker_result['completion_marker'], 'NATIVE_HULK_BREAKER_OK')
        self.assertEqual(pilot.breaker_result['arrival']['completion_marker'], 'NATIVE_HULK_ARRIVAL_OK')
        self.assertEqual(pilot.breaker_result['final_reward_count'], 1)
        self.assertGreater(pilot.reverse_walked, 70)
        # Parent require_unclaimed cannot run after the accepted breaker.
        with patch.object(native.HulkBreakerPilot, 'update', side_effect=AssertionError('parent called')):
            s = json.loads(json.dumps(s))
            s['candidate'] = True
            s['frame'] += 1
            pilot.update(s, s['frame']/60)

    def test_home_requires_live_unconflicted_boarding_and_never_retries_E(self):
        pilot, s = self.home_at_boarding()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+30, candidate=True)
        s['hulk_home']['station_candidate'] = 'HULK/Breaker'
        with self.assertRaisesRegex(AssertionError, 'conflicting station candidate'):
            pilot.update(s, s['frame']/60)
        s['hulk_home']['station_candidate'] = ''
        self.assertIn('e', pilot.update(s, s['frame']/60)[0])
        s = json.loads(json.dumps(s))
        s['frame'] += 121
        with self.assertRaisesRegex(AssertionError, 'no retry'):
            pilot.update(s, s['frame']/60)

    def test_home_rejects_cell_identity_changes_capsule_replacement_and_unreleased_departure(self):
        for mutate, error in [
            (lambda s: s['hulk_home'].update(reward_count=2), 'earned cell count one'),
            (lambda s: s['hulk_home']['reward_receipt'].update(receipt_id=99), 'exact receipt'),
            (lambda s: s['hulk_home']['activity'].update(generation=2), 'generation one'),
            (lambda s: s['hulk_home'].update(shape_id=99), 'same home berth and Player collision'),
            (lambda s: s['hulk'].update(lease_free=False), 'old HULK lease stays free'),
        ]:
            with self.subTest(error=error):
                pilot, s = self.home_in_flight()
                s = json.loads(json.dumps(s))
                s['frame'] += 1
                mutate(s)
                with self.assertRaisesRegex(AssertionError, error):
                    pilot.update(s, s['frame']/60)

    def test_home_requires_actual_fade_retirement_unload_and_rejects_reload(self):
        for mutate, error in [
            (lambda s: s['hulk_home']['streaming']['presentation'].update(retire_ready=False), 'outside tick'),
            (lambda s: s['hulk_home']['streaming']['presentation'].update(opacity=.1), 'zero-opacity'),
            (lambda s: s['hulk_home']['streaming'].update(distance_m=650), 'outside tick'),
            (lambda s: s['hulk_home']['streaming'].update(load_request_count=2), 'no reload'),
            (lambda s: s['hulk_home']['streaming'].update(generation=3), 'actual Cinder unload'),
        ]:
            with self.subTest(error=error):
                pilot, s = self.home_after_unload()
                s = json.loads(json.dumps(s))
                s['frame'] += 1
                mutate(s)
                with self.assertRaisesRegex(AssertionError, error):
                    pilot.update(s, s['frame']/60)
        pilot, s = self.home_across_header()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+1200, position=[0, 2, -18])
        # A long wait at home cannot substitute for the actual streamed unload.
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_approach')
        self.assertIsNone(pilot.result)

    def test_home_clearance_staging_requires_arrival_and_full_settle_before_approach(self):
        pilot, s = self.home_in_flight()
        self.assertEqual(pilot.home_clearance_target, [0, 2.7, -150])
        for position, velocity in [([0, 2.7, -152], [0, 0, 0]),
                                   ([0, 2.7, -150], [0, 0, .36])]:
            s = json.loads(json.dumps(s))
            s.update(frame=s['frame']+60, position=position, velocity=velocity)
            pilot.update(s, s['frame']/60)
            self.assertEqual(pilot.stage, 'home_flight')
            self.assertIsNone(pilot.home_clearance_staging)
            self.assertIsNone(pilot.home_header_crossing)
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+60, velocity=[0, 0, 0])
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_approach')
        self.assertEqual(pilot.home_clearance_staging['waypoint'], [0, 2.7, -150])
        self.assertEqual(pilot.home_clearance_staging['speed_m_s'], 0)
        self.assertIsNone(pilot.home_header_crossing)

    def test_home_clearance_waits_for_observed_attitude_and_settled_velocity(self):
        pilot, s = self.home_in_flight()
        # Retained failed route frames 5005/5006: arrival and then zero
        # velocity, but the same nose remains 9.286 degrees down.
        s = json.loads(json.dumps(s))
        s.update(frame=5005,
                 position=[-.355457872152328, 2.85557842254639, -150.746719360352],
                 velocity=[.0643201246857643, -.0256182551383972, .144237756729126],
                 back=[-.403144985437393, .161362916231155, -.900797545909882],
                 up=[.044654157012701, .986627817153931, .156753361225128],
                 right=[-.914046049118042, -.0229699686169624, .40495952963829],
                 camera=[-6.84788227081299, 12.66379737854, -164.971878051758])
        keys, _, _, _ = pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_approach')
        self.assertIn('Prior', keys)
        self.assertNotIn('w', keys)
        self.assertIsNone(pilot.home_clearance_ready)
        s = json.loads(json.dumps(s))
        s.update(frame=5006, velocity=[0, 0, 0],
                 camera=[-6.85218906402588, 12.6680374145508, -164.967407226562])
        keys, _, _, _ = pilot.update(s, s['frame']/60)
        self.assertIn('Prior', keys)
        self.assertNotIn('w', keys)
        self.assertIsNone(pilot.home_clearance_ready)
        self.assertAlmostEqual(math.degrees(math.asin(-s['back'][1])), -9.285997, places=4)

        for velocity, pitch_error, yaw_error in [
            ([0, 0, .02], 0, 0),  # aligned but still moving
            ([0, -.02, 0], 0, 0),  # aligned but descending
            ([0, 0, 0], .6, 0),  # dot exceeds .9999; pitch is still unsafe
            ([0, 0, 0], 0, 1),  # pitch is ready; direction is not
        ]:
            with self.subTest(velocity=velocity, pitch_error=pitch_error, yaw_error=yaw_error):
                s = json.loads(json.dumps(s))
                s.update(frame=s['frame']+1, velocity=velocity)
                self.face_home(s, pitch_error=pitch_error, yaw_error=yaw_error)
                keys, _, _, _ = pilot.update(s, s['frame']/60)
                self.assertIn('Prior', keys)
                self.assertNotIn('w', keys)
                self.assertIsNone(pilot.home_clearance_ready)

        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+1, velocity=[0, 0, 0])
        self.face_home(s, pitch_error=.4)
        keys, _, _, _ = pilot.update(s, s['frame']/60)
        self.assertIn('w', keys)
        self.assertNotIn('Prior', keys)
        ready = pilot.home_clearance_ready
        self.assertEqual(ready['frame'], s['frame'])
        self.assertEqual(ready['position'], s['position'])
        self.assertEqual(ready['velocity'], [0, 0, 0])
        self.assertEqual(ready['speed_m_s'], 0)
        self.assertGreaterEqual(ready['direction_alignment'], .9999)
        self.assertAlmostEqual(ready['pitch_error_deg'], .4)
        self.assertGreater(ready['frame'], pilot.home_clearance_staging['frame'])
        # Once departure was observed ready, ordinary speed and brake logic
        # continues without imposing the initial settled-speed gate again.
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+1, velocity=[0, 0, 10])
        self.assertIn('w', pilot.update(s, s['frame']/60)[0])
        self.assertEqual(pilot.home_clearance_ready, ready)

    def test_home_header_crossing_refuses_missing_staging_unsafe_altitude_or_extra_damage(self):
        pilot, s = self.home_in_flight()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+600, position=[0, 2.7, -125])
        with self.assertRaisesRegex(AssertionError, 'staging must be reached and fully settled'):
            pilot.update(s, s['frame']/60)
        for position, hull, error in [
            ([0, 8.6833, -120], 100, 'documented ship-origin clearance band'),
            ([0, 1.39, -120], 100, 'documented ship-origin clearance band'),
            ([0, 2.6, -120], 99, 'no extra hull loss'),
        ]:
            with self.subTest(position=position, hull=hull):
                pilot, s = self.home_at_staging()
                s = json.loads(json.dumps(s))
                s.update(frame=s['frame']+30, position=position)
                s['telemetry']['hull'] = hull
                with self.assertRaisesRegex(AssertionError, error):
                    pilot.update(s, s['frame']/60)
                self.assertIsNone(pilot.home_header_crossing)
        pilot, s = self.home_across_header()
        receipt = pilot.home_header_crossing
        self.assertEqual(receipt['origin_z_interval'], [-130, -110])
        self.assertGreaterEqual(receipt['min_y'], 1.4)
        self.assertLessEqual(receipt['max_y'], 3.8)
        self.assertEqual(receipt['hull_before'], receipt['hull_after'])
        self.assertGreater(receipt['exit_frame'], pilot.home_clearance_staging['frame'])
        self.assertEqual(receipt['samples'][-1]['position'], [0, 2.5, -109])

    def test_home_completes_only_after_strict_dock_neutral_shutdown_and_supported_twenty_tick_walk(self):
        pilot, s = self.home_at_exit()
        s = json.loads(json.dumps(s))
        s.update(frame=s['frame']+120, phase='COMPLETE', piloted=False, seated=False,
                 control_enabled=True, player=[8, .1, -10])
        s['hulk_home']['capsule_enabled'] = True
        s['hulk_home']['home'].update(grounded=True, supported=True, support_collider='LandingPad/Deck')
        pilot.update(s, s['frame']/60)
        self.assertEqual(pilot.stage, 'home_walk')
        self.assertIsNone(pilot.result)
        for tick in range(20):
            s = json.loads(json.dumps(s))
            s['frame'] += 1
            s['player'][2] -= .09
            pilot.update(s, s['frame']/60)
        result = pilot.result
        self.assertEqual(result['completion_marker'], 'NATIVE_HULK_HOME_OK')
        self.assertEqual(result['home_walk_ticks'], 20)
        self.assertEqual(result['home_clearance_staging']['waypoint'], [0, 2.7, -150])
        self.assertIsNotNone(result['home_clearance_ready'])
        self.assertEqual(result['home_header_crossing']['hull_before'],
                         result['home_header_crossing']['hull_after'])
        self.assertGreater(result['home_walk_displacement_m'], .25)
        self.assertLess(result['home_walk_displacement_m'], 5)
        self.assertEqual(result['hulk_departure']['phase'], 'FREE_FLIGHT')
        self.assertTrue(result['hulk_departure']['lease_free'])
        self.assertTrue(result['cinder_unload']['old_hulk_absent'])
        self.assertEqual((result['final_reward_count'], result['final_generation']), (1, 1))
        self.assertEqual(result['reward_receipt'], result['breaker']['claimed']['receipt'])
        self.assertEqual(native.CAP, 300)

    def test_home_rejects_unsupported_or_unusable_yard_exit(self):
        for supported in (False, True):
            with self.subTest(supported=supported):
                pilot, s = self.home_at_exit()
                s = json.loads(json.dumps(s))
                s.update(frame=s['frame']+120, phase='COMPLETE', piloted=False, seated=False,
                         control_enabled=True, player=[8, .1, -10])
                s['hulk_home']['capsule_enabled'] = True
                s['hulk_home']['home'].update(grounded=True, supported=supported, support_collider='LandingPad/Deck')
                if not supported:
                    with self.assertRaisesRegex(AssertionError, 'supported yard exit'):
                        pilot.update(s, s['frame']/60)
                else:
                    pilot.update(s, s['frame']/60)
                    s = json.loads(json.dumps(s))
                    s['frame'] += 20
                    with self.assertRaisesRegex(AssertionError, 'more than a quarter metre'):
                        pilot.update(s, s['frame']/60)

    def test_breaker_restoration_accepts_observed_float_but_refuses_early_time_or_frames(self):
        # The exported route emitted this normal accumulated physics duration.
        pilot, s = self.press_breaker_and_restore(claimed_elapsed=2.99999999999999)
        self.assertEqual(pilot.stage, 'hulk_repeat_release')
        self.assertEqual(s['hulk']['interior']['activity']['elapsed_seconds'], 2.99999999999999)
        with self.assertRaisesRegex(AssertionError, 'normal three-second production restoration'):
            self.press_breaker_and_restore(claimed_elapsed=2.999)
        # The near-three float must not bypass the independent 180-frame floor.
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        pilot.stage = 'hulk_restoring'
        pilot.first_press = s['frame'] - 179
        with self.assertRaisesRegex(AssertionError, 'normal three-second production restoration'):
            pilot.update(s, s['frame']/60)

    def test_breaker_rejects_accelerated_timer_and_duplicate_reward(self):
        pilot, s = self.breaker_at_exit()
        s = json.loads(json.dumps(s))
        s['frame'] += 1
        s['hulk']['interior']['activity']['elapsed_seconds'] = 3
        with self.assertRaisesRegex(AssertionError, 'without accelerated activity timer'):
            pilot.update(s, 2)
        for mutation, error in [
            (lambda i: i.update(reward_count=2), 'exactly one committed'),
            (lambda i: i['reward_receipt'].update(receipt_id=2), 'same committed cell receipt'),
            (lambda i: i.update(bus_lights_restored=False), 'restored bus lighting'),
        ]:
            with self.subTest(error=error):
                pilot, s = self.press_breaker_and_restore()
                s = json.loads(json.dumps(s))
                s['frame'] += 1
                mutation(s['hulk']['interior'])
                with self.assertRaisesRegex(AssertionError, error):
                    pilot.update(s, s['frame']/60)

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

    def test_full_walk_releases_early_and_settles_before_advancing_a_corner(self):
        for stage in ('craft_approach', 'walk_station'):
            with self.subTest(stage=stage):
                pilot = native.SandboxPilot()
                s = self.full_observation()
                target = [0, 0, 0]
                # An actual right-angle corner: the old station fixture used
                # Central followed by tractor_west_clearance, both straight
                # ahead from its approach and therefore eligible to continue.
                pilot.WAYPOINTS = (('before', [0, 0, 10]), ('corner', target),
                                   ('after', [1, 0, 0]))
                s['player'] = [target[0], target[1], target[2]+1]
                pilot.update(s, 1)
                pilot.stage = stage
                pilot.index = 1
                pilot.craft_key = 'arrow_provisional'
                pilot.pending_walk = [target, [target[0]+1, target[1], target[2]]]
                # Observed 5.8m/s approach: releasing only inside .30m let the
                # body drift past an aft-wing corner while the next goal began.
                for frame, offset in [(103, .71), (106, .49), (109, .34), (112, .26)]:
                    observation = dict(s, frame=frame,
                                       player=[target[0], target[1], target[2]+offset])
                    keys, *_ = pilot.update(observation, 1+(frame-100)/60)
                    self.assertNotIn('w', keys)
                    self.assertEqual(pilot.index, 1)
                    self.assertEqual(len(pilot.pending_walk), 2)
                # Same radius, grounded floor and now genuinely settled speed.
                observation = dict(s, frame=115,
                                   player=[target[0], target[1], target[2]+.25])
                pilot.update(observation, 1.25)
                self.assertEqual(pilot.index-1 if stage == 'walk_station' else 2-len(pilot.pending_walk), 1)

        for stage in ('craft_approach', 'return_walk', 'recovery_walk', 'walk_station'):
            with self.subTest(straight_stage=stage):
                pilot = native.SandboxPilot()
                pilot.WAYPOINTS = (('before', [0, 0, 10]), ('middle', [0, 0, 0]),
                                   ('after', [0, 0, -10]))
                s = self.full_observation()
                s['player'] = [0, 0, 1]
                s['spawn'] = [0, 0, 10]
                pilot.update(s, 1)
                pilot.stage, pilot.index = stage, 1
                pilot.craft_key = 'arrow_provisional'
                s['sandbox']['fleet'][pilot.craft_key].update(active_ship=True, details_current=True)
                pilot.pending_walk = [[0, 0, 0], [0, 0, -10]]
                pilot.walk_origin = [0, 0, 10]
                for frame, offset in [(103, .71), (106, .49), (109, .34), (112, .26)]:
                    keys, *_ = pilot.update(dict(s, frame=frame, player=[0, 0, offset]),
                                            1+(frame-100)/60)
                    self.assertIn('w', keys)
                    self.assertIn('Shift_L', keys)
                self.assertGreater(native.norm(pilot.foot_velocity), pilot.SETTLED_WALK_SPEED)
                self.assertEqual(pilot.index if stage == 'walk_station' else len(pilot.pending_walk),
                                 2 if stage == 'walk_station' else 1)

    def test_early_bomber_returns_to_station_and_cargo_skips_it_before_guarded_crash(self):
        pilot = native.SandboxPilot()
        s = self.full_observation()
        pilot.stage = 'walk_station'
        pilot.index = next(i for i, (name, _) in enumerate(pilot.WAYPOINTS) if name == 'aft_stair_top')
        s['player'] = pilot.WAYPOINTS[pilot.index][1][:]
        pilot.update(s, 1)
        self.assertEqual(pilot.craft_key, 'cinder_long_range_bomber')
        resume, station_index = pilot.resume_target, pilot.index

        pilot.stage = 'craft_exit'
        craft = s['sandbox']['fleet'][pilot.craft_key]
        craft.update(active_ship=True, details_current=True, exit=s['player'])
        pilot.update(dict(s, frame=101), 1.02)
        self.assertEqual(pilot.stage, 'return_walk')
        self.assertEqual(pilot.pending_walk[-1], resume)
        self.assertEqual(pilot.completed[-1]['craft'], 'cinder_long_range_bomber')
        pilot.pending_walk = [resume]
        pilot.update(dict(s, frame=102), 1.04)
        pilot.update(dict(s, frame=103), 1.06)
        self.assertEqual((pilot.stage, pilot.index), ('walk_station', station_index))
        self.assertIsNone(pilot.resume_target)

        pilot.stage, pilot.craft_key = 'craft_exit', 'cinder_cargo_hauler'
        craft.update(active_ship=False)
        cargo = s['sandbox']['fleet'][pilot.craft_key]
        cargo.update(active_ship=True, details_current=True, exit=s['player'])
        pilot.update(dict(s, frame=104), 1.08)
        self.assertEqual((pilot.stage, pilot.craft_key), ('craft_approach', 'cinder_light_interceptor'))
        pilot.stage = 'craft_exit'
        cargo.update(active_ship=False)
        s['sandbox']['fleet'][pilot.craft_key].update(active_ship=True, details_current=True, exit=s['player'])
        with self.assertRaisesRegex(AssertionError, 'all eight required craft secured before deliberate crash'):
            pilot.update(dict(s, frame=105), 1.10)
        self.assertFalse(pilot.crashed)

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
