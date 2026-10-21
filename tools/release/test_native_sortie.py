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
    def supply_paid_observation(self):
        reward = native.CinderSupplyPilot.REWARD
        return {'paid_slot': {'delivery': {'contract_id': 'cinder_platform_supply_run', 'quantity': 1,
                'generation': 1, 'ordered_phases': ['load_crate', 'clear_gate', 'dock_platform'],
                'deadline_seconds': 120, 'elapsed_seconds': 24,
                'transfer_proof': {'source_quantity_after': 1, 'destination_quantity_after': 1},
                'reward_receipt': {'activity_id': 'cinder_kit_cargo_run', 'reward_id': reward,
                                   'granted': True, 'replay_allowed': False}}},
                'reward_record': {'total_receipts': 1, 'receipt_serial': 1, 'reward_counts': {reward: 1},
                    'last_receipt': {'activity_id': 'cinder_kit_cargo_run', 'activity_generation': 1,
                                     'granted': True, 'replay_allowed': False}}}

    def test_supply_stopping_distance_uses_authored_jovian_brake(self):
        pilot = native.CinderSupplyPilot()
        for brake, expected in [(25, 'Prior'), (48, 'w')]:
            with self.subTest(brake=brake):
                s = {'position': [0, 0, 0], 'camera': [0, 0, 10], 'ship_velocity': [0, 0, -40],
                     'right': [1, 0, 0], 'up': [0, 1, 0], 'back': [0, 0, 1],
                     'tuning': {'brake': brake, 'mouse': .0022}}
                keys = set()
                pilot.flight(s, [0, 0, -25], keys)
                self.assertEqual(keys, {expected})

    def test_supply_ordinary_roll_feedback_reduces_actual_basis_error(self):
        pilot = native.CinderSupplyPilot()
        for degrees in (35, -35, 160, -160):
            with self.subTest(degrees=degrees):
                angle = math.radians(degrees)
                right, up = [math.cos(angle), math.sin(angle), 0], [-math.sin(angle), math.cos(angle), 0]
                s = {'position': [0, 0, 0], 'camera': [0, 0, 10], 'ship_velocity': [0, 0, 0],
                     'right': right, 'up': up, 'back': [0, 0, 1], 'tuning': {'brake': 48, 'mouse': .0022}}
                keys = set()
                pilot.flight(s, [0, 0, -100], keys)
                self.assertIn('r' if degrees > 0 else 'q', keys)
                self.assertNotIn('q' if degrees > 0 else 'r', keys)
                # HeroShip rotates about local FORWARD (-Z): positive R makes
                # new right=cos(a)*right-sin(a)*up, new up=sin(a)*right+cos(a)*up.
                delta = math.radians(2 if 'r' in keys else -2)
                next_right_y = math.cos(delta)*right[1]-math.sin(delta)*up[1]
                next_up_y = math.sin(delta)*right[1]+math.cos(delta)*up[1]
                self.assertLess(abs(math.atan2(next_right_y, next_up_y)), abs(angle))
        for right, up in [([1, 0, 0], [0, 1, 0]), ([1, 0, 0], [0, .01, -math.sqrt(1-.01**2)])]:
            back = [right[1]*up[2]-right[2]*up[1], right[2]*up[0]-right[0]*up[2], right[0]*up[1]-right[1]*up[0]]
            s = {'position': [0, 0, 0], 'camera': [0, 0, 10], 'ship_velocity': [0, 0, 0],
                 'right': right, 'up': up, 'back': back, 'tuning': {'brake': 48, 'mouse': .0022}}
            keys = set()
            pilot.flight(s, [-v*100 for v in back], keys)
            self.assertTrue(keys.isdisjoint({'q', 'r'}))

    def test_supply_authored_capture_admits_normal_landing_without_extra_stop(self):
        for stage, expected in [('outbound', 'cargo_land'), ('gate_brake', 'cargo_redock'),
                                ('gate_return', 'cargo_redock'), ('home_flight', 'home_land')]:
            for accepted in (True, False):
                with self.subTest(stage=stage, accepted=accepted):
                    pilot = native.CinderSupplyPilot()
                    pilot.stage = stage
                    # Actual first accepted Cinder approach: speed34.9306 is
                    # inside authored35, with1.618m root error and upright.638.
                    s = {'frame': 5345, 'phase': 'FREE_FLIGHT', 'position': [31, -62.85, -740.382],
                         'player': [31, -62, -740], 'ship_velocity': [0, 0, -34.9306],
                         'camera': [31, -60, -730], 'right': [1, 0, 0], 'up': [0, .638, .77],
                         'back': [0, -.77, .638], 'tuning': {'brake': 48, 'mouse': .0022},
                         'cargo': {'available': True, 'capture': accepted, 'capture_position': [31, -62.85, -742]},
                         'home': {'capture': accepted, 'capture_position': [31, -62.85, -742]}}
                    pilot.last_state = s
                    keys, _, _, _ = pilot.update(s, 1)
                    self.assertEqual('l' in keys, accepted)
                    self.assertEqual(pilot.stage, expected if accepted else stage)

    def test_supply_root_waypoint_aim_ignores_displaced_chase_camera(self):
        pilot = native.CinderSupplyPilot()
        # Actual failed observation's root/camera displacement. Align the hull
        # with the root-to-capture vector: navigation should request no turn.
        position, camera, target = [-53, -11.69, 108.13], [-53, -40.16, 116.10], [-53, 13.63, 83.3]
        forward = native.unit(native.sub(target, position))
        s = {'position': position, 'camera': camera, 'ship_velocity': [0, 0, 0],
             'right': [1, 0, 0], 'up': [0, -forward[2], forward[1]],
             'back': [-v for v in forward], 'tuning': {'brake': 48, 'mouse': .0022}}
        self.assertNotEqual(pilot.aim(s, target, .3)[1], 0)
        keys = set()
        dx, dy, settled = pilot.flight(s, target, keys)
        self.assertEqual((dx, dy), (0, 0))
        self.assertEqual(keys, {'w'})
        self.assertFalse(settled)
        self.assertEqual(s['camera'], camera)

    def test_supply_eight_metre_launch_cannot_turn_directly_toward_cinder(self):
        pilot = native.CinderSupplyPilot()
        pilot.stage = 'launch'
        pilot.initial = {'parked': [-53, 1.63, 57.3]}
        s = {'frame': 2261, 'phase': 'FREE_FLIGHT', 'position': [-53, 1.63, 65.53],
             'player': [-53, 2, 65.53], 'ship_velocity': [0, 0, 15.38],
             'landed': False, 'home': {'lease_free': True, 'capture_position': [-53, 13.63, 83.3]},
             'cargo': {'available': False}}
        pilot.last_state = s
        pilot.update(s, 1)
        self.assertEqual(pilot.stage, 'outbound_clearance')
        with patch.object(pilot, 'flight', return_value=(0, 0, False)) as flight:
            pilot.update(s, 2)
        self.assertEqual(flight.call_args.args[1], s['home']['capture_position'])
        self.assertEqual(pilot.stage, 'outbound_clearance')
        self.assertEqual(pilot.clearance_index, 0)
        outbound = pilot.station_clearance_targets(s)
        self.assertEqual(len(outbound), 6)
        self.assertEqual(outbound[-1], [31, 80, -225])
        self.assertEqual(pilot.station_clearance_targets(s, reverse=True), list(reversed(outbound)))
        translated = copy.deepcopy(s)
        translated['home']['capture_position'] = [p+10 for p in s['home']['capture_position']]
        self.assertEqual(pilot.station_clearance_targets(translated), [[p+10 for p in point] for point in outbound])

    def test_supply_payment_requires_actual_transfer_and_one_credit(self):
        pilot = native.CinderSupplyPilot()
        s = self.supply_paid_observation()
        pilot.require_paid(s)
        for section, key, value in [('transfer_proof', 'source_quantity_after', 2),
                                    ('transfer_proof', 'destination_quantity_after', 0),
                                    ('reward_receipt', 'granted', False)]:
            bad = copy.deepcopy(s)
            bad['paid_slot']['delivery'][section][key] = value
            with self.assertRaises(AssertionError): pilot.require_paid(bad)
        bad = copy.deepcopy(s); bad['reward_record']['total_receipts'] = 2
        with self.assertRaises(AssertionError): pilot.require_paid(bad)
        bad = copy.deepcopy(s); bad['paid_slot']['delivery']['elapsed_seconds'] = 120
        with self.assertRaises(AssertionError): pilot.require_paid(bad)

    def test_supply_paid_receipt_survives_retired_live_binding_but_cannot_change(self):
        pilot = native.CinderSupplyPilot()
        s = self.supply_paid_observation()
        pilot.paid_slot, pilot.paid_record = copy.deepcopy(s['paid_slot']), copy.deepcopy(s['reward_record'])
        s['cargo'] = {'available': False}
        pilot.require_paid(s)
        s['paid_slot']['delivery']['elapsed_seconds'] += 1
        with self.assertRaises(AssertionError): pilot.require_paid(s)

    def test_supply_real_file_payment_rejects_unrelated_payload_corruption(self):
        with tempfile.TemporaryDirectory() as root:
            profile, output = Path(root)/'profile', Path(root)/'result'
            (profile/'data').mkdir(parents=True)
            output.mkdir()
            path = profile/'data'/'mudds_user_data.json'
            document = self.restart_document()
            path.write_text(json.dumps(document))
            files, pilot = native.CinderSupplyFiles(profile, output), native.CinderSupplyPilot()
            sample = {'path': str(path), 'generation': document['generation'], 'source': 'primary'}
            s = dict(self.supply_paid_observation(), save=sample)
            files.observe(s, pilot)
            document['generation'] += 1
            document['payload']['cinder_cargo_delivery'] = s['paid_slot']
            document['payload']['game_flow_reward_store'] = s['reward_record']
            document['payload']['unrelated']['progress'].append(99)
            path.write_text(json.dumps(document))
            sample['generation'] = document['generation']
            pilot.paid_state = s
            with self.assertRaisesRegex(AssertionError, 'unrelated actual-file'):
                files.observe(s, pilot)
            self.assertFalse(pilot.file_paid)

    def test_supply_cannot_finish_before_real_normal_ui_exit(self):
        pilot = native.CinderSupplyPilot()
        with self.assertRaises(AssertionError): pilot.finish(0)
        pilot.quit_requested = True; pilot.stage = 'quit_wait'; pilot.file_home = True
        with self.assertRaises(AssertionError): pilot.finish(1)

    def life_observation(self):
        return {'mode': 'life-tow', 'actors_current': True, 'frame': 100, 'phase': 'INTRO',
                'main_id': 1, 'world_id': 2, 'player_id': 3, 'capsule_id': 4, 'shape_id': 5, 'ship_id': 6,
                'player': [-8.5, .18, 11], 'position': [-8.5, .18, 11], 'spawn': [-8.5, .18, 11],
                'menu_ready': False, 'walk_forward': [1, 0, 0], 'walk_right': [0, 0, 1],
                'velocity': [0, 0, 0], 'walk_tuning': native.LifeTowPilot.DEFAULT_WALK.copy(),
                'capsule_geometry': [.38, 1.8], 'physics_ticks': 60, 'time_scale': 1,
                'control_enabled': True, 'seated': False, 'station_seated': False,
                'game_station_seated': False, 'sleeping': False, 'transition_busy': False,
                'mouse_captured': True, 'capsule_enabled': True, 'native_interact': False,
                'grounded': True, 'supported': True, 'support_collider': '/Main/World/Deck',
                'default_controls': True, 'default_sampler': True, 'tuning_unchanged': True,
                'ship_tuning': {'mouse': .0022, 'boarding': .8}, 'candidate': False,
                'walk_offset': [10, 0, 0], 'piloted': False, 'remote_piloted': False,
                'active_ship': True, 'seated_at_pilot': False,
                'service': {'id': 7, 'clock': 1.0, 'enabled': True, 'advancing': True,
                            'processing': True, 'visible': True,
                            'movers': [{'id': 10+i, 'path': 'mover'+str(i), 'visible': True,
                                        'drawn_mesh_ids': [100+i],
                                        'pose': [[0., 0., 0.], [1., 0., 0.], [0., 1., 0.], [0., 0., 1.]]}
                                       for i in range(7)]}}

    def life_tick(self, pilot, s, frames=1, clock=True, movers=True):
        s['frame'] += frames
        if pilot.config.get('motion_proof', False):
            self.arm_motion(s, pilot.observed_previous)
        if clock: s['service']['clock'] += frames/60
        if movers: s['service']['movers'][0]['pose'][0][0] += frames*.001
        return pilot.update(copy.deepcopy(s), s['frame']/60)

    def life_walking_pilot(self, route="life-tow"):
        pilot = native.LifeTowPilot(route)
        s = {'life-tow': self.life_observation, 'life-gantry': self.gantry_observation,
             'life-arm': self.arm_observation, 'life-patrol': self.patrol_observation}[route]()
        s['menu_ready'] = True
        pilot.update(copy.deepcopy(s), 0)
        s.update(phase='APPROACH_SHIP', native_interact=True)
        self.life_tick(pilot, s)
        s['native_interact'] = False
        return pilot, s

    def life_seated_pilot(self):
        pilot, s = self.life_walking_pilot()
        # Unit seam for the post-ownership interval; the positive full journey
        # below establishes the ordinary press/transition admission separately.
        pilot.stage = 'seated_observe'
        pilot.seated_frame = s['frame']
        pilot.seated_service = copy.deepcopy(s['service'])
        s.update(phase='START_ENGINES', seated=True, seated_at_pilot=True, piloted=True,
                 grounded=False, supported=False, capsule_enabled=False)
        return pilot, s

    def test_life_tow_complete_real_walk_then_original_pilot_interval(self):
        pilot, s = self.life_walking_pilot()
        for name, target in native.LifeTowPilot.OUTBOUND + native.LifeTowPilot.RETURN:
            # Dense supported samples exercise continuity as well as ordered goals.
            target = [target[0], .18, target[2]]
            while native.norm(native.sub(target, s['player'])) > .09:
                delta = native.sub(target, s['player'])
                step = [v*.09/native.norm(delta) for v in delta]
                s['player'] = [a+b for a, b in zip(s['player'], step)]
                s['position'] = s['player'][:]
                self.life_tick(pilot, s)
            s['player'] = target
            s['position'] = target[:]
            # The driver stops at .30 m, so avoid feeding extra old-goal frames
            # after it has already advanced to the next waypoint.
            if not pilot.visited or pilot.visited[-1]['waypoint'] != name:
                self.life_tick(pilot, s)
        self.assertEqual(pilot.stage, 'approach_ship')
        s.update(candidate=True, walk_offset=[0, 0, 0])
        self.life_tick(pilot, s)
        self.assertEqual(pilot.stage, 'board')
        # Candidate can clear on the very frame that accepts Interact.
        s.update(phase='BOARDING', native_interact=True, candidate=False,
                 transition_busy=True, control_enabled=False)
        self.life_tick(pilot, s)
        s.update(phase='START_ENGINES', seated=True, seated_at_pilot=True, piloted=True,
                 grounded=False, supported=False, capsule_enabled=False, transition_busy=False)
        self.life_tick(pilot, s)
        self.assertEqual(pilot.stage, 'seated_observe')
        s['native_interact'] = False
        self.life_tick(pilot, s, 89)
        self.assertIsNone(pilot.result)
        self.life_tick(pilot, s)
        self.assertEqual(pilot.result['completion_marker'], 'NATIVE_LIFE_TOW_OK')
        self.assertEqual(pilot.result['seated_physics_frames'], 90)
        self.assertEqual([v['waypoint'] for v in pilot.visited],
                         [name for name, _point in pilot.OUTBOUND + pilot.RETURN])
        self.assertGreater(pilot.result['nearby_walked_m'], 10)

    def test_life_tow_boarding_requires_prior_candidate_and_actual_board_edge(self):
        def boarding_fixture():
            pilot, s = self.life_walking_pilot()
            self.life_tick(pilot, s)  # Observe release of the earlier Start Shift press.
            s.update(candidate=True)
            pilot.receipts['board_press'] = pilot.receipt(copy.deepcopy(s))
            pilot.stage = 'board'
            s.update(phase='BOARDING', native_interact=True, candidate=False,
                     transition_busy=True, control_enabled=False)
            return pilot, s

        # The first observed pressed sample may already be normal BOARDING.
        pilot, s = boarding_fixture()
        self.life_tick(pilot, s)
        self.assertEqual(pilot.native_edges[-1]['stage'], 'board')
        self.assertEqual(pilot.phases[-1], 'BOARDING')
        # A held press continues to authorize only this same busy transition.
        self.life_tick(pilot, s)
        self.assertEqual(pilot.stage, 'board')
        mutations = [lambda p, s: setattr(p, 'stage', 'approach_ship'),
                     lambda p, s: p.receipts.pop('board_press'),
                     lambda p, s: p.receipts['board_press'].update(candidate=False),
                     lambda p, s: p.receipts['board_press'].update(ship_id=999),
                     lambda p, s: p.receipts['board_press'].update(player_id=999),
                     lambda p, s: p.receipts['board_press'].update(frame=s['frame']+1),
                     lambda p, s: s.update(native_interact=False),
                     lambda p, s: s.update(transition_busy=False),
                     lambda p, s: s.update(control_enabled=True)]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                pilot, s = boarding_fixture()
                mutate(pilot, s)
                with self.assertRaisesRegex(AssertionError, 'BOARDING only follows'):
                    self.life_tick(pilot, s)
        pilot, s = boarding_fixture()
        s['native_interact'] = False
        pilot.native_edges.append({'pressed': True, 'stage': 'begin_shift', 'frame': s['frame']+1})
        with self.assertRaisesRegex(AssertionError, 'BOARDING only follows'):
            self.life_tick(pilot, s)

    def test_life_tow_rejects_frozen_clock_or_frozen_drawn_movers(self):
        for clock, movers, message in [(False, True, 'strictly increasing'),
                                       (True, False, 'changed drawn mover')]:
            with self.subTest(clock=clock):
                pilot, s = self.life_seated_pilot()
                with self.assertRaisesRegex(AssertionError, message):
                    self.life_tick(pilot, s, 90, clock=clock, movers=movers)
        # Physics catch-up can observe the same presentation tick; interval
        # progress remains mandatory, without demanding one render per physics tick.
        pilot, s = self.life_seated_pilot()
        self.life_tick(pilot, s, clock=False, movers=False)
        self.life_tick(pilot, s, 89)
        self.assertEqual(pilot.result['completion_marker'], native.LifeTowPilot.MARKER)

    def test_life_tow_rejects_wrong_pilot_owner(self):
        for key, value in [('seated_at_pilot', False), ('piloted', False),
                           ('active_ship', False), ('remote_piloted', True), ('seated', False)]:
            with self.subTest(key=key):
                pilot, s = self.life_seated_pilot()
                s[key] = value
                with self.assertRaisesRegex(AssertionError, 'actual local seated pilot'):
                    self.life_tick(pilot, s)

    def test_life_tow_rejects_unsupported_teleport_identity_and_tuning_changes(self):
        mutations = [lambda s: s.update(supported=False), lambda s: s.update(grounded=False),
                     lambda s: s.update(player=[20, .18, 11]), lambda s: s.update(player_id=300),
                     lambda s: s.update(ship_id=600), lambda s: s.update(shape_id=500),
                     lambda s: s.update(capsule_geometry=[.4, 1.8]),
                     lambda s: s['walk_tuning'].update(sprint=40),
                     lambda s: s.update(default_controls=False), lambda s: s.update(default_sampler=False),
                     lambda s: s.update(tuning_unchanged=False), lambda s: s.update(time_scale=2),
                     lambda s: s['service'].update(id=700),
                     lambda s: s['service']['movers'][0].update(id=1000),
                     lambda s: s['service']['movers'][0].update(drawn_mesh_ids=[]),
                     lambda s: s['service'].update(visible=False),
                     lambda s: s['service'].update(advancing=False),
                     lambda s: s['service'].update(clock=float('nan')),
                     lambda s: s['service'].update(clock=-1)]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                pilot, s = self.life_walking_pilot()
                mutate(s)
                with self.assertRaises(AssertionError): self.life_tick(pilot, s)

    def test_life_tow_batch_checks_intermediate_samples_without_staging_input(self):
        for mutate in [lambda s: s.update(supported=False),
                       lambda s: s['service'].update(clock=.5),
                       lambda s: s['service'].update(enabled=False)]:
            pilot, s = self.life_walking_pilot()
            intermediate = copy.deepcopy(s)
            intermediate['frame'] += 1
            mutate(intermediate)
            latest = copy.deepcopy(s)
            latest['frame'] += 2
            latest['service']['clock'] += .1
            with self.assertRaises(AssertionError):
                for sample in [intermediate, latest]: pilot.validate_observation(sample)
        # Read-only batch validation cannot begin a press that never reached X11.
        pilot, s = native.LifeTowPilot(), self.life_observation()
        s['menu_ready'] = True
        for frame in [101, 102, 103]:
            sample = copy.deepcopy(s)
            sample['frame'] = frame
            pilot.validate_observation(sample)
        self.assertEqual(pilot.stage, 'boot')
        self.assertIsNone(pilot.tap_key)
        keys, _dx, _dy, _fire = pilot.update(sample, 2)
        self.assertIn('e', keys)
        self.assertEqual(pilot.stage, 'begin_shift')

    def test_life_tow_intervals_reject_clock_only_and_pose_only(self):
        a = self.life_observation()['service']
        for clock, pose in [(1., .1), (2., 0.)]:
            b = copy.deepcopy(a)
            b['clock'] = clock
            b['movers'][0]['pose'][0][0] = pose
            with self.assertRaises(AssertionError):
                native.LifeTowPilot.require_service_interval(a, b, 'nearby walking')

    def gantry_observation(self):
        s = self.life_observation()
        s.update(mode='life-gantry', ship_name='JovianLightFreighter',
                 engine='OFFLINE', parked_exact=True, home_lease=True,
                 home_berth_id='freight', home_berth_instance_id=80,
                 boarding=[-42, .38, 65])
        s['service'].update(profile='gantry',
                            path='OperationalLattice/Activities/FreightApproachGantry',
                            origin=[-53, .38, 29.7])
        s['service']['movers'] = s['service']['movers'][:2]
        return s

    def gantry_tick(self, pilot, s, **kwargs):
        # Each actual transform owner advances independently of the clock.
        if kwargs.get('movers', True):
            for mover in s['service']['movers'][1:]:
                mover['pose'][0][2] += .001
        return self.life_tick(pilot, s, **kwargs)

    def gantry_finish_goal(self, pilot, s):
        name, target = pilot.route[pilot.index]
        while native.norm(native.sub(target, s['player'])) > .09:
            delta = native.sub(target, s['player'])
            step = [v*.09/native.norm(delta) for v in delta]
            s['player'] = [a+b for a, b in zip(s['player'], step)]
            s['position'] = s['player'][:]
            self.gantry_tick(pilot, s)
        s['player'], s['position'] = target[:], target[:]
        for _ in range(15):
            if pilot.visited and pilot.visited[-1]['waypoint'] == name: break
            self.gantry_tick(pilot, s)
        self.assertEqual(pilot.visited[-1]['waypoint'], name)

    def test_life_gantry_ordered_physical_goals_local_interval_and_real_boarding(self):
        pilot, s = self.life_walking_pilot('life-gantry')
        expected = [[0, 0, 13.5], [-35, 0, 13.5], [-35, 0, 22], [-48, 0, 22],
                    [-48, .38, 24], [-49, .38, 26], [-51.5, .38, 26],
                    [-53, .38, 27.5], [-53, .38, 33.5], [-53, .38, 40],
                    [-42, .38, 40], [-42, .38, 65], [-39, .38, 65]]
        self.assertGreater(native.norm(native.sub(s['player'], s['service']['origin'])), 12)
        s['boarding'][2] = 60
        for index, target in enumerate(expected):
            self.assertEqual(pilot.route[0][1], target)
            if index == 11:
                # The penultimate goal reads the current marker on phase entry.
                self.assertEqual(pilot.route[0][1][2], s['boarding'][2])
            if index == 10: s['boarding'][2] = 65
            if index == 11: s['boarding'][0] = -39
            self.gantry_finish_goal(pilot, s)
        self.assertEqual(pilot.stage, 'approach_ship')
        self.assertFalse(pilot.near_active)
        self.assertGreater(pilot.near_walked, 11)
        self.assertLess(pilot.near_walked, 13)
        self.assertGreater(pilot.walked, 100)
        s.update(candidate=True, walk_offset=[0, 0, 0])
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'board')
        s.update(phase='BOARDING', candidate=False, native_interact=True,
                 transition_busy=True, control_enabled=False)
        self.gantry_tick(pilot, s)
        s.update(phase='START_ENGINES', seated=True, seated_at_pilot=True, piloted=True,
                 grounded=False, supported=False, capsule_enabled=False, transition_busy=False)
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'seated_observe')
        s['native_interact'] = False
        for _ in range(89): self.gantry_tick(pilot, s)
        self.assertIsNone(pilot.result)
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.result['completion_marker'], 'NATIVE_LIFE_GANTRY_OK')
        self.assertEqual(pilot.result['seated_physics_frames'], 90)
        self.assertIn('BOARDING', pilot.result['phases'])
        self.assertEqual(len(pilot.result['visited']), 13)

    def test_life_bounded_goals_require_fifteen_consecutive_settled_samples(self):
        for route in ('life-gantry', 'life-arm', 'life-patrol'):
            with self.subTest(route=route):
                pilot, s = self.life_walking_pilot(route)
                # Move by legal supported increments to the first goal.
                target = pilot.route[0][1]
                while native.norm(native.sub(target, s['player'])) > .09:
                    delta = native.sub(target, s['player'])
                    s['player'] = [a+v*.09/native.norm(delta) for a, v in zip(s['player'], delta)]
                    s['position'] = s['player'][:]
                    s['velocity'] = [.1, 0, 0]  # Strictly less than .1 is required.
                    self.gantry_tick(pilot, s)
                s['player'], s['position'] = target[:], target[:]
                s['velocity'] = [0, 0, 0]
                for _ in range(14): self.gantry_tick(pilot, s)
                self.assertEqual(pilot.visited, [])
                s['velocity'] = [.1, 0, 0]
                self.gantry_tick(pilot, s)
                self.assertEqual(pilot.settled_frames, 0)
                s['velocity'] = [0, 0, 0]
                # Read-only batch admission counts each emitted sample, stages no goal.
                for _ in range(15):
                    s['frame'] += 1
                    s['service']['clock'] += 1/60
                    if pilot.config.get('motion_proof', False): self.arm_motion(s, pilot.observed_previous)
                    pilot.validate_observation(copy.deepcopy(s))
                self.assertEqual(pilot.visited, [])
                pilot.update(pilot.observed_previous, s['frame']/60)
                self.assertEqual(len(pilot.visited), 1)

    def test_life_gantry_rejects_mutated_actors_profile_lease_support_and_defaults(self):
        mutations = [lambda s: s.update(ship_name='TorrentInterceptor'),
                     lambda s: s.update(ship_id=99), lambda s: s.update(player_id=99),
                     lambda s: s.update(home_lease=False), lambda s: s.update(parked_exact=False),
                     lambda s: s.update(engine='ONLINE'), lambda s: s.update(home_berth_instance_id=99),
                     lambda s: s.update(default_sampler=False), lambda s: s.update(default_controls=False),
                     lambda s: s.update(supported=False), lambda s: s.update(grounded=False),
                     lambda s: s['service'].update(profile='full'),
                     lambda s: s['service'].update(path='OperationalLattice/Activities/CentralTowServiceActivity'),
                     lambda s: s['service']['movers'].pop(),
                     lambda s: s['service']['movers'][0].update(id=999),
                     lambda s: s['service']['movers'][1].update(drawn_mesh_ids=[999]),
                     lambda s: s['walk_tuning'].update(sprint=20)]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                pilot, s = self.life_walking_pilot('life-gantry')
                mutate(s)
                with self.assertRaises(AssertionError): self.gantry_tick(pilot, s)

    def test_life_bounded_retains_all_samples_and_bounds_only_local_walk(self):
        for route in ('life-gantry', 'life-arm', 'life-patrol'):
            with self.subTest(route=route):
                pilot, s = self.life_walking_pilot(route)
                # The hub is deliberately farther than 12m; it is not the near interval.
                self.gantry_tick(pilot, s)
                with self.assertRaisesRegex(AssertionError, 'consecutive'):
                    self.gantry_tick(pilot, s, frames=2)
                pilot, s = self.life_walking_pilot(route)
                pilot.near_active = True
                with self.assertRaisesRegex(AssertionError, 'within 12m'):
                    self.gantry_tick(pilot, s)
                pilot, s = self.life_walking_pilot(route)
                intermediate = copy.deepcopy(s)
                intermediate['frame'] += 1
                intermediate['service']['enabled'] = False
                with self.assertRaises(AssertionError): pilot.validate_observation(intermediate)

    def test_life_bounded_goal_and_board_deadlines_do_not_retry(self):
        for route in ('life-gantry', 'life-arm', 'life-patrol'):
            with self.subTest(route=route):
                pilot, s = self.life_walking_pilot(route)
                s['frame'] += 1
                if pilot.config.get('motion_proof', False): self.arm_motion(s, pilot.observed_previous)
                with self.assertRaisesRegex(AssertionError, '15-second'):
                    pilot.update(copy.deepcopy(s), pilot.goal_started + 15.001)
                pilot, s = self.life_walking_pilot(route)
                pilot.stage, pilot.board_started = 'board', 0
                s['frame'] += 1
                if pilot.config.get('motion_proof', False): self.arm_motion(s, pilot.observed_previous)
                with self.assertRaisesRegex(AssertionError, '12-second'):
                    pilot.update(copy.deepcopy(s), 12.001)

    def test_life_bounded_pilot_requires_actual_authenticated_boarding(self):
        for route in ('life-gantry', 'life-arm', 'life-patrol'):
            with self.subTest(route=route):
                pilot, s = self.life_walking_pilot(route)
                pilot.stage, pilot.board_started = 'board', s['frame']/60
                pilot.receipts['board_press'] = pilot.receipt(copy.deepcopy(s))
                s.update(phase='START_ENGINES', seated=True, seated_at_pilot=True, piloted=True,
                         grounded=False, supported=False, capsule_enabled=False)
                with self.assertRaisesRegex(AssertionError, 'authenticated BOARDING'):
                    self.gantry_tick(pilot, s)

    def test_life_gantry_both_movers_and_clock_change_for_each_interval(self):
        a = self.gantry_observation()['service']
        for clock, changed in [(False, [0, 1]), (True, []), (True, [0]), (True, [1])]:
            b = copy.deepcopy(a)
            if clock: b['clock'] += 1
            for index in changed: b['movers'][index]['pose'][0][0] += .1
            with self.subTest(clock=clock, changed=changed), self.assertRaises(AssertionError):
                native.LifeTowPilot.require_service_interval(a, b, 'gantry', all_movers=True)

    def patrol_observation(self):
        s = self.gantry_observation()
        s.update(mode='life-patrol', ship_name='TorrentInterceptor',
                 ship_definition_id='torrent_provisional', home_berth_id='central_berth',
                 boarding=[0, 1.8, 0], station_candidate={}, capsule_geometry=[.38, 1.94],
                 door={'id': 90, 'path': 'HabitatSpine/MainAccess',
                       'position': [49, 0, 15.5], 'state': 0, 'open': False,
                       'blocked': True, 'locked': False, 'candidate': False})
        config = native.LifeTowPilot.ROUTES['life-patrol']
        s['service'].update(profile='drone_patrol', path=config['path'],
                            origin=[59.15, 4.88, 15.5], seed=3301)
        for mover, path in zip(s['service']['movers'], config['mover_paths']):
            mover['path'] = path
        self.arm_motion(s)
        return s

    def patrol_at_door(self):
        pilot, s = self.life_walking_pilot('life-patrol')
        for _ in range(8):
            self.gantry_finish_goal(pilot, s)
        self.assertEqual(pilot.stage, 'door_aim')
        return pilot, s

    def patrol_press_door(self, pilot, s):
        s['door']['candidate'] = True
        started = pilot.goal_started
        keys, *_ = self.gantry_tick(pilot, s)
        self.assertIn('e', keys)
        self.assertEqual(pilot.stage, 'door_wait')
        self.assertEqual(pilot.goal_started, started)
        s['native_interact'] = True
        s['door']['state'] = 1
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.goal_started, started)
        return started

    def test_life_patrol_exact_route_drone_roots_local_interval_and_original_torrent(self):
        config = native.LifeTowPilot.ROUTES['life-patrol']
        expected = [[0, 0, 12.5], [6, 0, 12.5], [6, 0, 13.5], [34.8, 0, 13.5],
                    [34.8, 0, 15.5], [43, 0, 15.5], [46, 0, 15.5], [48, 0, 15.5],
                    [50.5, 0, 15.5], [59.15, 0, 15.5], [67.8, 0, 15.5],
                    [59.15, 0, 15.5], [54.1, 0, 15.5], [50.5, 0, 15.5],
                    [48, 0, 15.5], [46, 0, 15.5], [43, 0, 15.5], [34.8, 0, 15.5],
                    [34.8, 0, 13.5], [6, 0, 13.5], [6, 0, 12.5], [0, 0, 12.5]]
        self.assertEqual([target for _, target in config['goals']], expected)
        self.assertEqual(config['near'], ('patrol_inner_threshold', 'patrol_common'))
        self.assertEqual(config['origin'], [59.15, 4.88, 15.5])
        self.assertEqual(config['ship_definition_id'], 'torrent_provisional')
        self.assertEqual(config['home_berth_id'], 'central_berth')
        self.assertFalse(config.get('candidate_only', False))
        pilot, s = self.patrol_at_door()
        self.patrol_press_door(pilot, s)
        # OPEN alone is insufficient until the real collision portal clears.
        s['door'].update(state=2, open=True)
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'door_wait')
        s['door']['blocked'] = False
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'walk_service')
        self.assertEqual(pilot.route[0][0], 'patrol_inner_threshold')
        self.assertEqual(pilot.goal_started, s['frame']/60)
        for _ in range(3): self.gantry_finish_goal(pilot, s)
        self.assertGreater(pilot.near_walked, 11)
        self.assertFalse(pilot.near_active)
        self.assertIn('nearby_walk_end', pilot.receipts)
        self.assertNotIn('board_press', pilot.receipts)
        s['door']['blocked'] = True
        with self.assertRaisesRegex(AssertionError, 'stays OPEN'):
            self.gantry_tick(pilot, s)

    def test_life_patrol_door_candidate_press_identity_and_shared_clock_are_required(self):
        pilot, s = self.patrol_at_door()
        # No production candidate: aiming sends no Interact and stays on this goal.
        keys, *_ = self.gantry_tick(pilot, s)
        self.assertNotIn('e', keys)
        self.assertEqual(pilot.stage, 'door_aim')
        for stage in ('door_aim', 'door_wait'):
            timed = copy.deepcopy(pilot)
            timed.stage = stage
            sample = copy.deepcopy(s)
            sample['frame'] += 1
            self.arm_motion(sample, timed.observed_previous)
            with self.subTest(stage=stage), self.assertRaisesRegex(AssertionError, '15-second'):
                timed.update(sample, timed.goal_started+15.001)
        mutations = [lambda x: x['door'].update(id=999),
                     lambda x: x['door'].update(path='HabitatSpine/Other'),
                     lambda x: x['door'].update(locked=True),
                     lambda x: x['door'].update(state=1),
                     lambda x: x.update(supported=False),
                     lambda x: x['player'].__setitem__(0, x['player'][0]+1)]
        for mutate in mutations:
            other, sample = copy.deepcopy(pilot), copy.deepcopy(s)
            mutate(sample)
            with self.subTest(mutate=mutate), self.assertRaises(AssertionError):
                self.gantry_tick(other, sample)
        self.patrol_press_door(pilot, s)
        without_edge = copy.deepcopy(pilot)
        without_edge.native_edges = []
        sample = copy.deepcopy(s)
        sample['door'].update(state=2, open=True, blocked=False)
        with self.assertRaisesRegex(AssertionError, 'door-stage OS press'):
            self.gantry_tick(without_edge, sample)
        closing = copy.deepcopy(s)
        closing['door']['state'] = 0
        with self.assertRaisesRegex(AssertionError, 'never closes or retries'):
            self.gantry_tick(copy.deepcopy(pilot), closing)
        s['door'].update(state=2, open=True, blocked=False)
        self.gantry_tick(pilot, s)
        # A prior door press must never authenticate subsequent ship ownership.
        pilot.stage, pilot.board_started = 'board', s['frame']/60
        pilot.receipts['board_press'] = pilot.receipt(s)
        pilot.receipts['board_press']['candidate'] = True
        s['native_interact'] = False
        s.update(phase='BOARDING', transition_busy=True, control_enabled=False)
        with self.assertRaisesRegex(AssertionError, 'board-stage OS press'):
            self.gantry_tick(pilot, s)

    def test_life_patrol_actual_drone_configuration_and_motion_epoch_cannot_change(self):
        mutations = [lambda x: x['service'].update(seed=3302),
                     lambda x: x['service'].update(origin=[59.15, 0, 15.5]),
                     lambda x: x['service']['movers'][0].update(path='SummaryDrone'),
                     lambda x: x['service']['movers'][1].update(id=999),
                     lambda x: x['service']['movers'].pop(),
                     lambda x: x['completed_motion'].update(frame=0)]
        for mutate in mutations:
            pilot, s = self.life_walking_pilot('life-patrol')
            s['frame'] += 1
            self.arm_motion(s, pilot.observed_previous)
            mutate(s)
            with self.subTest(mutate=mutate), self.assertRaises(AssertionError):
                pilot.validate_observation(copy.deepcopy(s))
        for changed in ((0,), (1,), ()):
            before = self.patrol_observation()['service']
            after = copy.deepcopy(before)
            after['clock'] += 1
            for index in changed: after['movers'][index]['pose'][0][0] += .1
            with self.subTest(changed=changed), self.assertRaises(AssertionError):
                native.LifeTowPilot.require_service_interval(before, after, 'patrol', all_movers=True)

    def arm_observation(self):
        s = self.gantry_observation()
        s.update(mode='life-arm', ship_name='ZenithInterceptor',
                 ship_definition_id='zenith_b7_observed',
                 home_berth_id='zenith_fleet_dock_berth', boarding=[14, 4.2, 58.2],
                 station_candidate={})
        s['service'].update(profile='service_arm',
                            path='OperationalLattice/Activities/AftOperationsActivity',
                            origin=[5.8, 4.99, 61.2])
        s['service']['movers'] = self.life_observation()['service']['movers'][:3]
        s['capsule_geometry'] = [.38, 1.94]
        self.arm_motion(s)
        return s

    @staticmethod
    def arm_motion(s, previous=None, event=None, lag=1):
        s['completed_motion'] = {'frame': s['frame']-lag,
                                 'start': (previous or s)['player'][:],
                                 'end': s['player'][:], 'step_up': event or {}}

    def arm_step_fixture(self, lag=1):
        pilot, s = self.life_walking_pilot('life-arm')
        # Match either valid observer order without changing its scheduling.
        pilot.motion_lag = lag
        pilot.observed_previous['completed_motion']['frame'] = s['frame']-lag
        previous = copy.deepcopy(pilot.observed_previous)
        s['frame'] += 1
        s['service']['clock'] += 1/60
        s['player'] = [s['player'][0], s['player'][1]+.146, s['player'][2]+.4]
        s['position'] = s['player'][:]
        event = {'frame': s['frame']-lag, 'player_id': s['player_id'],
                 'capsule_id': s['capsule_id'], 'shape_id': s['shape_id'],
                 'start': previous['player'][:], 'tick_start': previous['player'][:],
                 'landing': s['player'][:], 'tick_end': s['player'][:],
                 'intended': [0, 0, .0966667], 'up': [0, 1, 0],
                 'collision_transform': [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]],
                 'bounds': {'max_step_height': .30, 'min_clearance': .02, 'min_advance': .01,
                            'probe_reach': .40, 'capsule_radius': .38, 'capsule_height': 1.94,
                            'floor_max_angle_rad': .872665, 'safe_margin': .002,
                            'movement_up': [0, 1, 0], 'requires_floor_contact': True,
                            'requires_wall_contact': True, 'requires_walkable_landing': True,
                            'within_capsule_radius': True, 'steps_into_void': False}}
        self.arm_motion(s, previous, event, lag)
        return pilot, s

    def test_life_arm_actual_step_event_accepts_exact_point_four_advance_and_point_146_rise(self):
        for lag in (0, 1):
            with self.subTest(lag=lag):
                pilot, s = self.arm_step_fixture(lag)
                # Actual Godot Resource instance IDs can be signed.
                for sample in (pilot.initial, pilot.observed_previous, s):
                    sample['shape_id'] = -9223371935033849953
                s['completed_motion']['step_up']['shape_id'] = s['shape_id']
                pilot.validate_observation(s)
                self.assertEqual(pilot.consumed_step_frames, {s['frame']-lag})
                self.assertGreater(pilot.walked, .4)

    def test_life_arm_step_receipt_rejects_missing_stale_replayed_malformed_or_geometry_only_motion(self):
        mutations = {
            'missing event': lambda s, p, e: s['completed_motion'].update(step_up={}),
            'missing epoch': lambda s, p, e: s.pop('completed_motion'),
            'malformed event': lambda s, p, e: s['completed_motion'].update(step_up=[]),
            'malformed bounds': lambda s, p, e: e.update(bounds=None),
            'stale event': lambda s, p, e: e.update(frame=e['frame']-1),
            'replayed event': lambda s, p, e: p.consumed_step_frames.add(e['frame']),
            'wrong player': lambda s, p, e: e.update(player_id=99),
            'wrong capsule': lambda s, p, e: e.update(capsule_id=99),
            'wrong shape': lambda s, p, e: e.update(shape_id=99),
            'zero shape': lambda s, p, e: e.update(shape_id=0),
            'wrong start': lambda s, p, e: e['start'].__setitem__(0, 4),
            'wrong landing': lambda s, p, e: e['landing'].__setitem__(0, 4),
            'wrong tick start': lambda s, p, e: e['tick_start'].__setitem__(0, 4),
            'wrong tick end': lambda s, p, e: e['tick_end'].__setitem__(0, 4),
            'wrong epoch end': lambda s, p, e: s['completed_motion']['end'].__setitem__(0, 4),
            'epoch lag changed': lambda s, p, e: s['completed_motion'].update(frame=s['frame']),
            'epoch gap': lambda s, p, e: s['completed_motion'].update(frame=s['frame']-2),
            'shifted collision': lambda s, p, e: e['collision_transform'][0].__setitem__(0, .1),
            'rotated collision': lambda s, p, e: e['collision_transform'][1].__setitem__(0, -1),
            'nonunit up': lambda s, p, e: e.update(up=[0, 2, 0]),
            'nonworld up': lambda s, p, e: e.update(up=[1, 0, 0]),
            'no intended motion': lambda s, p, e: e.update(intended=[0, 0, 0]),
            'reverse intended': lambda s, p, e: e.update(intended=[0, 0, -.1]),
            'vertical intended': lambda s, p, e: e.update(intended=[0, .01, .1]),
            'excess intended': lambda s, p, e: e.update(intended=[0, 0, 1]),
            'unsupported before': lambda s, p, e: p.observed_previous.update(supported=False),
            'uncontrolled before': lambda s, p, e: p.observed_previous.update(control_enabled=False),
            'seated before': lambda s, p, e: p.observed_previous.update(seated=True),
            'unsupported after': lambda s, p, e: s.update(supported=False),
            'nondefault controls before': lambda s, p, e: p.observed_previous.update(default_controls=False),
            'invented grounded before': lambda s, p, e: p.observed_previous.update(grounded=False),
            'changed bound up': lambda s, p, e: e['bounds'].update(movement_up=[1, 0, 0]),
            'unwalkable bound': lambda s, p, e: e['bounds'].update(requires_walkable_landing=False),
            'nonfinite collision': lambda s, p, e: e['collision_transform'][0].__setitem__(0, math.inf),
            'additional displacement': lambda s, p, e: (s['player'].__setitem__(0, s['player'][0]+.01),
                s['completed_motion']['end'].__setitem__(0, s['player'][0])),
        }
        for key in ('max_step_height', 'min_clearance', 'min_advance', 'probe_reach',
                    'capsule_radius', 'capsule_height', 'floor_max_angle_rad', 'safe_margin'):
            mutations['changed '+key] = lambda s, p, e, k=key: e['bounds'].update({k: 10})
        for key in ('start', 'landing', 'intended', 'up', 'tick_start', 'tick_end'):
            for value in (math.nan, math.inf):
                mutations['nonfinite '+key+str(value)] = lambda s, p, e, k=key, v=value: e[k].__setitem__(0, v)
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                pilot, s = self.arm_step_fixture()
                mutate(s, pilot, s['completed_motion']['step_up'])
                with self.assertRaises(AssertionError): pilot.validate_observation(s)

    def test_life_arm_step_event_cannot_account_for_extra_displacement_or_broaden_other_routes(self):
        for rise, advance in ((0, .4), (.302, .4), (.146, .411), (.146, .009)):
            with self.subTest(rise=rise, advance=advance):
                pilot, s = self.arm_step_fixture()
                event = s['completed_motion']['step_up']
                start = event['start']
                end = [start[0], start[1]+rise, start[2]+advance]
                s['player'] = s['position'] = end[:]
                s['completed_motion']['end'] = end[:]
                event['tick_end'] = event['landing'] = end[:]
                with self.assertRaises(AssertionError): pilot.validate_observation(s)
        for route in ('life-tow', 'life-gantry'):
            pilot, s = self.life_walking_pilot(route)
            s['player'][2] += .4
            with self.assertRaisesRegex(AssertionError, 'continuous real walking'):
                self.life_tick(pilot, s)

    def test_life_arm_exact_route_local_interval_and_original_zenith_pilot(self):
        pilot, s = self.life_walking_pilot('life-arm')
        expected = [[0, 0, 15.5], [0, 0, 39], [0, 0, 46.3], [0, 0, 51],
                    [-5.7, 0, 51], [-5.7, 4.2, 61.2], [-3.5, 4.2, 61.5],
                    [-3.5, 4.2, 64.2], [-3.5, 4.2, 68.3], [6, 4.2, 68.3],
                    [13, 4.2, 68.3], [22, 4.2, 68.3], [20.2, 4.2, 59.2],
                    [18.6, 4.2, 58.6], [18.2, 4.2, 58.2]]
        for index, target in enumerate(expected):
            self.assertEqual(pilot.route[0][1], target)
            self.assertEqual(pilot.near_active, 6 <= index <= 9)
            self.gantry_finish_goal(pilot, s)
        self.assertEqual(pilot.stage, 'approach_ship')
        self.assertEqual(len(pilot.visited), 15)
        self.assertGreater(pilot.near_walked, 11)
        self.assertLess(pilot.near_walked, 20)
        self.assertFalse(pilot.near_active)
        self.assertEqual(pilot.receipts['nearby_walk_start']['player'], expected[5])
        self.assertEqual(pilot.receipts['nearby_walk_end']['player'], expected[9])
        # Production's actual candidate is enough: no Jovian 3.1m constraint or
        # dynamic marker approach may extend the exact fifteen-goal route.
        s.update(candidate=False, walk_offset=[6, 0, 0])
        keys, dx, _, _ = self.gantry_tick(pilot, s)
        self.assertEqual(keys, set())
        self.assertEqual(dx, 0)
        self.assertEqual(pilot.stage, 'approach_ship')
        # A real competing station prompt wins GameFlow's ordinary E. Rotate
        # away from that actual object while staying at the final authored goal.
        # Acknowledge the prior OS yaw with a coherent observed camera basis.
        s.update(walk_forward=[.8, 0, .6], walk_right=[-.6, 0, .8])
        s.update(candidate=True, station_candidate={'path': '/Main/ActualPrompt',
                 'position': [s['player'][0]+1, s['player'][1], s['player'][2]]})
        keys, dx, _, _ = self.gantry_tick(pilot, s)
        self.assertEqual(keys, set())
        self.assertNotEqual(dx, 0)
        self.assertEqual(pilot.stage, 'approach_ship')
        self.assertNotIn('board_press', pilot.receipts)
        self.assertEqual(len(pilot.visited), 15)
        s['station_candidate'] = {}
        s.update(candidate=True, velocity=[.1, 0, 0])
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'approach_ship')
        s['velocity'] = [0, 0, 0]
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'board')
        s.update(phase='BOARDING', candidate=False, native_interact=True,
                 transition_busy=True, control_enabled=False)
        self.gantry_tick(pilot, s)
        s.update(phase='START_ENGINES', seated=True, seated_at_pilot=True, piloted=True,
                 grounded=False, supported=False, capsule_enabled=False, transition_busy=False)
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.stage, 'seated_observe')
        s['native_interact'] = False
        for _ in range(89): self.gantry_tick(pilot, s)
        self.assertIsNone(pilot.result)
        self.gantry_tick(pilot, s)
        self.assertEqual(pilot.result['completion_marker'], 'NATIVE_LIFE_ARM_OK')
        self.assertEqual(pilot.result['seated_physics_frames'], 90)
        self.assertIn('BOARDING', pilot.result['phases'])
        self.assertEqual(pilot.result['receipts']['seated_end']['home_berth_id'], 'zenith_fleet_dock_berth')

    def test_life_arm_rejects_wrong_definition_berth_origin_and_actual_movers(self):
        mutations = [lambda s: s.update(ship_definition_id='jovian_provisional'),
                     lambda s: s.update(home_berth_id='another_berth'),
                     lambda s: s.update(home_lease=False),
                     lambda s: s.update(parked_exact=False), lambda s: s.update(engine='ONLINE'),
                     lambda s: s['service'].update(origin=[0, 0, 0]),
                     lambda s: s['service'].update(profile='full'),
                     lambda s: s['service'].update(path='OperationalLattice/Activities/FreightApproachGantry'),
                     lambda s: s['service']['movers'].pop(),
                     lambda s: s['service']['movers'][2].update(id=999),
                     lambda s: s['service']['movers'][2].update(drawn_mesh_ids=[])]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                pilot, s = self.life_walking_pilot('life-arm')
                mutate(s)
                with self.assertRaises(AssertionError): self.gantry_tick(pilot, s)
        # Authored identity/origin must also hold on the very first sample.
        for mutate in mutations[:2] + [mutations[5]]:
            pilot, s = native.LifeTowPilot('life-arm'), self.arm_observation()
            mutate(s)
            with self.assertRaises(AssertionError): pilot.validate_observation(s)

    def test_life_arm_all_three_movers_change_in_each_acceptance_interval(self):
        start = self.arm_observation()['service']
        for clock, changed in [(False, [0, 1, 2]), (True, []),
                               (True, [0, 1]), (True, [0, 2]), (True, [1, 2])]:
            end = copy.deepcopy(start)
            if clock: end['clock'] += 1
            for index in changed: end['movers'][index]['pose'][0][0] += .1
            with self.subTest(clock=clock, changed=changed), self.assertRaises(AssertionError):
                native.LifeTowPilot.require_service_interval(start, end, 'arm', all_movers=True)

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



class ArrowReturnReuseTests(unittest.TestCase):
    def observation(self):
        s = {key: index+1 for index, key in enumerate(native.ArrowReturnReusePilot.IDS)}
        s.update(mode='arrow-return-reuse', sequence=1, frame=100, actors_current=True,
                 phase='INTRO', paused=False, menu_ready=True, guided_complete=False,
                 definition_id='arrow_provisional', home_id='arrow_recon_berth',
                 player=[-8.5, .18, 11], spawn=[-8.5, .18, 11], position=[-43, 1.15, 15.5],
                 parked=[-43, 1.15, 15.5], boarding=[-47.5, .06, 18.9], exit=[-47.8, 0, 18.9],
                 capture_position=[-58, 9.15, 15.5], back=[1, 0, 0],
                 right=[0, 0, -1], up=[0, 1, 0], camera=[-38, 3, 15.5],
                 camera_right=[0, 0, -1], camera_up=[0, 1, 0], camera_back=[1, 0, 0],
                 ship_invert_y=False, shot={'present': False, 'request': {}},
                 target={'name': 'TargetDrone01', 'target_id': 'DRONE-01',
                         'base_position': [-13, 7, -95], 'position': [-12, 7, -95],
                         'health': 100, 'maximum_health': 100, 'destroyed': False,
                         'components': {'components': {}},
                         'hit_source': {'source_id': 0, 'source_entity_id': 0, 'weapon_id': '',
                                        'sequence': -1, 'presentation_receipt_id': -1}},
                 velocity=[0, 0, 0], ship_velocity=[0, 0, 0], walk_forward=[0, 0, -1], walk_right=[1, 0, 0],
                 capsule_geometry=[.38, 1.8], capsule_enabled=True,
                 default_sampler=True, default_controls=True, tuning_unchanged=True,
                 walk_tuning=native.LifeTowPilot.DEFAULT_WALK.copy(), ship_tuning={'mouse': .0022, 'cooldown': .38},
                 physics_ticks=60, time_scale=1, destroyed=False, hull=82, remote_piloted=False,
                 control_enabled=True, seated=False, seated_at_pilot=False, piloted=False,
                 active_ship=False, player_camera=True, ship_camera=False, transition_busy=False,
                 grounded=True, supported=True, support_collider='/Main/World/Deck', mouse_captured=True,
                 candidate=False, station_candidate=False, boarding_distance=40, reboard_blocked=False,
                 boarding_reserved=False, native_interact=False, native_landing=False, native_thrust=False,
                 native_fire=False, flight_demand=False, engine='OFFLINE', landed=True,
                 landing_active=False, capture=False, parked_exact=True, lease=True, lease_free=False,
                 lease_token='initial-token', contract=False,
                 boarding_confirmation={'adapter': {'view': {'state': 'approach'}}},
                 native_keys={'escape': False, 'tab': False, 'return': False},
                 ui={'main_visible': True, 'exit_visible': True, 'exit_enabled': True,
                     'exit_text': 'EXIT TO DESKTOP', 'exit_path': '/Main/HUD/Exit',
                     'focus_path': '/Main/HUD/Exit', 'focus_is_exit': True})
        return s

    def tick(self, pilot, s, update=True, now=None, **changes):
        s.update(changes); s['frame'] += 1; s['sequence'] += 1
        snapshot = copy.deepcopy(s)
        pilot.validate_observation(snapshot)
        if update: return pilot.update(snapshot, s['frame']/60 if now is None else now)

    def start(self):
        p, s = native.ArrowReturnReusePilot(), self.observation()
        snapshot = copy.deepcopy(s)
        p.validate_observation(snapshot); p.update(snapshot, s['frame']/60)
        self.tick(p, s, phase='APPROACH_SHIP', native_interact=True)
        for _ in range(30): self.tick(p, s, native_interact=False)
        return p, s

    def move_to(self, p, s, target):
        while native.norm(native.sub(target, s['player'])) > .01:
            delta = native.sub(target, s['player'])
            length = native.norm(delta)
            s['player'] = [a+b*min(.10/length, 1) for a, b in zip(s['player'], delta)]
            self.tick(p, s)

    def at_board(self):
        p, s = self.start()
        for _name, target in p.OUTBOUND: self.move_to(p, s, target)
        self.tick(p, s, candidate=True, boarding_distance=3)
        self.assertEqual(p.stage, 'board')
        return p, s

    def hit(self, s):
        request = {'source_id': 1102, 'source_entity_id': s['ship_id'],
                   'weapon_id': 'arrow_precision_recon_emitter', 'sequence': 0,
                   'presentation_receipt_id': 7, 'range': 480, 'damage': 24,
                   'origin': [-58, 1.15, 15.5], 'direction': [0, 0, -1]}
        context = {k: request[k] for k in ('source_id', 'source_entity_id', 'weapon_id',
                                         'sequence', 'presentation_receipt_id')}
        target = copy.deepcopy(s['target'])
        target.update(health=76, hit_source=context)
        return {'target': target, 'native_fire': True,
                'shot': {'present': True, 'request': request, 'accepted': True, 'resolved': True,
                         'hit': True, 'damaged': True, 'status': 'damaged', 'destroyed': False,
                         'source_id': 1102, 'source_entity_id': s['ship_id'],
                         'target_entity_id': s['target_instance_id'], 'damageable_id': s['target_adapter_id'],
                         'applied_damage': 24, 'remaining_health': 76,
                         'damage_result': {'accepted': True, 'applied_damage': 24, 'health': 76,
                                           'maximum_health': 100, 'destroyed': False}}}

    def weapon_request(self, p, s):
        self.assertEqual(p.stage, 'weapon_aim')
        direction = native.unit(native.sub(s['target']['position'], s['camera']))
        right = native.unit([-direction[2], 0, direction[0]])
        up = [right[1]*direction[2]-right[2]*direction[1],
              right[2]*direction[0]-right[0]*direction[2],
              right[0]*direction[1]-right[1]*direction[0]]
        target = copy.deepcopy(s['target']); target['position'][0] += .1
        keys, *_ = self.tick(p, s, camera_back=[-v for v in direction],
                             camera_right=right, camera_up=up, target=target)
        # Consume the pending physical mouse delivery and any prior E tap's
        # release/cooldown before the shared tap owner accepts the first F.
        for _ in range(40):
            if p.stage != 'weapon_aim': break
            self.assertNotIn('pre_fire', p.weapon)
            keys, *_ = self.tick(p, s)
        self.assertEqual(p.stage, 'weapon_fire')
        self.assertIn('f', keys)
        self.assertEqual(p.weapon['pre_fire']['target']['health'], 100)

    def weapon_hit_and_restore(self, p, s):
        self.weapon_request(p, s)
        keys, *_ = self.tick(p, s, **self.hit(s))
        self.assertIn('f', keys)
        self.assertIn('hit', p.weapon)
        self.release_fire(p, s)
        self.assertEqual(p.stage, 'weapon_restore')
        for _ in range(35): self.tick(p, s)
        self.assertIn('restored', p.weapon)

    def release_fire(self, p, s):
        for _ in range(12):
            keys, *_ = self.tick(p, s, native_fire=True)
            self.assertEqual(p.stage, 'weapon_fire')
            if 'f' not in keys: break
        else: self.fail('shared F tap did not release after its normal lifetime')
        self.assertIsNone(p.tap_key)
        keys, *_ = self.tick(p, s, native_fire=False)
        self.assertNotIn('f', keys)

    def fly_and_exit(self, p, s):
        self.tick(p, s, phase='BOARDING', native_interact=True, candidate=False,
                  transition_busy=True, control_enabled=False, boarding_reserved=True,
                  boarding_confirmation={'adapter': {'view': {'state': 'boarding'}}})
        self.tick(p, s, phase='START_ENGINES', seated=True, seated_at_pilot=True,
                  piloted=True, active_ship=True, capsule_enabled=False, grounded=False,
                  supported=False, player_camera=False, ship_camera=True, transition_busy=False,
                  boarding_confirmation={'adapter': {'view': {'state': 'seated'}}})
        self.assertEqual(p.stage, 'launch')
        # A genuine consumed thrust command, released lease and physical excursion.
        self.tick(p, s, native_interact=False, native_thrust=True, flight_demand=True,
                  engine='ONLINE', phase='FREE_FLIGHT', landed=False, lease=False,
                  lease_free=True, lease_token='', parked_exact=False,
                  position=[-60, 1.15, 15.5], capture=True)
        if p.flight == 0:
            self.tick(p, s, native_thrust=False)
            self.weapon_hit_and_restore(p, s)
        else:
            for _ in range(35): self.tick(p, s, native_thrust=False)
        self.assertEqual(p.stage, 'land')
        self.tick(p, s, native_landing=True)
        self.tick(p, s, phase='SHUT_DOWN', landed=True, lease=True, lease_free=False,
                  lease_token='dock-'+str(p.flight), parked_exact=True, contract=True,
                  position=s['parked'][:], native_landing=False, flight_demand=False)
        self.assertEqual(p.stage, 'shutdown')
        for _ in range(90): self.tick(p, s)
        self.tick(p, s, engine='OFFLINE')
        for _ in range(30):
            if p.stage == 'exit': break
            self.tick(p, s)
        self.assertEqual(p.stage, 'exit')
        self.tick(p, s, phase='DISEMBARKING', native_interact=True, transition_busy=True,
                  boarding_confirmation={'adapter': {'view': {'state': 'disembarking'}}})
        self.tick(p, s, phase='APPROACH_SHIP', player=s['exit'][:], seated=False,
                  seated_at_pilot=False, piloted=False, capsule_enabled=True, grounded=True,
                  supported=True, player_camera=True, ship_camera=False, transition_busy=False,
                  control_enabled=True, boarding_reserved=False, reboard_blocked=True,
                  boarding_distance=1.8, boarding_confirmation={'adapter': {'view': {'state': 'approach'}}})
        if len(p.trips) == 1:
            for _ in range(30): self.tick(p, s, native_interact=False)
        else:
            s['native_interact'] = False

    def reused(self):
        p, s = self.at_board()
        self.fly_and_exit(p, s)
        self.assertEqual(p.stage, 'clear')
        self.move_to(p, s, [-35, 0, 22])
        self.tick(p, s, boarding_distance=13, reboard_blocked=False)
        self.assertTrue(p.clear_seen)
        self.assertEqual(p.stage, 'reapproach')
        self.tick(p, s, candidate=True, boarding_distance=3)
        self.assertEqual(p.stage, 'board')
        self.fly_and_exit(p, s)
        self.assertEqual(p.stage, 'pause')
        return p, s

    def test_two_departures_returns_clear_walk_reboard_and_normal_quit(self):
        p, s = self.reused()
        self.assertIsNone(p.result)
        self.tick(p, s, paused=True)
        self.assertTrue(p.quit_requested)
        # A trailing receipt must still be checked after the ordinary UI request.
        self.tick(p, s, update=False)
        result = p.finish(0)
        self.assertEqual(result['completion_marker'], 'NATIVE_ARROW_RETURN_REUSE_OK')
        self.assertEqual(len(result['trips']), 2)
        self.assertTrue(all(t['excursion_m'] > 8 and t['neutral_frames'] >= 90 for t in result['trips']))
        self.assertGreater(result['receipts']['board_2']['frame'], result['receipts']['walk_clear']['frame'])
        self.assertEqual([e['flight'] for e in p.native_edges if e['stage'] == 'board'], [1, 2])

    def ready_to_fire(self):
        p, s = self.start()
        # The normal route has separate lifecycle coverage below. These tests
        # isolate the shot boundary with an already admitted airborne pilot.
        p.stage = 'weapon_aim'
        p.weapon_started, p.weapon_start_frame = s['frame']/60, s['frame']
        p.weapon['brake'] = p.weapon_receipt(s)
        s.update(phase='FREE_FLIGHT', engine='ONLINE', landed=False, lease=False, lease_free=True,
                 seated=True, seated_at_pilot=True, piloted=True, active_ship=True,
                 capsule_enabled=False, ship_camera=True)
        self.weapon_request(p, s)
        return p, s

    def test_fire_uses_one_shared_tap_until_both_time_and_physics_minima(self):
        for pending in ('frames', 'wall_time'):
            with self.subTest(pending=pending):
                p, s = self.ready_to_fire()
                press_frame, press_time = p.tap_frame, p.tap_until-.15
                baseline = p.weapon['pre_fire']
                count = 5 if pending == 'frames' else 6
                for index in range(count):
                    elapsed = .20 if pending == 'frames' else .14*(index+1)/count
                    keys, *_ = self.tick(p, s, native_fire=True, now=press_time+elapsed)
                    self.assertIn('f', keys)
                self.assertEqual(s['frame'], press_frame+count)
                release_time = press_time+(.201 if pending == 'frames' else .151)
                keys, *_ = self.tick(p, s, native_fire=True, now=release_time)
                self.assertNotIn('f', keys)
                self.assertIsNone(p.tap_key)
                for index in range(25):
                    keys, *_ = self.tick(p, s, native_fire=False, now=release_time+(index+1)/60)
                    self.assertNotIn('f', keys)
                    self.assertEqual(p.stage, 'weapon_fire')
                    self.assertIs(p.weapon['pre_fire'], baseline)
                self.assertEqual(sum(e['stage'] == 'weapon_fire' for e in p.stages), 1)

    def test_aligned_aim_does_not_store_baseline_or_advance_while_tap_unavailable(self):
        for busy in ('key', 'time', 'frames'):
            with self.subTest(busy=busy):
                p, s = self.ready_to_fire()
                p.stage = 'weapon_aim'; p.weapon.pop('pre_fire')
                p.tap_key = 'e' if busy == 'key' else None
                p.tap_until = s['frame']/60+1
                p.tap_cooldown = s['frame']/60+1 if busy == 'time' else 0
                p.tap_release_frame = s['frame'] if busy == 'frames' else -100
                keys, *_ = self.tick(p, s)
                self.assertEqual(p.stage, 'weapon_aim')
                self.assertNotIn('pre_fire', p.weapon)
                self.assertNotIn('f', keys)

    def test_weapon_rejects_stale_wrong_target_source_sequence_and_hit_receipts(self):
        mutations = [lambda p,s,h: h['shot'].update(accepted=False),
                     lambda p,s,h: h['shot'].update(hit=False),
                     lambda p,s,h: h['shot'].update(damaged=False),
                     lambda p,s,h: h['shot'].update(target_entity_id=999),
                     lambda p,s,h: h['shot'].update(damageable_id=999),
                     lambda p,s,h: h['shot'].update(source_id=1001),
                     lambda p,s,h: h['shot']['request'].update(source_entity_id=999),
                     lambda p,s,h: h['shot']['request'].update(weapon_id='torrent'),
                     lambda p,s,h: h['shot']['request'].update(sequence=-1),
                     lambda p,s,h: h['shot']['request'].update(sequence=1),
                     lambda p,s,h: h['shot']['request'].update(presentation_receipt_id=-1),
                     lambda p,s,h: h['target']['hit_source'].update(presentation_receipt_id=8),
                     lambda p,s,h: h['target']['hit_source'].update(source_id=1001),
                     lambda p,s,h: h['target']['hit_source'].update(sequence=1),
                     lambda p,s,h: h['shot']['damage_result'].update(applied_damage=23),
                     lambda p,s,h: h['target'].update(health=75),
                     lambda p,s,h: h.update(native_fire=False),
                     lambda p,s,h: setattr(p, 'stage', 'launch'),
                     lambda p,s,h: setattr(p, 'flight', 1)]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                p, s = self.ready_to_fire(); hit = self.hit(s)
                mutate(p, s, hit)
                with self.assertRaises(AssertionError): self.tick(p, s, update=False, **hit)
        p, s = self.start()
        with self.assertRaises(AssertionError): self.tick(p, s, update=False, **self.hit(s))

    def test_weapon_cannot_land_before_hit_and_full_attitude_restoration(self):
        p, s = self.ready_to_fire()
        keys, *_ = self.tick(p, s)
        self.assertIn('f', keys)
        self.assertNotIn('l', keys)
        self.assertEqual(p.stage, 'weapon_fire')
        self.tick(p, s, **self.hit(s)); self.release_fire(p, s)
        # A matching nose alone does not establish restored attitude.
        keys, *_ = self.tick(p, s, right=[0, .2, -.98], up=[0, .98, .2])
        self.assertNotIn('l', keys)
        self.assertEqual(p.stage, 'weapon_restore')
        self.tick(p, s, right=[0, 0, -1], up=[0, 1, 0], capture=True)
        for _ in range(25):
            if p.stage == 'land': break
            self.tick(p, s)
        self.assertEqual(p.stage, 'land')
        self.assertGreater(p.weapon['hit']['frame'], p.weapon['pre_fire']['frame'])
        self.assertGreater(p.weapon['restored']['frame'], p.weapon['hit']['frame'])

    def test_weapon_25_second_deadline_includes_braking_and_stalled_observations(self):
        p, s = self.ready_to_fire()
        p.check_weapon_deadline(p.weapon_started+25)
        with self.assertRaisesRegex(AssertionError, '25 seconds'):
            p.check_weapon_deadline(p.weapon_started+25.001)
        p.weapon_start_frame = s['frame']-1500
        with self.assertRaisesRegex(AssertionError, 'physics budget'):
            self.tick(p, s, update=False)
        self.assertEqual(native.CAP, 300)

    def test_second_flight_and_quit_tail_reject_another_shot(self):
        p, s = self.reused()
        self.assertEqual(p.flight, 1)
        self.assertEqual(sum(e['stage'] == 'weapon_aim' for e in p.stages), 1)
        self.assertEqual(p.weapon['hit']['shot']['applied_damage'], 24)
        for mutate in (lambda snapshot: snapshot.update(native_fire=True),
                       lambda snapshot: snapshot['shot']['request'].update(sequence=1),
                       lambda snapshot: snapshot['target'].update(health=52)):
            snapshot = copy.deepcopy(s); snapshot['frame'] += 1; snapshot['sequence'] += 1
            mutate(snapshot)
            with self.assertRaises(AssertionError): p.validate_observation(snapshot)

    def test_every_intermediate_receipt_rejects_changed_actors_controls_support_and_motion(self):
        mutations = [dict(player_id=999), dict(capsule_id=999), dict(shape_id=999),
                     dict(ship_id=999), dict(berth_id=999), dict(default_sampler=False),
                     dict(default_controls=False), dict(tuning_unchanged=False), dict(time_scale=2),
                     dict(supported=False), dict(player=[80, 0, 0]), dict(lease=False),
                     dict(native_fire=True), dict(actors_current=False)]
        for changed in mutations:
            with self.subTest(changed=changed):
                p, s = self.start()
                with self.assertRaises(AssertionError): self.tick(p, s, update=False, **changed)

    def test_approach_candidates_do_not_bypass_actual_boarding_gate(self):
        p, s = self.start()
        for _name, target in p.OUTBOUND: self.move_to(p, s, target)
        self.move_to(p, s, [-38.540359, .0491382, 21.9952])
        self.assertEqual(p.stage, 'approach')
        keys, _dx, _dy, _fire = self.tick(p, s, candidate=True,
                                         station_candidate=True, boarding_distance=9.56)
        self.assertEqual(p.stage, 'approach')
        self.assertNotIn('e', keys)
        self.assertNotIn('board_1', p.receipts)
        keys, _dx, _dy, _fire = self.tick(p, s, boarding_distance=6.9)
        self.assertEqual(p.stage, 'approach')
        self.assertNotIn('e', keys)
        self.assertNotIn('board_1', p.receipts)
        keys, _dx, _dy, _fire = self.tick(p, s, station_candidate=False)
        self.assertEqual(p.stage, 'board')
        self.assertIn('e', keys)
        self.assertFalse(p.receipts['board_1']['station_candidate'])
        self.assertLessEqual(p.receipts['board_1']['boarding_distance'], 7)

    def test_boarding_rejects_no_edge_wrong_candidate_range_reservation_and_rejection(self):
        mutations = [lambda p,s: p.receipts.pop('board_1'),
                     lambda p,s: p.receipts['board_1'].update(candidate=False),
                     lambda p,s: p.receipts['board_1'].update(player_id=999),
                     lambda p,s: p.receipts['board_1'].update(boarding_distance=7.01),
                     lambda p,s: p.receipts['board_1'].update(reboard_blocked=True),
                     lambda p,s: s.update(native_interact=False),
                     lambda p,s: s.update(boarding_reserved=False),
                     lambda p,s: s.update(boarding_confirmation={'adapter': {'view': {'state': 'rejected'}}})]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                p, s = self.at_board()
                s.update(phase='BOARDING', native_interact=True, transition_busy=True,
                         control_enabled=False, boarding_reserved=True,
                         boarding_confirmation={'adapter': {'view': {'state': 'boarding'}}})
                mutate(p, s)
                with self.assertRaises(AssertionError): self.tick(p, s, update=False)

    def test_no_success_without_both_flights_clear_walk_and_actual_ui_exit(self):
        p, s = self.at_board()
        with self.assertRaises(AssertionError): p.finish(0)
        self.fly_and_exit(p, s)
        with self.assertRaises(AssertionError): p.finish(0)
        # Approaching the marker again without the physical clear walk cannot board.
        p.stage = 'reapproach'
        with self.assertRaisesRegex(AssertionError, 'clear walk'):
            self.tick(p, s, candidate=True, reboard_blocked=False, boarding_distance=2)
        p, s = self.reused()
        for changed in [dict(contract=False), dict(lease=False), dict(parked_exact=False), dict(supported=False)]:
            with self.subTest(changed=changed):
                snapshot = copy.deepcopy(s); snapshot.update(changed)
                snapshot['frame'] += 1; snapshot['sequence'] += 1
                with self.assertRaises(AssertionError): p.validate_observation(snapshot)
        with self.assertRaises(AssertionError): p.finish(0)
        self.tick(p, s, paused=True)
        with self.assertRaises(AssertionError): p.finish(1)

    def test_neutral_offline_and_original_cap_are_required(self):
        self.assertEqual(native.CAP, 300)
        p, s = self.at_board()
        p.stage = 'shutdown'; p.departed = p.landing_seen = True
        s.update(phase='SHUT_DOWN', active_ship=True, seated=True, seated_at_pilot=True,
                 piloted=True, capsule_enabled=False, ship_camera=True, contract=True,
                 flight_demand=False, engine='OFFLINE')
        for _ in range(89): self.tick(p, s)
        self.assertEqual(p.stage, 'shutdown')
        self.tick(p, s, flight_demand=True)
        self.assertIsNone(p.neutral_start)
        self.tick(p, s, flight_demand=False)
        self.assertEqual(p.stage, 'shutdown')


if __name__ == '__main__':
    unittest.main()
