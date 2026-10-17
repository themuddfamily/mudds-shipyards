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

    def breaker_at_exit(self, supported=True):
        pilot, s = self.hulk_pilot(native.HulkBreakerPilot), self.breaker_observation()
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

    def walk_breaker_interior(self):
        pilot, s = self.breaker_at_exit()
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

    def press_breaker_and_restore(self, claimed_elapsed=3):
        pilot, s = self.walk_breaker_interior()
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
