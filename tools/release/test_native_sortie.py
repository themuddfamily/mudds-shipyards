#!/usr/bin/env python3
"""Focused native-driver safety regressions; no Godot or display is launched."""
import copy
import hashlib
import importlib.util
import json
import math
import os
import signal
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
    def outbound_observation(self, sequence=1, **changes):
        s = dict(pid=42, mode='beacon-home', sequence=sequence, frame=sequence,
                 paused=False, main_id=2, player_id=3, ship_id=4,
                 home=dict(berth_id='central_berth', berth_instance_id=5, berth_parent_id=6),
                 lease=True, lease_free=False, parked_exact=True, landed=True,
                 default_sampler=True, tuning_unchanged=True, tuning=dict(brake=48),
                 phase='START_ENGINES', destroyed=False, piloted=True, seated=True,
                 active_ship=True, source_enabled=True, application_focused=True,
                 transition_busy=False, telemetry=dict(engine='OFFLINE'),
                 position=[0, 0, 0], velocity=[0, 0, 0],
                 beacon=dict(available=True, binding_id=7, owner_id=8,
                             activity_id=native.BeaconEntryPilot.ACTIVITY, beacon_count=4,
                             first_world=[0, 0, -230], distance_m=230))
        s.update(changes)
        return s

    def start_outbound(self, clock=100):
        from unittest.mock import Mock
        timing = native.BeaconOutboundTiming(42)
        s = self.outbound_observation()
        timing.observe(s, clock - 1)
        desktop = Mock()
        with patch.object(native.time, 'monotonic', return_value=clock):
            # Mouse steering wakes automatic propulsion before the first W.
            timing.send_input(desktop, 'launch', s, set(), 3, -2, False)
        return timing, s, desktop

    def test_beacon_outbound_clock_starts_before_actual_mouse_engine_input(self):
        from unittest.mock import Mock
        timing = native.BeaconOutboundTiming(42)
        s = self.outbound_observation()
        timing.observe(s, 90)
        desktop = Mock()
        events = []
        def keys(keys):
            events.append(('keys', set(keys)))
            self.assertEqual(timing.start['monotonic_seconds'], 100)
            self.assertFalse(timing.input_acknowledged)
        # Seated boarding/release with no propulsion cannot start the clock.
        timing.send_input(desktop, 'launch', s, {'e'}, 0, 0, False)
        self.assertIsNone(timing.start)
        desktop.keys.side_effect = keys
        desktop.mouse.side_effect = lambda *args: events.append(('mouse', args))
        with patch.object(native.time, 'monotonic', return_value=100):
            timing.send_input(desktop, 'launch', s, set(), 3, -2, False)
        self.assertEqual(events, [('keys', set()), ('mouse', (3, -2, False))])
        self.assertTrue(timing.input_acknowledged)
        self.assertEqual(timing.start['keys'], [])
        self.assertEqual(timing.start['mouse'], [3, -2])

    def test_beacon_outbound_first_raw_32m_sample_stops_without_changing_tighter_route(self):
        timing, s, _ = self.start_outbound()
        # A coalesced batch's middle sample qualifies even though its last
        # sample has moved outside32m. Production steering still uses the last.
        before = self.outbound_observation(2, lease=False, lease_free=True, landed=False,
                                          position=[0, 0, -198], velocity=[0, 0, -.451])
        before['beacon']['distance_m'] = 32
        first = copy.deepcopy(before); first.update(sequence=3, frame=3, velocity=[0, 0, -.45])
        after = copy.deepcopy(first); after.update(sequence=4, position=[0, 0, -190])
        after['beacon']['distance_m'] = 40
        for observation in (before, first, after): timing.observe(observation, 160)
        report = timing.report()
        self.assertTrue(report['qualified'])
        self.assertEqual(report['observed_upper_bound_seconds'], 60)
        self.assertEqual(report['stop']['observation'], first)
        self.assertEqual(report['paused_intervals'], [])
        self.assertEqual(report['paused_seconds_subtracted'], 0)
        # Caller-owned observations and consumer-owned reports cannot rewrite
        # the retained launch/approach receipt after qualification.
        s['position'][0] = 999
        s['beacon']['first_world'][0] = 999
        first['position'][0] = 999
        first['beacon']['distance_m'] = 999
        report['start']['observation']['position'][0] = 888
        report['start']['observation']['beacon']['first_world'][0] = 888
        report['stop']['observation']['position'][0] = 888
        report['stop']['observation']['beacon']['distance_m'] = 888
        retained = timing.report()
        self.assertEqual(retained['start']['observation']['position'], [0, 0, 0])
        self.assertEqual(retained['start']['observation']['beacon']['first_world'], [0, 0, -230])
        self.assertEqual(retained['stop']['observation']['position'], [0, 0, -198])
        self.assertEqual(retained['stop']['observation']['beacon']['distance_m'], 32)
        self.assertTrue(retained['qualified'])

    def test_beacon_outbound_wall_stalls_count_and_clock_never_restarts(self):
        for approach in (False, True):
            timing, s, _ = self.start_outbound()
            late = self.outbound_observation(2, frame=2)
            if approach:
                late.update(lease=False, lease_free=True, landed=False, position=[0, 0, -210])
                late['beacon']['distance_m'] = 20
            with self.subTest(approach=approach):
                with self.assertRaisesRegex(AssertionError, '60.0-second'):
                    timing.observe(late, 160.001)
                self.assertFalse(timing.report()['qualified'])
                self.assertEqual(timing.start['monotonic_seconds'], 100)
        timing, _, _ = self.start_outbound()
        with self.assertRaisesRegex(AssertionError, '60.0-second'):
            timing.check_deadline(161)  # No new samples during an engine stall.

    def test_beacon_outbound_rejects_pause_recovery_replacement_and_control_changes(self):
        mutations = [lambda s: s.update(paused=True), lambda s: s.update(pid=99),
                     lambda s: s.update(main_id=99), lambda s: s.update(player_id=99),
                     lambda s: s.update(ship_id=99), lambda s: s['home'].update(berth_instance_id=99),
                     lambda s: s.update(destroyed=True), lambda s: s.update(phase='RECOVERING'),
                     lambda s: s.update(phase='FAILED'), lambda s: s.update(default_sampler=False),
                     lambda s: s.update(tuning_unchanged=False), lambda s: s['tuning'].update(brake=99),
                     lambda s: s.update(source_enabled=False), lambda s: s.update(application_focused=False),
                     lambda s: s.update(seated=False), lambda s: s.update(piloted=False),
                     lambda s: s.update(active_ship=False), lambda s: s.update(transition_busy=True),
                     lambda s: s['beacon'].update(owner_id=99),
                     lambda s: s['beacon'].update(available=False)]
        for index, mutate in enumerate(mutations):
            timing, _, _ = self.start_outbound()
            bad = self.outbound_observation(2)
            mutate(bad)
            with self.subTest(mutation=index):
                with self.assertRaises(AssertionError): timing.observe(bad, 110)
        timing, _, _ = self.start_outbound()
        with self.assertRaisesRegex(AssertionError, 'zero pauses'):
            timing.observe(dict(pid=42, mode='beacon-home', sequence=2, paused=True), 110)

    def test_beacon_outbound_requires_occupied_offline_start_and_no_issued_boost(self):
        from unittest.mock import Mock
        for change in (dict(lease=False), dict(parked_exact=False), dict(lease_free=True),
                       dict(landed=False), dict(telemetry=dict(engine='ONLINE'))):
            timing = native.BeaconOutboundTiming(42)
            s = self.outbound_observation()
            timing.observe(s, 90)
            s.update(change)
            with self.subTest(change=change):
                with self.assertRaises(AssertionError):
                    timing.send_input(Mock(), 'launch', s, {'w'}, 0, 0, False)
        timing, s, desktop = self.start_outbound()
        for boost in ('Shift_L', 'Shift_R'):
            with self.assertRaisesRegex(AssertionError, 'boost'):
                timing.send_input(desktop, 'launch', s, {'w', boost}, 0, 0, False)
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)/'not-created'
            with self.assertRaisesRegex(AssertionError, 'full beacon-home'):
                native.run(Path('/bin/true'), output, 'beacon-entry', qualify_beacon_outbound=True)
            self.assertFalse(output.exists())

    def test_beacon_home_rolled_clearance_deadband_corrects_before_thrust(self):
        # Actual stalled observation from the original full-home replay: the
        # craft is rolled, so a small global pitch error needs both mouse axes.
        s = {'position': [-.0558251887559891, 2.65951657295227, -150.610794067383],
             'camera': [5.92166090011597, 6.4426064491272, -167.663055419922],
             'back': [-.00221747788600624, -.0101716602221131, -.999945819377899],
             'right': [-.54952347278595, .83544659614563, -.00727971736341715],
             'up': [.835475385189056, .549477577209473, -.0074421507306397],
             'velocity': [0, 0, 0], 'tuning': {'mouse': .0022, 'brake': 48},
             'phase': 'TARGET_PRACTICE', 'piloted': True, 'seated': True,
             'landed': False, 'lease_free': True,
             'home': {'range_clearance': [0, 2.70000004768372, -150],
                      'range_clearance_exit': [0, 2.70000004768372, -100]}}
        pilot = native.BeaconHomePilot()
        pilot.stage = 'beacon_home_clearance_exit'
        pilot.home_previous = copy.deepcopy(s)
        target = s['home']['range_clearance_exit']
        off = native.sub(target, s['position'])
        aim = [s['camera'][i]+off[i] for i in range(3)]
        dx, dy, align = pilot.aim(s, aim)
        self.assertEqual((dx, dy), (0, 0))
        self.assertGreaterEqual(align, .9999)
        direction = native.unit(off)
        pitch_error = abs(math.degrees(math.asin(-s['back'][1]))
                          - math.degrees(math.asin(direction[1])))
        self.assertAlmostEqual(pitch_error, .5369725075938734)
        self.assertGreater(pitch_error, .5)
        # Sending a corrective pixel does not itself count as observed alignment.
        for now in (0, 1):
            keys, dx, dy, fire = pilot.update_home(s, now, 1)
            self.assertFalse(pilot.home_clearance_ready)
            self.assertEqual(keys, {'Prior'})
            self.assertEqual((dx, dy), (-3, 3))
            self.assertFalse(fire)
            self.assertNotIn('home_clearance_ready', pilot.receipts)
        # Only a subsequent observed attitude inside the unchanged guard opens W.
        corrected = copy.deepcopy(s)
        corrected['back'] = [-v for v in direction]
        right = s['right']
        projection = native.dot(right, direction)
        corrected['right'] = native.unit([right[i]-projection*direction[i] for i in range(3)])
        back, right = corrected['back'], corrected['right']
        corrected['up'] = [back[1]*right[2]-back[2]*right[1],
                           back[2]*right[0]-back[0]*right[2],
                           back[0]*right[1]-back[1]*right[0]]
        keys, _, _, _ = pilot.update_home(corrected, 2, 1)
        self.assertTrue(pilot.home_clearance_ready)
        self.assertEqual(keys, {'w'})
        self.assertIs(pilot.receipts['home_clearance_ready'], corrected)

    def hauler_supply_observation(self):
        return dict(ship_definition_id='cinder_cargo_hauler', production_hauler=True,
                    home={'id': 'dock_04_cargo'}, cargo=dict(
                        available=True, lease=True,
                        route_local=[p[:] for p in native.CinderHaulerSupplyPilot.CARGO_LOCAL_POINTS],
                        dock_local=[-29, 4.25, 0], dock_yaw_pi=True))

    def test_hauler_supply_requires_actual_production_craft_and_contact(self):
        pilot = native.CinderHaulerSupplyPilot()
        with patch.object(native.CinderSupplyPilot, 'validate_observation') as baseline:
            s = self.hauler_supply_observation()
            pilot.validate_observation(s)
            baseline.assert_called_once_with(s)
            for field, value in [('ship_definition_id', 'jovian_provisional'),
                                 ('production_hauler', False), ('home', {'id': 'freight_berth'})]:
                bad = copy.deepcopy(s); bad[field] = value
                with self.subTest(field=field):
                    with self.assertRaises(AssertionError): pilot.validate_observation(bad)
            for field, value in [('dock_local', [-29, 4.15, 0]), ('dock_yaw_pi', False)]:
                bad = copy.deepcopy(s); bad['cargo'][field] = value
                with self.subTest(field=field):
                    with self.assertRaises(AssertionError): pilot.validate_observation(bad)

    def test_hauler_supply_freezes_ten_point_walk_and_initial_supported_apron(self):
        pilot = native.CinderHaulerSupplyPilot()
        expected = [[-21, 2.9, 0], [-21, 2.9, 10], [-24.3, 2.9, 13.75],
                    [-24.3, 3.8, 17.8], [-14.15, 3.8, 18], [-4, 3.8, 18],
                    [-2.4, 3.8, 16.7], [-1.6, 4.05, 16.166667],
                    [-.8, 4.30, 15.633333], [0, 4.65, 15.1]]
        self.assertEqual(list(pilot.CARGO_LOCAL_POINTS), expected)
        route = pilot.initial_walk_route({'boarding': [7, 5, 83]})
        self.assertEqual(route[:12], [p for _, p in native.LifeTowPilot.ARM_GOALS[:12]])
        self.assertEqual(route[12:], [[25.4, 4.2, 68.3], [25.4, 4.2, 70.6], [23, 4.18, 72.8],
                                      [22.2, 4.18, 75.2], [22.2, 4.18, 90], [8.8, 4.18, 90]])
        self.assertEqual(pilot.reboard_walk_route({'boarding': [7, 5, 83]}), [[7, 5, 83]])
        with patch.object(native.CinderSupplyPilot, 'validate_observation'):
            for mutation in ('short', 'shift', 'reverse'):
                bad = self.hauler_supply_observation()
                if mutation == 'short': bad['cargo']['route_local'].pop()
                elif mutation == 'shift': bad['cargo']['route_local'][2][0] += .1
                else: bad['cargo']['route_local'].reverse()
                with self.subTest(mutation=mutation):
                    with self.assertRaises(AssertionError): pilot.validate_observation(bad)

    def test_hauler_supply_home_clearance_uses_live_capture_world_up_and_exact_reverse(self):
        pilot = native.CinderHaulerSupplyPilot()
        s = {'home': {'capture_position': [31, 13.8, 83.4]}}
        self.assertEqual(pilot.station_clearance_targets(s), [[31, 13.8, 83.4], [31, 73.8, 83.4]])
        self.assertEqual(pilot.station_clearance_targets(s, True), [[31, 73.8, 83.4], [31, 13.8, 83.4]])
        self.assertEqual(s['home']['capture_position'], [31, 13.8, 83.4])
        jovian = native.CinderSupplyPilot.station_clearance_targets(s)
        offsets = ([0, 0, 0], [0, 0, 26.7], [0, 66.37, 66.7], [84, 66.37, -308.3])
        self.assertEqual(jovian, [[p+d for p, d in zip(s['home']['capture_position'], off)] for off in offsets])

    def test_hauler_supply_settled_home_uprights_without_aim_or_premature_landing(self):
        pilot = native.CinderHaulerSupplyPilot()
        pilot.stage = 'home_flight'
        s = dict(frame=12000, phase='FREE_FLIGHT', player=[31, 15, 83],
                 position=[31, 15.793295, 83.4], ship_velocity=[0, 0, 0],
                 up=[0, .030437, .999537], cargo={},
                 home=dict(capture=False, capture_position=[31, 13.8, 83.4]))
        pilot.last_state = s
        with patch.object(native.time, 'monotonic', return_value=100), \
             patch.object(native.CinderSupplyPilot, 'flight') as baseline:
            self.assertEqual(pilot.update(s, 100), ({'Prior', 'h'}, 0, 0, False))
            baseline.assert_not_called()
        self.assertEqual(pilot.stage, 'home_flight')
        self.assertEqual(pilot.home_alignment_started, 100)
        with patch.object(native.time, 'monotonic', return_value=114):
            self.assertEqual(pilot.update(s, 114), ({'Prior', 'h'}, 0, 0, False))
        self.assertEqual(pilot.home_alignment_started, 100)
        fresh = copy.deepcopy(s)
        fresh['frame'] += 1; fresh['home']['capture'] = True
        pilot.last_state = fresh
        with patch.object(native.time, 'monotonic', return_value=114.5):
            self.assertEqual(pilot.update(fresh, 114.5), ({'Prior', 'h', 'l'}, 0, 0, False))
        self.assertEqual(pilot.stage, 'home_land')
        self.assertIs(pilot.receipts['home_land'], fresh)

    def test_hauler_supply_alignment_budget_never_resets_or_changes_other_flight(self):
        pilot = native.CinderHaulerSupplyPilot()
        pilot.stage = 'home_flight'
        s = dict(position=[0, 1.99, 0], ship_velocity=[0, 0, 0])
        with patch.object(native.time, 'monotonic', return_value=100):
            self.assertEqual(pilot.flight(s, [0, 0, 0], set()), (0, 0, True))
        # Losing the settled predicate does not restart the bounded hold.
        moving = dict(position=[0, 3, 0], ship_velocity=[0, 0, 1])
        with patch.object(native.time, 'monotonic', return_value=110), \
             patch.object(native.CinderSupplyPilot, 'flight', return_value=(7, 8, False)) as baseline:
            self.assertEqual(pilot.flight(moving, [0, 0, 0], set()), (7, 8, False))
            baseline.assert_called_once()
        self.assertEqual(pilot.home_alignment_started, 100)
        with patch.object(native.time, 'monotonic', return_value=115.001):
            with self.assertRaisesRegex(AssertionError, '15 seconds'):
                pilot.flight(s, [0, 0, 0], set())
        for stage in ('outbound_clearance', 'outbound', 'gate_return', 'home_clearance'):
            pilot.stage = stage
            with self.subTest(stage=stage), \
                 patch.object(native.CinderSupplyPilot, 'flight', return_value=(7, 8, False)) as baseline:
                self.assertEqual(pilot.flight(s, [0, 0, 0], set()), (7, 8, False))
                baseline.assert_called_once_with(s, [0, 0, 0], set())
        jovian = native.CinderSupplyPilot()
        jovian.stage = 'home_flight'
        self.assertFalse(hasattr(jovian, 'home_alignment_started'))
        original = dict(s, camera=[0, 5, 0], right=[1, 0, 0], up=[0, 0, 1],
                        tuning={'brake': 48})
        keys = set()
        with patch.object(jovian, 'aim', return_value=(27, 42, .95)) as aim:
            self.assertEqual(jovian.flight(original, [0, 0, 0], keys), (27, 42, True))
            aim.assert_called_once()
        self.assertEqual(keys, {'Prior'})

    def test_supply_home_exit_uses_hauler_supported_apron_and_preserves_jovian_camera_goal(self):
        s = dict(frame=8980, phase='SHUT_DOWN', player=[7, 4.513402, 89.046707],
                 position=[7, 5.81, 84.7000046], walk_forward=[.8, 0, -.6], ship_velocity=[0, 0, 0], cargo={},
                 grounded=True, supported=True, support_collider='Hauler/PilotRamp',
                 seated=False, control_enabled=True, transition_busy=False)
        for cls in (native.CinderSupplyPilot, native.CinderHaulerSupplyPilot):
            with self.subTest(pilot=cls.__name__):
                pilot = cls()
                pilot.stage, pilot.stage_since, pilot.last_state = 'home_exit', 0, s
                self.assertEqual(pilot.update(s, 1), (set(), 0, 0, False))
                self.assertEqual(pilot.stage, 'home_walk')
                self.assertIs(pilot.receipts['home_exterior'], s)
                expected = ([[8.8, 4.18, 90]] if cls is native.CinderHaulerSupplyPilot
                            else [[p+1.5*f for p, f in zip(s['player'], s['walk_forward'])]])
                self.assertEqual(pilot.route, expected)
                if cls is native.CinderHaulerSupplyPilot:
                    self.assertEqual(pilot.route, [pilot.initial_walk_route(s)[-1]])
                    self.assertIsNot(pilot.route[0], pilot.INITIAL_GOALS[-1])
                    pilot.route[0][0] = -100
                    self.assertEqual(pilot.home_walk_route(s), [[8.8, 4.18, 90]])
        self.assertEqual(s['player'], [7, 4.513402, 89.046707])

    def test_hauler_supply_exact_source_manifest_cannot_spend_or_aggregate_jovian_stock(self):
        pilot = native.CinderHaulerSupplyPilot()
        for source, destination in ((2, 0), (1, 1)):
            s = {'cargo': {'destination_handle': {'entity_id': 'cinder_destination', 'manifest_id': 'destination'},
                           'inventory': {'manifests': [
                {'owner_entity_id': pilot.SHIP, 'manifest_id': pilot.MANIFEST,
                 'entries': [{'item_id': 'cinder_supply_crates', 'quantity': source}]},
                {'owner_entity_id': 'cinder_destination', 'manifest_id': 'destination',
                 'entries': [{'item_id': 'cinder_supply_crates', 'quantity': destination}]}]}}}
            pilot.require_stock(s, source, destination)
            # The accepted Jovian pilot still requires its own source custody.
            with self.assertRaises(AssertionError): native.CinderSupplyPilot().require_stock(s, source, destination)
            for field, value in [('owner_entity_id', 'jovian_provisional'),
                                 ('manifest_id', 'cinder_jovian_source_manifest')]:
                bad = copy.deepcopy(s); bad['cargo']['inventory']['manifests'][0][field] = value
                with self.subTest(source=source, field=field):
                    with self.assertRaises(AssertionError): pilot.require_stock(bad, source, destination)
            bad = copy.deepcopy(s)
            bad['cargo']['inventory']['manifests'].append(dict(owner_entity_id='jovian_provisional', entries=[]))
            with self.assertRaises(AssertionError): pilot.require_stock(bad, source, destination)
        self.assertEqual(native.CinderSupplyPilot.MODE, 'cinder-supply')
        self.assertEqual(native.CinderSupplyPilot.MARKER, 'NATIVE_CINDER_SUPPLY_OK')
        self.assertEqual(pilot.MARKER, 'NATIVE_HAULER_SUPPLY_OK')

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

    def test_supply_stair_airtime_requires_current_bounded_cinder_region(self):
        pilot = native.CinderSupplyPilot()
        s = {'grounded': False, 'supported': False, 'support_collider': '',
             'control_enabled': True, 'seated': False, 'transition_busy': False,
             'cargo': {'available': True, 'actor_authorized': True, 'lease': True,
                       'contract': True, 'walk_within_region': True}}
        for stage in ('terminal_walk', 'reverse_walk', 'reboard_walk'):
            pilot.stage = stage
            pilot.foot(s)
            for key in s['cargo']:
                bad = copy.deepcopy(s); bad['cargo'][key] = False
                with self.subTest(stage=stage, missing=key):
                    with self.assertRaises(AssertionError): pilot.foot(bad)
        for stage in ('walk', 'cargo_exit', 'home_exit', 'home_walk'):
            pilot.stage = stage
            with self.subTest(stage=stage):
                with self.assertRaises(AssertionError): pilot.foot(s)
        pilot.stage = 'terminal_walk'
        for key, value in [('control_enabled', False), ('seated', True), ('transition_busy', True)]:
            bad = copy.deepcopy(s); bad[key] = value
            with self.subTest(invalid=key):
                with self.assertRaises(AssertionError): pilot.foot(bad)
        pilot.stage = 'home_walk'
        s.update(grounded=True, supported=True, support_collider='Yard/Deck')
        pilot.foot(s)

    def test_supply_step_control_check_requires_current_cinder_region(self):
        pilot = native.CinderSupplyPilot()
        pilot.stage = 'terminal_walk'
        s = {'grounded': True, 'supported': False, 'support_collider': '',
             'control_enabled': True, 'seated': False, 'transition_busy': False,
             'station_seated': False, 'game_station_seated': False, 'sleeping': False,
             'mouse_captured': True, 'capsule_enabled': True, 'piloted': False,
             'cargo': {'available': True, 'actor_authorized': True, 'lease': True,
                       'contract': True, 'walk_within_region': True}}
        pilot.require_walking(s)
        for key, value in [('station_seated', True), ('game_station_seated', True),
                           ('sleeping', True), ('mouse_captured', False),
                           ('capsule_enabled', False), ('piloted', True)]:
            bad = copy.deepcopy(s); bad[key] = value
            with self.subTest(invalid=key):
                with self.assertRaises(AssertionError): pilot.require_walking(bad)
        bad = copy.deepcopy(s); bad['cargo']['walk_within_region'] = False
        with self.assertRaises(AssertionError): pilot.require_walking(bad)
        pilot.stage = 'home_walk'
        with self.assertRaises(AssertionError): pilot.require_walking(s)

    def test_supply_waypoint_waits_for_actual_physical_landing(self):
        pilot = native.CinderSupplyPilot()
        pilot.stage = 'terminal_walk'
        s = {'grounded': False, 'supported': False, 'support_collider': '',
             'control_enabled': True, 'seated': False, 'transition_busy': False,
             'cargo': {'available': True, 'actor_authorized': True, 'lease': True,
                       'contract': True, 'walk_within_region': True},
             'player': [0, 0, 0], 'velocity': [0, 0, 0], 'frame': 12}
        self.assertFalse(pilot.walk_to(s, [0, 0, 0], set(), 0)[1])
        self.assertEqual(pilot.visited, [])
        s['grounded'] = True
        self.assertTrue(pilot.walk_to(s, [0, 0, 0], set(), 0)[1])
        self.assertTrue(pilot.visited[-1]['grounded'])

    def test_supply_reboard_near_goal_backs_toward_retained_failed_sample(self):
        pilot = native.CinderSupplyPilot()
        pilot.stage = 'reboard_walk'
        target = [35.7, -67.1, -686.25]
        s = {'player': [35.88654327392578, -67.09832763671875, -686.6527709960938],
             'velocity': [0, 0, 0], 'walk_forward': [.358537882566452, 0, -.9335076212882996],
             'walk_right': [.9335076212882996, 0, .358537882566452],
             'walk_tuning': {'walk': 5.8, 'sprint': 9.2, 'deceleration': 42, 'mouse': .0025},
             'grounded': True, 'supported': True, 'support_collider': 'Cinder/Structure/LandingDeck',
             'control_enabled': True, 'seated': False, 'transition_busy': False, 'frame': 8682}
        old_keys = set()
        old_dx, old_reached = native.ArrowReturnReusePilot.walk_to(pilot, s, target, old_keys)
        self.assertEqual((old_dx, old_keys, old_reached), (-360, set(), False))
        keys = set()
        self.assertEqual(pilot.walk_to(s, target, keys, 0), (0, False))
        self.assertEqual(keys, {'s'})
        self.assertGreater(native.dot(native.sub(target, s['player']),
                                     [-v for v in s['walk_forward']]), 0)
        # Crossing the radius while still moving is braking, never arrival.
        s.update(player=[35.725, -66.9289, -686.2908], velocity=[1.4, 0, -3.2])
        keys = set()
        self.assertEqual(pilot.walk_to(s, target, keys, 1), (0, False))
        self.assertEqual(keys, set())
        self.assertEqual(pilot.visited, [])
        s.update(velocity=[0, 0, 0])
        self.assertTrue(pilot.walk_to(s, target, set(), 2)[1])

    def test_supply_first_dock_waits_neutral_for_actual_engine_shutdown(self):
        pilot = native.CinderSupplyPilot()
        pilot.stage, pilot.stage_since = 'cargo_land', 0
        cargo = {'lease': True, 'contract': True, 'dock': [31, -65.85, -700], 'source_entity_id': 7,
                 'cluster_id': 10, 'generation': 1, 'access_id': 11, 'attachment': 1,
                 'berth_id': 12, 'terminal_id': 13, 'binding_id': 14, 'activity_id': 15,
                 'inventory': {'manifests': [
                     {'owner_entity_id': 'jovian_provisional', 'entries': [{'item_id': 'cinder_supply_crates', 'quantity': 2}]},
                     {'owner_entity_id': 'cinder_destination', 'entries': [{'item_id': 'cinder_supply_crates', 'quantity': 0}]}]}}
        s = {'frame': 6000, 'phase': 'SHUT_DOWN', 'position': cargo['dock'], 'player': [31, -64, -700],
             'ship_velocity': [0, 0, 0], 'ship_id': 7, 'landed': True, 'engine': 'ONLINE', 'cargo': cargo}
        pilot.last_state = s
        self.assertEqual(pilot.update(s, 1)[0], set())
        self.assertEqual(pilot.stage, 'cargo_arrival_shutdown')
        self.assertEqual(pilot.update(s, 2)[0], set())
        self.assertEqual(pilot.stage, 'cargo_arrival_shutdown')
        s['engine'] = 'OFFLINE'
        self.assertEqual(pilot.update(s, 3)[0], set())
        self.assertEqual(pilot.stage, 'supply_pause')
        self.assertIn('occupied_source', pilot.receipts)

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
        self.assertEqual(outbound, [[-53, 13.63, 83.3], [-53, 13.63, 110],
                                    [-53, 80, 150], [31, 80, -225]])
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

    def test_supply_pretransfer_cut_protects_existing_and_new_ordinary_records(self):
        for corruption in ('none', 'change_initial', 'delete_initial', 'change_new', 'change_new_repeat', 'change_new_home', 'missing_cut'):
            with self.subTest(corruption=corruption), tempfile.TemporaryDirectory() as root:
                profile, output = Path(root)/'profile', Path(root)/'result'
                (profile/'data').mkdir(parents=True); output.mkdir()
                path = profile/'data'/'mudds_user_data.json'
                document = self.restart_document()
                path.write_text(json.dumps(document))
                files, pilot = native.CinderSupplyFiles(profile, output), native.CinderSupplyPilot()
                sample = {'path': str(path), 'generation': document['generation'], 'source': 'primary'}
                s = dict(self.supply_paid_observation(), save=sample)
                files.observe(s, pilot)
                document['generation'] += 1
                document['payload']['tutorial_prompts_seen'] = {'schema_version': 1, 'seen_ids': ['cinder_platform_supply_run']}
                if corruption == 'change_initial': document['payload']['unrelated']['progress'].append(3)
                if corruption == 'delete_initial': del document['payload']['unrelated']
                path.write_text(json.dumps(document)); sample['generation'] = document['generation']
                if corruption != 'missing_cut':
                    pilot.stage = 'terminal_aim'
                    if corruption in ('change_initial', 'delete_initial'):
                        with self.assertRaisesRegex(AssertionError, 'unrelated actual-file'):
                            files.observe(s, pilot)
                        self.assertFalse(pilot.file_pretransfer)
                        continue
                    files.observe(s, pilot)
                    self.assertTrue(pilot.file_pretransfer)
                    self.assertEqual((output/'pretransfer.json').read_bytes(), path.read_bytes())
                document['generation'] += 1
                document['payload']['cinder_cargo_delivery'] = s['paid_slot']
                document['payload']['game_flow_reward_store'] = s['reward_record']
                if corruption == 'change_new': document['payload']['tutorial_prompts_seen']['seen_ids'] = []
                path.write_text(json.dumps(document)); sample['generation'] = document['generation']
                pilot.paid_state = s
                if corruption in ('change_new', 'missing_cut'):
                    with self.assertRaisesRegex(AssertionError, 'unrelated actual-file|pre-transfer'):
                        files.observe(s, pilot)
                    self.assertFalse(pilot.file_paid)
                else:
                    files.observe(s, pilot)
                    self.assertTrue(pilot.file_paid)
                    for label, cut in (('repeat_terminal', 'repeat'), ('home_docked', 'home')):
                        pilot.receipts[label] = s
                        if corruption == 'change_new_'+cut:
                            document['generation'] += 1
                            document['payload']['tutorial_prompts_seen']['seen_ids'] = []
                            path.write_text(json.dumps(document)); sample['generation'] = document['generation']
                            with self.assertRaisesRegex(AssertionError, 'unrelated actual-file'):
                                files.observe(s, pilot)
                            self.assertFalse(pilot.file_repeat if cut == 'repeat' else pilot.file_home)
                            break
                        files.observe(s, pilot)
                    if corruption == 'none': self.assertTrue(pilot.file_repeat and pilot.file_home)

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
            pilot.stage = 'terminal_aim'
            files.observe(s, pilot)
            self.assertTrue(pilot.file_pretransfer)
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
        if pilot.mode == 'life-arm' and name == 'zenith_approach':
            target = [20.4,4.2,59.1]  # Same published goal region; safe corner fixture endpoint.
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

    def zenith_corner_fixture(self, point):
        pilot, sample = self.life_walking_pilot('life-arm')
        sample.update(player=list(point), position=list(point), velocity=[0,0,0], native_interact=False)
        self.arm_motion(sample)
        pilot.observed_previous = copy.deepcopy(sample)
        pilot.previous = copy.deepcopy(sample)
        pilot.tap_key = None
        pilot.stage = 'walk_service'
        pilot.route = [pilot.ARM_GOALS[12]]
        pilot.index = 0
        pilot.visited = [{'waypoint':name} for name,_point in pilot.ARM_GOALS[:12]]
        pilot.goal_started = sample['frame']/60
        pilot.settled_frames = 0
        return pilot, sample

    def test_zenith_corner_old_failure_cannot_advance_and_safe_interior_uses_same_fifteen_samples(self):
        point = [20.197271347,4.20189333,59.318538666]
        pilot,sample = self.zenith_corner_fixture(point)
        published = pilot.route[0][1][:]
        self.assertLess(math.hypot(point[0]-published[0],point[2]-published[2]),.30)
        self.assertLess(point[0],20.2); self.assertGreater(point[2],59.3)
        pilot.settled_frames = 15
        direction = native.unit(native.sub([20.4,point[1],59.1],point))
        sample['walk_forward'] = direction
        sample['walk_right'] = [-direction[2],0,direction[0]]
        keys=set(); _dx,reached=pilot.walk_to(sample,published,keys,1)
        self.assertFalse(reached); self.assertIn('w',keys)
        self.life_tick(pilot,sample)
        self.assertEqual(pilot.settled_frames,0)
        self.assertEqual(len(pilot.visited),12)
        self.assertEqual(pilot.route[0],('zenith_approach',published))
        pilot,sample = self.zenith_corner_fixture([20.4,4.2,59.1])
        for _ in range(14): self.life_tick(pilot,sample)
        self.assertEqual(pilot.settled_frames,14); self.assertEqual(len(pilot.visited),12)
        self.life_tick(pilot,sample)
        self.assertEqual(pilot.visited[-1]['waypoint'],'zenith_approach')
        self.assertEqual(pilot.route[0][0],'zenith_clearance')
        self.assertEqual(len(pilot.ARM_GOALS),15)
        self.assertEqual(pilot.ARM_GOALS[12],('zenith_approach',[20.2,4.2,59.2]))
        self.assertEqual(pilot.ARM_GOALS[13:],(('zenith_clearance',[18.6,4.2,58.6]),
                                              ('zenith_candidate',[18.2,4.2,58.2])))

    def test_zenith_corner_keeps_real_support_and_original_goal_time_guard(self):
        pilot,sample=self.zenith_corner_fixture([20.4,4.2,59.1])
        sample['supported']=False
        with self.assertRaisesRegex(AssertionError,'actual physical station floor support'): self.life_tick(pilot,sample)
        pilot,sample=self.zenith_corner_fixture([20.4,4.2,59.1])
        sample['frame'] += 1; sample['service']['clock'] += 1/60
        self.arm_motion(sample,pilot.observed_previous)
        with self.assertRaisesRegex(AssertionError,'15-second authored Zenith goal deadline'):
            pilot.update(copy.deepcopy(sample),pilot.goal_started+15.001)
        control=[20.4,59.1]; goal=[20.2,59.2]
        self.assertLess(math.hypot(control[0]-goal[0],control[1]-goal[1])+.05,.30)
        crossing_x=22+(20.4-22)*(59.3-68.3)/(59.1-68.3)
        self.assertAlmostEqual(crossing_x,20.4347826087)
        for fraction in (0,.25,.5,.75,1):
            x=20.3+(18.6-20.3)*fraction
            z=59.2+(58.6-59.2)*fraction
            self.assertTrue(13 <= x <= 28 and 47.3 <= z <= 59.3)

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

    def bomber_policy(self):
        p, s = native.BomberRearmPilot(), self.full_observation()
        p.expected_pid = 42
        s['bomber_rearm'] = dict(pid=42, main_id=2, player_id=1, ship_id=3, seat_id=4,
            authority_id=5, component_id=6, component_generation=1, berth_id='bomber_home',
            berth_instance_id=7, berth_parent_id=8, definition_id=p.CRAFT, paused=False,
            piloted=False, active_ship=False, seated_at_pilot=False, destroyed=False,
            regeneration_pending=False, landed=True, engine='OFFLINE', position=[0, 0, 0],
            velocity=[0, 0, 0], parked_exact=True, lease=True, default_sampler=True,
            tuning_unchanged=True, source_enabled=True, application_focused=True,
            native_fire=False, command_fire=False, native_interact=False,
            reboard_blocked=False, boarding_distance=8, boarding_reach=7,
            grounded=True, supported=True, support_collider='Yard/Deck',
            authority=dict(active=False, generation=0, ammunition_remaining=0,
                           cooldown_remaining=0, release_records=[], detach_reason=''),
            loop=dict(active=False, generation=0, ship_id='', request_sequence=0,
                      projectiles=[], last_result={}))
        p.validate_observation(s)
        p.stage = 'craft_board'
        b = s['bomber_rearm']
        s.update(frame=101, seated=True, control_enabled=False)
        b.update(piloted=True, active_ship=True, seated_at_pilot=True)
        b['authority'].update(active=True, generation=1, ammunition_remaining=4)
        b['loop'].update(active=True, generation=1, ship_id=p.CRAFT)
        p.validate_observation(s)
        p._update_route(s, 2)
        return p, s

    def bomber_fire_receipt(self, p, s, kind='release', presentation=True):
        b, a, loop = s['bomber_rearm'], s['bomber_rearm']['authority'], s['bomber_rearm']['loop']
        self.assertTrue(p.fire(s, s['frame']/60, kind)[3])
        s['frame'] += 3
        b.update(native_fire=True, command_fire=True)
        if kind == 'release':
            count = len(a['release_records'])+1
            a['ammunition_remaining'] = 4-count
            a['release_records'].append(dict(generation=a['generation'], release_sequence=count,
                request_sequence=count, ammunition_remaining=4-count, actor_id='player_pilot'))
            loop.update(request_sequence=count, last_result=dict(accepted=True,
                        presentation=dict(accepted=presentation, reason='presented' if presentation else 'invalid_release_record')))
        else: loop['last_result'] = dict(accepted=False, reason='ammunition_exhausted')
        p.validate_observation(s)
        s['frame'] += 6
        self.assertFalse(p.finish_fire(s, s['frame']/60)[3])
        b.update(native_fire=False, command_fire=False)
        s['frame'] += 3
        p.validate_observation(s)
        p.finish_fire(s, s['frame']/60)

    def test_bomber_policy_spends_four_distinct_edges_then_proves_exhaustion(self):
        p, s = self.bomber_policy()
        for remaining in (3, 2, 1, 0):
            self.bomber_fire_receipt(p, s)
            self.assertEqual(s['bomber_rearm']['authority']['ammunition_remaining'], remaining)
        s['bomber_rearm']['authority']['cooldown_remaining'] = .01
        with self.assertRaisesRegex(AssertionError, 'actual cooldown'): p.fire(s, 10, 'exhausted')
        s['bomber_rearm']['authority']['cooldown_remaining'] = 0
        self.bomber_fire_receipt(p, s, 'exhausted')
        self.assertEqual(p.stage, 'payload_idle_exit')
        self.assertEqual(len(p.receipts['exhausted']['bomber_rearm']['authority']['release_records']), 4)
        self.assertEqual(len([e for e in p.native_edges if e['action'] == 'fire' and e['pressed']]), 5)

    def test_bomber_policy_requires_detach_physical_clear_and_exact_refill_before_fresh_fire(self):
        p, s = self.bomber_policy()
        p.stage = 'payload_exit_wait'
        b = s['bomber_rearm']
        s.update(frame=110, seated=False, control_enabled=True)
        b.update(piloted=False, seated_at_pilot=False)
        b['authority'].update(active=False, ammunition_remaining=0, release_records=[], detach_reason='pilot_disembarked')
        b['loop'].update(active=False, request_sequence=0, projectiles=[])
        p.validate_observation(s)
        p.retain('detached_foot', s)
        p.retain('walked_clear', s)
        p.stage = 'payload_reboard_wait'
        s.update(frame=120, seated=True, control_enabled=False)
        b.update(piloted=True, seated_at_pilot=True)
        b['authority'].update(active=True, generation=2, ammunition_remaining=4, detach_reason='')
        b['loop'].update(active=True, generation=2)
        bad = copy.deepcopy(s); bad['bomber_rearm']['authority']['ammunition_remaining'] = 3
        with self.assertRaisesRegex(AssertionError, 'exactly four'): p.validate_observation(bad)
        s['frame'] += 1
        p.validate_observation(s)
        p._update_route(s, 3)
        self.assertEqual(p.stage, 'payload_reboard_fire')
        with self.assertRaisesRegex(AssertionError, 'admit its payload presentation'):
            self.bomber_fire_receipt(copy.deepcopy(p), copy.deepcopy(s), presentation=False)
        self.bomber_fire_receipt(p, s)
        self.assertEqual(p.receipts['refilled_seated']['bomber_rearm']['authority']['ammunition_remaining'], 4)
        self.assertEqual(p.receipts['reboard_release']['bomber_rearm']['authority']['ammunition_remaining'], 3)
        s['bomber_rearm']['authority']['ammunition_remaining'] = 99
        self.assertEqual(p.receipts['reboard_release']['bomber_rearm']['authority']['ammunition_remaining'], 3)

    def test_bomber_policy_rejects_raw_lifecycle_changes_and_unissued_held_releases(self):
        for field, value in (('pid', 99), ('ship_id', 99), ('authority_id', 99), ('component_generation', 2),
                             ('berth_instance_id', 99), ('paused', True), ('destroyed', True),
                             ('regeneration_pending', True), ('default_sampler', False),
                             ('tuning_unchanged', False), ('parked_exact', False), ('native_fire', True)):
            p, s = self.bomber_policy(); s['frame'] += 1
            s['bomber_rearm'][field] = value
            with self.subTest(field=field):
                with self.assertRaises(AssertionError): p.validate_observation(s)
        p, s = self.bomber_policy()
        self.bomber_fire_receipt(p, s)
        # A second unsolicited record while held cannot be hidden by a later
        # coalesced observation restoring the expected count.
        s['frame'] += 1
        s['bomber_rearm']['loop']['request_sequence'] = 2
        with self.assertRaises(AssertionError): p.validate_observation(s)

    def test_bomber_policy_idle_exit_and_outward_clear_are_observed_guards(self):
        p, s = self.bomber_policy()
        p.craft_key = p.CRAFT
        p.stage = 'payload_idle_exit'
        s['bomber_rearm']['engine'] = 'ONLINE'
        self.assertNotIn('e', p._update_route(s, 3)[0])
        p.stage = 'payload_clear'
        p.pending_walk = [[0, 0, 0]]
        s.update(seated=False, control_enabled=True)
        s['bomber_rearm'].update(reboard_blocked=True, boarding_distance=6)
        with patch.object(p, 'walk_pending', return_value=(0, True)):
            with self.assertRaisesRegex(AssertionError, 'suppression'): p._update_route(s, 4)

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

    def courier_pilot(self, pilot_type=native.CourierPilot):
        pilot = pilot_type()
        pilot.identities = (1, 2)
        pilot.stage = 'range'
        pilot.parked_forward = [0, 0, -1]
        s = self.hulk_observation()
        s.update(phase='INTERCEPTOR_ENGAGEMENT', opponent_active=True, targets=[],
                 shot_accepted=False, command_fire=False, opponent=[0, 8, -20],
                 opponent_id=12, opponent_health=85., position=[0, 8, -73], camera=[0, 8, -91])
        s['tuning']['cooldown'] = .22
        s['courier'] = dict(native.CourierPilot.CONFIG, director_id=10, actor_id=11,
                            weapon_ready=True,
                            scenario_origin=s['position'][:],
                            scenario='none', generation=0, state='arming', outcome='pending',
                            elapsed_seconds=0., escape_progress=0., active=False,
                            position=[0, 8, -200], velocity=[0, 0, -52], health=78.,
                            maximum_health=78., seen_alive=False, hit={}, kill={})
        self.assertFalse(pilot.update(copy.deepcopy(s), 0)[3])
        self.assertEqual(pilot.stage, 'courier_wait')
        return pilot, s

    def courier_dispatch(self, pilot, s):
        self.courier_wound_defender(pilot, s)
        s['frame'] += 280
        s['courier'].update(scenario='courier_intercept', generation=1, state='running',
                            active=True, seen_alive=True)
        pilot.update(copy.deepcopy(s), 5)
        self.assertEqual(pilot.stage, 'courier_attack')

    def courier_wound_defender(self, pilot, s):
        for before in (85., 51.):
            s['frame'] = pilot.defender_ready_frame
            self.assertEqual(s['opponent_health'], before)
            self.assertTrue(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
            s.update(frame=s['frame']+1, command_fire=True, opponent_health=before-34.)
            self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
            s.update(frame=s['frame']+1, command_fire=False)
            self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])

    def courier_kill(self, s):
        s['frame'] += 60
        receipt = dict(source_entity_id=2, target_id=11, sequence=16, applied_damage=10.,
                       remaining_health=0., destroyed=True, accepted=True, resolved=True,
                       scenario_generation=1, frame=s['frame'], escape_progress=.15)
        s['courier'].update(state='concluded', outcome='cleared', active=False,
                            health=0., escape_progress=.15, hit=receipt.copy(), kill=receipt.copy())

    def test_courier_wait_requires_cooldown_ack_damage_and_release_between_pulses(self):
        pilot, s = self.courier_pilot()
        for frame in range(s['frame']+1, pilot.defender_ready_frame):
            s.update(frame=frame, command_fire=False)
            self.assertFalse(pilot.update(copy.deepcopy(s), frame/60)[3])
        self.courier_wound_defender(pilot, s)
        self.assertEqual(s['opponent_health'], 17.)
        self.assertEqual([(w['before_health'], w['after_health']) for w in pilot.defender_wounds],
                         [(85., 51.), (51., 17.)])
        for wound in pilot.defender_wounds:
            self.assertEqual((wound['source_entity_id'], wound['target_id']), (2, 12))
            self.assertGreater(wound['ack_frame'], wound['frame'])
            self.assertGreater(wound['release_frame'], wound['ack_frame'])
        self.assertGreaterEqual(pilot.defender_wounds[1]['frame'],
                                pilot.defender_wounds[0]['frame'] + math.ceil(.22*60) + 6)
        for health in (17., 34.):
            s.update(frame=s['frame']+30, opponent_health=health)
            self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])

    def test_courier_wait_requires_observed_weapon_readiness_for_each_new_pulse(self):
        pilot, s = self.courier_pilot()
        # Failed run: wait1331, command ack1353/release1355, no health loss.
        # Earlier passive capture of the same range prefix observes overheat
        # at1343 despite .22s cooldown; actual weapon readiness returns1403.
        s['courier']['weapon_ready'] = False
        for frame in (1343, 1353, 1402):
            s['frame'] = frame
            self.assertFalse(pilot.update(copy.deepcopy(s), frame/60)[3])
            self.assertIsNone(pilot.defender_pulse)
        s.update(frame=1403)
        s['courier']['weapon_ready'] = True
        self.assertTrue(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        s.update(frame=1404, command_fire=True, opponent_health=51.)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        s.update(frame=1405, command_fire=False)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        self.assertEqual(len(pilot.defender_wounds), 1)
        s['courier']['weapon_ready'] = False
        for frame in (pilot.defender_ready_frame, 1450):
            s['frame'] = frame
            self.assertFalse(pilot.update(copy.deepcopy(s), frame/60)[3])
            self.assertIsNone(pilot.defender_pulse)
        s.update(frame=1451)
        s['courier']['weapon_ready'] = True
        self.assertTrue(pilot.update(copy.deepcopy(s), s['frame']/60)[3])

    def test_courier_wait_never_blindly_repeats_a_missed_or_unacknowledged_pulse(self):
        for acknowledge in (False, True):
            with self.subTest(acknowledge=acknowledge):
                pilot, s = self.courier_pilot()
                start = pilot.defender_ready_frame
                s['frame'] = start
                self.assertTrue(pilot.update(copy.deepcopy(s), start/60)[3])
                for offset in (1, 5, 6, 20, 100):
                    s.update(frame=start+offset, command_fire=acknowledge and offset == 1)
                    fire = pilot.update(copy.deepcopy(s), s['frame']/60)[3]
                    self.assertEqual(fire, not acknowledge and offset < 6)
                self.assertEqual(pilot.defender_wounds, [])
                s['courier'].update(scenario='courier_intercept', generation=1, state='running',
                                    active=True, seen_alive=True)
                with self.assertRaisesRegex(AssertionError, 'two observed nonlethal'):
                    pilot.update(copy.deepcopy(s), 5)

    def test_courier_wait_observes_release_and_damage_before_rearming(self):
        pilot, s = self.courier_pilot()
        start = pilot.defender_ready_frame
        s['frame'] = start
        self.assertTrue(pilot.update(copy.deepcopy(s), start/60)[3])
        s.update(frame=start+1, command_fire=True)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        s.update(frame=start+30, command_fire=True, opponent_health=51.)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        self.assertEqual(pilot.defender_wounds, [])
        s.update(frame=start+31, command_fire=False)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        self.assertEqual(len(pilot.defender_wounds), 1)
        for offset in (32, 36):
            s['frame'] = start+offset
            self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        s['frame'] = start+37
        self.assertTrue(pilot.update(copy.deepcopy(s), s['frame']/60)[3])

    def test_courier_actual_kill_precedes_original_defender_and_home(self):
        pilot, s = self.courier_pilot()
        self.courier_dispatch(pilot, s)
        self.courier_kill(s)
        pilot.update(copy.deepcopy(s), 6)
        self.assertEqual(pilot.stage, 'interceptor')
        self.assertIsNone(pilot.result)
        s.update(frame=s['frame']+1, phase='RETURN_TO_YARD', opponent_active=False,
                 shot_accepted=True, command_fire=True)
        # Actual command and accepted-shot invariants still belong to base.
        pilot.update(copy.deepcopy(s), 7)
        self.assertEqual(pilot.stage, 'return_align')
        self.assertIsNone(pilot.result)
        # Reaching the exact original terminal seam retains courier proof;
        # the packaged route supplies all intervening physical flight states.
        pilot.stage = 'exit'
        pilot.phases = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                        'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN']
        s.update(frame=s['frame']+1, phase='COMPLETE', piloted=False, seated=False,
                 control_enabled=True, guided_complete=True, exit_error=.17,
                 lease=True, parked_exact=True, contract=True, spawn=[0, 0, 0])
        pilot.update(copy.deepcopy(s), 8)
        self.assertEqual(pilot.result['completion_marker'], native.CourierPilot.MARKER)
        self.assertEqual(pilot.result['courier']['kill']['target_id'], 11)
        self.assertEqual(pilot.result['defender_wounds'], pilot.defender_wounds)
        self.assertEqual(pilot.stage, 'complete')

    def test_courier_terminal_outcomes_cannot_substitute_for_kill(self):
        for outcome in ('escaped', 'withdrawn', 'expired', 'aborted', 'cleared'):
            with self.subTest(outcome=outcome):
                pilot, s = self.courier_pilot()
                self.courier_dispatch(pilot, s)
                s['courier'].update(state='concluded', outcome=outcome, active=False)
                with self.assertRaises(AssertionError): pilot.update(s, 6)
                self.assertIsNone(pilot.result)

    def test_courier_receipts_reject_wrong_source_target_generation_and_generic_fire(self):
        mutations = [('kill', {}), ('hit', {}), ('kill', {'source_entity_id': 99}),
                     ('kill', {'target_id': 99}), ('kill', {'scenario_generation': 2}),
                     ('kill', {'sequence': -1}), ('kill', {'applied_damage': 0}),
                     ('kill', {'applied_damage': float('nan')}), ('kill', {'accepted': False}),
                     ('kill', {'resolved': False}), ('kill', {'destroyed': False}),
                     ('kill', {'remaining_health': 1}), ('kill', {'escape_progress': 1}),
                     ('kill', {'frame': 1})]
        for field, change in mutations:
            with self.subTest(field=field, change=change):
                pilot, s = self.courier_pilot()
                self.courier_dispatch(pilot, s)
                self.courier_kill(s)
                s.update(shot_accepted=True, command_fire=True)
                if change: s['courier'][field].update(change)
                else: s['courier'][field] = {}
                with self.assertRaises(AssertionError): pilot.update(s, 6)

    def test_courier_configuration_identity_and_defender_lifetime_are_required(self):
        for change, outer in [({'escape_distance': 999}, {}), ({'actor_id': 12}, {}),
                              ({'generation': 2}, {}), ({'escape_progress': 1}, {}),
                              ({'active': False}, {}), ({}, {'opponent_active': False}),
                              ({}, {'phase': 'RETURN_TO_YARD'}), ({}, {'opponent_id': 13}),
                              ({}, {'opponent_health': 0})]:
            with self.subTest(change=change, outer=outer):
                pilot, s = self.courier_pilot()
                self.courier_dispatch(pilot, s)
                s['courier'].update(change)
                s.update(outer)
                with self.assertRaises(AssertionError): pilot.update(s, 6)

    def courier_escape_prep(self):
        pilot, s = self.courier_pilot(native.CourierEscapePilot)
        s['courier']['prep_shot'] = dict(present=True, accepted=True, resolved=True,
            hit=True, damaged=True, destroyed=True, status='destroyed',
            source_id=1101, source_entity_id=2, target_entity_id=15, damageable_id=16,
            collider_id=17, collider_path='Main/Range/Target', applied_damage=50.,
            request=dict(source_id=1101, source_entity_id=2,
                         weapon_id='range_pulse_cannon', sequence=8))
        s['frame'] = pilot.defender_ready_frame
        self.assertTrue(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        return pilot, s

    def courier_prep_miss(self):
        return dict(present=True, accepted=True, resolved=True, hit=False, damaged=False,
                    destroyed=False, status='miss', source_id=1101, source_entity_id=2,
                    target_entity_id=0, damageable_id=0, collider_id=0, collider_path='',
                    applied_damage=0., request=dict(source_id=1101, source_entity_id=2,
                    weapon_id='torrent_compact_pulse_cannon', sequence=9))

    def test_escape_actual_miss_rearms_only_after_ack_release_cooldown_and_readiness(self):
        pilot, s = self.courier_escape_prep()
        start = s['frame']
        s['courier']['prep_shot'] = self.courier_prep_miss()
        s.update(frame=start+1, command_fire=True)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        self.assertEqual(pilot.defender_misses, [])
        s.update(frame=start+2, command_fire=False)
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        self.assertIsNone(pilot.defender_pulse)
        self.assertEqual(len(pilot.defender_misses), 1)
        self.assertEqual(pilot.defender_wounds, [])
        miss = pilot.defender_misses[0]
        self.assertEqual(miss['prepress_shot']['request']['sequence'], 8)
        self.assertEqual(miss['resolved_shot']['request']['sequence'], 9)
        self.assertEqual((miss['ack_frame'], miss['release_frame']), (start+1, start+2))
        for frame in range(start+3, pilot.defender_ready_frame):
            s['frame'] = frame
            self.assertFalse(pilot.update(copy.deepcopy(s), frame/60)[3])
        s['frame'] = pilot.defender_ready_frame
        s['courier']['weapon_ready'] = False
        self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        s['courier']['weapon_ready'] = True
        self.courier_wound_defender(pilot, s)
        self.assertEqual([(w['before_health'], w['after_health']) for w in pilot.defender_wounds],
                         [(85., 51.), (51., 17.)])
        s['frame'] += 280
        s['courier'].update(scenario='courier_intercept', generation=1, state='running',
                            active=True, seen_alive=True, escape_origin=[0, 8, -200],
                            terminal={}, standdown_violation='', roster_ids=[11],
                            actors=[dict(id=11, present=True, active=True, health=78.,
                                         fire_authorized=True, shots_fired=0, pending_receipts=0)])
        pilot.update(copy.deepcopy(s), s['frame']/60)
        self.assertEqual(pilot.stage, 'courier_escape_wait')

    def test_escape_miss_recovery_rejects_stale_foreign_blocked_damaging_and_malformed_results(self):
        mutations = [dict(present=False), dict(accepted=False), dict(resolved=False),
            dict(status='unresolved'), dict(status='duplicate_sequence'),
            dict(status='world_blocked'), dict(status='non_damageable_blocked'),
            dict(hit=True), dict(damaged=True), dict(destroyed=True),
            dict(source_id=1102), dict(source_entity_id=99), dict(target_entity_id=12),
            dict(target_entity_id=99), dict(damageable_id=13), dict(collider_id=14),
            dict(applied_damage=34.), dict(applied_damage=float('nan')),
            dict(applied_damage=float('inf'))]
        for key, value in [('sequence', 8), ('sequence', -1), ('sequence', True),
                           ('source_id', 1102), ('source_entity_id', 99),
                           ('weapon_id', 'range_pulse_cannon')]:
            request = self.courier_prep_miss()['request']
            request[key] = value
            mutations.append(dict(request=request))
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                pilot, s = self.courier_escape_prep()
                shot = self.courier_prep_miss()
                shot.update(mutation)
                s['courier']['prep_shot'] = shot
                s.update(frame=s['frame']+1, command_fire=True)
                pilot.update(copy.deepcopy(s), s['frame']/60)
                for offset in (1, 30, 100):
                    s.update(frame=s['frame']+offset, command_fire=False)
                    self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
                self.assertIsNotNone(pilot.defender_pulse)
                self.assertEqual(pilot.defender_misses, [])
                self.assertEqual(pilot.defender_wounds, [])

    def test_escape_miss_needs_actual_ack_release_unchanged_health_and_same_source_baseline(self):
        for failure in ('missing_baseline', 'foreign_baseline', 'no_ack', 'no_release', 'health_changed'):
            with self.subTest(failure=failure):
                pilot, s = self.courier_escape_prep()
                if failure == 'missing_baseline': pilot.defender_pulse['prepress_shot'] = {}
                if failure == 'foreign_baseline':
                    pilot.defender_pulse['prepress_shot']['source_entity_id'] = 99
                s['courier']['prep_shot'] = self.courier_prep_miss()
                s.update(frame=s['frame']+1, command_fire=failure != 'no_ack')
                pilot.update(copy.deepcopy(s), s['frame']/60)
                s.update(frame=s['frame']+30, command_fire=failure == 'no_release')
                if failure == 'health_changed': s['opponent_health'] = 84.
                self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
                self.assertIsNotNone(pilot.defender_pulse)
                self.assertEqual(pilot.defender_misses, [])

    def test_escape_consumed_miss_never_rearms_another_pulse_or_replaces_two_wounds(self):
        pilot, s = self.courier_escape_prep()
        s['courier']['prep_shot'] = self.courier_prep_miss()
        for command_fire in (True, False):
            s.update(frame=s['frame']+1, command_fire=command_fire)
            pilot.update(copy.deepcopy(s), s['frame']/60)
        s['frame'] = pilot.defender_ready_frame
        self.assertTrue(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        for command_fire in (True, False, False):
            s.update(frame=s['frame']+30, command_fire=command_fire)
            self.assertFalse(pilot.update(copy.deepcopy(s), s['frame']/60)[3])
        self.assertEqual(len(pilot.defender_misses), 1)
        self.assertEqual(pilot.defender_wounds, [])
        self.assertIsNotNone(pilot.defender_pulse)
        s['courier'].update(scenario='courier_intercept', generation=1, state='running',
                            active=True, seen_alive=True)
        with self.assertRaisesRegex(AssertionError, 'two observed nonlethal'):
            pilot.update(copy.deepcopy(s), s['frame']/60)

    def escaping_courier(self):
        pilot, s = self.courier_pilot(native.CourierEscapePilot)
        self.courier_wound_defender(pilot, s)
        s['frame'] += 280
        actor = dict(id=11, present=True, active=True, health=78.,
                     fire_authorized=True, shots_fired=3, pending_receipts=0)
        s['courier'].update(scenario='courier_intercept', generation=1, state='running',
                            active=True, seen_alive=True, actors=[actor], roster_ids=[11],
                            escape_origin=[0, 8, -200], terminal={}, standdown_violation='')
        self.assertFalse(pilot.update(copy.deepcopy(s), 5)[3])
        self.assertEqual(pilot.stage, 'courier_escape_wait')
        return pilot, s

    def runner_reaches_boundary(self, s):
        s['frame'] += 1700
        actor = s['courier']['actors'][0]
        actor.update(active=False, fire_authorized=False)
        c = s['courier']
        c.update(position=[0, 8, -1600], escape_progress=1., state='concluded',
                 outcome='escaped', active=False, roster_ids=[], elapsed_seconds=28.3)
        c['terminal'] = dict(frame=s['frame'], actor_id=11, director_id=10, generation=1,
                             position=list(c['position']), escape_origin=list(c['escape_origin']),
                             health=78., escape_progress=1., actors=copy.deepcopy(c['actors']))

    def test_escape_stops_on_explicit_weapon_component_failure_while_waiting_with_live_defender(self):
        pilot, s = self.escaping_courier()
        # The observed failure started at frame2019, hull89->67, long before
        # firing resumed. Positive hull and ONLINE do not imply usable weapons.
        s.update(command_fire=False, opponent_health=17.)
        s['telemetry'].update(hull=67., engine='ONLINE')
        s['courier']['weapon_ready'] = False
        s['courier']['weapon_status'] = dict(ready=False, reason='weapon_cooldown')
        s['frame'] += 1
        self.assertFalse(pilot.update(copy.deepcopy(s), 6)[3])
        s['courier']['weapon_status']['reason'] = 'weapon_overheated'
        s['frame'] += 1
        self.assertFalse(pilot.update(copy.deepcopy(s), 6)[3])
        s['courier']['weapon_status']['reason'] = 'weapon_component_failed'
        s['frame'] += 1
        with self.assertRaisesRegex(AssertionError, 'authoritative weapon_component_failed'):
            pilot.update(copy.deepcopy(s), 6)
        self.assertIsNone(pilot.result)

    def test_escape_fixed_wait_flight_requires_standdown_and_physical_return_before_defender(self):
        pilot, s = self.escaping_courier()
        saved_attack = s['position'][:]
        self.assertEqual(pilot.saved_attack_position, saved_attack)
        self.assertEqual(len(pilot.wait_waypoints), 4)
        for waypoint in pilot.wait_waypoints:
            self.assertAlmostEqual(native.norm(native.sub(waypoint, pilot.scenario_origin)),
                                   math.sqrt(220**2+180**2+220**2))
        for progress in (.1, .5, .99):
            s['frame'] += 60
            s['courier']['escape_progress'] = progress
            keys, dx, dy, fire = pilot.update(copy.deepcopy(s), 6)
            self.assertFalse(fire)
            self.assertTrue(keys <= {'w', 'Prior'})
            self.assertNotEqual((dx, dy), (0, 0))
            self.assertEqual(pilot.wait_waypoint_index, 0)
        self.runner_reaches_boundary(s)
        self.assertFalse(pilot.update(copy.deepcopy(s), 30)[3])
        self.assertEqual(pilot.stage, 'courier_standdown')
        self.assertIsNone(pilot.result)
        s['frame'] += 59
        self.assertFalse(pilot.update(copy.deepcopy(s), 31)[3])
        self.assertEqual(pilot.stage, 'courier_standdown')
        s['frame'] += 1
        self.assertFalse(pilot.update(copy.deepcopy(s), 32)[3])
        self.assertEqual(pilot.stage, 'courier_return_attack')
        self.assertEqual(pilot.attack_return_visited, [])
        for waypoint in pilot.attack_return_waypoints:
            s.update(frame=s['frame']+1, position=waypoint[:], velocity=[2., 0, 0])
            self.assertFalse(pilot.update(copy.deepcopy(s), 32)[3])
            self.assertEqual(pilot.stage, 'courier_return_attack')
            s.update(frame=s['frame']+1, velocity=[0., 0, 0])
            self.assertFalse(pilot.update(copy.deepcopy(s), 32)[3])
        self.assertEqual(pilot.stage, 'interceptor')
        self.assertEqual(pilot.attack_return_visited[-1]['position'], saved_attack)
        self.assertEqual(len(pilot.attack_return_visited), 2)
        s.update(frame=s['frame']+1, phase='RETURN_TO_YARD', opponent_active=False,
                 opponent_health=0., shot_accepted=True, command_fire=True)
        pilot.update(copy.deepcopy(s), 33)
        self.assertEqual(pilot.stage, 'return_align')
        self.assertIsNone(pilot.result)
        pilot.stage = 'exit'
        pilot.phases = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                        'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN']
        s.update(frame=s['frame']+1, phase='COMPLETE', piloted=False, seated=False,
                 control_enabled=True, guided_complete=True, exit_error=.17,
                 lease=True, parked_exact=True, contract=True, spawn=[0, 0, 0])
        pilot.update(copy.deepcopy(s), 34)
        self.assertEqual(pilot.result['completion_marker'], native.CourierEscapePilot.MARKER)
        self.assertEqual(pilot.result['courier']['terminal']['actor_id'], 11)

    def test_escape_flight_uses_only_normal_thrust_and_brake_and_never_cycles_waypoints(self):
        pilot, s = self.escaping_courier()
        first = pilot.wait_waypoints[0]
        direction = native.unit(native.sub(first, s['position']))
        s['camera'] = s['position'][:]
        s['back'] = [-v for v in direction]
        s['right'] = native.unit([-direction[2], 0, direction[0]])
        right = s['right']
        s['up'] = [right[1]*direction[2]-right[2]*direction[1],
                   right[2]*direction[0]-right[0]*direction[2],
                   right[0]*direction[1]-right[1]*direction[0]]
        s['frame'] += 1
        self.assertEqual(pilot.update(copy.deepcopy(s), 6)[0], {'w'})
        for index, waypoint in enumerate(pilot.wait_waypoints):
            s.update(frame=s['frame']+1, position=waypoint[:], velocity=[0., 0, 0])
            keys, _, _, fire = pilot.update(copy.deepcopy(s), 6)
            self.assertEqual(keys, {'Prior'})
            self.assertFalse(fire)
            self.assertEqual(pilot.wait_waypoint_index, index+1)
        s['frame'] += 1
        self.assertEqual(pilot.update(copy.deepcopy(s), 6), ({'Prior'}, 0, 0, False))
        self.assertEqual(pilot.wait_waypoint_index, 4)
        self.assertEqual(len(pilot.wait_visited), 4)

    def test_escape_flight_rejects_origin_drift_outside_bounds_fire_and_hurt_runner(self):
        for violation in ('origin_drift', 'outside', 'fire', 'hurt_runner'):
            with self.subTest(violation=violation):
                pilot, s = self.escaping_courier()
                if violation == 'origin_drift': s['courier']['scenario_origin'][0] += 1
                if violation == 'outside': s['position'][0] += 450.01
                if violation == 'fire': s['command_fire'] = True
                if violation == 'hurt_runner': s['courier']['health'] = 77.
                s['frame'] += 1
                with self.assertRaises(AssertionError): pilot.update(copy.deepcopy(s), 6)
                self.assertIsNone(pilot.result)

    def test_escape_flight_begins_after_released_second_wound_and_bounds_predispatch(self):
        pilot, s = self.courier_pilot(native.CourierEscapePilot)
        self.assertIsNone(pilot.saved_attack_position)
        self.courier_wound_defender(pilot, s)
        self.assertEqual(len(pilot.defender_wounds), 2)
        self.assertIsNone(pilot.defender_pulse)
        self.assertEqual(pilot.saved_attack_position, s['position'])
        s.update(frame=s['frame']+1, position=[s['position'][0]+450.01, *s['position'][1:]])
        with self.assertRaisesRegex(AssertionError, '450m'):
            pilot.update(copy.deepcopy(s), 6)

    def test_escape_rejects_director_label_without_actual_live_same_runner_at_boundary(self):
        # A forged progress/ESCAPED label must not hide a 1399m position,
        # substituted actor, killed runner, or a different generation.
        for change in ({'position': [0, 8, -1599]}, {'actor_id': 99}, {'generation': 2},
                       {'health': 0.}, {'health': -1.}, {'health': float('nan')},
                       {'escape_origin': [0, 8, -201]}, {'frame': 1}):
            with self.subTest(change=change):
                pilot, s = self.escaping_courier()
                self.runner_reaches_boundary(s)
                s['courier']['terminal'].update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 30)
                self.assertIsNone(pilot.result)

    def test_escape_rejects_premature_outcome_and_defender_loss(self):
        for outcome in ('escaped', 'cleared', 'withdrawn', 'expired', 'aborted'):
            with self.subTest(outcome=outcome):
                pilot, s = self.escaping_courier()
                s['frame'] += 1
                s['courier'].update(outcome=outcome, state='concluded', active=False)
                with self.assertRaises(AssertionError): pilot.update(s, 6)
        for change in ({'opponent_health': 0}, {'opponent_active': False},
                       {'opponent_id': 99}, {'phase': 'RETURN_TO_YARD'}):
            with self.subTest(defender=change):
                pilot, s = self.escaping_courier()
                self.runner_reaches_boundary(s)
                s.update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 30)

    def test_escape_standdown_covers_all_dispatched_actors_and_latches_new_fire_through_home(self):
        for change in ({'active': True}, {'fire_authorized': True}, {'pending_receipts': 1},
                       {'shots_fired': 4}, {'present': False}):
            for stage in ('courier_standdown', 'return'):
                with self.subTest(change=change, stage=stage):
                    pilot, s = self.escaping_courier()
                    # Include a genuine second dispatched actor in the observed
                    # traffic: checking only the runner would miss its violation.
                    escort = dict(s['courier']['actors'][0], id=13)
                    s['courier']['actors'].append(escort)
                    s['courier']['roster_ids'].append(13)
                    s['frame'] += 1
                    pilot.update(copy.deepcopy(s), 6)
                    self.runner_reaches_boundary(s)
                    escort.update(active=False, fire_authorized=False)
                    s['courier']['terminal']['actors'] = copy.deepcopy(s['courier']['actors'])
                    pilot.update(copy.deepcopy(s), 30)
                    pilot.stage = stage
                    s['frame'] += 61
                    s['courier']['actors'][1].update(change)
                    with self.assertRaises(AssertionError): pilot.update(s, 32)
                    self.assertIsNone(pilot.result)
        for mutation in ('lost_actor', 'live_roster', 'latched_fire', 'new_terminal'):
            with self.subTest(mutation=mutation):
                pilot, s = self.escaping_courier()
                self.runner_reaches_boundary(s)
                pilot.update(copy.deepcopy(s), 30)
                s['frame'] += 61
                if mutation == 'lost_actor': s['courier']['actors'] = []
                if mutation == 'live_roster': s['courier']['roster_ids'] = [11]
                if mutation == 'latched_fire': s['courier']['standdown_violation'] = 'fired then ceased'
                if mutation == 'new_terminal': s['courier']['terminal']['frame'] += 1
                with self.assertRaises(AssertionError): pilot.update(s, 32)

    def phase_withdraw_prepared(self, pilot_type=native.CourierWithdrawPhasePilot):
        pilot, s = self.courier_pilot(pilot_type)
        s['courier']['prep_shot'] = dict(present=True, accepted=True, resolved=True,
            source_id=1101, source_entity_id=2,
            request=dict(source_id=1101, source_entity_id=2,
                         weapon_id='torrent_compact_pulse_cannon', sequence=10))
        self.courier_wound_defender(pilot, s)
        s['frame'] += 280
        actor = dict(id=11, present=True, active=True, health=78.,
                     fire_authorized=True, shots_fired=0, pending_receipts=0)
        s['courier'].update(scenario='courier_intercept', generation=1, state='running',
            active=True, seen_alive=True, actors=[actor], roster_ids=[11],
            escape_origin=[0, 8, -200], terminal={}, standdown_violation='',
            main_id=20, authority_id=21, defender_kill={}, maximum_withdraw_radius=0.)
        return pilot, s

    def distance_withdraw_running(self):
        pilot, s = self.phase_withdraw_prepared(native.CourierWithdrawDistancePilot)
        s['courier'].update(escape_heading=[0., 0., -1.], disengaged_elapsed=0., distance_violation='')
        s['courier']['actors'][0]['position'] = s['courier']['position'][:]
        self.assertFalse(pilot.update(copy.deepcopy(s), 5)[3])
        self.assertEqual(pilot.stage, 'courier_distance_out')
        return pilot, s

    def distance_withdraw_terminal(self, pilot, s):
        s.update(frame=s['frame']+1200, position=pilot.withdraw_waypoint[:], velocity=[0., 0., 0.])
        c = s['courier']
        c['actors'][0]['position'] = [0., 8., -1200.]
        c.update(escape_progress=.7, disengaged_elapsed=7.0000000001, elapsed_seconds=20.)
        pending = dict(frame=s['frame']-1, phase='INTERCEPTOR_ENGAGEMENT', state='running', outcome='pending',
            ship_position=s['position'][:], scenario_origin=c['scenario_origin'][:],
            disengaged_elapsed=7.0000000001-1/60, courier_active=True, courier_health=78.,
            defender_active=True, defender_health=17., escape_progress=.7,
            roster_ids=c['roster_ids'][:], actors=copy.deepcopy(c['actors']))
        for actor in c['actors']:
            actor.update(active=False, fire_authorized=False)
        c.update(state='concluded', outcome='withdrawn', active=False, roster_ids=[])
        c['terminal'] = dict(frame=s['frame'], actor_id=11, director_id=10, generation=1,
            position=c['position'][:], escape_origin=c['escape_origin'][:], health=78., escape_progress=.7,
            actors=copy.deepcopy(c['actors']), phase='INTERCEPTOR_ENGAGEMENT', outcome='withdrawn',
            scenario_origin=c['scenario_origin'][:], ship_position=s['position'][:],
            disengaged_elapsed=c['disengaged_elapsed'], pending=pending, defender_active=True, defender_health=17.)

    def test_distance_withdraw_ordinary_out_hold_actual_grace_return_kill_and_strict_home(self):
        pilot, s = self.distance_withdraw_running()
        self.assertEqual(pilot.withdraw_waypoint, [0., 908., -73.])
        self.assertEqual(pilot.saved_attack_position, [0, 8, -73])
        frozen = pilot.withdraw_waypoint[:]
        # Actual grace is checked against every live craft, independently of
        # elapsed route time. No timeout, boost, shooting or moving waypoint.
        s.update(frame=s['frame']+600, position=[0., 750., -73.])
        s['courier'].update(disengaged_elapsed=1., escape_progress=.4)
        s['courier']['actors'][0]['position'] = [0., 8., -800.]
        controls = pilot.update(copy.deepcopy(s), 15)
        self.assertTrue(controls[0] <= {'w', 'Prior'})
        self.assertFalse(controls[3])
        self.assertEqual(pilot.withdraw_waypoint, frozen)
        self.assertIsNone(pilot.courier_withdrawal)
        self.distance_withdraw_terminal(pilot, s)
        pilot.update(copy.deepcopy(s), 25)
        self.assertEqual(pilot.stage, 'courier_distance_standdown')
        s['frame'] += 60
        pilot.update(copy.deepcopy(s), 26)
        self.assertEqual(pilot.stage, 'courier_distance_return')
        self.assertIsNone(pilot.final_fire_frame)
        s.update(frame=s['frame']+1, position=pilot.saved_attack_position[:], velocity=[0., 0., 0.])
        self.assertFalse(pilot.update(copy.deepcopy(s), 27)[3])
        self.assertEqual(pilot.stage, 'interceptor')
        s['frame'] += 1
        self.assertTrue(pilot.update(copy.deepcopy(s), 27.1)[3])
        self.phase_withdraw_kill(s)
        s['courier']['defender_kill'].update(state='concluded', outcome='withdrawn', courier_active=False)
        pilot.update(copy.deepcopy(s), 28)
        self.assertEqual(pilot.stage, 'return_align')
        self.assertEqual(pilot.defender_kill['target_entity_id'], 12)
        pilot.stage = 'exit'
        pilot.phases = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                        'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN']
        s.update(frame=s['frame']+1, phase='DISEMBARKING', piloted=True, seated=True,
                 control_enabled=False, guided_complete=False, lease=True, parked_exact=True, contract=True)
        s['telemetry']['engine'] = 'OFFLINE'
        pilot.update(copy.deepcopy(s), 29)
        self.assertIsNone(pilot.result)
        s.update(frame=s['frame']+1, phase='COMPLETE', piloted=False, seated=False,
                 control_enabled=True, guided_complete=True, exit_error=.17, spawn=[0, 0, 0])
        pilot.update(copy.deepcopy(s), 30)
        self.assertEqual(pilot.result['completion_marker'], native.CourierWithdrawDistancePilot.MARKER)
        self.assertEqual(pilot.result['courier']['terminal']['phase'], 'INTERCEPTOR_ENGAGEMENT')
        self.assertGreater(pilot.result['defender_kill']['frame'], pilot.result['courier']['terminal']['frame'])

    def test_distance_withdraw_rejects_incomplete_geometry_grace_and_other_terminal_causes(self):
        for violation in ('origin_only', 'craft_only', 'short_grace', 'phase', 'escaped', 'expired',
                          'predispatch', 'dead_defender', 'hurt_runner', 'latched_clearance', 'stale_pending'):
            with self.subTest(violation=violation):
                pilot, s = self.distance_withdraw_running()
                self.distance_withdraw_terminal(pilot, s)
                c, t = s['courier'], s['courier']['terminal']
                if violation == 'origin_only':
                    t['pending']['actors'][0]['position'] = s['position'][:]
                if violation == 'craft_only':
                    t['pending']['ship_position'] = pilot.scenario_origin[:]
                if violation == 'short_grace': t['disengaged_elapsed'] = 6.99
                if violation == 'phase': t['phase'] = 'RETURN_TO_YARD'
                if violation == 'escaped': c.update(outcome='escaped', escape_progress=1.)
                if violation == 'expired': c.update(outcome='expired', elapsed_seconds=150.)
                if violation == 'predispatch': t['frame'] = pilot.running_frame
                if violation == 'dead_defender': t['defender_active'] = False
                if violation == 'hurt_runner': c['health'] = 77.
                if violation == 'latched_clearance': c['distance_violation'] = 'transient close actor'
                if violation == 'stale_pending': t['pending']['frame'] -= 1
                with self.assertRaises(AssertionError): pilot.update(copy.deepcopy(s), 30)
                self.assertIsNone(pilot.result)

    def test_distance_withdraw_rejects_live_grace_near_actor_and_tracks_all_standdown_through_return(self):
        pilot, s = self.distance_withdraw_running()
        s.update(frame=s['frame']+600, position=pilot.withdraw_waypoint[:])
        s['courier']['disengaged_elapsed'] = 1.
        s['courier']['actors'][0]['position'] = s['position'][:]
        with self.assertRaisesRegex(AssertionError, 'every active roster'): pilot.update(copy.deepcopy(s), 15)
        for violation in ('active', 'fire_authorized', 'pending_receipts', 'shots_fired', 'present'):
            with self.subTest(violation=violation):
                pilot, s = self.distance_withdraw_running()
                escort = dict(s['courier']['actors'][0], id=13)
                s['courier']['actors'].append(escort)
                s['courier']['roster_ids'].append(13)
                s['frame'] += 1
                pilot.update(copy.deepcopy(s), 5.1)
                self.distance_withdraw_terminal(pilot, s)
                pilot.update(copy.deepcopy(s), 25)
                s['frame'] += 60
                pilot.update(copy.deepcopy(s), 26)
                self.assertEqual(pilot.stage, 'courier_distance_return')
                s['courier']['actors'][1][violation] = False if violation == 'present' else 1
                s['frame'] += 1
                with self.assertRaises(AssertionError): pilot.update(copy.deepcopy(s), 27)
                self.assertIsNone(pilot.result)

    def phase_withdraw_running(self):
        pilot, s = self.phase_withdraw_prepared()
        self.assertEqual(pilot.update(copy.deepcopy(s), 5), ({'Prior'}, 0, 0, False))
        self.assertEqual(pilot.stage, 'courier_withdraw_attack')
        self.assertIsNone(pilot.final_fire_frame)
        s['frame'] += 1
        self.assertTrue(pilot.update(copy.deepcopy(s), 5.1)[3])
        self.assertEqual(pilot.final_fire_frame, s['frame'])
        return pilot, s

    def phase_withdraw_kill(self, s):
        s.update(frame=s['frame']+1, phase='RETURN_TO_YARD', opponent_active=False,
                 opponent_health=0., command_fire=True, shot_accepted=True)
        c = s['courier']
        c['defender_kill'] = dict(present=True, accepted=True, resolved=True,
            hit=True, damaged=True, destroyed=True, status='destroyed',
            source_id=1101, source_entity_id=2, target_entity_id=12,
            damageable_id=30, collider_id=31, applied_damage=34., remaining_health=0.,
            request=dict(source_id=1101, source_entity_id=2,
                         weapon_id='torrent_compact_pulse_cannon', sequence=11),
            frame=s['frame'], main_id=20, authority_id=21, director_id=10,
            actor_id=11, generation=1, last_sequence=11, command_fire=True,
            phase='RETURN_TO_YARD', state='running', outcome='pending',
            courier_active=True, courier_health=78., courier_maximum_health=78.,
            escape_progress=.01, scenario_origin=c['scenario_origin'][:],
            ship_position=s['position'][:])
        c['escape_progress'] = .01

    def phase_withdraw_terminal(self, s):
        s.update(frame=s['frame']+1, command_fire=False)
        c = s['courier']
        for actor in c['actors']:
            actor.update(active=False, fire_authorized=False, pending_receipts=0)
        c.update(state='concluded', outcome='withdrawn', active=False, roster_ids=[])
        c['terminal'] = dict(frame=s['frame'], actor_id=11, director_id=10, generation=1,
            position=c['position'][:], escape_origin=c['escape_origin'][:], health=78.,
            escape_progress=.01, actors=copy.deepcopy(c['actors']), phase='RETURN_TO_YARD',
            outcome='withdrawn', scenario_origin=c['scenario_origin'][:], ship_position=s['position'][:])

    def test_phase_withdraw_requires_fresh_kill_then_withdrawal_standdown_and_strict_home(self):
        pilot, s = self.phase_withdraw_running()
        self.phase_withdraw_kill(s)
        self.assertFalse(pilot.update(copy.deepcopy(s), 6)[3])
        self.assertIsNone(pilot.courier_withdrawal)
        self.phase_withdraw_terminal(s)
        self.assertEqual(pilot.update(copy.deepcopy(s), 6.1), ({'Prior'}, 0, 0, False))
        self.assertEqual(pilot.stage, 'courier_withdraw_standdown')
        self.assertIsNone(pilot.result)
        s['frame'] += 59
        pilot.update(copy.deepcopy(s), 7)
        self.assertEqual(pilot.stage, 'courier_withdraw_standdown')
        s['frame'] += 1
        pilot.update(copy.deepcopy(s), 7.1)
        self.assertEqual(pilot.stage, 'return_align')
        self.assertIsNone(pilot.result)
        # The original strict-home controller remains the only success seam.
        pilot.stage = 'exit'
        pilot.phases = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                        'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN']
        # Real GameFlow awaits canopy and avatar motion in DISEMBARKING.
        # The actor remains seated initially; this interval is not completion.
        s.update(frame=s['frame']+1, phase='DISEMBARKING', piloted=True, seated=True,
                 control_enabled=False, guided_complete=False,
                 lease=True, parked_exact=True, contract=True)
        s['telemetry']['engine'] = 'OFFLINE'
        self.assertFalse(pilot.update(copy.deepcopy(s), 7.2)[3])
        self.assertEqual(pilot.stage, 'exit')
        self.assertIsNone(pilot.result)
        s.update(frame=s['frame']+1, phase='COMPLETE', piloted=False, seated=False,
                 control_enabled=True, guided_complete=True, exit_error=.17,
                 lease=True, parked_exact=True, contract=True, spawn=[0, 0, 0])
        pilot.update(copy.deepcopy(s), 8)
        self.assertEqual(pilot.result['completion_marker'], native.CourierWithdrawPhasePilot.MARKER)
        self.assertEqual(pilot.result['defender_kill']['target_entity_id'], 12)
        self.assertEqual(pilot.result['courier']['terminal']['outcome'], 'withdrawn')
        self.assertEqual(pilot.result['courier_dispatch']['opponent_health'], 17.)
        self.assertGreaterEqual(pilot.result['standdown_observed_frames'], 60)

    def test_phase_withdraw_rejects_predispatch_kill_and_nonfirst_dispatch(self):
        for change in ({'opponent_active': False}, {'opponent_health': 0.},
                       {'phase': 'RETURN_TO_YARD'}):
            with self.subTest(change=change):
                pilot, s = self.phase_withdraw_prepared()
                s.update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 5)
        for change in ({'generation': 2}, {'defender_kill': {'frame': 1}},
                       {'health': 77.}, {'active': False}, {'outcome': 'withdrawn'}):
            with self.subTest(dispatch=change):
                pilot, s = self.phase_withdraw_prepared()
                s['courier'].update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 5)

    def test_phase_withdraw_rejects_missing_wrong_stale_or_nonlethal_authority_receipt(self):
        mutations = [dict(source_id=99), dict(source_entity_id=99), dict(target_entity_id=11),
            dict(generation=2), dict(main_id=99), dict(authority_id=99), dict(director_id=99),
            dict(actor_id=99), dict(frame=1), dict(last_sequence=10), dict(command_fire=False),
            dict(accepted=False), dict(resolved=False), dict(damaged=False), dict(destroyed=False),
            dict(remaining_health=1.), dict(applied_damage=0.), dict(courier_active=False),
            dict(courier_health=77.), dict(escape_progress=1.), dict(outcome='withdrawn'),
            dict(state='concluded'), dict(phase='INTERCEPTOR_ENGAGEMENT')]
        for change in mutations:
            with self.subTest(change=change):
                pilot, s = self.phase_withdraw_running()
                self.phase_withdraw_kill(s)
                s['courier']['defender_kill'].update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 6)
                self.assertIsNone(pilot.result)
        for change in ({'sequence': 10}, {'weapon_id': 'range_pulse_cannon'},
                       {'source_id': 99}, {'source_entity_id': 99}):
            with self.subTest(request=change):
                pilot, s = self.phase_withdraw_running()
                self.phase_withdraw_kill(s)
                s['courier']['defender_kill']['request'].update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 6)
        pilot, s = self.phase_withdraw_running()
        self.phase_withdraw_kill(s)
        s['courier']['defender_kill'] = {}
        with self.assertRaises(AssertionError): pilot.update(s, 6)

    def test_phase_withdraw_rejects_escape_distance_and_other_terminal_substitutes(self):
        for outcome in ('escaped', 'cleared', 'expired', 'aborted', 'lost'):
            with self.subTest(outcome=outcome):
                pilot, s = self.phase_withdraw_running()
                self.phase_withdraw_kill(s)
                self.phase_withdraw_terminal(s)
                s['courier']['outcome'] = outcome
                with self.assertRaises(AssertionError): pilot.update(s, 6)
        for mutation in ('position', 'all_frames_radius', 'origin', 'hurt', 'progress', 'terminal_phase'):
            with self.subTest(mutation=mutation):
                pilot, s = self.phase_withdraw_running()
                self.phase_withdraw_kill(s)
                self.phase_withdraw_terminal(s)
                c = s['courier']
                if mutation == 'position': s['position'][0] += 450.01
                if mutation == 'all_frames_radius': c['maximum_withdraw_radius'] = 450.01
                if mutation == 'origin': c['scenario_origin'][0] += 1
                if mutation == 'hurt': c['health'] = 77.
                if mutation == 'progress': c['escape_progress'] = 1.
                if mutation == 'terminal_phase': c['terminal']['phase'] = 'INTERCEPTOR_ENGAGEMENT'
                with self.assertRaises(AssertionError): pilot.update(s, 6)

    def test_phase_withdraw_standdown_covers_all_actual_actors_through_home(self):
        for change in ({'active': True}, {'fire_authorized': True}, {'pending_receipts': 1},
                       {'shots_fired': 1}, {'present': False}):
            for stage in ('courier_withdraw_standdown', 'return'):
                with self.subTest(change=change, stage=stage):
                    pilot, s = self.phase_withdraw_running()
                    s['courier']['actors'].append(dict(s['courier']['actors'][0], id=13))
                    s['courier']['roster_ids'].append(13)
                    s['frame'] += 1
                    pilot.update(copy.deepcopy(s), 5.2)
                    self.phase_withdraw_kill(s)
                    self.phase_withdraw_terminal(s)
                    pilot.update(copy.deepcopy(s), 6)
                    self.assertEqual(pilot.dispatched_ids, {11, 13})
                    pilot.stage = stage
                    s['frame'] += 1
                    s['courier']['actors'][1].update(change)
                    with self.assertRaises(AssertionError): pilot.update(s, 6.1)
        for mutation in ('lost_actor', 'live_roster', 'latched_fire', 'new_terminal', 'new_kill'):
            with self.subTest(mutation=mutation):
                pilot, s = self.phase_withdraw_running()
                self.phase_withdraw_kill(s)
                self.phase_withdraw_terminal(s)
                pilot.update(copy.deepcopy(s), 6)
                s['frame'] += 1
                if mutation == 'lost_actor': s['courier']['actors'] = []
                if mutation == 'live_roster': s['courier']['roster_ids'] = [11]
                if mutation == 'latched_fire': s['courier']['standdown_violation'] = 'fired then ceased'
                if mutation == 'new_terminal': s['courier']['terminal']['frame'] += 1
                if mutation == 'new_kill': s['courier']['defender_kill']['frame'] += 1
                with self.assertRaises(AssertionError): pilot.update(s, 6.1)

    def test_phase_withdraw_keeps_original_strict_occupied_offline_physical_exit_gate(self):
        for change in ({'lease': False}, {'parked_exact': False}, {'contract': False},
                       {'exit_error': .3}, {'piloted': True}, {'seated': True},
                       {'control_enabled': False}, {'guided_complete': False}, {'engine': 'ONLINE'}):
            with self.subTest(change=change):
                pilot, s = self.phase_withdraw_running()
                self.phase_withdraw_kill(s)
                self.phase_withdraw_terminal(s)
                pilot.update(copy.deepcopy(s), 6)
                pilot.stage = 'exit'
                pilot.phases = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                                'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN']
                s.update(frame=s['frame']+61, phase='COMPLETE', piloted=False, seated=False,
                         control_enabled=True, guided_complete=True, exit_error=.17,
                         lease=True, parked_exact=True, contract=True, spawn=[0, 0, 0])
                s['telemetry']['engine'] = 'OFFLINE'
                if 'engine' in change: s['telemetry'].update(change)
                else: s.update(change)
                with self.assertRaises(AssertionError): pilot.update(s, 8)
                self.assertIsNone(pilot.result)

    def test_phase_withdraw_has_no_boost_chase_or_final_fire_before_observed_dispatch(self):
        pilot, s = self.phase_withdraw_prepared()
        self.assertFalse(pilot.update(copy.deepcopy(s), 5)[3])
        s['frame'] += 1
        s['courier']['weapon_ready'] = False
        keys, _, _, fire = pilot.update(copy.deepcopy(s), 5.1)
        self.assertEqual(keys, {'Prior'})
        self.assertFalse(fire)
        self.assertIsNone(pilot.final_fire_frame)
        s['frame'] += 1
        s['courier']['weapon_ready'] = True
        keys, _, _, fire = pilot.update(copy.deepcopy(s), 5.2)
        self.assertEqual(keys, {'Prior'})
        self.assertTrue(fire)
        self.assertGreater(pilot.final_fire_frame, pilot.running_frame)

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


class HeavyBreachCallerTests(unittest.TestCase):
    """Focused caller/decoder fixtures; the full game must prove the sortie."""
    @staticmethod
    def sample(n=10, fire=False):
        return dict(mode='heavy-breach', sequence=n, frame=n, pid=1, main_id=2, player_id=3,
            ship_id=4, source_id=5, input_stream=6, command_stream=6, command_sequence=n,
            paused=False, destroyed=False, transition_busy=False, phase='FREE_FLIGHT',
            actors_current=True, piloted=True, seated=True, seated_at_pilot=True, active_ship=True,
            default_sampler=True, source_enabled=True, application_focused=True, mouse_captured=True,
            weapon_source=1102, native_fire=fire, command_fire=fire, native_interact=False,
            player=[0, 0, 0], position=[-60, 1, 15], ship_velocity=[0, 0, 0],
            camera=[-65, 3, 15], camera_back=[math.sin(n*.01), 0, math.cos(n*.01)],
            target=dict(id=20, generation=7, source_id=2102, active=True, health=60,
                        destroyed=False, aim=[-90, 30, 40]),
            breach=dict(board_id=30, director_id=31, objective_id=32,
                board=dict(director=dict(scenario='heavy_breach', state='running', outcome='pending',
                    elapsed=10, scenario_generation=8, bounds=dict(scenario_time_limit=150)),
                    reward_handoff=dict(highest_reward_generation=8, pending_reward_generation=0))),
            fire_gate=dict(frame=n, ship_id=4, target_id=20, clear=True, weapon=dict(ready=True)))

    def pressing(self):
        control = native.BreachFireControl()
        self.assertFalse(control.step(self.sample(10), True))
        self.assertFalse(control.step(self.sample(11), True))
        self.assertTrue(control.step(self.sample(12), True))
        return control

    def test_short_forecast_window_waits_for_consumed_press_and_release(self):
        control = self.pressing()
        self.assertTrue(control.step(self.sample(13), False))
        stale = self.sample(14, True); stale['command_sequence'] = 12
        self.assertTrue(control.step(stale, False))
        self.assertFalse(control.step(self.sample(15, True), False))
        self.assertFalse(control.step(self.sample(16, True), True))
        self.assertFalse(control.step(self.sample(17), True))
        self.assertTrue(control.step(self.sample(18), True))
        self.assertEqual([r['action'] for r in control.receipts],
                         ['released', 'requested', 'consumed', 'released', 'requested'])

    def test_focus_owner_stream_target_generation_and_deadline_release(self):
        mutations = [lambda s: s.update(application_focused=False),
                     lambda s: s.update(source_enabled=False), lambda s: s.update(piloted=False),
                     lambda s: s.update(paused=True), lambda s: s.update(ship_id=40),
                     lambda s: s.update(source_id=50), lambda s: s.update(input_stream=7),
                     lambda s: s['target'].update(generation=9),
                     lambda s: s['target'].update(active=False),
                     lambda s: s['target'].update(health=0),
                     lambda s: s['breach']['board']['director'].update(scenario_generation=9),
                     lambda s: s['breach']['board']['director'].update(elapsed=150)]
        for change in mutations:
            with self.subTest(change=change):
                control = self.pressing(); sample = self.sample(13); change(sample)
                self.assertFalse(control.step(sample, True))
                self.assertFalse(any(r['action'] == 'consumed' for r in control.receipts))

    def test_pending_fire_keeps_current_aim_without_turning_forecast_into_a_hit(self):
        pilot = native.HeavyBreachPilot(); pilot.stage = 'fight'
        pilot.launched = pilot.charge = dict(frame=1)
        with patch.object(pilot, 'weapon_aim', return_value=(7, -4, .9999770180378582)):
            for n in (10, 11, 12, 13, 14):
                sample = self.sample(n, fire=(n == 14))
                sample['fire_gate']['clear'] = n <= 12
                pilot.last_state = sample
                keys, dx, dy, fire = pilot.update(sample, 100+n/60)
                self.assertEqual((dx, dy), (7, -4))
                self.assertEqual(fire, n in (12, 13))
        self.assertIsNone(pilot.kill)
        self.assertIsNone(pilot.paid)

    @staticmethod
    def shot(terminal=False):
        return dict(present=True, source_id=1102, source_entity_id=4, accepted=True, resolved=True,
            request=dict(source_id=1102, source_entity_id=4, weapon_id='arrow_precision_recon_emitter',
                         range=480, damage=24, sequence=0, presentation_receipt_id=50,
                         origin=[0, 0, 0], direction=[0, 0, -1]),
            status='damaged' if terminal else 'miss', impact=[0, 0, -10] if terminal else [math.inf]*3,
            collider=dict(id=21, path='/picket') if terminal else dict(id=0, path=''),
            target_entity_id=20 if terminal else 0, damageable_id=22 if terminal else 0,
            applied_damage=24 if terminal else 0, damaged=terminal, destroyed=terminal,
            remaining_health=0 if terminal else -1,
            damage_result=dict(accepted=terminal, health=0 if terminal else -1, destroyed=terminal))

    def test_only_real_terminal_picket_damage_is_a_kill_not_a_miss_or_consumed_input(self):
        pilot = native.HeavyBreachPilot(); pilot.departure = dict(frame=1)
        sample = self.sample(); sample['shot'] = self.shot()
        pilot.observe_shot(sample); self.assertIsNone(pilot.kill)
        pilot = native.HeavyBreachPilot(); pilot.departure = pilot.launched = pilot.charge = dict(frame=1)
        sample['shot'] = self.shot(True); sample['target'].update(health=0, destroyed=True)
        pilot.observe_shot(sample)
        self.assertEqual(pilot.kill['shot']['remaining_health'], 0)
        self.assertIsNone(pilot.paid)
        for changes in (dict(source_id=1103), dict(target_entity_id=99), dict(damaged=False)):
            with self.subTest(changes=changes):
                p = native.HeavyBreachPilot(); p.departure = p.launched = p.charge = dict(frame=1)
                sample['shot'] = self.shot(True); sample['shot'].update(changes)
                if 'source_id' in changes:
                    with self.assertRaises(AssertionError): p.observe_shot(sample)
                else: p.observe_shot(sample)
                self.assertIsNone(p.kill)

    def test_malformed_miss_and_contact_without_actual_collider_are_refused(self):
        for change in (dict(impact=[0, 0, 0]), dict(damaged=True), dict(applied_damage=24),
                       dict(status='world_blocked', impact=[0, 0, -10])):
            with self.subTest(change=change):
                pilot = native.HeavyBreachPilot(); pilot.departure = dict(frame=1)
                sample = self.sample(); sample['shot'] = self.shot(); sample['shot'].update(change)
                with self.assertRaises(AssertionError): pilot.observe_shot(sample)
                self.assertIsNone(pilot.kill)

    @staticmethod
    def paid_sample():
        s = HeavyBreachCallerTests.sample()
        s['settlement'] = dict(record=dict(receipt_serial=1, total_receipts=1,
            reward_counts={'return_heavy_breach_credit': 1}, last_receipt=dict(receipt_id=1,
            activity_id='shipyard_heavy_breach', reward_id='return_heavy_breach_credit',
            activity_generation=8, granted=True, replay_allowed=False)))
        return s

    def test_payment_requires_exact_heavy_identity_single_receipt_and_board_acknowledgement(self):
        sample = self.paid_sample(); native.HeavyBreachPilot.require_paid(sample)
        for mutate in (lambda s: s['settlement']['record'].update(total_receipts=2),
                       lambda s: s['settlement']['record']['last_receipt'].update(activity_id='shipyard_torpedo_run'),
                       lambda s: s['settlement']['record']['last_receipt'].update(replay_allowed=True),
                       lambda s: s['breach']['board']['reward_handoff'].update(pending_reward_generation=8),
                       lambda s: s['breach']['board']['director'].update(scenario_generation=9)):
            with self.subTest(mutate=mutate):
                bad = self.paid_sample(); mutate(bad)
                with self.assertRaises(AssertionError): native.HeavyBreachPilot.require_paid(bad)

    def test_physical_arm_uses_actual_candidate_and_three_dimensional_margin(self):
        for distance, candidate, expected in ((2.5, True, True), (2.9, True, False), (2.5, False, False)):
            pilot = native.HeavyBreachPilot(); pilot.stage = 'walk_board'
            sample = self.sample(); sample.update(phase='APPROACH_SHIP', seated=False, seated_at_pilot=False, active_ship=False, piloted=False,
                velocity=[0, 0, 0], walk_forward=[0, 0, -1], station_seated=False,
                game_station_seated=False, sleeping=False, control_enabled=True, capsule_enabled=True,
                grounded=True, supported=True, support_collider='/floor')
            sample['breach'].update(candidate=candidate, distance=distance, facing=1,
                position=[8, 1, -26], available=dict(available=True))
            sample['breach']['board']['offered_scenario'] = 'heavy_breach'
            pilot.last_state = sample
            with patch.object(pilot, 'yaw_to', return_value=(0, 0, 1)):
                keys, _, _, fire = pilot.update(sample, 100)
            self.assertEqual('e' in keys, expected)
            self.assertFalse(fire)
            self.assertIsNone(pilot.armed)

    def test_actual_file_consumer_rejects_mismatched_committed_terminal(self):
        with tempfile.TemporaryDirectory() as tmp:
            profile = Path(tmp)/'profile'; data = profile/'data'; data.mkdir(parents=True)
            output = Path(tmp)/'out'; output.mkdir()
            path = data/'mudds_user_data.json'; sample = self.paid_sample()
            sample['settlement']['store'] = dict(path=str(path), source='primary', generation=2)
            completion = dict(activity_id='shipyard_heavy_breach', scenario='heavy_breach',
                              outcome='cleared', reward_granted=True, generation=8)
            document = dict(schema_version=1, generation=2, commit=dict(id='fixture'),
                payload=dict(game_flow_reward_store=sample['settlement']['record'],
                             heavy_breach_session=dict(session=dict(completion=completion))))
            path.write_text(json.dumps(document)); pilot = native.HeavyBreachPilot(); pilot.paid = dict(frame=1)
            files = native.HeavyBreachFiles(profile, output); files.observe(sample, pilot)
            self.assertEqual(files.snapshots['paid']['document']['payload'], document['payload'])
            document['payload']['heavy_breach_session']['session']['completion']['generation'] = 9
            path.write_text(json.dumps(document)); files = native.HeavyBreachFiles(profile, output)
            with self.assertRaises(AssertionError): files.observe(sample, pilot)


class RetainedHeavyCallerTests(unittest.TestCase):
    """Retained reader/ordinary-input boundaries; no engine or display launch."""
    @staticmethod
    def document():
        return dict(schema_version=1, generation=19, commit=dict(id='actual-fixture'), payload=dict(
            runtime_settings=dict(schema_version=11, values=dict(camera_fov=72)),
            game_flow_reward_store=dict(receipt_serial=1, total_receipts=1,
                reward_counts={'return_heavy_breach_credit': 1}, last_receipt=dict(receipt_id=1,
                    activity_id='shipyard_heavy_breach', reward_id='return_heavy_breach_credit',
                    activity_generation=1, granted=True, replay_allowed=False)),
            heavy_breach_session=dict(session=dict(generation_floor=1, offered_index=1,
                completion=dict(activity_id='shipyard_heavy_breach', scenario='heavy_breach',
                    state_id='concluded', outcome='cleared', generation=1, reward_granted=True))),
            solo_safe_recovery=dict(mode='on_foot', craft_id='arrow_provisional',
                berth_id='arrow_recon_berth', location='mudds_home_berth'),
            crash_recovery=dict(state='clean', session_id=1, startup_generation=1, unclean_start_count=0),
            safe_start_recovery=dict(state='clean_shutdown', startup_generation=1,
                consecutive_failure_count=0, safe_settings_recommended=False),
            session_diagnostics=dict(events=[dict(event_code='session_ended', session_id=1)]),
            tutorial_prompts_seen=dict(schema_version=1, seen_ids=['shipyard_heavy_breach'])))

    @classmethod
    def sample(cls, n=1):
        s = HeavyBreachCallerTests.sample(n)
        s.update(pid=1, main_id=2, world_id=3, player_id=4, capsule_id=5, shape_id=6,
            ship_id=7, berth_id=8, seat_id=9, source_id=10, phase='INTRO', menu_ready=True,
            spawn=[-8.5, .18, 11], player=[-8.5, .18, 11], velocity=[0, 0, 0],
            piloted=False, seated=False, seated_at_pilot=False, active_ship=False, remote_piloted=False,
            station_seated=False, game_station_seated=False, sleeping=False, control_enabled=False,
            capsule_enabled=True, grounded=True, supported=True, support_collider='/actual-floor',
            native_fire=False, command_fire=False, guided_complete=False, default_controls=True,
            tuning_unchanged=True, ship_tuning=dict(mouse=.001),
            walk_tuning=copy.deepcopy(native.RetainedHeavyPilot.DEFAULT_WALK), physics_ticks=60, time_scale=1,
            walk_forward=[0, 0, -1], walk_right=[1, 0, 0],
            native_keys=dict(escape=False, tab=False, **{'return': False}))
        s['completed_motion'] = dict(frame=n, start=s['player'][:], end=s['player'][:], step_up={})
        s['settlement'] = dict(record=cls.document()['payload']['game_flow_reward_store'],
                              store=dict(path='/owned/mudds_user_data.json', source='primary', generation=20))
        s['breach'].update(position=[8, 1, -26], objective_position=[24, 1, -26],
                           candidate=True, distance=2.1, facing=1,
                           available=dict(available=True), prompt='[ E ] ARM TORPEDO RUN SORTIE')
        s['breach']['board'].update(offered_scenario='torpedo_run', sortie_armed=False, active_director_generation=0)
        s['breach']['board']['director'].update(state='idle', scenario_generation=0)
        s['breach']['board']['reward_handoff'].update(highest_reward_generation=1, pending_reward_generation=0)
        return s

    def pilot(self):
        p = native.RetainedHeavyPilot(self.document(), 1); s = self.sample()
        p.validate_observation(s)
        return p, s

    @staticmethod
    def tick(p, s, **changes):
        start = s['player'][:]
        s.update(frame=s['frame']+1, sequence=s['sequence']+1, **changes)
        s['completed_motion'] = dict(frame=s['frame'], start=start, end=s['player'][:], step_up={})
        p.validate_observation(s)
        return p.update(s, 100+s['frame']/60)

    def walking(self):
        p, s = self.pilot()
        self.assertEqual(p.update(s, 100), (set(), 0, 0, False))
        p.file_context_accepted = True
        self.assertIn('e', self.tick(p, s)[0])
        self.tick(p, s, phase='APPROACH_SHIP', menu_ready=False, native_interact=True, control_enabled=True)
        self.assertEqual(p.stage, 'walk_next')
        return p, s

    def at_posting(self):
        p, s = self.walking()
        while p.route:
            target = p.route[0]
            off = native.sub(target, s['player']); distance = native.norm(off)
            point = [a+b*min(1, .15/distance) for a,b in zip(s['player'], off)] if distance else target[:]
            direction = native.unit([off[0], 0, off[2]]) if distance else [0, 0, -1]
            self.tick(p, s, player=point, native_interact=False, walk_forward=direction,
                      walk_right=[-direction[2], 0, direction[0]])
        self.tick(p, s, native_interact=False, walk_forward=[0, 0, -1], walk_right=[1, 0, 0])
        self.assertEqual(p.stage, 'pause')
        return p, s

    def test_retained_cold_director_and_decoded_ledger_are_independent_of_old_combat_generation(self):
        p, s = self.pilot()
        self.assertEqual(s['breach']['board']['director']['scenario_generation'], 0)
        self.assertEqual(s['settlement']['record']['last_receipt']['activity_generation'], 1)
        for mutate in (lambda x: x.update(pid=999), lambda x: x.update(player_id=999),
                       lambda x: x['settlement']['record'].update(total_receipts=2),
                       lambda x: x['settlement']['record']['last_receipt'].update(replay_allowed=True),
                       lambda x: x['breach']['board'].update(sortie_armed=True),
                       lambda x: x['breach']['board'].update(offered_scenario='heavy_breach'),
                       lambda x: x['breach']['board']['director'].update(state='running'),
                       lambda x: x['breach']['board']['reward_handoff'].update(pending_reward_generation=1)):
            with self.subTest(mutate=mutate):
                p, s = self.pilot(); bad = copy.deepcopy(s)
                bad.update(frame=2, sequence=2); mutate(bad)
                with self.assertRaises(AssertionError): p.validate_observation(bad)

    def test_retained_route_uses_three_supported_waypoints_without_arming_and_requires_ui_os0(self):
        p, s = self.at_posting()
        self.assertEqual([v['point'] for v in p.visited], [list(v) for v in p.WAYPOINTS])
        self.assertGreater(p.walked, 10)
        self.assertEqual(len([e for e in p.native_edges if e['pressed']]), 1)
        with self.assertRaises(AssertionError): p.finish(0)
        self.assertEqual(self.tick(p, s)[0], {'Escape'})
        ui = dict(main_visible=True, exit_visible=True, exit_enabled=True,
                  exit_text='EXIT TO DESKTOP', exit_path='/pause/ExitButton', focus_is_exit=True,
                  focus_path='/pause/ExitButton')
        # Let the existing UI key hold and release finish before actual Return.
        self.tick(p, s, paused=True, ui=ui)
        for _ in range(20): self.tick(p, s)
        self.assertTrue(p.quit_requested)
        self.assertIn('exit_ui', p.receipts)
        with self.assertRaises(AssertionError): p.finish(1)
        p.finish(0)
        self.assertEqual(p.result['completion_marker'], 'NATIVE_RETAINED_HEAVY_OK')

    def test_retained_walk_refuses_missing_support_motion_gap_and_nonordinary_controls(self):
        for change in (dict(supported=False), dict(capsule_enabled=False), dict(control_enabled=False),
                       dict(default_controls=False), dict(native_fire=True), dict(piloted=True),
                       dict(player=[0, 20, 0])):
            with self.subTest(change=change):
                p, s = self.walking()
                with self.assertRaises(AssertionError): self.tick(p, s, **change)
        p, s = self.walking()
        s.update(frame=s['frame']+1, sequence=s['sequence']+2)
        with self.assertRaises(AssertionError): p.validate_observation(s)

    def fixture_files(self, root, session=1):
        profile = root/'profile'; profile.mkdir(); (profile/'data').mkdir()
        output = root/'output'; output.mkdir()
        document = self.document()
        document['generation'] = 19 if session == 1 else 27
        document['payload']['crash_recovery'].update(session_id=session, startup_generation=session)
        document['payload']['safe_start_recovery']['startup_generation'] = session
        document['payload']['session_diagnostics']['events'][0]['session_id'] = session
        fixture = root/'input.json'; raw = json.dumps(document).encode(); fixture.write_bytes(raw)
        with patch.object(native.RetainedHeavyFiles, 'FIXTURES', {(len(raw), hashlib.sha256(raw).hexdigest())}):
            files = native.RetainedHeavyFiles(profile, output, fixture)
        return files, fixture, raw

    def test_retained_seed_is_exact_private_input_and_invalid_fixture_is_refused_before_launch(self):
        with tempfile.TemporaryDirectory() as tmp:
            files, fixture, raw = self.fixture_files(Path(tmp))
            self.assertEqual(files.path, files.profile/native.RetainedHeavyFiles.RELATIVE_SAVE)
            self.assertEqual(files.path.read_bytes(), raw)
            self.assertEqual(fixture.read_bytes(), raw)
            self.assertEqual(files.path.stat().st_mode & 0o777, 0o644)
            with self.assertRaisesRegex(AssertionError, 'exact accepted'):
                native.RetainedHeavyFiles(files.profile, files.output, fixture)

    def loaded_document(self, files):
        document = copy.deepcopy(files.expected); document['generation'] += 1
        session = files.expected['payload']['crash_recovery']['session_id'] + 1
        document['commit'] = dict(id='production-startup')
        document['payload']['crash_recovery'].update(state='running', session_id=session, startup_generation=session)
        document['payload']['safe_start_recovery'].update(state='starting', startup_generation=session)
        document['payload']['session_diagnostics']['events'].append(
            dict(event_code='session_started', session_id=session, fields=dict(recovered=False)))
        return document

    def test_retained_inputs_are_exactly_the_two_declared_raw_fixture_identities(self):
        self.assertEqual(native.RetainedHeavyFiles.FIXTURES, {
            (8655, '25f9ccfe03b22018eae2cffcb52841ed5fbcff3f4a51a6c020e6c7495701aa73'),
            (9296, 'af2fada0a687b3a2dad6ee5c4550d4e6cd92120f2df94f6681f053e5b23ed409'),
        })

    def test_retained_both_inputs_require_exact_next_session_startup_and_matching_diagnostic(self):
        for session in (1, 2):
            with self.subTest(input_session=session), tempfile.TemporaryDirectory() as tmp:
                files, _, _ = self.fixture_files(Path(tmp), session)
                document = self.loaded_document(files); sample = self.sample()
                sample['settlement']['store']['generation'] = document['generation']
                files.require_loaded(document, sample)
                self.assertEqual(document['payload']['crash_recovery']['session_id'], session + 1)
                for counter in (session, session + 2):
                    for section, field in (('crash_recovery', 'session_id'),
                                           ('crash_recovery', 'startup_generation'),
                                           ('safe_start_recovery', 'startup_generation')):
                        bad = copy.deepcopy(document); bad['payload'][section][field] = counter
                        with self.subTest(section=section, field=field, counter=counter), self.assertRaises(AssertionError):
                            files.require_loaded(bad, sample)
                    bad = copy.deepcopy(document)
                    bad['payload']['session_diagnostics']['events'][-1]['session_id'] = counter
                    with self.subTest(diagnostic_session=counter), self.assertRaises(AssertionError):
                        files.require_loaded(bad, sample)

    def test_retained_actual_primary_loaded_state_and_clean_shutdown_preserve_all_protected_siblings(self):
        with tempfile.TemporaryDirectory() as tmp:
            files, fixture, raw = self.fixture_files(Path(tmp)); document = self.loaded_document(files)
            p = native.RetainedHeavyPilot(files.expected, 1); s = self.sample()
            s['settlement']['store']['path'] = str(files.path)
            files.path.write_text(json.dumps(document)); files.observe(s, p)
            self.assertTrue(p.file_context_accepted)
            p.next_posting = dict(frame=10); s['menu_ready'] = False; files.observe(s, p)
            for key in ('runtime_settings', 'game_flow_reward_store', 'heavy_breach_session', 'tutorial_prompts_seen'):
                bad = copy.deepcopy(document); bad['payload'][key] = {}
                with self.subTest(key=key), self.assertRaises(AssertionError): files.require_retained(bad)
            for mutate in (lambda d: d['payload']['crash_recovery'].update(unclean_start_count=1),
                           lambda d: d['payload']['crash_recovery'].update(session_id=1),
                           lambda d: d['payload']['safe_start_recovery'].update(safe_settings_recommended=True),
                           lambda d: d.update(generation=19)):
                bad = copy.deepcopy(document); mutate(bad)
                with self.subTest(mutate=mutate), self.assertRaises(AssertionError): files.require_loaded(bad, s)
            bad = copy.deepcopy(s); bad['settlement']['store']['source'] = 'backup'
            with self.assertRaises(AssertionError): files.capture('refused-backup', bad['settlement']['store'])
            document['generation'] = 21; document['payload']['crash_recovery']['state'] = 'clean'
            document['payload']['safe_start_recovery']['state'] = 'clean_shutdown'
            document['payload']['session_diagnostics']['events'].append(dict(event_code='session_ended', session_id=2))
            files.path.write_text(json.dumps(document)); files.finish()
            self.assertEqual(fixture.read_bytes(), raw)
            self.assertEqual(files.snapshots['orderly-close']['document']['payload']['runtime_settings'],
                             files.expected['payload']['runtime_settings'])

    def test_retained_data_flag_is_route_exclusive_at_cli_and_direct_api(self):
        for route, fixture in [('guided', Path('/input')), ('retained-heavy', None)]:
            with self.subTest(route=route):
                with self.assertRaises(AssertionError): native.run(Path('/game'), Path('/unused'), route, retained_data=fixture)
                argv = ['run_native_sortie.py', '/game', '--output', '/unused', '--route', route]
                if fixture is not None: argv.extend(['--retained-data', str(fixture)])
                with patch.object(sys, 'argv', argv), patch.object(native, 'validate_binary') as binary, \
                        patch.object(native.subprocess, 'Popen') as launch:
                    with self.assertRaises(SystemExit) as error: native.main()
                    self.assertEqual(error.exception.code, 2)
                    binary.assert_not_called(); launch.assert_not_called()


class RaceHomeCallerTests(unittest.TestCase):
    """Caller rejection fixtures; only an actual package can prove the journey."""
    @staticmethod
    def sample(frame=1, state='idle', cursor=0):
        generation = int(state != 'idle')
        snapshot = dict(activity_id=native.RaceHomePilot.ACTIVITY, attached=True, closed=False,
            state_id=state, session_generation=generation, activity_generation=generation,
            race_generation=generation, penalty_seconds=0, failure_reason='',
            countdown_remaining_seconds=2 if state == 'countdown' else 0,
            next_checkpoint_index=cursor, current_time_seconds=0,
            last_time_seconds=-1, progress_unitless=cursor/5)
        home = dict(berth_id='central_berth', berth_instance_id=11, berth_parent_id=12,
            capsule_id=13, shape_id=14, range_staging=[0, 8, -78],
            range_clearance=[0, 2.7, -150], range_clearance_exit=[0, 2.7, -100],
            approach=[0, 2, -18], dock=[0, 0, 0], walk_tuning=dict(walk=4, sprint=7))
        return dict(mode='race-home', sequence=frame, frame=frame, pid=1, main_id=2,
            player_id=3, ship_id=4, paused=False, default_sampler=True, tuning_unchanged=True,
            physics_ticks=60, time_scale=1, destroyed=False, phase='FREE_FLIGHT',
            piloted=True, seated=True, active_ship=True, lease_free=True, landed=False,
            flight_demand=False, telemetry=dict(engine='OFFLINE'), home=home,
            tutorial_approach=dict(binding_id=21, tick=frame, activated=False, caller_mode=True,
                accepted=False, sample_reason='unavailable', actor_id=0, position=[],
                piloting=False, enabled=True, range=250, cluster_id=0, markers=[]),
            position=copy.deepcopy(native.RaceHomePilot.POINTS[max(0, cursor-1)]),
            race=dict(owner_id=5, clock_id=6, director_id=7, selected_kind='timed_race',
                active_id=native.RaceHomePilot.ACTIVITY, active_generation=generation,
                route_path='res://assets/activities/cinder_reach_checkpoint_route.tres',
                points=copy.deepcopy(native.RaceHomePilot.POINTS), radius=32,
                snapshot=snapshot, director=dict(generation=generation, next_checkpoint_index=cursor),
                capture=dict(session_generation=generation, configured_laps=1, configured_countdown_seconds=2,
                             configured_timeout_seconds=120)),
            settlement=dict(configured=True, authority_id=8, store_id=9,
                store=dict(source='primary', path='/tmp/profile/data/mudds_user_data.json', generation=1),
                record=dict(receipt_serial=0, total_receipts=0, reward_counts={}, last_receipt={}),
                terminal={}, handoff={}))

    def running(self):
        pilot = native.RaceHomePilot()
        pilot.validate_observation(self.sample())
        pilot.guided_result = dict(genuine_guided_prerequisite=True)
        pilot.validate_observation(self.sample(2, 'countdown'))
        active = self.sample(122, 'active')
        pilot.validate_observation(active)
        return pilot, active

    @classmethod
    def paid(cls):
        sample = cls.sample(130, 'completed', 5)
        snap = sample['race']['snapshot']
        snap.update(last_time_seconds=10, current_time_seconds=10, progress_unitless=1)
        capture = sample['race']['capture']
        capture.update(session_generation=1, activity_state=dict(state=2, next_checkpoint_index=5),
                       race_state=dict(state=3, last_time_seconds=10))
        receipt = dict(receipt_id=1, activity_id=native.RaceHomePilot.ACTIVITY,
            activity_generation=1, reward_id=native.RaceHomePilot.REWARD,
            reward_label='Race record accepted', granted=True, replay_allowed=False)
        sample['settlement'].update(record=dict(schema_version=1, payload_kind='game_flow_reward_store',
            authority_id='game_flow_reward_authority', store_id='game_flow_reward_store', receipt_serial=1, total_receipts=1,
            reward_counts={native.RaceHomePilot.REWARD: 1}, last_receipt=receipt),
            terminal=dict(schema_version=1, activities=[dict(activity_id=native.RaceHomePilot.ACTIVITY,
                generation=1, state=3, reward_requested=True, reward_granted=True,
                progress=dict(session_state=copy.deepcopy(capture)))]),
            handoff=dict(accepted=True, reason='reward_request_committed',
                reward_request=dict(activity_id=native.RaceHomePilot.ACTIVITY, activity_generation=1,
                    reward_id=native.RaceHomePilot.REWARD, reward_authority=False, granted=False),
                callback=dict(accepted=True, granted=True, receipt=copy.deepcopy(receipt),
                    reason='reward_receipt_committed', reward_authority_id='game_flow_reward_authority',
                    reward_store_id='game_flow_reward_store', store_generation=1)))
        return sample

    def test_real_countdown_precedes_all_five_ordered_physical_gates(self):
        pilot, _ = self.running()
        self.assertEqual(pilot.countdown['frame'], 2)
        self.assertEqual(pilot.active['frame'], 122)
        for cursor in range(1, 5):
            sample = self.sample(122+cursor, 'active', cursor)
            pilot.validate_observation(sample)
        pilot.validate_observation(self.paid())
        self.assertEqual(len(pilot.gates), 5)
        self.assertIsNone(pilot.result)  # Payment never substitutes for usable home/UI exit.
        self.assertIsNone(pilot.home_result)
        self.assertEqual(native.CAP, 300)

    def test_shortened_countdown_skips_and_remote_crossings_are_rejected(self):
        pilot = native.RaceHomePilot(); pilot.guided_result = dict(done=True)
        pilot.validate_observation(self.sample(1, 'countdown'))
        with self.assertRaisesRegex(AssertionError, 'countdown'):
            pilot.validate_observation(self.sample(60, 'active'))
        for cursor, remote in ((2, False), (1, True)):
            with self.subTest(cursor=cursor, remote=remote):
                pilot, _ = self.running(); sample = self.sample(123, 'active', cursor)
                if remote: sample['position'] = [0, 0, 0]
                with self.assertRaises(AssertionError): pilot.validate_observation(sample)
        pilot, _ = self.running()
        stale = self.sample(122, 'active')
        with self.assertRaisesRegex(AssertionError, 'fresh'): pilot.validate_observation(stale)

    def test_mutated_owner_generation_route_clock_or_controls_fail(self):
        mutations = (lambda s: s['race'].update(owner_id=50),
            lambda s: s['race'].update(clock_id=60),
            lambda s: s['race'].update(selected_kind='checkpoint_route'),
            lambda s: s['race']['snapshot'].update(race_generation=2),
            lambda s: s['race']['capture'].update(configured_timeout_seconds=121),
            lambda s: s['race']['capture'].update(configured_countdown_seconds=0),
            lambda s: s['race'].update(radius=33),
            lambda s: s['race']['points'][0].__setitem__(0, 17),
            lambda s: s.update(default_sampler=False), lambda s: s.update(time_scale=2),
            lambda s: s['settlement']['store'].update(source='backup'))
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                pilot, _ = self.running(); sample = self.sample(123, 'active'); mutate(sample)
                with self.assertRaises(AssertionError): pilot.validate_observation(sample)

    def test_exact_paid_generation_terminal_capture_and_single_reward_required(self):
        native.RaceHomePilot.require_paid(self.paid())
        mutations = (lambda s: s['settlement']['record'].update(total_receipts=2),
            lambda s: s['settlement']['record']['last_receipt'].update(activity_generation=2),
            lambda s: s['settlement']['record']['last_receipt'].update(reward_id='debris_route_navigation_data'),
            lambda s: s['settlement']['terminal']['activities'][0].update(reward_granted=False),
            lambda s: s['race']['capture']['race_state'].update(last_time_seconds=120),
            lambda s: s['settlement']['handoff']['callback'].update(granted=False))
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                sample = self.paid(); mutate(sample)
                with self.assertRaises(AssertionError): native.RaceHomePilot.require_paid(sample)

    def test_race_handoff_requires_exact_direct_request_and_real_authority_callback(self):
        mutations = (
            lambda h: h.pop('callback'),
            lambda h: h.update(callback=None),
            lambda h: h.update(reason='reward_receipt_committed'),
            lambda h: h['reward_request'].update(activity_generation=2),
            lambda h: h['reward_request'].update(activity_id='cinder_debris_beacon_traversal'),
            lambda h: h['reward_request'].update(reward_id='debris_route_navigation_data'),
            lambda h: h['reward_request'].update(reward_authority=True),
            lambda h: h['reward_request'].update(granted=True),
            lambda h: h['callback'].update(accepted=False),
            lambda h: h['callback'].update(reason='reward_generation_already_committed'),
            lambda h: h['callback'].update(reward_authority_id='another_authority'),
            lambda h: h['callback'].update(reward_store_id='another_store'),
            lambda h: h['callback'].update(store_generation=0),
            lambda h: h['callback'].update(store_generation=2),
            lambda h: h['callback'].update(store_generation=True),
            lambda h: h['callback']['receipt'].update(activity_generation=2))
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                sample = self.paid(); mutate(sample['settlement']['handoff'])
                with self.assertRaises(AssertionError): native.RaceHomePilot.require_paid(sample)
        sample = self.paid()
        sample['settlement']['handoff'] = dict(accepted=True, reward_committed=True,
            authority_result=sample['settlement']['handoff']['callback'])
        with self.assertRaisesRegex(AssertionError, 'direct race adapter'):
            native.RaceHomePilot.require_paid(sample)
        # Subsequent ordinary autosaves may advance the store; the immutable
        # successful callback still names the original committed generation.
        sample = self.paid(); sample['settlement']['store']['generation'] = 2
        native.RaceHomePilot.require_paid(sample)

    @staticmethod
    def approached_sample(frame=2):
        sample = RaceHomeCallerTests.sample(frame)
        sample['tutorial_approach'] = dict(binding_id=21, tick=frame, activated=True,
            caller_mode=True, accepted=True, sample_reason='available', actor_id=4,
            position=[0, 0, 0], piloting=True, enabled=True, range=250, cluster_id=22,
            markers=[dict(family='nearby_hulk_dock', prompt_id='cinder_hulk_power_restoration',
                          position=[250, 0, 0]),
                     dict(family='nearby_belt_bore', prompt_id='cinder_asteroid_field_threading_run',
                          position=[0, 0, 249])])
        return sample

    @staticmethod
    def tutorial_pair():
        # Exact tutorial namespaces from the archived package baseline18/paid32;
        # unrelated siblings remain represented and protected in this fixture.
        before = dict(generation=18, payload=dict(runtime_settings=dict(show_tutorials=True),
            tutorial_prompts_seen=dict(schema_version=1.0, seen_ids=['cinder_reach_checkpoint_route'])))
        after = copy.deepcopy(before); after['generation'] = 32
        after['payload']['tutorial_prompts_seen']['seen_ids'] = [
            'cinder_asteroid_field_threading_run', 'cinder_hulk_power_restoration',
            'cinder_reach_checkpoint_route']
        return before, after

    def tutorial_files(self, tmp):
        profile = Path(tmp)/'profile'; profile.mkdir()
        files = native.RaceHomeFiles(profile, Path(tmp))
        pilot = native.RaceHomePilot()
        pilot.observe_tutorial_approaches(self.sample())
        approached = self.approached_sample()
        pilot.observe_tutorial_approaches(approached)
        files.baseline_sequence = 1
        files.observe(approached, pilot)
        return files, pilot

    def test_archived_tutorial_pair_preserves_exact_observed_approaches_and_all_siblings(self):
        with tempfile.TemporaryDirectory() as tmp:
            files, pilot = self.tutorial_files(tmp)
            before, after = self.tutorial_pair(); files.require_preserved(before, after)
            self.assertEqual(len(pilot.tutorial_approaches), 2)
            self.assertNotEqual(pilot.tutorial_approaches[0]['sample']['position'],
                                self.approached_sample()['position'])
            self.assertNotIn('tutorial_prompts_seen', files.MUTABLE)
            # Repeated or stale retained data cannot create new approach evidence.
            pilot.observe_tutorial_approaches(self.approached_sample())
            self.assertEqual(len(pilot.tutorial_approaches), 2)
            for mutate in (
                lambda p: p['tutorial_prompts_seen']['seen_ids'].remove('cinder_reach_checkpoint_route'),
                lambda p: p['tutorial_prompts_seen']['seen_ids'].append('unrelated_prompt'),
                lambda p: p['tutorial_prompts_seen'].update(schema_version=2),
                lambda p: p['tutorial_prompts_seen'].update(extra=True),
                lambda p: p['tutorial_prompts_seen']['seen_ids'].reverse(),
                lambda p: p['tutorial_prompts_seen']['seen_ids'].append('cinder_reach_checkpoint_route'),
                lambda p: p['runtime_settings'].update(show_tutorials=False)):
                with self.subTest(mutate=mutate):
                    changed = copy.deepcopy(after); mutate(changed['payload'])
                    with self.assertRaises(AssertionError): files.require_preserved(before, changed)

    def test_unavailable_stale_or_out_of_range_actor_samples_cannot_justify_tutorial_additions(self):
        mutations = (lambda s: s.update(accepted=False), lambda s: s.update(sample_reason='unavailable'),
            lambda s: s.update(actor_id=99), lambda s: s.update(activated=False),
            lambda s: s.update(caller_mode=False), lambda s: s.update(piloting=False),
            lambda s: s.update(enabled=False), lambda s: s.update(cluster_id=0),
            lambda s: s.update(tick=1), lambda s: s.update(position=[1000, 0, 0]))
        for mutate in mutations:
            with self.subTest(mutate=mutate), tempfile.TemporaryDirectory() as tmp:
                profile = Path(tmp)/'profile'; profile.mkdir()
                files = native.RaceHomeFiles(profile, Path(tmp)); pilot = native.RaceHomePilot()
                pilot.observe_tutorial_approaches(self.sample())
                sample = self.approached_sample(); mutate(sample['tutorial_approach'])
                pilot.observe_tutorial_approaches(sample)
                files.baseline_sequence = 1; files.observe(sample, pilot)
                self.assertEqual(files.expected_tutorial_ids, set())
                before, after = self.tutorial_pair()
                with self.assertRaises(AssertionError): files.require_preserved(before, after)

    def test_reapproach_is_rejected_until_actual_walk_clears_reboard_block(self):
        pilot = native.RaceHomePilot(); pilot.guided_result = dict(done=True)
        sample = self.sample(); pilot.last_state = sample; pilot.stage = 'walk'
        sample['reboard_blocked'] = True
        with self.assertRaisesRegex(AssertionError, 'still-blocked'):
            pilot.update(sample, 1)
        pilot.receipts['reboard_clear'] = dict(boarding_distance=8, reboard_blocked=False)
        with self.assertRaisesRegex(AssertionError, 'still-blocked'):
            pilot.update(sample, 2)
        self.assertIsNone(pilot.result)

    def test_actual_race_disk_consumer_checks_all_settlement_and_home_captures(self):
        with tempfile.TemporaryDirectory() as tmp:
            profile = Path(tmp)/'profile'; data = profile/'data'; data.mkdir(parents=True)
            output = Path(tmp)/'out'; output.mkdir()
            path = data/'mudds_user_data.json'
            files = native.RaceHomeFiles(profile, output)
            pilot = native.RaceHomePilot(); pilot.process_identity = (1, 2, 3, 4)
            pilot.entry_result = dict(guided=True)
            baseline = self.sample(2, 'countdown')
            baseline['settlement']['store']['path'] = str(path)
            document = dict(schema_version=1, generation=1, commit=dict(id='fixture-baseline'), payload={})
            path.write_text(json.dumps(document)); files.observe(baseline, pilot)
            paid = self.paid(); paid['settlement']['store']['path'] = str(path)
            document.update(generation=2, commit=dict(id='fixture-payment'), payload={
                'game_flow_reward_store': copy.deepcopy(paid['settlement']['record']),
                files.SLOT: copy.deepcopy(paid['settlement']['terminal'])})
            path.write_text(json.dumps(document)); pilot.paid_state = paid
            files.observe(paid, pilot)
            pilot.settlement_result = dict(complete=True); files.observe(paid, pilot)
            pilot.home_result = dict(complete=True); files.observe(paid, pilot)
            self.assertTrue(pilot.file_home)
            self.assertEqual(set(files.snapshots), {'baseline', 'paid', 'stable', 'home'})
            del files.snapshots['home']
            document['payload'][files.SLOT]['activities'][0]['reward_granted'] = False
            path.write_text(json.dumps(document))
            with self.assertRaisesRegex(AssertionError, 'independent actual file'):
                files.observe(paid, pilot)

    def test_ui_zero_exit_and_independent_home_file_are_required(self):
        pilot = native.RaceHomePilot()
        for code in (0, 1):
            with self.assertRaises(AssertionError): pilot.finish(code)
        pilot.home_result = dict(completion_marker=pilot.MARKER)
        pilot.quit_requested = True; pilot.stage = 'quit_wait'
        pilot.receipts['exit_ui'] = dict(sequence=999)
        with self.assertRaises(AssertionError): pilot.finish(0)
        pilot.file_home = True
        with self.assertRaises(AssertionError): pilot.finish(1)
        pilot.finish(0)
        self.assertEqual(pilot.result['completion_marker'], 'NATIVE_RACE_HOME_OK')

    def test_existing_home_behavior_defaults_and_race_prerequisite_are_preserved(self):
        self.assertEqual(native.BeaconHomePilot.HOME_RETURN_PHASES, ('RETURN_TO_YARD',))
        self.assertEqual(native.BeaconHomePilot.HOME_CLEARANCE_PHASE, 'TARGET_PRACTICE')
        self.assertTrue(native.BeaconHomePilot.HOME_RANGE_REQUIRED)
        pilot = native.RaceHomePilot()
        with self.assertRaisesRegex(AssertionError, 'countdown'):
            pilot.validate_observation(self.sample(1, 'countdown'))
        self.assertEqual(native.RaceHomeFiles.SLOT, 'cinder_timed_race_session')
        self.assertNotIn('cinder_beacon_session', native.RaceHomeFiles.MUTABLE)


class PatrolRelayHomeCallerTests(unittest.TestCase):
    @staticmethod
    def sample(frame=1, state='idle', cursor=0, dwell=0, position=None):
        sample = RaceHomeCallerTests.sample(frame)
        sample['mode'] = 'patrol-relay-home'
        sample.pop('race')
        generation = int(state != 'idle')
        position = list(position if position is not None else [0, 8, -78])
        sample['position'] = position
        sample['tutorial_approach'].update(accepted=True, sample_reason='available',
            actor_id=sample['ship_id'], piloting=True, position=position[:])
        snapshot = dict(activity_id=native.PatrolRelayHomePilot.ACTIVITY, branch_id='relay_sweep',
            attached=True, closed=False, state_id=state, state={'idle':0,'active':1,'completed':2}[state],
            generation=generation, activity_generation=generation, dwell_seconds=2,
            dwell_elapsed_seconds=dwell, checkpoint_occupied=dwell>0,
            dwell_checkpoint_index=cursor if dwell else -1, next_checkpoint_index=cursor,
            completed_checkpoint_count=cursor, current_time_seconds=(frame-1)/60 if generation else 0,
            patrol_actor_instance_id=sample['ship_id'] if generation else 0,
            patrol_actor_status_id='tracked' if generation else 'unbound',
            last_duration_seconds=(frame-1)/60 if state == 'completed' else -1,
            failure_reason='', terminal_reason='')
        capture = dict(schema_version=2, activity_id=native.PatrolRelayHomePilot.ACTIVITY,
            branch_id='relay_sweep', configured_dwell_seconds=2, generation=generation,
            activity_generation=generation, state=snapshot['state'], next_checkpoint_index=cursor,
            completed_checkpoint_count=cursor, dwell_checkpoint_index=snapshot['dwell_checkpoint_index'],
            dwell_elapsed_seconds=dwell, last_duration_seconds=snapshot['last_duration_seconds'],
            activity_state=dict(state=2 if state == 'completed' else generation, next_checkpoint_index=cursor))
        sample['patrol'] = dict(owner_id=5, director_id=7, selected_kind='patrol',
            active_id=native.PatrolRelayHomePilot.ACTIVITY, active_generation=generation,
            route_path='res://assets/activities/cinder_reach_checkpoint_route.tres',
            points=copy.deepcopy(native.PatrolRelayHomePilot.POINTS), radius=32,
            snapshot=snapshot, capture=capture,
            director=dict(generation=generation, next_checkpoint_index=cursor,
                          state=2 if state == 'completed' else generation))
        return sample

    @classmethod
    def paid(cls):
        sample = cls.sample(700, 'completed', 5)
        settlement = copy.deepcopy(RaceHomeCallerTests.paid()['settlement'])
        reward = native.PatrolRelayHomePilot.REWARD
        receipt = settlement['record']['last_receipt']
        receipt.update(activity_id='cinder_relay_patrol', reward_id=reward, reward_label='Patrol log accepted')
        settlement['record']['reward_counts'] = {reward:1}
        settlement['handoff']['reward_request'].update(activity_id='cinder_relay_patrol', reward_id=reward)
        settlement['handoff']['callback']['receipt'] = copy.deepcopy(receipt)
        settlement['terminal']['activities'] = [dict(activity_id=native.PatrolRelayHomePilot.ACTIVITY,
            generation=1, state=2, reward_requested=True, reward_granted=True,
            progress=dict(patrol_state=copy.deepcopy(sample['patrol']['capture'])))]
        sample['settlement'] = settlement
        return sample

    def running(self):
        pilot = native.PatrolRelayHomePilot()
        initial = self.sample()
        initial['patrol']['selected_kind'] = 'timed_race'
        initial['patrol']['snapshot']['attached'] = False
        pilot.validate_observation(initial)
        pilot.guided_result = dict(genuine_guided=True)
        pilot.patrol_selected = True
        pilot.validate_observation(self.sample(2, 'active'))
        return pilot

    def test_default_race_keeps_original_idle_patrol_detached_until_real_selection(self):
        pilot = native.PatrolRelayHomePilot()
        initial = self.sample()
        initial['patrol']['selected_kind'] = 'timed_race'
        initial['patrol']['snapshot']['attached'] = False
        pilot.validate_observation(initial)
        self.assertIsNone(pilot.patrol_active)
        selected = self.sample(2)
        pilot.validate_observation(selected)
        bad = self.sample(3)
        bad['patrol']['snapshot']['attached'] = False
        with self.assertRaises(AssertionError): pilot.validate_observation(bad)

    def test_exact_120_continuous_real_ticks_precede_director_commit(self):
        pilot = self.running()
        point = native.PatrolRelayHomePilot.POINTS[0]
        for tick in range(1, 120):
            pilot.validate_observation(self.sample(tick+2, 'active', dwell=tick/60, position=point))
        self.assertEqual(pilot.gates, [])
        pilot.validate_observation(self.sample(122, 'active', cursor=1, position=point))
        self.assertEqual(pilot.gates[0]['occupied_ticks'], 120)
        self.assertEqual(pilot.dwell_ticks, 0)

    def test_leaving_volume_resets_dwell_and_cannot_pay_for_accumulated_visits(self):
        pilot = self.running(); point = native.PatrolRelayHomePilot.POINTS[0]
        for tick in range(1, 61):
            pilot.validate_observation(self.sample(tick+2, 'active', dwell=tick/60, position=point))
        pilot.validate_observation(self.sample(63, 'active'))
        self.assertEqual(pilot.dwell_ticks, 0)
        for tick in range(1, 60):
            pilot.validate_observation(self.sample(tick+63, 'active', dwell=tick/60, position=point))
        with self.assertRaisesRegex(AssertionError, '120 continuous'):
            pilot.validate_observation(self.sample(123, 'active', cursor=1, position=point))

    def test_raw_tick_gap_clock_acceleration_and_unphysical_dwell_are_rejected(self):
        for mutation in ('gap', 'clock', 'timer', 'actor', 'branch'):
            with self.subTest(mutation=mutation):
                pilot = self.running()
                sample = self.sample(3, 'active')
                if mutation == 'gap': sample['frame'] += 1
                elif mutation == 'clock': sample['patrol']['snapshot']['current_time_seconds'] += 1/60
                elif mutation == 'timer': sample['patrol']['snapshot']['dwell_elapsed_seconds'] = 1/60
                elif mutation == 'actor': sample['tutorial_approach']['actor_id'] += 1
                else: sample['patrol']['snapshot']['branch_id'] = 'platform_sweep'
                with self.assertRaises(AssertionError): pilot.validate_observation(sample)

    def test_relay_payment_requires_actual_patrol_enum_schema_branch_and_callback(self):
        native.PatrolRelayHomePilot.require_paid(self.paid())
        for mutation in ('state', 'schema', 'branch', 'reward', 'activity', 'callback'):
            with self.subTest(mutation=mutation):
                sample = self.paid(); terminal = sample['settlement']['terminal']['activities'][0]
                if mutation == 'state': terminal['state'] = 3
                elif mutation == 'schema': sample['patrol']['capture']['schema_version'] = 1
                elif mutation == 'branch': sample['patrol']['capture']['branch_id'] = 'platform_sweep'
                elif mutation == 'reward': sample['settlement']['record']['reward_counts'] = {native.RaceHomePilot.REWARD:1}
                elif mutation == 'activity': sample['settlement']['record']['last_receipt']['activity_id'] = native.RaceHomePilot.ACTIVITY
                else: sample['settlement']['handoff']['callback']['receipt']['reward_id'] = native.RaceHomePilot.REWARD
                with self.assertRaises(AssertionError): native.PatrolRelayHomePilot.require_paid(sample)

    def test_ui_selects_actual_patrol_and_relay_buttons_before_resuming(self):
        pilot = native.PatrolRelayHomePilot(); pilot.guided_result = dict(genuine=True)
        sample = self.sample(); sample['paused'] = True
        sample['native_keys'] = dict(escape=False, tab=False, return_key=False)
        sample['ui'] = dict(main_visible=True, activity_visible=False,
            focus_path='/Pause/ActivityBoardButton', focus_name='ActivityBoardButton',
            focus_enabled=True, focus_visible=True, patrol_branch='relay_sweep',
            relay_enabled=True, relay_visible=True)
        pilot.beacon_stage('patrol_ui_board', sample)
        keys, *_ = pilot.patrol_ui_update(sample, 1)
        self.assertEqual(keys, {'Return'})
        self.assertEqual(pilot.ui_pending['kind'], 'board')
        pilot.ui_key = pilot.ui_pending = None
        sample['ui'].update(activity_visible=True, focus_name='PatrolActivityButton')
        pilot.beacon_stage('patrol_ui_select', sample)
        keys, *_ = pilot.patrol_ui_update(sample, 2)
        self.assertEqual(keys, {'Return'})
        self.assertEqual(pilot.ui_pending['kind'], 'select')
        pilot.ui_key = pilot.ui_pending = None
        sample['ui']['focus_name'] = 'RelaySweepPatrolBranchButton'
        pilot.beacon_stage('patrol_ui_branch', sample)
        keys, *_ = pilot.patrol_ui_update(sample, 3)
        self.assertEqual(keys, {'Return'})
        self.assertEqual(pilot.ui_pending['kind'], 'branch')
        self.assertFalse(pilot.patrol_selected)

    def test_patrol_file_scope_protects_unrelated_race_and_beacon_records(self):
        self.assertEqual(native.PatrolRelayHomeFiles.SLOT, 'cinder_patrol_session')
        self.assertNotIn('cinder_timed_race_session', native.PatrolRelayHomeFiles.MUTABLE)
        self.assertNotIn('cinder_beacon_session', native.PatrolRelayHomeFiles.MUTABLE)
        self.assertEqual(native.CAP, 300)

    def test_disabled_relay_choice_requires_actual_matching_default_and_never_sends_start(self):
        for branch in ('relay_sweep', 'platform_sweep'):
            with self.subTest(branch=branch):
                pilot = native.PatrolRelayHomePilot(); pilot.guided_result = dict(genuine=True)
                sample = self.sample(); sample['paused'] = True
                sample['native_keys'] = dict(escape=False, tab=False, return_key=False)
                sample['ui'] = dict(activity_visible=True, focus_path='/Pause/PatrolActivityButton',
                    focus_name='PatrolActivityButton', patrol_branch=branch,
                    relay_enabled=False, relay_visible=True)
                pilot.beacon_stage('patrol_ui_branch', sample)
                if branch == 'relay_sweep':
                    keys, *_ = pilot.patrol_ui_update(sample, 1)
                    self.assertEqual(keys, set())
                    self.assertEqual(pilot.stage, 'patrol_ui_back')
                    self.assertIn('patrol_ui_branch_disabled_default', pilot.receipts)
                    self.assertFalse(pilot.patrol_selected)
                else:
                    with self.assertRaisesRegex(AssertionError, 'actual fresh default'):
                        pilot.patrol_ui_update(sample, 1)

    def test_patrol_outbound_brakes_hovers_and_aligns_at_original_low_near_endpoint(self):
        for unsafe in (None, 'speed', 'upright', 'pitch'):
            with self.subTest(unsafe=unsafe):
                pilot = native.PatrolRelayHomePilot()
                sample = self.sample(3, 'active', position=[0, 2.7, -100])
                sample.update(camera=sample['position'][:], velocity=[0,0,0], upright=1,
                    right=[1,0,0], up=[0,1,0], back=[0,0,1],
                    tuning=dict(brake=14, maximum_speed=60, mouse=.002))
                if unsafe == 'speed': sample['velocity'][0] = .02
                elif unsafe == 'upright': sample['upright'] = .93
                elif unsafe == 'pitch': sample['back'][1] = .1
                pilot.receipts['patrol_outbound_near'] = sample
                pilot.stage = 'patrol_outbound_align'; pilot.last_state = sample
                keys, *_ = pilot.update(sample, 1)
                self.assertEqual(keys, {'Prior', 'h'})
                self.assertEqual(pilot.stage, 'patrol_outbound_far' if unsafe is None else 'patrol_outbound_align')
                if unsafe is None:
                    self.assertIs(pilot.receipts['patrol_outbound_ready'], sample)

    def test_reverse_header_crossing_retains_every_actual_low_lane_sample(self):
        pilot = native.PatrolRelayHomePilot()
        def sample(frame, z):
            s = self.sample(frame, 'active', position=[0,2.7,z])
            s['telemetry']['hull'] = 100
            s['tuning'] = dict(maximum_speed=60)
            return s
        initial = sample(1, -100)
        pilot.home_initial = copy.deepcopy(initial['home'])
        pilot.receipts.update(patrol_outbound_near=initial, patrol_outbound_ready=initial)
        pilot.raw_previous = sample(2, -109)
        for frame, z in enumerate(range(-110, -131, -1), 3):
            current = sample(frame, z)
            pilot.observe_patrol_outbound_header(current)
            if z > -130: self.assertIsNone(pilot.patrol_outbound_header_crossing)
            pilot.raw_previous = current
        crossing = pilot.patrol_outbound_header_crossing
        self.assertEqual(crossing['origin_z_interval'], [-130,-110])
        self.assertEqual([s['position'][2] for s in crossing['samples']], list(range(-109,-131,-1)))
        self.assertEqual([s['frame'] for s in crossing['samples']], list(range(2,24)))

    def test_reverse_header_rejects_changed_endpoints_unsafe_clearance_or_unphysical_motion(self):
        for mutation in ('near', 'far', 'height', 'damage', 'gap', 'jump', 'not_ready'):
            with self.subTest(mutation=mutation):
                pilot = native.PatrolRelayHomePilot()
                previous = self.sample(2, 'active', position=[0,2.7,-109])
                current = self.sample(3, 'active', position=[0,2.7,-110])
                for s in (previous, current):
                    s['telemetry']['hull'] = 100; s['tuning'] = dict(maximum_speed=60)
                pilot.home_initial = copy.deepcopy(previous['home'])
                pilot.receipts.update(patrol_outbound_near=previous, patrol_outbound_ready=previous)
                pilot.raw_previous = previous
                if mutation == 'near': current['home']['range_clearance_exit'][2] += 1
                elif mutation == 'far': current['home']['range_clearance'][2] += 1
                elif mutation == 'height': current['position'][1] = 4
                elif mutation == 'damage': current['telemetry']['hull'] = 99
                elif mutation == 'gap': current['frame'] += 1
                elif mutation == 'jump': current['position'][2] = -131
                else: del pilot.receipts['patrol_outbound_ready']
                with self.assertRaises(AssertionError): pilot.observe_patrol_outbound_header(current)


class TorrentReturnReuseTests(unittest.TestCase):
    """Small synthetic lifecycle fixtures; the packaged route proves real input."""
    def observation(self):
        s = ArrowReturnReuseTests().observation()
        s.update(mode='torrent-return-reuse', definition_id='torrent_provisional', home_id='central_berth',
                 opponent_id=80, opponent_active=False, opponent=[0, 8, -100],
                 targets=[{'name': str(i), 'position': [i, 8, -90]} for i in range(4)],
                 destroyed_targets=0, guided_return_authorized=False,
                 player_velocity=[0, 0, 0], position=[0, 1.15, -10], parked=[0, 1.15, -10],
                 boarding=[-4.5, 0, -6.6], exit=[-4.8, 0, -6.6],
                 right=[1, 0, 0], back=[0, 0, 1], camera=[0, 3, -10],
                 tuning={'mouse': .002, 'brake': 20}, telemetry={'engine': 'OFFLINE', 'hull': 100},
                 upright=1, shot_accepted=False, command_fire=False, walk_offset=[0, 0, 0], exit_error=0)
        return s

    def tick(self, p, s, update=True, **changes):
        s.update(changes); s['frame'] += 1; s['sequence'] += 1
        s['telemetry']['engine'] = s['engine']
        snapshot = copy.deepcopy(s)
        p.validate_observation(snapshot)
        if update: return p.update(snapshot, s['frame']/60)

    def after_guided(self):
        p, s = native.TorrentReturnReusePilot(), self.observation()
        p.validate_observation(copy.deepcopy(s))
        # Isolate the reuse seam. Full prelude production control remains Pilot;
        # its actual packaged run must supply all combat and home phases.
        s.update(phase='COMPLETE', guided_complete=True, targets=[], destroyed_targets=4,
                 contract=True, active_ship=True, player=s['exit'][:], boarding_distance=3,
                 reboard_blocked=True)
        p.guided_result = {'phases': ['COMPLETE']}
        p.flight = 1; p.stage = 'reuse_release'; p.neutral_frames = 90
        p.receipts['exited_1'] = p.receipt(s)
        p.trips = [{'flight': 1, 'excursion_m': 75, 'neutral_frames': 90}]
        p.observed_previous = copy.deepcopy(s)
        self.tick(p, s)
        self.assertEqual(p.stage, 'reuse_clear')
        return p, s

    def move_to(self, p, s, target):
        for _ in range(200):
            delta = native.sub(target, s['player']); distance = native.norm(delta)
            if distance <= .01: return
            s['player'] = [a+b*min(.1/distance, 1) for a,b in zip(s['player'], delta)]
            distance_to_board = native.norm(native.sub(s['player'], s['boarding']))
            self.tick(p, s, boarding_distance=distance_to_board, reboard_blocked=distance_to_board <= 7)
        self.fail('bounded fixture walk did not finish')

    def at_second_board(self):
        p, s = self.after_guided()
        self.move_to(p, s, p.clear_target)
        self.tick(p, s, boarding_distance=8, reboard_blocked=False)
        self.assertTrue(p.clear_seen)
        self.tick(p, s, candidate=True, boarding_distance=3)
        self.assertEqual(p.stage, 'board')
        return p, s

    def test_prefix_remains_existing_guided_and_generic_completion_cannot_succeed(self):
        p, s = native.TorrentReturnReusePilot(), self.observation()
        snapshot = copy.deepcopy(s); p.validate_observation(snapshot)
        with patch.object(native.Pilot, 'update', wraps=lambda pilot, state, now: (set(), 0, 0, False)) as guided:
            p.update(snapshot, 0)
            guided.assert_called_once_with(p, snapshot, 0)
        p.stage = 'exit'; p.identities = (s['player_id'], s['ship_id'])
        p.phases = ['SHUT_DOWN']; p.neutral_frames = 90; p.disembarking_seen = True
        with self.assertRaisesRegex(AssertionError, 'genuine gameplay phases'):
            self.tick(p, s, phase='COMPLETE', guided_complete=True, targets=[], destroyed_targets=4,
                      player=s['exit'][:], active_ship=True, contract=True)
        self.assertIsNone(p.result)
        self.assertIsNone(p.guided_result)

    def test_wrong_identity_stale_guided_and_early_pause_fail_before_reuse(self):
        for changes in ({'ship_id': 999}, {'main_id': 999}, {'opponent_active': True},
                        {'guided_return_authorized': True}, {'destroyed_targets': 3},
                        {'targets': [{'name': 'stale'}]}, {'paused': True}):
            with self.subTest(changes=changes):
                p, s = self.after_guided()
                with self.assertRaises(AssertionError): self.tick(p, s, **changes)
                self.assertIsNone(p.result)

    def test_fresh_boarding_requires_clear_walk_native_edge_and_current_reservation(self):
        p, s = self.at_second_board()
        self.assertGreater(p.receipts['board_2']['frame'], p.receipts['walk_clear']['frame'])
        with self.assertRaisesRegex(AssertionError, 'native E and reservation'):
            self.tick(p, s, phase='BOARDING', transition_busy=True, boarding_reserved=True,
                      boarding_confirmation={'adapter': {'view': {'state': 'boarding'}}})
        p, s = self.at_second_board()
        self.tick(p, s, phase='BOARDING', native_interact=True, transition_busy=True,
                  boarding_reserved=True, boarding_confirmation={'adapter': {'view': {'state': 'boarding'}}})
        self.tick(p, s, phase='START_ENGINES', seated=True, seated_at_pilot=True, piloted=True,
                  active_ship=True, capsule_enabled=False, player_camera=False, ship_camera=True,
                  transition_busy=False, boarding_confirmation={'adapter': {'view': {'state': 'seated'}}})
        self.assertEqual(p.stage, 'reuse_launch')
        self.tick(p, s, phase='FREE_FLIGHT', engine='ONLINE', native_thrust=True,
                  flight_demand=True, landed=False, lease=False, lease_free=True,
                  lease_token='', parked_exact=False, position=[0, 8, -78], native_interact=False)
        self.assertTrue(p.departed)
        self.assertIn('departed_2', p.receipts)
        self.assertEqual(p.stage, 'reuse_return_align')

    def test_exit_requires_consecutive_neutral_offline_ticks(self):
        p, s = self.after_guided()
        p.stage = 'reuse_shutdown'
        s.update(phase='SHUT_DOWN', seated=True, seated_at_pilot=True, piloted=True,
                 capsule_enabled=False, player_camera=False, ship_camera=True)
        p.neutral_frames = 0
        for _ in range(90): self.tick(p, s, engine='ONLINE')
        self.assertEqual(p.neutral_frames, 0)
        for _ in range(89): self.tick(p, s, engine='OFFLINE')
        self.assertNotIn('exit_2', p.receipts)
        self.tick(p, s, flight_demand=True)
        self.assertEqual(p.neutral_frames, 0)
        for _ in range(89): self.tick(p, s, flight_demand=False)
        self.assertNotIn('exit_2', p.receipts)
        self.tick(p, s)
        self.assertEqual(p.stage, 'exit')
        self.assertEqual(p.neutral_frames, 90)
        self.assertIn('e', self.tick(p, s)[0])

    def test_second_home_rejects_first_lease_and_preserves_new_lease(self):
        p, s = self.after_guided()
        p.receipts['departed_2'] = p.receipt(s)
        with self.assertRaisesRegex(AssertionError, 'fresh lease token'):
            p.require_home(s)
        s['lease_token'] = 'second-home-token'
        p.require_home(s)
        p.receipts['docked_2'] = p.receipt(s)
        s['lease_token'] = 'replacement-token'
        with self.assertRaisesRegex(AssertionError, 'same newly acquired'):
            p.require_home(s)

    def test_first_guided_exit_also_waits_for_90_neutral_offline_ticks(self):
        p, s = native.TorrentReturnReusePilot(), self.observation()
        p.validate_observation(copy.deepcopy(s))
        p.stage = 'shutdown'
        s.update(phase='SHUT_DOWN', contract=True, seated=True, seated_at_pilot=True, piloted=True,
                 active_ship=True, capsule_enabled=False, player_camera=False, ship_camera=True)
        for _ in range(89):
            keys, *_ = self.tick(p, s)
            self.assertNotIn('e', keys)
        self.assertEqual(p.stage, 'shutdown')
        keys, *_ = self.tick(p, s)
        self.assertIn('e', keys)
        self.assertEqual(p.stage, 'exit')
        self.assertEqual(p.neutral_frames, 90)

    def test_quit_before_second_exit_or_usable_walk_cannot_report_success(self):
        p, s = self.after_guided()
        p.quit_requested = True; p.stage = 'quit_wait'; p.clear_seen = True
        p.receipts['exit_ui'] = {'ui': {}}
        with self.assertRaises(AssertionError): p.finish(0)
        p.trips.append({'flight': 2, 'excursion_m': 20, 'neutral_frames': 90})
        p.receipts.update({key: {} for key in ('walk_clear', 'board_2', 'seated_2', 'departed_2',
                                              'docked_2', 'offline_2', 'exited_2')})
        with self.assertRaises(AssertionError): p.finish(0)
        p.receipts['walked_2'] = {}
        with self.assertRaises(AssertionError): p.finish(1)
        self.assertEqual(p.finish(0)['completion_marker'], native.TorrentReturnReusePilot.MARKER)


class TorrentDamagedReturnTests(unittest.TestCase):
    def start(self):
        p = native.TorrentDamagedReturnPilot()
        s = TorrentReturnReuseTests().observation()
        s['mode'] = p.MODE
        s['damage'] = dict(model_id=91, generation=1, revision=2, authority_id=92, damageable_id=93,
            hull=100, maximum_hull=100, landed=True, landing_active=False, repair_rate=.62,
            components=[dict(id=k, integrity=1., state_id='nominal') for k in p.COMPONENTS],
            modifiers={k+suffix: value for k in ('mobility', 'fire', 'targeting')
                       for suffix, value in (('_multiplier', 1.), ('_disabled', False))},
            effects=dict(localized=0, repair_cues=0, pending=0, impacts=0),
            opponent_tuning=dict(maximum_health=85, weapon_cooldown=1.55),
            incoming={}, incoming_last={}, incoming_count=0, incoming_damage=0, incoming_violation=False,
            repair_first={}, repair_last={}, repair_count=0, repair_violation=False)
        p.validate_damage(s)
        return p, s

    def incoming(self, p, s, component='port_wing'):
        d = s['damage']; s['frame'] += 1
        s.update(phase='INTERCEPTOR_ENGAGEMENT', landed=False, contract=False, seated=True, piloted=True,
                 active_ship=True, ship_camera=True, opponent_health=85, opponent_active=True)
        d.update(hull=89, landed=False, revision=3)
        for row in d['components']:
            if row['id'] == component: row.update(integrity=.56, state_id='impaired')
        if component in p.CHANNELS: d['modifiers'][p.CHANNELS[component]+'_multiplier'] = .62
        hit = dict(frame=s['frame'], present=True, accepted=True, resolved=True, hit=True, damaged=True,
            destroyed=False, request_matches=True, source_entity_id=s['opponent_id'], source_id=2101,
            target_entity_id=s['ship_id'], damageable_id=d['damageable_id'], collider_id=s['ship_id'],
            contact_finite=True, position=[1, 2, 3], applied_damage=11, remaining_health=89,
            phase='INTERCEPTOR_ENGAGEMENT', opponent_active=True, opponent_health=85,
            native_fire=False, command_fire=False, cumulative_damage=11, snapshot=copy.deepcopy(d),
            request=dict(source_entity_id=s['opponent_id'], source_id=2101, weapon_id='defence_pulse_cannon',
                         sequence=7, damage=11),
            context=dict(source_entity_id=s['opponent_id'], source_id=2101, weapon_id='defence_pulse_cannon',
                         sequence=7, target_id=s['ship_id'], contact_finite=True, position=[1, 2, 3]))
        d.update(incoming=hit, incoming_last=copy.deepcopy(hit), incoming_count=1, incoming_damage=11)
        return hit

    def airborne(self, p, s, frames=90):
        for _ in range(frames):
            s['frame'] += 1
            p.validate_damage(s)

    def berth(self, p, s):
        s['frame'] += 1
        s.update(phase='SHUT_DOWN', landed=True, contract=True)
        d = s['damage']; d.update(landed=True, revision=d['revision']+1, repair_count=1)
        for row in d['components']:
            if row['integrity'] < 1: row['integrity'] = min(1., row['integrity']+.62/60)
        event = dict(frame=s['frame'], origin='passive_berth', generation=1, revision=d['revision'],
                     strict_home=True, lease_token=s['lease_token'], snapshot=copy.deepcopy(d))
        d.update(repair_first=copy.deepcopy(event), repair_last=copy.deepcopy(event))
        p.validate_damage(s)

    def test_first_hit_uses_actual_region_and_declared_channel_then_resumes_fire(self):
        for component in native.TorrentDamagedReturnPilot.COMPONENTS:
            with self.subTest(component=component):
                p, s = self.start(); self.incoming(p, s, component); p.validate_damage(s)
                self.assertEqual(p.receipts['incoming_damage']['component'], component)
                p.stage = 'interceptor'; p.last_state = s
                with patch.object(native.TorrentReturnReusePilot, 'update', return_value=({'Prior'}, 0, 0, True)) as update:
                    self.assertTrue(p.update(s, 1)[3]); update.assert_called_once()
        p, s = self.start(); s.update(phase='INTERCEPTOR_ENGAGEMENT', opponent_active=True,
            opponent_health=85, seated=True, piloted=True, active_ship=True, ship_camera=True)
        p.stage = 'interceptor'
        self.assertFalse(p.update(s, 1)[3])

    def test_foreign_receipt_context_or_wrong_damage_cannot_unlock_fire(self):
        for mutation in ('source', 'context', 'damageable', 'point', 'damage', 'generation'):
            with self.subTest(mutation=mutation):
                p, s = self.start(); hit = self.incoming(p, s)
                if mutation == 'source': hit['source_entity_id'] = 999
                elif mutation == 'context': hit['context']['source_id'] = 999
                elif mutation == 'damageable': hit['damageable_id'] = 999
                elif mutation == 'point': hit['contact_finite'] = False
                elif mutation == 'damage': hit['applied_damage'] = 1
                else: hit['snapshot']['generation'] += 1
                with self.assertRaises(AssertionError): p.validate_damage(s)
                self.assertIsNone(p.incoming)

    def test_airborne_repair_and_replaced_or_reset_model_are_rejected(self):
        for mutation in ('increase', 'repair', 'generation', 'model'):
            with self.subTest(mutation=mutation):
                p, s = self.start(); self.incoming(p, s); p.validate_damage(s); s['frame'] += 1
                d = s['damage']
                if mutation == 'increase': d['components'][1]['integrity'] += .01
                elif mutation == 'repair': d['repair_count'] = 1
                elif mutation == 'generation': d['generation'] += 1
                else: d['model_id'] += 1
                with self.assertRaises(AssertionError): p.validate_damage(s)

    def second_incoming(self, p, s):
        d = s['damage']; s['frame'] += 1
        d.update(hull=78, revision=d['revision']+1, incoming_count=2, incoming_damage=22)
        for row in d['components']:
            if row['id'] == 'core_systems': row.update(integrity=.56, state_id='impaired')
        d['modifiers']['targeting_multiplier'] = .62
        hit = copy.deepcopy(d['incoming'])
        hit.update(frame=s['frame'], remaining_health=78, cumulative_damage=22, opponent_health=51,
                   native_fire=True, command_fire=True, snapshot=copy.deepcopy(d))
        hit['request']['sequence'] += 1; hit['context']['sequence'] += 1
        d['incoming_last'] = hit
        return hit

    def test_multiple_genuine_hits_preserve_cumulative_loss_and_repair_all_actual_damage(self):
        p, s = self.start(); self.incoming(p, s); p.validate_damage(s)
        self.second_incoming(p, s); p.validate_damage(s)
        self.assertEqual(s['damage']['hull'], 78)
        self.airborne(p, s); self.berth(p, s)
        d = s['damage']; s['frame'] += 43; d.update(revision=47, repair_count=43)
        for row in d['components']: row.update(integrity=1., state_id='nominal')
        d['modifiers'].update(fire_multiplier=1., targeting_multiplier=1.)
        d['repair_last'] = dict(frame=s['frame'], origin='passive_berth', generation=1,
                               revision=47, strict_home=True, snapshot=copy.deepcopy(d))
        p.validate_damage(s)
        self.assertIsNotNone(p.repaired)
        self.assertEqual(d['hull'], 78)
        self.assertEqual(p.incoming['remaining_health'], 89)

    def test_later_hit_requires_provenance_cumulative_loss_and_no_airborne_heal(self):
        for mutation in ('context', 'cumulative', 'healing', 'sticky'):
            with self.subTest(mutation=mutation):
                p, s = self.start(); self.incoming(p, s); p.validate_damage(s)
                hit = self.second_incoming(p, s)
                if mutation == 'context': hit['context']['source_entity_id'] = 999
                elif mutation == 'cumulative': s['damage']['incoming_damage'] = 11
                elif mutation == 'healing': s['damage']['components'][1]['integrity'] += .01
                else: s['damage']['incoming_violation'] = True
                with self.assertRaises(AssertionError): p.validate_damage(s)

    def test_landed_transient_resets_incomplete_airborne_run(self):
        p, s = self.start(); self.incoming(p, s); p.validate_damage(s)
        self.airborne(p, s, 45)
        s['frame'] += 1; s['damage'].update(landed=True, landing_active=True)
        p.validate_damage(s)
        self.assertEqual(p.airborne_run, 0)
        s['damage'].update(landed=False, landing_active=False)
        self.airborne(p, s, 45)
        with self.assertRaisesRegex(AssertionError, 'ninety consecutive'):
            self.berth(p, s)
        self.assertIsNone(p.airborne_proof)

    def test_real_passive_commit_restores_components_and_retains_hull_loss(self):
        p, s = self.start(); self.incoming(p, s); p.validate_damage(s); self.airborne(p, s)
        self.berth(p, s)
        d = s['damage']; s['frame'] += 43; d.update(revision=46, repair_count=43)
        for row in d['components']: row.update(integrity=1., state_id='nominal')
        d['modifiers']['fire_multiplier'] = 1.
        d['repair_last'] = dict(frame=s['frame'], origin='passive_berth', generation=1,
                               revision=46, strict_home=True, snapshot=copy.deepcopy(d))
        p.validate_damage(s)
        self.assertIsNotNone(p.repaired); self.assertEqual(d['hull'], 89)
        self.assertEqual(p.airborne_frames, 90)

    def test_fake_or_late_or_unsecured_repair_cannot_complete(self):
        for mutation in ('no_commit', 'fake_state', 'late', 'unsecured', 'hull_healed'):
            with self.subTest(mutation=mutation):
                p, s = self.start(); self.incoming(p, s); p.validate_damage(s); self.airborne(p, s)
                self.berth(p, s); d = s['damage']; s['frame'] += 1
                if mutation == 'no_commit': d['repair_count'] = 0
                elif mutation == 'fake_state':
                    for row in d['components']: row.update(integrity=1., state_id='nominal')
                elif mutation == 'late': s['frame'] = p.repair_start+180
                elif mutation == 'unsecured': d['repair_violation'] = True
                else: d['hull'] = 100
                with self.assertRaises(AssertionError): p.validate_damage(s)
                self.assertIsNone(p.repaired)


class TorrentArrowHandoffTests(unittest.TestCase):
    """Actor/epoch/consumer regressions; only packaged OS input can qualify the route."""
    def state(self):
        damage_tests = TorrentDamagedReturnTests()
        base, s = damage_tests.start(); damage_tests.incoming(base, s); base.validate_damage(s)
        damage_tests.airborne(base, s); damage_tests.berth(base, s)
        d = s['damage']; s['frame'] += 43; d.update(revision=46, repair_count=43)
        for row in d['components']: row.update(integrity=1., state_id='nominal')
        d['modifiers']['fire_multiplier'] = 1.
        d['repair_last'] = dict(frame=s['frame'], origin='passive_berth', generation=1,
                               revision=46, strict_home=True, snapshot=copy.deepcopy(d))
        base.validate_damage(s)
        p = native.TorrentArrowHandoffPilot(); p.__dict__.update(base.__dict__)
        s.update(mode=p.MODE, phase='COMPLETE', guided_complete=True, targets=[], destroyed_targets=4,
            guided_return_authorized=False, opponent_active=False, paused=False, seated=False,
            piloted=False, active_ship=True, transition_busy=False, control_enabled=True,
            capsule_enabled=True, player_camera=True, grounded=True, supported=True,
            support_collider='/Main/World/Deck', engine='OFFLINE', flight_demand=False,
            player_velocity=[0,0,0], native_interact=False)
        p.guided_result = {'phases': ['COMPLETE']}; p.trips = [
            dict(flight=i, excursion_m=75, neutral_frames=90) for i in (1,2)]
        p.receipts['walked_2'] = {'frame': s['frame']-1}
        def craft(key, ids, stream):
            return dict(zip(p.HULL_IDS, ids), definition_id=key,
                home_id='central_berth' if key == p.TORRENT else 'arrow_recon_berth',
                actors_current=True, active=key == p.TORRENT, piloted=False, remote_piloted=False,
                seated=False, camera=False, reserved=False, player_reservation=False, candidate=False,
                reboard_blocked=False, boarding_distance=8, boarding=[-5,0,-6] if key == p.TORRENT else [-39,0,14],
                exit=[-5,0,-6] if key == p.TORRENT else [-39,0,14], parked_exact=True,
                position=[0,1.15,-10] if key == p.TORRENT else [-43,1.17,15], velocity=[0,0,0],
                landed=True, landing_active=False, lease=True, lease_token=key+'-lease', contract=key == p.TORRENT,
                physical_strict=True, main_lease_token=key+'-lease',
                main_berth_id='central_berth' if key == p.TORRENT else 'arrow_recon_berth',
                occupant_id=ids[0], reservation_owner_id=ids[0], reserved_ship_id=key,
                hull=89 if key == p.TORRENT else 100, destroyed=False, engine='OFFLINE', flight_demand=False,
                default_sampler=True, tuning_unchanged=True, tuning={'default': True}, stream=stream,
                next_sequence=0, pending=0, delivery_generation=stream, source_enabled=True,
                command_valid=True, command_neutral=True, command_stream=0, command_sequence=0, interact={})
        s['handoff'] = dict(actors_current=True, fleet={
            p.TORRENT: craft(p.TORRENT, (s['ship_id'],s['source_id'],s['seat_id'],98,s['berth_id']),8),
            p.ARROW: craft(p.ARROW, (101,102,103,104,105),0)},
            active_ship_id=s['ship_id'], piloting=False, consumed_ship_id=0, consumed_stream=-1, consumed_sequence=-1)
        p.handoff_started=True; p.stage='handoff_release'
        p.handoff_initial=copy.deepcopy(s['handoff']); p.initial=copy.deepcopy(s)
        p.observed_previous=copy.deepcopy(s); p.handoff_previous=copy.deepcopy(s)
        p.remember_retired(p.TORRENT,s); p.remember_retired(p.ARROW,s)
        return p,s

    def tick(self,p,s):
        s['frame']+=1; s['sequence']+=1
        p.validate_observation(copy.deepcopy(s))

    def exit_state(self):
        p,s=self.state(); p.stage='handoff_arrow_exit'; p.retired.pop(p.ARROW)
        a=s['handoff']['fleet'][p.ARROW]
        a.update(stream=10,next_sequence=5,delivery_generation=10,piloted=True,seated=True,camera=True,
                 reserved=True,player_reservation=True,active=True,command_stream=10,command_sequence=4)
        s['handoff']['fleet'][p.TORRENT]['active']=False
        s['handoff'].update(active_ship_id=a['ship_id'],piloting=True,consumed_ship_id=a['ship_id'],
                            consumed_stream=10,consumed_sequence=4)
        p.handoff_receipts['arrow_exit_press']=p.handoff_receipt(s)
        s['frame']+=1; s['phase']='DISEMBARKING'; s['transition_busy']=True; s['native_interact']=True
        a['interact']=dict(frame=s['frame'],ship_id=a['ship_id'],source_id=a['source_id'],stream=10,
                           sequence=4,native=True,valid=True,current=True)
        p.handoff_edges=[dict(frame=s['frame'],stage=p.stage)]
        return p,s

    def test_exit_witness_requires_exact_actor_epoch_and_current_consumer(self):
        p,s=self.exit_state(); p.require_exit_consumer(p.ARROW,'arrow_exit',s)
        self.assertIn('arrow_exit_transition',p.handoff_receipts)
        for mutation in ('old_stream','wrong_source','wrong_actor','stale_consumer','not_native'):
            with self.subTest(mutation=mutation):
                p,s=self.exit_state(); a=s['handoff']['fleet'][p.ARROW]
                if mutation=='old_stream': a['interact']['stream']=9
                elif mutation=='wrong_source': a['interact']['source_id']=999
                elif mutation=='wrong_actor': s['handoff']['consumed_ship_id']=s['ship_id']
                elif mutation=='stale_consumer': s['handoff']['consumed_sequence']=3
                else: a['interact']['native']=False
                with self.assertRaises(AssertionError): p.require_exit_consumer(p.ARROW,'arrow_exit',s)

    def test_retired_source_can_remain_enabled_but_cannot_consume_or_keep_claims(self):
        p,s=self.state(); self.tick(p,s)
        self.assertTrue(s['handoff']['fleet'][p.TORRENT]['source_enabled'])
        for mutation in ('cursor','pending','seat','camera','reservation','command'):
            with self.subTest(mutation=mutation):
                p,s=self.state(); t=s['handoff']['fleet'][p.TORRENT]
                if mutation=='cursor': t['next_sequence']+=1
                elif mutation=='pending': t['pending']=1
                elif mutation=='seat': t['seated']=True
                elif mutation=='camera': t['camera']=True
                elif mutation=='reservation': t['reserved']=True
                else: t['command_neutral']=False
                with self.assertRaises(AssertionError): self.tick(p,s)

    def test_actor_replacement_or_departure_during_handoff_fails(self):
        for mutation in ('actor','lease','position','engine','demand'):
            with self.subTest(mutation=mutation):
                p,s=self.state(); a=s['handoff']['fleet'][p.ARROW]
                if mutation=='actor': a['ship_id']=999
                elif mutation=='lease': a['lease']=False
                elif mutation=='position': a['parked_exact']=False
                elif mutation=='engine': a['engine']='ONLINE'
                else: a['flight_demand']=True
                with self.assertRaises(AssertionError): self.tick(p,s)

    def test_false_exit_and_premature_normal_quit_cannot_complete(self):
        p,s=self.state(); p.stage='handoff_arrow_exit'; p.last_state=s
        # On-foot flags alone do not prove the Arrow command consumer exited it.
        s['player']=s['handoff']['fleet'][p.ARROW]['exit'][:]
        with self.assertRaises(AssertionError): p.update(s,1)
        p,s=self.state(); p.stage='quit_wait'; p.quit_requested=True
        with self.assertRaises(AssertionError): p.finish(0)
        s['paused']=True; p.stage='pause'
        with self.assertRaises(AssertionError): self.tick(p,s)

    def test_stationary_arrow_exit_uses_physical_lease_without_landing_history(self):
        p,s=self.state(); a=s['handoff']['fleet'][p.ARROW]
        self.assertFalse(a['contract'])
        p.require_handoff_exit_home(p.ARROW,a)
        for mutation in ('token','occupant','owner','registry_berth','ship','acceptance'):
            with self.subTest(mutation=mutation):
                p,s=self.state(); a=s['handoff']['fleet'][p.ARROW]
                if mutation=='token': a['main_lease_token']='foreign-token'
                elif mutation=='occupant': a['occupant_id']=s['ship_id']
                elif mutation=='owner': a['reservation_owner_id']=s['ship_id']
                elif mutation=='registry_berth': a['main_berth_id']='central_berth'
                elif mutation=='ship': a['reserved_ship_id']=p.TORRENT
                else: a['physical_strict']=False
                with self.assertRaises(AssertionError): p.require_handoff_exit_home(p.ARROW,a)
        p,s=self.state(); t=s['handoff']['fleet'][p.TORRENT]; t['contract']=False
        with self.assertRaises(AssertionError): p.require_handoff_exit_home(p.TORRENT,t)

    def test_final_boarding_uses_current_candidate_above_floor_and_waits_for_settle(self):
        p,s=self.state(); p.stage='handoff_to_torrent'; p.last_state=s
        t=s['handoff']['fleet'][p.TORRENT]
        t.update(boarding=[-3.2,1.2,-9.35],candidate=True,boarding_distance=.86,reboard_blocked=False)
        s.update(player=[-3.98,0,-9.33],player_velocity=[0,0,.5],station_candidate=False)
        p.handoff_route=[t['boarding'][:]]
        keys,dx,dy,fire=p.update(s,1)
        self.assertEqual(keys,set()); self.assertEqual((dx,dy,fire),(0,0,False))
        self.assertEqual(p.stage,'handoff_to_torrent')
        self.assertEqual(len(p.handoff_route),1)
        s['player_velocity']=[0,0,0]
        keys,dx,dy,fire=p.update(s,1.1)
        self.assertEqual(keys,set()); self.assertEqual(p.stage,'handoff_torrent_ready')
        self.assertFalse(p.handoff_route)
        self.assertNotIn('torrent_board_press',p.handoff_receipts)

    def test_reclaim_requires_fresh_torrent_stream(self):
        p,s=self.state(); p.stage='handoff_torrent_board'; p.last_state=s
        t=s['handoff']['fleet'][p.TORRENT]
        p.handoff_receipts['torrent_board_press']=p.handoff_receipt(s)
        s.update(phase='START_ENGINES',transition_busy=False)
        t.update(piloted=True,seated=True,camera=True,reserved=True,player_reservation=True,
                 command_stream=t['stream'],command_sequence=1,next_sequence=2)
        with self.assertRaisesRegex(AssertionError,'fresh current producer epoch'): p.update(s,1)



class GuidedExitTests(unittest.TestCase):
    PHASES = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
              'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN', 'COMPLETE']

    def observation(self):
        s = {key: index+1 for index, key in enumerate(native.GuidedExitPilot.IDS)}
        s.update(mode='guided', sequence=1, frame=100, phase='COMPLETE', paused=False,
                 gameplay_snapshot_fresh=True, window_focused=True,
                 player=[12, 0, 0], spawn=[0, 0, 0], position=[0, 1.15, -10],
                 parked=[0, 1.15, -10], velocity=[0, 0, 0],
                 default_sampler=True, tuning_unchanged=True, destroyed=False,
                 shot_accepted=True, command_fire=False, piloted=False, seated=False,
                 control_enabled=True, guided_complete=True, active_ship=True,
                 exit_error=.17, lease=True, lease_free=False, home_lease_token='actual-home-token',
                 parked_exact=True, contract=True, landed=True,
                 telemetry={'engine': 'OFFLINE', 'hull': 80}, tuning={'mouse': .002, 'brake': 20},
                 native_keys={'escape': False, 'tab': False, 'return': False},
                 ui={'main_visible': True, 'exit_visible': True, 'exit_enabled': True,
                     'exit_text': 'EXIT TO DESKTOP', 'exit_path': '/Main/HUD/Pause/ExitButton',
                     'focus_path': '/Main/HUD/Pause/ResumeButton', 'focus_is_exit': False})
        return s

    def ready(self, pilot_type=native.GuidedExitPilot):
        p, s = pilot_type(), self.observation()
        p.stage = 'exit'
        p.identities = (s['player_id'], s['ship_id'])
        p.phases = self.PHASES.copy()
        p.max_walk = 12; p.max_excursion = 100
        p.shot = p.fired = True
        # The original physical disembarkation press may still be down.
        p.tap_key = 'e'; p.tap_frame = 99; p.tap_until = 2
        snapshot = copy.deepcopy(s)
        if isinstance(p, native.GuidedExitPilot):
            p.expected_pid = s['pid']
            p.validate_observation(snapshot)
        controls = p.update(snapshot, 1)
        return p, s, controls

    def tick(self, p, s, now, **changes):
        s.update(changes)
        s['sequence'] += 1
        if not s['paused']: s['frame'] += 1
        s['gameplay_snapshot_fresh'] = not s['paused']
        snapshot = copy.deepcopy(s)
        p.validate_observation(snapshot)
        return p.update(snapshot, now)

    def request_exit(self):
        p, s, _ = self.ready()
        self.assertEqual(self.tick(p, s, 1.11)[0], {'Escape'})
        self.assertEqual(self.tick(p, s, 1.15, paused=True)[0], {'Escape'})
        self.assertEqual(self.tick(p, s, 1.20)[0], set())
        self.assertEqual(self.tick(p, s, 1.31)[0], {'Tab'})
        self.assertEqual(self.tick(p, s, 1.40)[0], set())
        s['ui']['focus_is_exit'] = True
        s['ui']['focus_path'] = s['ui']['exit_path']
        s['native_keys']['tab'] = True
        self.assertEqual(self.tick(p, s, 1.51)[0], set())
        s['native_keys']['tab'] = False
        self.assertEqual(self.tick(p, s, 1.52)[0], {'Return'})
        return p, s

    def test_default_guided_complete_releases_e_and_requires_os0_instead_of_early_success(self):
        old, _, old_controls = self.ready(native.Pilot)
        self.assertIsNotNone(old.result)
        self.assertIn('e', old_controls[0])
        p, s, controls = self.ready()
        self.assertEqual(controls, (set(), 0, 0, False))
        self.assertIsNone(p.result)
        self.assertIsNone(p.tap_key)
        self.assertEqual(p.stage, 'pause')
        self.assertEqual(p.guided_result, old.result)
        self.assertEqual(p.receipts['complete'], s)
        with self.assertRaisesRegex(AssertionError, 'normal UI OS0'):
            p.finish(0)
        self.assertIsNone(p.result)

    def test_guided_flight_prefix_keeps_original_brake_and_thrust_commands(self):
        guided, original = native.GuidedExitPilot(), native.Pilot()
        s = self.observation()
        s.update(phase='TARGET_PRACTICE', camera=[0, 8, -69],
                 right=[1, 0, 0], up=[0, 1, 0], back=[0, 0, 1],
                 targets=[], upright=1, lease_free=True, landed=False)
        guided.expected_pid = s['pid']
        for p in (guided, original):
            p.stage = 'launch'; p.identities = (s['player_id'], s['ship_id'])
        for frame, position, velocity in [(100, [0, 7.5, -72.5], [0, 0, 0]),
                                           (101, [0, 7.5, -72.5], [0, 0, -20]),
                                           (102, [0, 8, -74], [0, 0, 0])]:
            s.update(frame=frame, sequence=frame, position=position, velocity=velocity)
            snapshot = copy.deepcopy(s)
            guided.validate_observation(snapshot)
            expected = original.update(snapshot, frame/60)
            self.assertEqual(guided.update(snapshot, frame/60), expected)
            self.assertEqual(guided.stage, original.stage)
            self.assertIsNone(guided.result)

    def test_ui_focus_press_release_and_real_zero_exit_complete_same_guided_sortie(self):
        p, s = self.request_exit()
        self.assertTrue(p.quit_requested)
        self.assertEqual(p.stage, 'quit_wait')
        self.assertTrue(p.receipts['exit_ui']['ui']['focus_is_exit'])
        self.assertIsNone(p.result)
        self.assertEqual(self.tick(p, s, 1.62)[0], set())
        self.assertEqual(self.tick(p, s, 2)[0], set())
        result = p.finish(0)
        self.assertTrue(result['normal_ui_exit'])
        self.assertEqual(result['exit_code'], 0)
        self.assertEqual(result['phases'], self.PHASES)
        self.assertEqual(result['same_actor_identities'], {k: s[k] for k in p.IDS})
        self.assertEqual(result['receipts']['complete']['home_lease_token'], s['home_lease_token'])
        self.assertNotIn('pause', [row['stage'] for row in p.guided_result['stages']])

    def test_early_death_and_wrong_exit_never_complete(self):
        p = native.GuidedExitPilot()
        for code in (0, 1, -9, -15):
            with self.subTest(stage='boot', code=code), self.assertRaises(AssertionError):
                p.finish(code)
        p, _ = self.request_exit()
        for code in (1, -9, -15):
            with self.subTest(stage='quit_wait', code=code), self.assertRaises(AssertionError):
                p.finish(code)
        self.assertIsNone(p.result)

    def test_ui_cannot_use_disabled_unfocused_or_unreleased_controls(self):
        p, s, _ = self.ready()
        s['native_keys']['return'] = True
        self.assertEqual(self.tick(p, s, 1.11)[0], set())
        self.assertFalse(p.quit_requested)
        for change in ({'exit_enabled': False}, {'exit_visible': False},
                       {'exit_text': 'OTHER'}, {'focus_path': ''}):
            p, s, _ = self.ready()
            s['ui'].update(change)
            with self.subTest(change=change), self.assertRaises(AssertionError):
                self.tick(p, s, 1.11, paused=True)
        p, s, _ = self.ready()
        with self.assertRaisesRegex(AssertionError, 'window retains keyboard focus'):
            self.tick(p, s, 1.11, window_focused=False)

    def test_ui_tail_rejects_identity_lease_dock_control_or_offline_changes(self):
        changes = [{key: 999} for key in native.GuidedExitPilot.IDS]
        changes += [{'home_lease_token': 'substituted'}, {'lease': False}, {'contract': False},
                    {'parked_exact': False}, {'control_enabled': False}, {'guided_complete': False},
                    {'seated': True}, {'piloted': True}, {'active_ship': False}, {'exit_error': .25},
                    {'landed': False}, {'telemetry': {'engine': 'ONLINE', 'hull': 80}},
                    {'default_sampler': False}, {'tuning_unchanged': False}, {'destroyed': True}]
        for change in changes:
            p, s, _ = self.ready()
            with self.subTest(change=change), self.assertRaises(AssertionError):
                self.tick(p, s, 1.11, **change)
            self.assertIsNone(p.result)

    def test_paused_snapshot_keeps_gameplay_frame_stale_and_sequence_advances(self):
        p, s, _ = self.ready()
        frame = s['frame']
        self.tick(p, s, 1.11, paused=True)
        self.assertEqual(p.last_state['frame'], frame)
        self.assertGreater(p.last_state['sequence'], p.receipts['complete']['sequence'])
        self.assertFalse(p.last_state['gameplay_snapshot_fresh'])
        with self.assertRaisesRegex(AssertionError, 'ordered Guided'):
            p.validate_observation(copy.deepcopy(p.last_state))
        p, s, _ = self.ready()
        s.update(paused=True, sequence=2, gameplay_snapshot_fresh=True)
        with self.assertRaisesRegex(AssertionError, 'never claims fresh Player motion'):
            p.validate_observation(s)
        p = native.GuidedExitPilot(); s = self.observation()
        p.expected_pid = s['pid']; s.update(paused=True, gameplay_snapshot_fresh=False)
        with self.assertRaisesRegex(AssertionError, 'remains unpaused'):
            p.validate_observation(s)

    def test_shutdown_capture_preserves_actual_raw_file_and_reports_clean_markers(self):
        with tempfile.TemporaryDirectory() as root:
            profile, output = Path(root)/'profile', Path(root)/'output'
            path = profile/'data'/'godot'/'app_userdata'/'Mudds'/'mudds_user_data.json'
            path.parent.mkdir(parents=True); output.mkdir()
            document = {'schema_version': 1, 'generation': 4, 'commit': {'id': 'actual-commit'},
                        'payload': {'crash_recovery': {'state': 'clean'},
                                    'safe_start_recovery': {'state': 'clean_shutdown'}}}
            raw = (json.dumps(document, indent=3)+'\n').encode()
            path.write_bytes(raw)
            captured = native.capture_guided_shutdown(profile, output)
            self.assertTrue(captured['captured'])
            self.assertEqual(captured['crash_recovery_state'], 'clean')
            self.assertEqual(captured['safe_start_recovery_state'], 'clean_shutdown')
            self.assertEqual((output/captured['artifact']).read_bytes(), raw)
            self.assertEqual(path.read_bytes(), raw)


class ZenithReturnReuseTests(unittest.TestCase):
    """Fresh literal combined-observer shape; no engine or display is launched."""
    @staticmethod
    def observation():
        admission = NativeSortieSafetyTests().arm_observation()
        tuning = dict(canopy=1, boarding=1, exit=1, cooldown=.24, maximum_speed=94,
            thrust=42, brake=54, drag=3.8, response=14, yaw=94, assist=7.2, mouse=.0022,
            boost_speed=126, boost_multiplier=1.42, maximum_hull=68, impact_threshold=34,
            impact_scale=1.8, impact_cooldown=.5)
        admission['ship_tuning'] = copy.deepcopy(tuning)
        admission['boarding'] = [14.35,4.73,53.85]
        sample = dict(mode='zenith-return-reuse', actors_current=True, frame=100, sequence=1, pid=700,
            main_id=admission['main_id'], world_id=admission['world_id'], player_id=admission['player_id'],
            capsule_id=admission['capsule_id'], shape_id=admission['shape_id'], ship_id=admission['ship_id'],
            berth_id=admission['home_berth_instance_id'], source_id=110, seat_id=111,
            target_instance_id=112, target_adapter_id=113, camera_id=114, chase_camera_id=114, cockpit_camera_id=115,
            phase='INTRO', paused=False, menu_ready=True, guided_complete=False,
            definition_id='zenith_b7_observed', home_id='zenith_fleet_dock_berth',
            player=[-8.5,.18,11], spawn=[-8.5,.18,11], position=[22,5.28,53.3], parked=[22,5.28,53.3],
            boarding=[14.35,4.73,53.85], exit=[14.15,4.73,54.15], capture_position=[22,15.28,35.3],
            right=[1,0,0], up=[0,1,0], back=[0,0,1], camera=[22,9,68],
            camera_right=[1,0,0], camera_up=[0,1,0], camera_back=[0,0,1], camera_view='CHASE',
            ship_invert_y=False, velocity=[0,0,0], ship_velocity=[0,0,0],
            walk_forward=[0,0,-1], walk_right=[1,0,0], capsule_geometry=[.38,1.94], capsule_enabled=True,
            walk_tuning=copy.deepcopy(native.LifeTowPilot.DEFAULT_WALK), ship_tuning=tuning,
            default_controls=True, default_sampler=True, tuning_unchanged=True, physics_ticks=60, time_scale=1,
            destroyed=False, hull=68, remote_piloted=False, control_enabled=True, seated=False,
            seated_at_pilot=False, piloted=False, active_ship=False, player_camera=True, ship_camera=False,
            transition_busy=False, grounded=True, supported=True, support_collider='/Main/ShipyardWorld/Deck',
            mouse_captured=True, candidate=False, station_candidate=False, boarding_distance=70,
            reboard_blocked=False, boarding_reserved=False, native_interact=False, native_landing=False,
            native_thrust=False, native_fire=False, flight_demand=False, engine='OFFLINE', landed=True,
            landing_active=False, capture=False, parked_exact=True, lease=True, lease_free=False,
            lease_token='zenith-initial', contract=False, input_stream=1, source_enabled=True,
            application_focused=True, admission=admission,
            endpoints=dict(clear=[22,5.28,33.3], climb=[22,25.28,15.3], lane=[22,25.28,-24.7],
                wing_port=[14.8,4.2,57.2], wing_clear=[20.4,4.2,59.2], reapproach=[18.2,4.2,58.2]),
            command=dict(schema_version=4, sequence=0, timestamp_usec=0, stream_id=0,
                throttle=0, yaw=0, pitch=0, roll=0, look_yaw_delta=0, look_pitch_delta=0,
                camera_distance_delta=0, boost=False, brake=False, hover=False, fire=False,
                barrel_roll=False, engine_start=False, engine_stop=False, landing=False,
                interact=False, camera_toggle=False, fire_pressed=False),
            native_control=dict(boost=False, roll=False, brake=False, hover=False, camera=False),
            landing=dict(active=False, elapsed=0, timeout_seconds=24, stall_elapsed=0,
                         stall_timeout_seconds=4, last_abort_reason=''),
            weapon_source=1104, weapon=dict(range=420, damage=28), shot=dict(present=False, request={}),
            target=dict(name='TargetDrone01', target_id='DRONE-01', base_position=[-13,7,-95],
                position=[-12,7,-95], health=100, maximum_health=100, destroyed=False, components={},
                hit_source=dict(source_id=0, source_entity_id=0, weapon_id='', sequence=-1, presentation_receipt_id=-1)),
            boarding_confirmation=dict(adapter=dict(view=dict(state='approach'))),
            native_keys=dict(escape=False, tab=False, **{'return':False}),
            ui=dict(main_visible=True, exit_visible=True, exit_enabled=True, exit_text='EXIT TO DESKTOP',
                exit_path='/Main/HUD/Exit', focus_path='/Main/HUD/Exit', focus_is_exit=True),
            save=dict(path='/tmp/private/data/mudds_user_data.json', source='primary', generation=1, payload={}))
        return sample

    def initial(self):
        pilot = native.ZenithReturnReusePilot(); sample = self.observation()
        pilot.validate_observation(sample)
        return pilot, sample

    @staticmethod
    def flight_sample(sample, frame=101):
        s = copy.deepcopy(sample); s.update(frame=frame, sequence=frame-99, phase='FREE_FLIGHT',
            piloted=True, seated=True, seated_at_pilot=True, active_ship=True, ship_camera=True,
            capsule_enabled=False, player_camera=False, grounded=False, supported=False,
            landed=False, lease=False, lease_free=True, lease_token='', parked_exact=False,
            engine='ONLINE', input_stream=3, position=[22,25.28,15.3])
        s['command']['stream_id'] = 3; s['command']['sequence'] = frame
        return s

    def test_full_literal_shape_initial_prefix_and_each_owned_identity(self):
        pilot,sample = self.initial()
        self.assertEqual(pilot.admission.mode, 'life-arm')
        self.assertEqual(len(pilot.admission.config['goals']), 15)
        self.assertEqual(set(pilot.IDS)-set(sample), set())
        for key in ('main_id','world_id','player_id','ship_id','source_id','chase_camera_id','cockpit_camera_id'):
            p,s = self.initial(); p.stage='depart'; bad=self.flight_sample(s)
            bad[key] += 900
            with self.subTest(key=key), self.assertRaises(AssertionError): p.validate_observation(bad)
        p,s=self.initial(); p.stage='depart'; bad=self.flight_sample(s)
        bad['endpoints']['clear'][2] -= 1
        with self.assertRaises(AssertionError): p.validate_observation(bad)

    def test_boost_requires_speed_above_authored_cruise_and_records_every_release_tail(self):
        p,s=self.initial(); p.enter('boost',s)
        for index in range(1,17):
            current=self.flight_sample(s,100+index)
            current['command'].update(boost=True,throttle=1)
            current['native_control']['boost']=True; current['native_thrust']=True
            current['ship_velocity']=[0,0,-13.23*index/16]
            p.validate_observation(current)
        self.assertNotIn('boost',p.handling)  # Prior16tick/13.23m/s attempt does not qualify.
        p.update(current,1); self.assertEqual(p.stage,'boost')
        fast=self.flight_sample(s,117); fast['command'].update(boost=True,throttle=1)
        fast['native_control']['boost']=True; fast['native_thrust']=True
        fast['ship_velocity']=[0,0,-95]; p.validate_observation(fast); p.update(fast,1.1)
        self.assertEqual(p.stage,'boost_brake')
        self.assertGreater(p.handling['boost']['speed'],94)
        self.assertEqual(p.control_pulses['boost']['release_request']['count'],17)
        tail=self.flight_sample(s,118); tail['command'].update(boost=True,throttle=1)
        tail['ship_velocity']=[0,0,-96]; p.validate_observation(tail)
        self.assertEqual(p.control_ticks['boost'],18)
        self.assertIsNone(p.control_pulses['boost']['released'])
        neutral=self.flight_sample(s,119); neutral['command']['brake']=True
        neutral['native_control']['brake']=True; neutral['ship_velocity']=[0,0,-80]
        p.validate_observation(neutral)
        self.assertEqual(p.control_pulses['boost']['released']['count'],18)
        self.assertEqual(len(p.control_pulses['boost']['samples']),19)
        self.assertIn('brake',p.handling)

    def test_roll_requires_thirty_degrees_from_captured_upright_baseline_then_neutral_release(self):
        p,s=self.initial(); p.enter('roll',s)
        for index,angle in enumerate((10,20,31),start=1):
            current=self.flight_sample(s,100+index); radians=math.radians(angle)
            current['up']=[math.sin(radians),math.cos(radians),0]
            current['right']=[math.cos(radians),-math.sin(radians),0]
            current['command']['roll']=-1; current['native_control']['roll']=True
            p.validate_observation(current)
            if angle<30: self.assertNotIn('roll',p.handling)
        self.assertGreaterEqual(p.handling['roll']['roll_degrees'],30)
        p.update(current,1); self.assertEqual(p.stage,'hover')
        tail=self.flight_sample(s,104); tail['command']['roll']=-1
        tail['up']=current['up'][:]; tail['right']=current['right'][:]
        p.validate_observation(tail)
        keys,*_=p.update(tail,1.1); self.assertNotIn('h',keys)
        self.assertEqual(p.control_ticks['roll'],4)
        neutral=self.flight_sample(s,105); neutral['up']=current['up'][:]; neutral['right']=current['right'][:]
        p.validate_observation(neutral)
        self.assertEqual(p.control_pulses['roll']['released']['count'],4)
        restored=self.flight_sample(s,106); angle=math.radians(15)
        restored['up']=[math.sin(angle),math.cos(angle),0]
        restored['command']['hover']=True; restored['native_control']['hover']=True
        p.validate_observation(restored); self.assertIn('hover',p.handling)

    def test_handling_rejects_preexisting_tilt_or_concurrent_roll_steering(self):
        p,s=self.initial(); tilted=copy.deepcopy(s); tilted['up']=[.8,.6,0]
        with self.assertRaises(AssertionError): p.enter('roll',tilted)
        p,s=self.initial(); moving=copy.deepcopy(s); moving['ship_velocity']=[0,0,-1]
        with self.assertRaises(AssertionError): p.enter('boost',moving)
        for key in ('yaw','pitch','look_yaw_delta','look_pitch_delta'):
            with self.subTest(key=key):
                p,s=self.initial(); p.enter('roll',s); current=self.flight_sample(s)
                current['command'].update(roll=-1); current['command'][key]=.01
                current['native_control']['roll']=True
                with self.assertRaises(AssertionError): p.validate_observation(current)

    def test_one_actual_repeater_hit_and_retained_receipt_reject_replay_or_other_target(self):
        for fault in (None,'source','target','damage','sequence','native'):
            with self.subTest(fault=fault):
                p,s=self.initial(); p.stage='weapon_fire'; p.first_stream=3
                baseline=self.flight_sample(s)
                p.weapon['pre_fire']=p.weapon_receipt(baseline)
                hit=self.flight_sample(s,102); hit['native_fire']=True; hit['command']['fire']=True
                request=dict(source_id=1104, source_entity_id=hit['ship_id'], weapon_id='zenith_interceptor_repeater',
                    sequence=0,presentation_receipt_id=9,range=420,damage=28)
                hit['target']['health']=72
                hit['target']['hit_source']={k:request[k] for k in
                    ('source_id','source_entity_id','weapon_id','sequence','presentation_receipt_id')}
                hit['shot']=dict(present=True,accepted=True,resolved=True,hit=True,damaged=True,status='damaged',destroyed=False,
                    source_id=1104,source_entity_id=hit['ship_id'],target_entity_id=hit['target_instance_id'],
                    damageable_id=hit['target_adapter_id'],applied_damage=28,remaining_health=72,request=request,
                    damage_result=dict(accepted=True,applied_damage=28,health=72,maximum_health=100,destroyed=False))
                if fault=='source': hit['shot']['source_id']=1103
                elif fault=='target': hit['shot']['target_entity_id']+=1
                elif fault=='damage': hit['shot']['applied_damage']=27
                elif fault=='sequence': request['sequence']=1
                elif fault=='native': hit['native_fire']=False
                if fault:
                    with self.assertRaises(AssertionError): p.validate_weapon(hit)
                else:
                    p.validate_weapon(hit); first=p.weapon['hit']
                    hit['native_fire']=False; hit['command']['fire']=False
                    p.stage='return_capture'; p.validate_weapon(hit)
                    self.assertIs(p.weapon['hit'],first)
                    self.assertEqual(p.weapon['hit']['target']['health'],72)

    def test_dynamic_landing_timeout_stall_and_single_l_press_remain_binding(self):
        for fault in (None,'timeout','stall','changed_budget','second_press'):
            with self.subTest(fault=fault):
                p,s=self.initial(); p.stage='land'; p.receipts['landing_1']=p.receipt(s)
                active=self.flight_sample(s); active.update(landing_active=True,native_landing=True)
                active['landing'].update(active=True,elapsed=1,timeout_seconds=30)
                p.validate_observation(active)
                self.assertEqual(p.landing_edges,[1,0]); self.assertEqual(p.landing_timeout,30)
                second=self.flight_sample(s,102); second.update(landing_active=True,native_landing=False)
                second['landing'].update(active=True,elapsed=2,timeout_seconds=30)
                if fault=='timeout': second['landing']['elapsed']=30.01
                elif fault=='stall': second['landing']['stall_elapsed']=4.01
                elif fault=='changed_budget': second['landing']['timeout_seconds']=31
                if fault in ('timeout','stall','changed_budget'):
                    with self.assertRaises(AssertionError): p.validate_observation(second)
                else:
                    p.validate_observation(second)
                    if fault=='second_press':
                        third=self.flight_sample(s,103); third.update(landing_active=True,native_landing=True)
                        third['landing'].update(active=True,elapsed=3,timeout_seconds=30)
                        with self.assertRaises(AssertionError): p.validate_observation(third)
                    else: self.assertEqual(p.landing_last[1]['landing']['elapsed'],2)

    def test_return_alignment_requires_upright_and_real_capture_before_single_landing_press(self):
        p,s=self.initial(); p.stage='return_align'; p.stage_since=0
        for frame,upright,capture in ((101,False,False),(102,True,False),(103,True,True)):
            current=self.flight_sample(s,frame); current['capture']=capture
            if not upright: current['up']=[1,-.00766,0]
            p.validate_observation(current)
            keys,*_=p.update(current,1+(frame-101)*.1)
            if not capture:
                self.assertEqual(p.stage,'return_align'); self.assertNotIn('l',keys)
                self.assertTrue({'Prior','h'} <= keys)
                self.assertNotIn('landing_1',p.receipts)
            else:
                self.assertEqual(p.stage,'land'); self.assertIn('l',keys)
                self.assertEqual(p.receipts['landing_1']['frame'],103)
        self.assertEqual(p.landing_edges,[0,0])  # Only actual native acknowledgement increments this.

    def test_reboard_waits_for_first_matching_consumed_stream_with_full_pilot_ownership(self):
        def boundary():
            p,s=self.initial(); p.stage='board'; p.stage_since=0
            p.first_stream=3; p.retired_stream=7; p.board_streams=[3]
            current=self.flight_sample(s)
            current.update(phase='START_ENGINES',landed=True,parked_exact=True,lease=True,
                lease_free=False,lease_token='reboard-home',contract=True,input_stream=9,position=s['parked'][:])
            current['command']=copy.deepcopy(s['command'])  # Actual frame4593: cleared stream0/sequence0.
            return p,current
        p,current=boundary(); p.validate_observation(current); p.update(current,1)
        self.assertEqual(p.stage,'board'); self.assertNotIn('seated_2',p.receipts)
        self.assertEqual(p.board_streams,[3])
        ready=copy.deepcopy(current); ready.update(frame=102,sequence=3)
        ready['command'].update(stream_id=9,sequence=0,timestamp_usec=90352411)
        p.validate_observation(ready); p.update(ready,1.1)
        self.assertEqual(p.stage,'reuse_seated'); self.assertEqual(p.stage_frame,102)
        self.assertEqual(p.board_streams,[3,9])
        self.assertEqual(p.receipts['seated_2']['command']['stream_id'],9)
        for fault in ('stale','nonzero_sequence','active','wrong_owner','wrong_camera'):
            with self.subTest(fault=fault):
                p,current=boundary()
                if fault=='stale': current['command']['stream_id']=7
                elif fault=='nonzero_sequence': current['command']['sequence']=1
                elif fault=='active': current['command']['throttle']=1
                elif fault=='wrong_owner': current['active_ship']=False
                else: current['ship_camera']=False
                with self.assertRaises(AssertionError): p.validate_observation(current)
        p,current=boundary(); p.validate_observation(current)
        with self.assertRaisesRegex(AssertionError,'executor phase bound 12s'): p.update(current,12.001)

    def test_new_phase_guards_fresh_epoch_and_both_camera_consumers(self):
        p,s=self.initial(); p.stage='climb'; p.stage_since=10
        p.stage_guard(25)
        with self.assertRaises(AssertionError): p.stage_guard(25.001)
        p,s=self.initial(); p.stage='camera_cockpit'
        cockpit=self.flight_sample(s); cockpit.update(camera_view='COCKPIT',camera_id=cockpit['cockpit_camera_id'])
        cockpit['native_control']['camera']=True; cockpit['command']['camera_toggle']=True
        p.validate_observation(cockpit)
        p.stage='camera_chase'; chase=self.flight_sample(s,102)
        chase['native_control']['camera']=True; chase['command']['camera_toggle']=True
        p.validate_observation(chase)
        self.assertIn('camera_cockpit',p.handling); self.assertIn('camera_chase',p.handling)
        p.stage='board'; p.stage_since=0; p.first_stream=3; p.retired_stream=5; p.now=1
        seated=copy.deepcopy(chase); seated.update(phase='START_ENGINES',landed=True,parked_exact=True,
            lease=True,lease_token='fresh-home',contract=True,input_stream=5)
        seated['command']['stream_id']=5; p.last_state=seated
        with self.assertRaises(AssertionError): p.update(seated,1)

    def test_actual_file_both_home_captures_and_clean_close_preserve_unrelated_slots(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); profile=root/'profile'; output=root/'results'
            (profile/'data').mkdir(parents=True); output.mkdir(); path=profile/'data'/'mudds_user_data.json'
            files=native.ZenithReturnReuseFiles(profile,output); p=native.ZenithReturnReusePilot()
            s=self.observation(); s['save']['path']=str(path)
            payload=dict(protected_inventory=dict(quantity=7),
                crash_recovery=dict(state='running',unclean_start_count=0,session_id=1,startup_generation=1),
                safe_start_recovery=dict(state='stable',consecutive_failure_count=0,safe_settings_recommended=False,startup_generation=1),
                session_diagnostics=dict(events=[]))
            doc=dict(schema_version=1,generation=1,commit=dict(id='baseline-fixture'),payload=payload)
            path.write_text(json.dumps(doc)); s['save']['payload']=copy.deepcopy(payload); files.observe(s,p)
            p.receipts['wing_clear_1']={}; doc['generation']=2
            path.write_text(json.dumps(doc)); files.observe(s,p)
            p.trips=[dict(flight=1),dict(flight=2)]; doc['generation']=3
            path.write_text(json.dumps(doc)); files.observe(s,p)
            self.assertTrue(p.file_home)
            doc['generation']=4; doc['commit']['id']='clean-fixture'
            payload['crash_recovery']['state']='clean'; payload['safe_start_recovery']['state']='clean_shutdown'
            payload['session_diagnostics']['events']=[dict(event_code='session_ended',session_id=1)]
            path.write_text(json.dumps(doc)); files.finish(s,p)
            self.assertEqual(set(files.snapshots),{'baseline','home-1','home-2','orderly-close'})
            broken=copy.deepcopy(doc); broken['payload']['protected_inventory']['quantity']=6
            with self.assertRaises(AssertionError): files.require_preserved(doc,broken)
            self.assertEqual(native.CAP,300)
            self.assertEqual(native.ZenithReturnReusePilot.WEAPON_CAP,25)


class ZenithTorrentHandbackTests(unittest.TestCase):
    """Reuse literal craft/claim fixtures; packaged OS input supplies qualification."""
    @staticmethod
    def observation():
        s=ZenithReturnReuseTests.observation()
        t=TorrentReturnReuseTests().observation()
        _, pair=TorrentArrowHandoffTests().state()
        z=copy.deepcopy(pair['handoff']['fleet'][native.TorrentArrowHandoffPilot.ARROW])
        r=copy.deepcopy(pair['handoff']['fleet'][native.TorrentArrowHandoffPilot.TORRENT])
        s['mode']=native.ZenithTorrentHandbackPilot.MODE
        for k in ('main_id','world_id','player_id','capsule_id','shape_id','pid'):
            t[k]=s[k]
        t.update(ship_id=601,source_id=602,seat_id=603,berth_id=604,
                 capsule_geometry=s['capsule_geometry'][:],application_focused=True)
        for row,craft,key,source,cameras in ((z,s,'zenith_b7_observed',1104,(114,115)),
                                           (r,t,'torrent_provisional',1101,(605,606))):
            row.update({k:craft[k] for k in ('ship_id','source_id','seat_id','berth_id','position','boarding','exit','hull')})
            row.update(definition_id=key,home_id=craft['home_id'],combat_source=source,
                chase_camera_id=cameras[0],cockpit_camera_id=cameras[1],active=key=='torrent_provisional',
                stream=1,next_sequence=0,delivery_generation=1,command_stream=0,
                tuning=copy.deepcopy(craft['ship_tuning']),hull=68 if key=='zenith_b7_observed' else 100,
                physical_strict=True,contract=False,lease_token=key+'-initial',main_lease_token=key+'-initial',
                main_berth_id=craft['home_id'],occupant_id=craft['ship_id'],reservation_owner_id=craft['ship_id'],
                reserved_ship_id=key)
        s['handoff']=dict(actors_current=True,fleet={'zenith_b7_observed':z,'torrent_provisional':r},
            active_ship_id=t['ship_id'],piloting=False,consumed_ship_id=0,consumed_stream=-1,consumed_sequence=-1)
        s['torrent']=t
        ZenithTorrentHandbackTests.sync(s)
        return s

    @staticmethod
    def sync(s):
        for craft,key in ((s,'zenith_b7_observed'),(s['torrent'],'torrent_provisional')):
            row=s['handoff']['fleet'][key]
            craft.update(piloted=row['piloted'],seated_at_pilot=row['seated'],active_ship=row['active'],
                         ship_camera=row['camera'],boarding_reserved=row['reserved'])
        for k in ('frame','player','phase','seated','transition_busy','control_enabled','capsule_enabled','player_camera','native_interact'):
            s['torrent'][k]=copy.deepcopy(s[k])
        a=s['admission']
        for k in ('frame','player','phase','seated','transition_busy','control_enabled','capsule_enabled','native_interact',
                  'grounded','supported','mouse_captured'):
            a[k]=copy.deepcopy(s[k])
        a['position']=s['player'][:]

    def initial(self):
        p=native.ZenithTorrentHandbackPilot(); s=self.observation()
        p.validate_observation(copy.deepcopy(s))
        return p,s

    def tick(self,p,s,**changes):
        s.update(changes); s['frame']+=1; s['sequence']+=1
        self.sync(s)
        NativeSortieSafetyTests.arm_motion(s['admission'],p.observed_previous['admission'])
        sample=copy.deepcopy(s)
        p.validate_observation(sample)
        return sample

    def test_admission_uses_existing_fifteen_goals_and_retains_two_literal_craft(self):
        p,s=self.initial()
        self.assertIs(type(p.admission),native.LifeTowPilot)
        self.assertIs(type(p.guided),native.Pilot)
        self.assertEqual(p.admission.config['goals'],native.LifeTowPilot.ARM_GOALS)
        self.assertEqual(len(p.admission.config['goals']),15)
        self.assertEqual(set(p.handoff_initial['fleet']),{p.ZENITH,p.TORRENT})
        self.assertEqual(native.CAP,300)

    def test_replaced_primary_or_detached_actor_and_registered_source_fail(self):
        for target,field in [('top','main_id'),('top','player_id'),('top','capsule_id'),
                             ('top','chase_camera_id'),('torrent','opponent_id'),('torrent','ship_id'),
                             ('zenith_row','source_id'),('zenith_row','seat_id'),('torrent_row','area_id'),
                             ('torrent_row','berth_id'),('torrent_row','combat_source')]:
            with self.subTest(target=target,field=field):
                p,s=self.initial(); p.stage='initial_release'
                row=s if target=='top' else s['torrent'] if target=='torrent' else s['handoff']['fleet'][p.ZENITH if target=='zenith_row' else p.TORRENT]
                row[field]+=900
                with self.assertRaises(AssertionError): self.tick(p,s)

    def test_guided_cannot_be_completed_or_zenith_flown_before_real_torrent_suffix(self):
        for change in ('guided','zenith_flight','missing_drone'):
            p,s=self.initial(); p.stage='initial_release'
            if change=='guided': s['torrent']['guided_complete']=True
            elif change=='zenith_flight': s['handoff']['fleet'][p.ZENITH]['parked_exact']=False
            else: s['torrent']['targets'].pop()
            with self.subTest(change=change), self.assertRaises(AssertionError): self.tick(p,s)

    def exit_state(self):
        p,s=self.initial(); p.stage='handoff_zenith_exit'
        p.admission_result={'seated_physics_frames':90}; p.admission_neutral=90
        row=s['handoff']['fleet'][p.ZENITH]
        row.update(active=True,piloted=True,seated=True,camera=True,reserved=True,player_reservation=True,
                   stream=3,next_sequence=9,command_stream=3,command_sequence=8,command_neutral=False)
        s['handoff']['fleet'][p.TORRENT]['active']=False
        s['handoff'].update(active_ship_id=row['ship_id'],piloting=True)
        p.handoff_receipts['zenith_exit_press']=p.handoff_receipt(s)
        s.update(phase='DISEMBARKING',transition_busy=True,seated=True,capsule_enabled=False,
                 player_camera=False,native_interact=True)
        row['interact']=dict(frame=s['frame']+1,ship_id=row['ship_id'],source_id=row['source_id'],
            stream=3,sequence=8,native=True,valid=True,current=True)
        s['handoff'].update(consumed_ship_id=row['ship_id'],consumed_stream=3,consumed_sequence=8)
        s['boarding_confirmation']['adapter']['view']['state']='disembarking'
        return p,s

    def test_queued_exit_producer_and_lifecycle_consumer_survive_latest_foot_sample(self):
        p,s=self.exit_state()
        edge=self.tick(p,s)
        retained=copy.deepcopy(p.handoff_receipts['zenith_exit_transition'])
        row=s['handoff']['fleet'][p.ZENITH]
        row.update(piloted=False,seated=False,camera=False,reserved=False,player_reservation=False,
                   stream=4,next_sequence=0,delivery_generation=4,command_stream=0,command_sequence=0,command_neutral=True)
        s['handoff']['piloting']=False
        self.tick(p,s,phase='APPROACH_SHIP',transition_busy=False,seated=False,capsule_enabled=True,
                  player_camera=True,native_interact=False)
        self.assertEqual(p.handoff_receipts['zenith_exit_transition'],retained)
        self.assertEqual(retained['frame'],edge['frame'])
        self.assertEqual(retained['handoff']['consumed_stream'],3)
        self.assertEqual(len(p.handoff_edges),1)

    def test_exit_rejects_wrong_current_source_epoch_or_consumer(self):
        for failure in ('wrong_source','stale_epoch','wrong_consumer','no_native'):
            p,s=self.exit_state(); row=s['handoff']['fleet'][p.ZENITH]
            if failure=='wrong_source': row['interact']['source_id']+=1
            elif failure=='stale_epoch': row['interact']['stream']-=1
            elif failure=='wrong_consumer': s['handoff']['consumed_ship_id']=s['torrent']['ship_id']
            else: row['interact']['native']=False
            with self.subTest(failure=failure), self.assertRaises(AssertionError): self.tick(p,s)
            self.assertNotIn('zenith_exit_transition',p.handoff_receipts)

    def test_retired_source_pending_cursor_and_claims_cannot_reactivate(self):
        for field,value in (('pending',1),('next_sequence',8),('stream',9),('delivery_generation',9),
                            ('piloted',True),('camera',True),('reserved',True),('command_neutral',False)):
            p,s=self.initial(); p.stage='initial_release'
            p.remember_retired(p.ZENITH,s)
            s['handoff']['fleet'][p.ZENITH][field]=value
            with self.subTest(field=field), self.assertRaises(AssertionError): self.tick(p,s)

    def test_observation_gap_and_walk_board_exit_clear_deadlines_are_binding(self):
        p,s=self.initial(); s['frame']+=1
        with self.assertRaisesRegex(AssertionError,'every raw'): self.tick(p,s)
        cases=(('to_torrent','goal_since',15.001,'fifteen'),
               ('torrent_ready','board_since',12.001,'twelve'),
               ('handoff_zenith_exit','stage_since',10.001,'exit10'),
               ('torrent_clear','clear_since',12.001,'radial-clear'))
        for stage,timer,now,message in cases:
            p,s=self.initial(); p.stage=stage; p.last_state=s
            p.route=[('fixture',[0,0,15.5])]; p.goal_since=0
            setattr(p,timer,0)
            with self.subTest(stage=stage), self.assertRaisesRegex(AssertionError,message): p.update(s,now)

    def test_live_torrent_candidate_stops_before_inside_hull_marker(self):
        p,s=self.initial(); p.stage='to_torrent'; p.last_state=s; p.goal_since=0
        row=s['handoff']['fleet'][p.TORRENT]
        row.update(candidate=True,boarding_distance=6.5,reboard_blocked=False)
        p.route=[('torrent_candidate',[500,0,500])]
        keys,dx,dy,fire=p.update(s,1)
        self.assertEqual((keys,dx,dy,fire),(set(),0,0,False))
        self.assertEqual(p.stage,'torrent_ready')
        self.assertNotIn('torrent_board_press',p.handoff_receipts)

    def test_real_guided_suffix_uses_original_pilot_and_has_no_added_nonlanding_deadline(self):
        p,s=self.initial(); p.stage='guided'; p.last_state=s
        p.guided.stage='board'
        t=s['torrent']; t.update(phase='START_ENGINES',piloted=True,seated=True,active_ship=True)
        p.update(s,299)
        self.assertEqual(p.guided.stage,'launch')
        self.assertEqual(p.stage,'guided')
        self.assertEqual(p.guided.identities,(t['player_id'],t['ship_id']))
        self.assertFalse(p.guided_result)

    def test_guided_prefix_is_derived_from_observed_torrent_candidate_and_boarding(self):
        p,s=self.initial(); p.stage='torrent_ready'; p.board_since=0
        r=s['handoff']['fleet'][p.TORRENT]
        r.update(candidate=True,boarding_distance=6.5,reboard_blocked=False)
        approach=self.tick(p,s,phase='APPROACH_SHIP')
        self.assertEqual(p.handoff_receipts['torrent_approach']['frame'],approach['frame'])
        p.update(approach,1)
        self.assertEqual(p.stage,'handoff_torrent_board')
        r.update(reserved=True,player_reservation=True)
        s['boarding_confirmation']['adapter']['view']['state']='boarding'
        self.tick(p,s,phase='BOARDING',transition_busy=True,native_interact=True,control_enabled=False)
        r.update(piloted=True,seated=True,camera=True,stream=3,command_stream=3,
                 command_sequence=1,next_sequence=2)
        s['handoff']['piloting']=True
        s['boarding_confirmation']['adapter']['view']['state']='seated'
        seated=self.tick(p,s,phase='START_ENGINES',transition_busy=False,native_interact=False,
                         seated=True,capsule_enabled=False,player_camera=False)
        p.update(seated,2)
        self.assertEqual(p.stage,'guided')
        self.assertEqual(p.guided.phases,[approach['phase'],'BOARDING'])
        self.assertIsNone(p.guided.identities)  # Original Pilot initializes from the actual seated snapshot next.
        p.update(seated,2.1)
        self.assertEqual(p.guided.identities,(seated['torrent']['player_id'],seated['torrent']['ship_id']))
        self.assertEqual(p.guided.parked_forward,[-v for v in seated['torrent']['back']])

    def test_fresh_zenith_neutral_count_requires_current_consumed_stream(self):
        p,s=self.initial(); p.stage='final_neutral'
        p.first_stream=2; p.retired_zenith_stream=3; p.guided_result={'phases':['COMPLETE']}
        s['torrent'].update(guided_complete=True,targets=[],destroyed_targets=4,opponent_active=False)
        s['handoff']['fleet'][p.TORRENT].update(active=False,contract=True)
        r=s['handoff']['fleet'][p.ZENITH]
        r.update(active=True,piloted=True,seated=True,camera=True,reserved=True,player_reservation=True,
                 stream=4,command_stream=4,command_sequence=1,next_sequence=2)
        s['handoff'].update(active_ship_id=r['ship_id'],piloting=True)
        p.handoff_receipts['zenith_seated']=p.handoff_receipt(s)
        self.tick(p,s,phase='START_ENGINES',seated=True,capsule_enabled=False,player_camera=False)
        self.assertEqual(p.final_neutral,1)
        r['command_stream']=3
        with self.assertRaisesRegex(AssertionError,'fresh current fenced neutral'): self.tick(p,s)
        self.assertEqual(p.final_neutral,1)

    def test_outward_arm_reuses_existing_corner_guard(self):
        p,s=self.initial(); p.stage='outward_arm'; p.last_state=s; p.goal_since=0
        p.route=[('zenith_approach',[20.2,4.2,59.2])]
        p.walker.stage='walk_service'; p.walker.route=p.route; p.walker.index=0
        s.update(player=[20.2,4.2,59.2],walk_forward=[0,0,-1],walk_right=[1,0,0])
        p.walker.settled_frames=15
        p.update(s,1)
        self.assertFalse(p.walker.zenith_corner_safe(s))
        self.assertEqual(p.stage,'outward_arm')
        self.assertEqual(len(p.route),1)

    def wing_clear_fixture(self, point):
        p,s=self.initial()
        direction=native.unit([20.4-point[0],0,59.1-point[2]])
        s.update(phase='APPROACH_SHIP',player=list(point),velocity=[0,0,0],
                 walk_forward=direction,walk_right=[-direction[2],0,direction[0]])
        s['handoff']['fleet'][p.ZENITH].update(boarding_distance=8,reboard_blocked=False)
        self.sync(s); NativeSortieSafetyTests.arm_motion(s['admission'])
        p.observed_previous=p.last_state=copy.deepcopy(s)
        p.begin_walk('wing_clear',[('wing_clear',s['endpoints']['wing_clear'])],s)
        p.goal_since=0
        return p,s

    def test_wing_clear_actual_failed_point_steers_into_existing_corner_instead_of_departing(self):
        point=[20.1391,4.20165,59.1174]
        p,s=self.wing_clear_fixture(point)
        published=s['endpoints']['wing_clear'][:]
        self.assertLess(math.hypot(point[0]-published[0],point[2]-published[2]),.30)
        p.walker.settled_frames=15
        sample=self.tick(p,s)
        keys,_,_,_=p.update(sample,1)
        self.assertIn('w',keys)
        self.assertEqual(p.stage,'wing_clear')
        self.assertEqual(p.route,[('wing_clear',published)])
        self.assertTrue(p.walker.zenith_corner_required())
        self.assertFalse(p.walker.zenith_corner_safe(sample))
        self.assertEqual(p.walker.settled_frames,0)
        self.assertNotIn('zenith_clear',p.handoff_receipts)
        self.assertEqual(p.visited,[])

    def test_wing_clear_safe_boundary_settles_fifteen_current_samples_before_unchanged_reverse(self):
        p,s=self.wing_clear_fixture([20.30,4.2,59.20])
        published=s['endpoints']['wing_clear'][:]
        for _ in range(14):
            sample=self.tick(p,s); p.update(sample,1)
        self.assertEqual(p.stage,'wing_clear')
        self.assertEqual(p.walker.settled_frames,14)
        sample=self.tick(p,s); keys,_,_,_=p.update(sample,1)
        self.assertEqual(keys,set())
        self.assertEqual(p.stage,'to_torrent')
        self.assertEqual(p.visited[-1]['target'],published)
        self.assertEqual(p.visited[-1]['goal'],'wing_clear')
        self.assertEqual([(name,target) for name,target in p.route if name.startswith('reverse_')],
                         [('reverse_'+str(i),target) for i,target in enumerate(p.REVERSE_ARM)])
        self.assertEqual(p.route[11:16],[('reverse_11',[0,0,15.5]),
                         ('cargo_south',[0,0,13.5]),('cargo_port',[-8.5,0,13.5]),
                         ('reverse_12',[-8.5,0,15.5]),('reverse_13',[-8.5,0,13.5])])
        self.assertEqual(p.handoff_receipts['zenith_clear']['player'],[20.30,4.2,59.20])
        for point in ([20.299999,4.2,59.20],[20.30,4.2,59.200001]):
            p,s=self.wing_clear_fixture(point); p.walker.settled_frames=14
            sample=self.tick(p,s); p.update(sample,1)
            self.assertEqual(p.stage,'wing_clear')
            self.assertEqual(p.walker.settled_frames,0)

    def test_wing_clear_preserves_actual_support_and_fifteen_second_deadline(self):
        p,s=self.wing_clear_fixture([20.4,4.2,59.1])
        with self.assertRaisesRegex(AssertionError,'actual physical station floor support'):
            self.tick(p,s,supported=False)
        p,s=self.wing_clear_fixture([20.4,4.2,59.1])
        sample=self.tick(p,s)
        with self.assertRaisesRegex(AssertionError,'fifteen-second per-goal deadline'):
            p.update(sample,15.001)
        self.assertEqual(native.CAP,300)

    def test_central_cargo_detour_avoids_recorded_capsule_block_without_dropping_old_goals(self):
        root=Path(native.__file__).resolve().parents[2]
        world=(root/'scripts/world/shipyard_world.gd').read_text()
        activity=(root/'scripts/world/station_operations_activity.gd').read_text()
        self.assertIn('Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.0, 17.9))',world)
        self.assertIn('"name": "CrateOutboundSmall", "position": Vector3(3.62, 0.44, -1.9), "size": Vector3(0.7, 0.52, 0.8)',activity)
        # Expand the real fixed crate by the unchanged production capsule and
        # contact margin. The former horizontal leg crosses this forbidden box.
        radius,margin=.38,.002
        centre=(-6+3.62,17.9-1.9)
        minimum=(centre[0]-.7/2-radius-margin,centre[1]-.8/2-radius-margin)
        maximum=(centre[0]+.7/2+radius+margin,centre[1]+.8/2+radius+margin)
        self.assertLessEqual(minimum[1],15.6092557907104)
        self.assertGreaterEqual(maximum[1],15.6092557907104)
        self.assertTrue(-8.5<minimum[0]<maximum[0]<0)
        self.assertAlmostEqual(maximum[0],-1.64938831329346,delta=.002)
        p,s=self.wing_clear_fixture([20.30,4.2,59.20])
        p.walker.settled_frames=14
        sample=self.tick(p,s);p.update(sample,1)
        outbound=[target for _,target in p.route[11:15]]
        self.assertEqual(outbound,[[0,0,15.5],[0,0,13.5],[-8.5,0,13.5],[-8.5,0,15.5]])
        p,s=self.initial();p.stage='torrent_clear';p.last_state=s
        p.goal_since=p.clear_since=0
        point=[-7.6,0,-9.25]
        s.update(player=point,velocity=[0,0,0])
        p.route=[('clear',point)];p.clear_target=point
        s['handoff']['fleet'][p.TORRENT]['boarding_distance']=8
        p.update(s,1)
        self.assertEqual(p.stage,'connector')
        self.assertEqual(p.route,[('0',[-8.5,0,-9.25]),('1',[-8.5,0,13.5]),
                         ('2',[-8.5,0,15.5]),('cargo_south',[-8.5,0,13.5]),
                         ('cargo_east',[0,0,13.5]),('3',[0,0,15.5])])
        returning=[target for _,target in p.route[2:]]
        for route in (outbound,returning):
            for start,end in zip(route,route[1:]):
                with self.subTest(start=start,end=end):
                    self.assertTrue(max(start[0],end[0])<minimum[0]
                                    or min(start[0],end[0])>maximum[0]
                                    or max(start[2],end[2])<minimum[1]
                                    or min(start[2],end[2])>maximum[1])
        self.assertIn(('hub_forward',[0,0,13.5]),native.LifeTowPilot.GANTRY_GOALS)
        self.assertEqual(native.CAP,300)

    def test_reverse_stair_base_leg_uses_walk_input_while_other_legs_keep_existing_sprint(self):
        cases=(('to_torrent','reverse_8',[-5.7,.1673,51],[0,0,51],False),
               ('to_torrent','reverse_9',[0,0,51],[0,0,46.3],True),
               ('connector','0',[0,0,51],[-8.5,0,51],True))
        for stage,name,point,target,sprint in cases:
            with self.subTest(stage=stage,goal=name):
                p,s=self.initial(); p.stage=stage; p.last_state=s; p.goal_since=0
                direction=native.unit([target[0]-point[0],0,target[2]-point[2]])
                s.update(player=point,velocity=[0,0,0],walk_forward=direction,
                         walk_right=[-direction[2],0,direction[0]])
                p.route=[(name,target),('next',[0,0,39])]
                keys,dx,dy,fire=p.update(s,1)
                self.assertIn('w',keys)
                self.assertEqual('Shift_L' in keys,sprint)
                self.assertEqual((dx,dy,fire),(0,0,False))
                self.assertEqual(p.stage,stage)
                self.assertEqual(p.route[0],(name,target))
                self.assertEqual(s['walk_tuning'],native.LifeTowPilot.DEFAULT_WALK)

    def test_actual_sprint_stair_base_downsnap_remains_rejected_by_unchanged_3d_guard(self):
        before=[-4.10339736938477,.167291432619095,51.178337097168]
        after=[-3.94836783409119,.00049455463886261,51.1717338562012]
        velocity=[9.19166946411133,0,-.391436964273453]
        p,s=self.initial(); p.stage='to_torrent'
        s.update(frame=2920,phase='APPROACH_SHIP',player=before,velocity=velocity,
                 support_collider='/root/Boot/Main/ShipyardWorld/AftJunctionStack/Structure/LowerOpenDeck/StairBaseLanding')
        self.sync(s); NativeSortieSafetyTests.arm_motion(s['admission'])
        s['admission']['support_collider']=s['support_collider']
        p.observed_previous=p.last_state=copy.deepcopy(s)
        p.route=[('reverse_8',[0,0,51]),('reverse_9',[0,0,46.3])]
        self.assertTrue(s['grounded'] and s['supported'])
        self.assertGreater(native.norm(native.sub(after,before)),native.LifeTowPilot.DEFAULT_WALK['sprint']/60*1.25+.02)
        with self.assertRaisesRegex(AssertionError,'continuous physically supported handback walking without placement'):
            self.tick(p,s,player=after)
        self.assertTrue(s['grounded'] and s['supported'])
        self.assertEqual(s['admission']['completed_motion']['step_up'],{})
        self.assertEqual(s['admission']['completed_motion']['start'],before)
        self.assertEqual(s['admission']['completed_motion']['end'],after)
        self.assertEqual(p.last_state['frame'],2920)
        self.assertEqual(native.CAP,300)

    def test_runner_selector_all_snapshot_dispatch_and_actual_disk_marker_gate(self):
        source=Path(native.__file__).read_text()
        self.assertIn('"zenith-torrent-handback": ZenithTorrentHandbackPilot',source)
        self.assertIn('choices=(\'zenith-torrent-handback\'',source)
        self.assertIn('(ZenithTorrentHandbackPilot, GuidedExitPilot, BomberRearmPilot',source)
        self.assertIn("closed.get('crash_recovery_state') == 'clean'",source)
        self.assertIn("closed.get('safe_start_recovery_state') == 'clean_shutdown'",source)
        observer=Path(native.__file__).resolve().parents[2]/'scripts/diagnostics/native_sortie_observer.gd'
        text=observer.read_text()
        self.assertIn('"--native-sortie-observer=zenith-torrent-handback"',text)
        self.assertIn('_arrow_observation(true, false, _handback_torrent)',text)
        self.assertIn('_zenith_observation(true)',text)
        self.assertNotIn('_ship = _handback_torrent',text)


class NativeProcessExitReportingTests(unittest.TestCase):
    def test_nonzero_exit_and_trailing_output_survive_ui_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder)/'game.log'
            game = subprocess.Popen([sys.executable, '-c',
                "import os; os.write(1,b'trailing-exit-17\\n'); raise SystemExit(17)"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
            try:
                self.assertEqual(game.wait(timeout=5), 17)
                leg = dict(exit_code=None, reaped=False)
                with self.assertRaisesRegex(AssertionError, 'normal UI'):
                    code = native.record_terminal_game_exit(game, leg, log)
                    native.require(False, f'normal UI required (actual exit {code})')
                self.assertEqual(leg, dict(exit_code=17, reaped=True))
                self.assertEqual(log.read_bytes(), b'trailing-exit-17\n')
                self.assertEqual(game.poll(), 17)
            finally:
                if game.poll() is None:
                    game.kill(); game.wait(timeout=5)
                game.stdout.close()

    def test_signal_exit_is_retained_before_ui_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder)/'game.log'
            game = subprocess.Popen([sys.executable, '-c',
                "import os,time; os.write(1,b'ready\\ntrailing-signal\\n'); time.sleep(30)"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
            try:
                self.assertEqual(game.stdout.readline(), b'ready\n')
                game.terminate()
                self.assertEqual(game.wait(timeout=5), -signal.SIGTERM)
                leg = dict(exit_code=None, reaped=False)
                with self.assertRaisesRegex(AssertionError, 'normal UI'):
                    code = native.record_terminal_game_exit(game, leg, log)
                    native.require(False, f'normal UI required (actual exit {code})')
                self.assertEqual(leg, dict(exit_code=-signal.SIGTERM, reaped=True))
                self.assertEqual(log.read_bytes(), b'trailing-signal\n')
            finally:
                if game.poll() is None:
                    game.kill(); game.wait(timeout=5)
                game.stdout.close()

    def test_live_process_cannot_be_recorded_as_reaped(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder)/'game.log'
            game = subprocess.Popen([sys.executable, '-c',
                "import os,time; os.write(1,b'ready\\n'); time.sleep(30)"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
            try:
                self.assertEqual(game.stdout.readline(), b'ready\n')
                leg = dict(exit_code=None, reaped=False)
                with self.assertRaisesRegex(AssertionError, 'only after'):
                    native.record_terminal_game_exit(game, leg, log)
                self.assertEqual(leg, dict(exit_code=None, reaped=False))
                self.assertFalse(log.exists())
            finally:
                game.terminate(); game.wait(timeout=5)
                game.stdout.close()


class CrewRecoverySafetyTests(unittest.TestCase):
    def document(self, cold=False):
        return dict(schema_version=1, generation=8 if cold else 4,
                    commit=dict(id='cold' if cold else 'solo-safe-return-4', parent_generation=3, parent_id='before'),
                    payload=dict(solo_safe_recovery=copy.deepcopy(native.CrewRecoveryFiles.CONTEXT),
                        runtime_settings={'real_setting': 7},
                        crash_recovery=dict(state='running', unclean_start_count=int(cold),
                                            session_id=2 if cold else 1, startup_generation=2 if cold else 1),
                        safe_start_recovery=dict(state='starting' if cold else 'stable',
                            startup_generation=2 if cold else 1, consecutive_failure_count=0, safe_settings_recommended=False),
                        session_diagnostics=dict(events=[{'event_code': 'crash_detected'}] if cold else [])))

    def claim(self):
        return dict(crew=dict(seated=True, current=True, role='engineer', seat_id='passenger_port_01', generation=1,
                             authority_id=21, tagged=True, seated_at_anchor=True, assignment={'role': 'engineer'}),
                    seated=True, station_seated=True, game_station_seated=True, control_enabled=True,
                    transition_busy=False, sleeping=False, piloted=False,
                    cabin=dict(frame_id=31, registered=True, contained=True, hatch_reserved=True, owner_current=True))

    def awake(self):
        s = self.claim()
        s.update(phase='IN_FLIGHT_CABIN', hud_mode='aboard', parked_exact=True, home_lease=True,
                 seated=False, grounded=True, supported=True, capsule_enabled=True)
        s['crew'].update(seated=False, current=False, tagged=False, authority_id=0, assignment={})
        return s

    def test_current_claim_and_cold_home_reject_role_seat_and_restored_authority(self):
        native.CrewRecoveryPilot.require_crew(self.claim())
        native.CrewRecoveryPilot.require_awake_home(self.awake())
        for field, value in [('role', 'passenger'), ('seat_id', 'wrong'), ('generation', 0), ('current', False), ('tagged', False)]:
            s = self.claim(); s['crew'][field] = value
            with self.subTest(field=field), self.assertRaises(AssertionError): native.CrewRecoveryPilot.require_crew(s)
        for section, field, value in [('crew', 'authority_id', 21), ('crew', 'assignment', {'role': 'engineer'}),
                                      ('cabin', 'hatch_reserved', False), ('cabin', 'registered', False)]:
            s = self.awake(); s[section][field] = value
            with self.subTest(field=field), self.assertRaises(AssertionError): native.CrewRecoveryPilot.require_awake_home(s)
        for field, value in [('phase', 'APPROACH_SHIP'), ('hud_mode', 'on-foot'), ('grounded', False), ('piloted', True)]:
            s = self.awake(); s[field] = value
            with self.subTest(field=field), self.assertRaises(AssertionError): native.CrewRecoveryPilot.require_awake_home(s)

    def test_cold_context_progress_and_actual_throttle_response(self):
        native.CrewRecoveryFiles.require_interrupted_cold(self.document(True), self.document())
        for mutation in [lambda d: d['payload']['solo_safe_recovery'].update(mode='pilot'),
                         lambda d: d['payload']['crash_recovery'].update(session_id=1),
                         lambda d: d['payload']['safe_start_recovery'].update(consecutive_failure_count=1),
                         lambda d: d['payload'].update(game_flow_reward_store={'injected_receipt': 1}),
                         lambda d: d['payload']['runtime_settings'].update(real_setting=8)]:
            cold = self.document(True); mutation(cold)
            with self.assertRaises(AssertionError): native.CrewRecoveryFiles.require_interrupted_cold(cold, self.document())
        s = self.awake(); s.update(piloted=True, seated_at_pilot=True, active_ship=True, engine_online=True,
                                  command_throttle=1, flight_demand=True, native_forward=True)
        native.CrewRecoveryPilot.require_throttle(s)
        for field, value in [('engine_online', False), ('command_throttle', 0), ('flight_demand', False),
                             ('native_forward', False), ('seated_at_pilot', False)]:
            bad = copy.deepcopy(s); bad[field] = value
            with self.subTest(field=field), self.assertRaises(AssertionError): native.CrewRecoveryPilot.require_throttle(bad)

    def test_owned_kill_reads_unchanged_actual_file_and_requires_terminal_minus_nine(self):
        from unittest.mock import Mock
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); profile = root/'profile'; profile.mkdir()
            output = root/'results'; output.mkdir()
            files = native.CrewRecoveryFiles(profile, output)
            files.path = profile/'mudds_user_data.json'
            files.path.write_text(json.dumps(self.document()))
            files.snapshots['crew-committed'] = {'document': self.document(), 'sha256': hashlib.sha256(files.path.read_bytes()).hexdigest()}
            process = Mock(); process.poll.side_effect = [None, -9]; process.wait.return_value = -9
            leg = dict(pid=42)
            with patch.object(native, 'drain_game_output'):
                files.kill(process, Mock(), leg, output/'game.log')
            process.kill.assert_called_once(); process.wait.assert_called_once_with(timeout=15)
            self.assertTrue(leg['reaped']); self.assertEqual(leg['exit_code'], -9)
            for status, terminal, mutate in [(0, 0, False), (-9, None, False), (-9, -9, True)]:
                process = Mock(); process.poll.side_effect = [None, terminal]; process.wait.return_value = status
                if mutate: process.kill.side_effect = lambda: files.path.write_text('{}')
                with patch.object(native, 'drain_game_output'), self.assertRaises(AssertionError):
                    files.kill(process, Mock(), {}, output/'game.log')

    def test_nominal_two_leg_contract_rejects_fake_kill_unreaped_same_process_and_cap_reset(self):
        legs = [dict(pid=42, exit_code=-9, reaped=True, signal='SIGKILL'),
                dict(pid=43, exit_code=0, reaped=True, normal_ui_exit=True)]
        native.CrewRecoveryFiles.require_two_legs(legs, 299.9)
        self.assertEqual(native.CAP, 300)
        for index, field, value in [(0, 'exit_code', 0), (0, 'reaped', False), (0, 'signal', 'SIGTERM'),
                                    (1, 'pid', 42), (1, 'reaped', False), (1, 'normal_ui_exit', False)]:
            bad = copy.deepcopy(legs); bad[index][field] = value
            with self.subTest(field=field), self.assertRaises(AssertionError): native.CrewRecoveryFiles.require_two_legs(bad, 100)
        with self.assertRaises(AssertionError): native.CrewRecoveryFiles.require_two_legs(legs, 300)

    def test_admission_commit_uses_real_primary_and_protects_absent_activity_reward(self):
        from unittest.mock import Mock
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); profile=root/'profile'; (profile/'data').mkdir(parents=True)
            output=root/'results'; output.mkdir()
            files=native.CrewRecoveryFiles(profile, output)
            path=profile/'data/mudds_user_data.json'
            before=self.document(); before.update(generation=3, commit={'id': 'before'})
            before['payload']['solo_safe_recovery']={'mode':'unavailable'}
            path.write_text(json.dumps(before))
            sample=dict(path=str(path), source='primary', generation=3)
            files.capture('title', sample); files.capture('before-chair', sample)
            path.write_text(json.dumps(self.document()))
            Path(str(path)+'.bak').write_text(json.dumps(before))
            s=self.claim(); s.update(paused=False, save=dict(sample, generation=4, context=native.CrewRecoveryFiles.CONTEXT,
                                                         context_generation=4, retry_seconds=0))
            pilot=Mock(stage='crew_commit', file_context_accepted=False, cold=False, awake=False)
            pilot.require_crew=native.CrewRecoveryPilot.require_crew
            files.observe(s, pilot)
            self.assertTrue(pilot.file_context_accepted)
            self.assertNotIn('game_flow_reward_store', files.snapshots['crew-committed']['document']['payload'])
            changed=self.document(); changed['payload']['jovian_cargo_session']={'fake':True}
            path.write_text(json.dumps(changed)); pilot.file_context_accepted=False
            with self.assertRaises(AssertionError): files.observe(s, pilot)


if __name__ == '__main__':
    unittest.main()
