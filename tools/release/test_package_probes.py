#!/usr/bin/env python3
"""Exercise actual embedded release-driver gates without running an engine."""
import ast
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).with_name("run_package_probes.sh")
ROOT = SCRIPT.resolve().parents[2]


def driver(tag):
    text = SCRIPT.read_text().split("<<'" + tag + "' &\n", 1)[1].split("\n" + tag + "\n", 1)[0]
    return ast.parse(text)


def execute(nodes, namespace):
    exec(compile(ast.fix_missing_locations(ast.Module(body=nodes, type_ignores=[])), str(SCRIPT), "exec"), namespace)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def conditional(tree, selector, message):
    return next(node for node in ast.walk(tree) if isinstance(node, ast.If)
                and ast.unparse(node.test) == selector and message in ast.unparse(node))


class LaunchReached(Exception):
    pass


class MetadataBeforeLaunch(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        self.binary = self.directory / "managed" / "game.x86_64"
        self.binary.parent.mkdir()
        self.binary.write_bytes(b"\x7fELF\x02\x01" + bytes(12) + b"\x3e\x00" + b"inert-test-data")
        self.binary.chmod(0o755)
        self.external = self.directory / "archive-export.json"
        self.adjacent = Path(str(self.binary) + ".export-result.json")
        self.metadata = {"schema_version": 1, "platform": "linux", "source_commit": "a" * 40,
                         "binary": {"bytes": self.binary.stat().st_size,
                                    "sha256": hashlib.sha256(self.binary.read_bytes()).hexdigest()}}
        self.launch = Mock(side_effect=LaunchReached)

    def launch_prefix(self, tag):
        tree = driver(tag)
        production = next(node for node in tree.body if isinstance(node, ast.Try))
        namespace = dict(hashlib=hashlib, json=json, os=os, pathlib=__import__('pathlib'), re=re,
                         subprocess=subprocess, sys=sys, require=require, package=str(self.binary),
                         root=ROOT, cap=300, profile=self.directory / "profile", run_dir=self.directory / "result",
                         result={"processes": [], "package_sha256": self.metadata["binary"]["sha256"]},
                         digest=lambda path: hashlib.sha256(path.read_bytes()).hexdigest(),
                         native_export=True, recovery_context="crew", activity="convoy", children=[],
                         environment={}, registering_child=False, pending_abort=None, cancelled=None,
                         manifest=lambda *_: "source-stable", snapshot=lambda *_: [], scope=[])
        namespace['profile'].mkdir(mode=0o700)
        (namespace['run_dir'] / 'logs').mkdir(parents=True, exist_ok=True)
        namespace['document'] = namespace['profile'] / 'data' / 'mudds_user_data.json'
        if tag == 'PYPROBE':
            execute([next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'start')], namespace)
            end = next(index for index, node in enumerate(production.body)
                       if isinstance(node, ast.Assign) and ast.unparse(node.value) == "start('arm')")
            nodes = production.body[:end + 1]
        else:
            nodes = []
            for node in production.body:
                if isinstance(node, ast.For) and ast.unparse(node.target) == "stage":
                    node = copy.deepcopy(node)
                    end = next(index for index, child in enumerate(node.body) if isinstance(child, ast.With))
                    node.body = node.body[:end + 1]
                    nodes.append(node)
                    break
                nodes.append(node)
        inventory = types.ModuleType('package_inventory')
        inventory.find_pck = lambda _: (0, 0)
        inventory.parse = lambda *_: {'pck': {}, 'entries': [
            {'path': 'scripts/diagnostics/runtime_settings_restart_probe.gdc'},
            {'path': 'scripts/game/startup_loader.gdc'}]}
        with patch.dict(sys.modules, {'package_inventory': inventory}), \
                patch.object(subprocess, 'Popen', self.launch), \
                patch.object(subprocess, 'check_output', return_value='b' * 40):
            execute(nodes, namespace)
        return namespace

    def run_case(self, tag, record, external=True):
        # Every invocation gets its own empty private root.
        import shutil
        shutil.rmtree(self.directory / 'profile', ignore_errors=True)
        path = self.external if external else self.adjacent
        if record is not None:
            path.write_text(record if isinstance(record, str) else json.dumps(record))
        original = self.binary.read_bytes()
        mode = self.binary.stat().st_mode
        env = {'PACKAGE_PROBE_EXPORT_METADATA': str(self.external)} if external else {'PACKAGE_PROBE_EXPORT_METADATA': ''}
        try:
            with patch.dict(os.environ, env):
                return self.launch_prefix(tag)
        finally:
            self.assertEqual(self.binary.read_bytes(), original)
            self.assertEqual(self.binary.stat().st_mode, mode)
            self.assertEqual(sorted(p.name for p in self.binary.parent.iterdir()),
                             ['game.x86_64'] if external else ['game.x86_64', 'game.x86_64.export-result.json'])

    def test_invalid_metadata_rejects_before_either_native_launch(self):
        cases = [None, '{bad-json', [], dict(self.metadata, schema_version=2),
                 dict(self.metadata, platform='windows'), dict(self.metadata, source_commit='short'),
                 dict(self.metadata, source_commit='A' * 40),
                 dict(self.metadata, binary=dict(self.metadata['binary'], bytes=1)),
                 dict(self.metadata, binary=dict(self.metadata['binary'], sha256='0' * 64))]
        for tag in ('PYPROBE', 'PYSETTINGS'):
            for record in cases:
                with self.subTest(driver=tag, record=record):
                    self.external.unlink(missing_ok=True)
                    self.launch.reset_mock()
                    with self.assertRaises((RuntimeError, ValueError, AttributeError, FileNotFoundError)):
                        self.run_case(tag, record)
                    self.launch.assert_not_called()

    def test_external_and_default_records_reach_existing_exact_elf_launch(self):
        for tag in ('PYPROBE', 'PYSETTINGS'):
            for external in (True, False):
                with self.subTest(driver=tag, external=external):
                    self.adjacent.unlink(missing_ok=True)
                    self.launch.reset_mock()
                    with self.assertRaises(LaunchReached):
                        self.run_case(tag, self.metadata, external)
                    arguments = self.launch.call_args.args[0]
                    self.assertEqual(arguments[0], str(self.binary.resolve()))
                    self.assertIn('--headless', arguments)
                    self.assertEqual(arguments[arguments.index('--audio-driver') + 1], 'Dummy')
                    for override in ('--script', '--main-pack', '--path'):
                        self.assertNotIn(override, arguments)

    def test_cleanup_rejects_changed_or_removed_external_metadata(self):
        for tag in ('PYPROBE', 'PYSETTINGS'):
            tree = driver(tag)
            production = next(node for node in tree.body if isinstance(node, ast.Try))
            gate = next(node for node in production.finalbody if isinstance(node, ast.If)
                        and any(isinstance(child, ast.Constant) and isinstance(child.value, str)
                                and 'export metadata unavailable or changed' in child.value for child in ast.walk(node)))
            for remove in (False, True):
                with self.subTest(driver=tag, removed=remove):
                    self.external.write_text(json.dumps(self.metadata))
                    before = hashlib.sha256(self.external.read_bytes()).hexdigest()
                    namespace = dict(native_export=True, result={'status': 'PASS', 'export_metadata_sha256': before},
                                     metadata_hash=before, metadata_path=self.external, require=require,
                                     digest=lambda path: hashlib.sha256(path.read_bytes()).hexdigest())
                    self.external.unlink() if remove else self.external.write_text('{}')
                    execute([gate], namespace)
                    self.assertEqual(namespace['result']['status'], 'FAIL')
                    self.assertEqual(namespace['result']['export_metadata_sha256'], before)


class CrewDocumentGuards(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.context = dict(location='mudds_home_berth', mode='crew', craft_id='halyard_new_design',
                            berth_id='halyard_fleet_dock_berth')
        self.boundary = dict(escort_ship_id='halyard_new_design', host_state={'movement_distance': 40},
                             threat_state={'generation': 2}, progress={'elapsed': 1})
        self.row = dict(activity_id='cinder_reach_emberline_convoy', generation=3, state=3,
                        progress={'convoy_session_state': copy.deepcopy(self.boundary)},
                        reward_requested=False, reward_granted=False)
        ledger = dict(schema_version=1, receipt_serial=4, total_receipts=4,
                      reward_counts={'return_convoy_credit_to_shipyard': 1, 'foreign_reward': 3},
                      last_receipt={'receipt_id': 4})
        crash = dict(state='running', session_id=1, startup_generation=1, unclean_start_count=0,
                     last_physics_tick=50, last_elapsed_physics_seconds=1)
        start = dict(state='running', startup_generation=1, record_generation=2,
                     consecutive_failure_count=0, safe_settings_recommended=False)
        ring = dict(events=[], next_sequence=1, capacity=32, dropped_event_count=0)
        self.saved = dict(payload=dict(solo_safe_recovery=copy.deepcopy(self.context),
                         cinder_convoy_session={'schema_version': 1, 'activities': [copy.deepcopy(self.row)]},
                         game_flow_reward_store=ledger, runtime_settings={'values': {'master_volume': 0.3}},
                         unknown_future_namespace={'keep': [1, 2, 3]},
                         crash_recovery=crash, safe_start_recovery=start, session_diagnostics=ring))
        self.cold = copy.deepcopy(self.saved)
        self.cold['payload']['crash_recovery'].update(session_id=2, startup_generation=2)
        safe = dict(craft_id='halyard_new_design', home_berth_id='halyard_fleet_dock_berth',
                    craft_piloted=False, piloting=False, player_seated=False, player_sleeping=False,
                    player_control_enabled=True, player_on_floor=True, cabin_containment=True,
                    moving_interior_occupant=True, solo_crew_seated=False, solo_crew_assignment_empty=True,
                    crew_authority_absent=True, crew_occupant_tag_absent=True, craft_at_home=True,
                    berth_occupied_by_craft=True, berth_reserved_by_craft=True, berth_lease_current=True,
                    hatch_reserved_by_player=True, berth_reservation_token='fresh-lease',
                    walking={'physics_ticks': 24, 'distance_m': 0.6, 'supported': True,
                             'control_enabled': True, 'craft_piloted': False})
        self.ready = dict(safe_context=copy.deepcopy(self.context), boundary=copy.deepcopy(self.boundary), receipts=1,
                          runtime_observation=dict(craft_id='halyard_new_design', player_seated=True,
                                                   craft_piloted=False, player_sleeping=False))
        self.recovered = dict(safe_context=copy.deepcopy(self.context), boundary=copy.deepcopy(self.boundary),
                              receipts_before=1, receipts_after=2, safe_recovery_observation=safe,
                              control_observation=dict(craft_id='halyard_new_design', player_at_pilot_seat=True,
                                craft_piloted=True, piloting=True, player_seated=True, cabin_containment=False,
                                moving_interior_occupant=False, engine_online=True, throttle=0.5, physics_ticks=2),
                              continuation_method='real_awake_home_cabin_walk_then_pilot_retake_new_convoy_escort_motion_fixture')
        self.final = copy.deepcopy(self.saved)
        payload = self.final['payload']
        payload['solo_safe_recovery']['mode'] = 'pilot'
        paid_row = payload['cinder_convoy_session']['activities'][0]
        paid_row.update(generation=5, state=2, reward_requested=True, reward_granted=True)
        payload['game_flow_reward_store'].update(receipt_serial=5, total_receipts=5,
            reward_counts={'return_convoy_credit_to_shipyard': 2, 'foreign_reward': 3},
            last_receipt=dict(receipt_id=5, activity_id=self.row['activity_id'], activity_generation=5,
                              reward_id='return_convoy_credit_to_shipyard', reward_label='Emberline escort credit logged',
                              granted=True, replay_allowed=False))
        payload['crash_recovery'].update(state='clean', session_id=2, startup_generation=2,
                                         last_physics_tick=60, last_elapsed_physics_seconds=2)
        payload['safe_start_recovery'].update(state='clean_shutdown', startup_generation=2, record_generation=4)
        events = []
        for sequence, (code, fields, severity) in enumerate([
                ('session_started', {'recovered': False}, 'info'),
                ('crash_detected', {'attempt_count': 1, 'recovered': True}, 'error'),
                ('session_ended', {'duration_physics_seconds': 2}, 'info')], 1):
            events.append(dict(sequence=sequence, event_code=code, fields=fields, severity=severity,
                               session_id=2, redacted_field_count=0, physics_tick=60, session_elapsed_physics_seconds=2))
        payload['session_diagnostics'].update(events=events, next_sequence=4)

    def check_documents(self):
        tree = driver('PYPROBE')
        nodes = [conditional(tree, "recovery_context == 'crew'", 'crew cut does not contain'),
                 conditional(tree, "recovery_context == 'crew'", 'cold_text ='),
                 conditional(tree, "recovery_context in ('exit', 'exit_refused', 'crew')", 'old_crash =')]
        namespace = dict(recovery_context='crew', require=require, json=json, hashlib=hashlib,
                         run_dir=Path(self.scratch.name), result={}, saved=self.saved, final=self.final,
                         row=self.saved['payload']['cinder_convoy_session']['activities'][0],
                         ready=self.ready, recovered=dict(self.recovered, cold_document_json=json.dumps(self.cold)))
        execute(nodes, namespace)

    def test_valid_distinct_payment_preserves_other_receipts_and_namespaces(self):
        self.check_documents()
        self.assertEqual(json.loads((Path(self.scratch.name) / 'cold-crew-document.json').read_text()), self.cold)

    def test_mismatched_actual_four_field_identity_is_rejected(self):
        for document in ('saved', 'cold'):
            for field in self.context:
                with self.subTest(document=document, field=field):
                    context = getattr(self, document)['payload']['solo_safe_recovery']
                    original = context[field]
                    context[field] = 'wrong'
                    with self.assertRaisesRegex(RuntimeError, 'four-field|cold document'):
                        self.check_documents()
                    context[field] = original
        self.cold['payload']['solo_safe_recovery']['unexpected'] = True
        with self.assertRaisesRegex(RuntimeError, 'cold document'):
            self.check_documents()

    def test_matching_self_report_cannot_hide_changed_cold_boundary(self):
        self.cold['payload']['cinder_convoy_session']['activities'][0]['progress']['convoy_session_state']['host_state']['movement_distance'] += 1
        self.recovered['boundary'] = copy.deepcopy(self.boundary)
        with self.assertRaisesRegex(RuntimeError, 'cold document'):
            self.check_documents()

    def test_cold_and_final_protect_settings_and_unknown_payload(self):
        for document in ('cold', 'final'):
            for namespace in ('runtime_settings', 'unknown_future_namespace'):
                with self.subTest(document=document, namespace=namespace):
                    payload = getattr(self, document)['payload']
                    original = payload[namespace]
                    payload[namespace] = {'changed': True}
                    with self.assertRaisesRegex(RuntimeError, 'cold document|protected payload'):
                        self.check_documents()
                    payload[namespace] = original

    def test_reward_replay_or_unrelated_ledger_change_is_rejected(self):
        ledger = self.final['payload']['game_flow_reward_store']
        for key, value in [('total_receipts', 6), ('receipt_serial', 6),
                           ('reward_counts', {'return_convoy_credit_to_shipyard': 2, 'foreign_reward': 4})]:
            with self.subTest(key=key):
                original = ledger[key]
                ledger[key] = value
                with self.assertRaisesRegex(RuntimeError, 'exact reward ledger'):
                    self.check_documents()
                ledger[key] = original

    def test_crew_requires_distinct_owned_arm_and_resume_pids(self):
        node = conditional(driver('PYPROBE'),
                           "activity == 'ember-abandon' or recovery_context in ('exit', 'exit_refused', 'crew')",
                           'distinct owned OS processes')
        for second in (42, 43):
            namespace = dict(recovery_context='crew', activity='convoy', require=require,
                             arm=types.SimpleNamespace(pid=42), resume=types.SimpleNamespace(pid=second))
            if second == 42:
                with self.assertRaisesRegex(RuntimeError, 'distinct owned'):
                    execute([node], namespace)
            else:
                execute([node], namespace)


if __name__ == '__main__':
    unittest.main()
