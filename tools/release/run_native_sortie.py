#!/usr/bin/env python3
"""Fly the embedded Linux game with OS XTest keys/mouse on an owned Xvfb.

Usage: run_native_sortie.py GAME.x86_64 --output NEW_RESULT_DIRECTORY
Use --route sandbox for the full five-branch/eight-craft/crash/reuse scenario.
Use --route sandbox-walk for the on-foot prerequisite only. The default is Guided.
No source/pack overrides. 300 seconds is the fixed whole-process sortie cap.
This establishes Linux/Xvfb OS-input behavior, not native GPU or human acceptance.
"""
import argparse
import ctypes as C
import hashlib
import json
import math
import multiprocessing
import os
from pathlib import Path
import re
import selectors
import secrets
import shutil
import signal
import socket
import subprocess
import tempfile
import time

PREFIX = b"NATIVE_SORTIE_OBSERVATION: "
CAP = 300
ANSI_ESCAPE = re.compile(rb'\x1b\[[0-?]*[ -/]*[@-~]')
DIAGNOSTIC = re.compile(
    rb'^\s*(?:SCRIPT\s+ERROR|ERROR:|WARNING:|FAIL:|NATIVE_SORTIE_REJECTED:)'
    rb'|\bFATAL ERROR\b|\bObjectDB\b|Resource.*still in use|\bOrphaned\b|\bLeaked\b',
    re.IGNORECASE,
)


def require(condition, description):
    if not condition: raise AssertionError(description)


def sub(a, b): return [x-y for x, y in zip(a, b)]
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def norm(a): return math.sqrt(dot(a, a))
def unit(a): return [x/max(norm(a), 1e-9) for x in a]


def diagnostic_lines(lines):
    normalized = [ANSI_ESCAPE.sub(b'', line).strip() for line in lines]
    return [line for line in normalized if not line.startswith(b'PASS:') and DIAGNOSTIC.search(line)]


def observations_from_lines(lines):
    diagnostics = diagnostic_lines(lines)
    if diagnostics:
        raise RuntimeError('native game diagnostic: ' + diagnostics[0].decode('utf-8', errors='replace'))
    return [json.loads(line[len(PREFIX):]) for line in lines if line.startswith(PREFIX)]


def drain_game_output(process, log_path):
    # The direct child has been waited for. Read its remaining pipe bytes without
    # blocking cleanup on an unexpected descendant holding the write end open.
    os.set_blocking(process.stdout.fileno(), False)
    deadline = time.monotonic() + 2
    with log_path.open('ab') as log:
        while time.monotonic() < deadline:
            try: chunk = os.read(process.stdout.fileno(), 262144)
            except BlockingIOError: return
            if not chunk: return
            log.write(chunk)
    raise RuntimeError('game output did not drain within cleanup deadline')


def validate_binary(path):
    path = Path(path).absolute()
    if path.is_symlink() or not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError("game must be a regular executable Linux ELF")
    with path.open('rb') as stream:
        header = stream.read(20)
    if header[:4] != b'\x7fELF' or header[4:6] != b'\x02\x01' or header[18:20] != b'\x3e\x00':
        raise ValueError("only native Linux x86_64 ELF is supported; PE/Wine is forbidden")
    return path


class _XDesktop:
    """Connection to this invocation's authenticated, private X server only."""
    def __init__(self, display):
        self.x = C.CDLL('libX11.so.6')
        self.xt = C.CDLL('libXtst.so.6')
        self.x.XOpenDisplay.argtypes = [C.c_char_p]
        self.x.XOpenDisplay.restype = C.c_void_p
        self.x.XStringToKeysym.argtypes = [C.c_char_p]
        self.x.XStringToKeysym.restype = C.c_ulong
        self.x.XKeysymToKeycode.argtypes = [C.c_void_p, C.c_ulong]
        self.x.XKeysymToKeycode.restype = C.c_uint
        self.x.XSetInputFocus.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_ulong]
        self.x.XFlush.argtypes = [C.c_void_p]
        self.x.XSync.argtypes = [C.c_void_p, C.c_int]
        self.errors = []
        self.error_handler_type = C.CFUNCTYPE(C.c_int, C.c_void_p, C.c_void_p)
        self.error_handler = self.error_handler_type(lambda _display, _event: self.errors.append('X11 protocol error') or 0)
        self.x.XSetErrorHandler.argtypes = [self.error_handler_type]
        self.x.XSetErrorHandler(self.error_handler)
        self.x.XCloseDisplay.argtypes = [C.c_void_p]
        self.xt.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
        self.xt.XTestFakeButtonEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
        self.xt.XTestFakeRelativeMotionEvent.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_ulong]
        self.d = self.x.XOpenDisplay(display.encode())
        if not self.d:
            raise RuntimeError('cannot connect to owned authenticated display')
        self.held = set()
        self.fire = False

    def keys(self, desired):
        desired = set(desired)
        for key in sorted(self.held ^ desired):
            code = self.x.XKeysymToKeycode(self.d, self.x.XStringToKeysym(key.encode()))
            if not code:
                raise RuntimeError('missing X key: '+key)
            self.xt.XTestFakeKeyEvent(self.d, code, key in desired, 0)
        self.held = desired
        self.x.XFlush(self.d)

    def mouse(self, dx, dy, fire=False):
        if dx or dy:
            self.xt.XTestFakeRelativeMotionEvent(self.d, int(dx), int(dy), 0)
        if fire != self.fire:
            self.xt.XTestFakeButtonEvent(self.d, 1, fire, 0)
            self.fire = fire
        self.x.XFlush(self.d)

    def close(self):
        self.keys([])
        self.mouse(0, 0, False)
        self.x.XCloseDisplay(self.d)


def _input_worker(display, authority, connection):
    # Xlib can terminate a process on server loss. Confine it to this helper;
    # the supervisor retains the independent abort and owned-child cleanup.
    os.environ['XAUTHORITY'] = authority
    desktop = None
    try:
        desktop = _XDesktop(display)
        connection.send({'ready': True})
        while True:
            command = connection.recv()
            kind = command[0]
            if kind == 'focus':
                desktop.x.XSetInputFocus(desktop.d, command[1], 1, 0)
            elif kind == 'keys': desktop.keys(command[1])
            elif kind == 'mouse': desktop.mouse(*command[1:])
            elif kind == 'close':
                desktop.close()
                desktop = None
                connection.send({'ok': True})
                break
            else: raise ValueError('unknown private input command')
            desktop.x.XSync(desktop.d, False)
            if desktop.errors: raise RuntimeError(desktop.errors[-1])
            connection.send({'ok': True})
    except Exception as error:
        try: connection.send({'error': str(error)})
        except (EOFError, BrokenPipeError): pass
    finally:
        if desktop:
            try: desktop.close()
            except Exception: pass
        connection.close()


class Desktop:
    """Bounded IPC supervisor for the fallible private Xlib input helper."""
    def __init__(self, display, authority):
        context = multiprocessing.get_context('spawn')
        self.connection, child = context.Pipe()
        self.process = context.Process(target=_input_worker, args=(display, authority, child))
        self.process.start()
        child.close()
        try: self._receive()
        except Exception:
            self._reap()
            raise

    def _receive(self):
        if not self.connection.poll(2):
            raise RuntimeError('private input helper timed out')
        try: reply = self.connection.recv()
        except EOFError as error: raise RuntimeError('private input helper exited') from error
        if 'error' in reply: raise RuntimeError(reply['error'])

    def _send(self, command):
        self.connection.send(command)
        self._receive()

    def focus(self, window): self._send(('focus', window))
    def keys(self, keys): self._send(('keys', sorted(keys)))
    def mouse(self, dx, dy, fire): self._send(('mouse', dx, dy, fire))

    def _reap(self):
        self.process.join(timeout=1)
        if self.process.is_alive():
            self.process.terminate()
            self.process.join(timeout=2)
        if self.process.is_alive():
            self.process.kill()
            self.process.join(timeout=2)
        self.connection.close()

    def close(self):
        try: self._send(('close',))
        finally: self._reap()


class Pilot:
    def __init__(self):
        self.stage = 'boot'
        self.stages = []
        self.phases = []
        self.identities = None
        self.shot = False
        self.fired = False
        self.target = None
        self.tap_until = 0
        self.tap_frame = 0
        self.frame = 0
        self.tap_key = None
        self.tap_cooldown = 0
        self.tap_release_frame = -100
        self.launch_braking = False
        self.return_braking = False
        self.max_walk = 0
        self.max_excursion = 0
        self.departed = False
        self.landing_distance = 0
        self.result = None

    def enter(self, stage, s):
        self.stage = stage
        event = {'stage': stage, 'frame': s['frame'], 'position': s['position'], 'phase': s['phase']}
        self.stages.append(event)
        print(json.dumps(event), flush=True)

    def tap(self, key, now):
        if self.tap_key is None and now >= self.tap_cooldown and self.frame >= self.tap_release_frame + 6:
            self.tap_key = key
            self.tap_until = now + .15
            self.tap_frame = self.frame

    def aim(self, s, target, gain=.15):
        desired = unit(sub(target, s['camera']))
        local = [dot(desired, s[a]) for a in ('right', 'up', 'back')]
        # Ordinary mouse controls map pixels directly to local craft attitude.
        yaw = math.atan2(local[0], -local[2])
        pitch = math.atan2(local[1], math.hypot(local[0], local[2]))
        sensitivity = s['tuning']['mouse']
        clamp = lambda v: round(max(-35, min(35, v)))
        return clamp(yaw*gain/sensitivity), clamp(-pitch*gain/sensitivity), -local[2]

    def update(self, s, now):
        self.frame = s['frame']
        phase = s['phase']
        if not self.phases or self.phases[-1] != phase:
            self.phases.append(phase)
        ids = (s['player_id'], s['ship_id'])
        if self.identities is None:
            self.identities = ids
            require(s['lease'], 'initial occupied central berth lease')
            require(len(s['targets']) == 4, 'four authored live range drones at startup')
            self.parked_forward = [-v for v in s['back']]
        require(self.identities == ids, 'same actor identities throughout')
        require(s['default_sampler'] and s['tuning_unchanged'], 'authored controls and tuning')
        require(phase != 'FAILED' and not s['destroyed'], 'live sortie')
        self.shot |= s['shot_accepted']
        self.fired |= s['command_fire']
        if self.stage == 'walk':
            self.max_walk = max(self.max_walk, norm(sub(s['player'], s['spawn'])))
        self.max_excursion = max(self.max_excursion, norm(sub(s['position'], s['parked'])))
        self.departed |= s['lease_free'] and not s['landed'] and self.max_excursion > .01
        keys = set()
        dx = dy = 0
        fire = False
        speed = norm(s['velocity'])
        if self.stage == 'boot' and s['menu_ready']:
            self.enter('begin_shift', s)
            self.tap('e', now)
        elif self.stage == 'begin_shift' and phase == 'APPROACH_SHIP':
            self.enter('walk', s)
        elif self.stage == 'walk':
            off = s['walk_offset'][:]
            off[1] = 0
            if norm(off) <= 3.1 and s['candidate']:
                require(self.max_walk > 8, 'physical walk from spawn')
                self.enter('board', s)
                self.tap('e', now)
            else:
                direction = unit(off)
                x, z = dot(direction, s['walk_right']), dot(direction, s['walk_forward'])
                keys.add('Shift_L')
                if x > .2: keys.add('d')
                if x < -.2: keys.add('a')
                if z > .2: keys.add('w')
                if z < -.2: keys.add('s')
        elif self.stage == 'board' and phase == 'START_ENGINES':
            require(s['piloted'] and s['seated'] and s['active_ship'], "s['piloted'] and s['seated'] and s['active_ship']")
            self.enter('launch', s)
        elif self.stage == 'launch':
            target = [0, 8, -78]
            off = sub(target, s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            dist = norm(off)
            stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
            if dist < stopping+5.75: self.launch_braking = True
            if speed <= .45 and dist > 5: self.launch_braking = False
            if dist <= 5 or self.launch_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if dist <= 5 and phase == 'TARGET_PRACTICE':
                require(self.departed and s['position'][2] < -66, "self.departed and s['position'][2] < -66")
                self.enter('range', s)
        elif self.stage == 'range':
            keys.add('Prior')
            if speed > .8:
                pass
            elif s['targets']:
                target = sorted(s['targets'], key=lambda t:t['name'])[0]
                dx, dy, align = self.aim(s, target['position'])
                fire = align >= .997
            else:
                require(s['destroyed_targets'] == 4 and phase == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active'], "s['destroyed_targets'] == 4 and phase == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']")
                self.enter('interceptor', s)
        elif self.stage == 'interceptor':
            keys.add('Prior')
            dx, dy, align = self.aim(s, s['opponent'], .2)
            fire = align >= .997
            if not s['opponent_active'] and phase == 'RETURN_TO_YARD':
                require(self.shot and self.fired and s['telemetry']['hull'] > 0, "self.shot and self.fired and s['telemetry']['hull'] > 0")
                self.enter('return_align', s)
        elif self.stage == 'return_align':
            # Match ordinary flight staging: brake and use the authored hover
            # control to recover upright attitude before approaching the dock.
            keys.update(('Prior','h'))
            off = sub([0, 2, -18], s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if align > .98 and s['upright'] > .94 and speed <= .8:
                self.enter('return', s)
        elif self.stage == 'return':
            waypoint = [0, 2, -18]
            off = sub(waypoint, s['position'])
            distance = norm(off)
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
            if distance < stopping+1.75: self.return_braking = True
            if speed <= .45 and distance > 1: self.return_braking = False
            if distance <= 1 or self.return_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if distance <= 1 and speed <= .45:
                self.enter('align_berth', s)
        elif self.stage == 'align_berth':
            keys.update(('Prior','h'))
            off = sub(s['parked'], s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(s['capture'], 'registered broad landing capture')
                require(dot([-v for v in s['back']], self.parked_forward) < -.95, 'nose-first return opposite the parked heading')
                self.landing_distance = norm(off)
                self.enter('land', s)
                self.tap('l', now)
        elif self.stage == 'land':
            if phase == 'RETURN_TO_YARD' and not s['landing_active']:
                self.tap('l', now)
            if phase == 'SHUT_DOWN':
                require(s['contract'] and s['parked_exact'] and s['lease'], 'exact secured home berth')
                self.enter('shutdown', s)
        elif self.stage == 'shutdown' and s['telemetry']['engine'] == 'OFFLINE':
            self.enter('exit', s)
            self.tap('e', now)
        elif self.stage == 'exit' and phase == 'SHUT_DOWN' and s['telemetry']['engine'] == 'OFFLINE':
            self.tap('e', now)
        elif self.stage == 'exit' and phase == 'COMPLETE':
            require(not s['piloted'] and not s['seated'] and s['control_enabled'], "not s['piloted'] and not s['seated'] and s['control_enabled']")
            require(s['guided_complete'] and s['active_ship'] and s['exit_error'] < .25, "s['guided_complete'] and s['active_ship'] and s['exit_error'] < .25")
            require(norm(sub(s['player'], s['spawn'])) > 8, "norm(sub(s['player'], s['spawn'])) > 8")
            require(s['lease'] and s['parked_exact'] and s['contract'], "s['lease'] and s['parked_exact'] and s['contract']")
            expected = ['APPROACH_SHIP','START_ENGINES','LAUNCH','TARGET_PRACTICE','INTERCEPTOR_ENGAGEMENT','RETURN_TO_YARD','SHUT_DOWN','COMPLETE']
            require(all(p in self.phases for p in expected), 'all genuine gameplay phases')
            self.enter('complete', s)
            self.result = {'phases': self.phases, 'stages': self.stages, 'walked_m': self.max_walk,
                           'excursion_m': self.max_excursion, 'landing_approach_m': self.landing_distance,
                           'exit_error_m': s['exit_error'], 'same_player_id': ids[0], 'same_ship_id': ids[1],
                           'authored_tuning': s['tuning'], 'default_sampler': True, 'shot_accepted': self.shot}
        # A short wall-clock pulse can fall wholly inside a busy engine frame.
        # Keep it down until six actual physics observations have passed, then
        # observe a release interval before a fresh physical press may begin.
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        return keys, dx, dy, fire


class SandboxWalkPilot(Pilot):
    """Five station branches through ordinary controls; fleet/crash gate stays open.

    These centre lines follow the authored decks and existing freight handoff
    samples. They are goals for OS walking, never poses written into the game.
    """
    WAYPOINTS = (
        ('Central', [0, 0, 15.5]),
        # The production tow tractor occupies x=.6..4.4 at z=15.6.
        # Walk its forward side on the existing central deck in both directions.
        ('tractor_west_clearance', [0, 0, 12.5]),
        ('tractor_forward_clearance', [6, 0, 12.5]),
        ('tractor_east_clearance', [6, 0, 13.5]),
        # Cargo-line totes occupy z=15.05..15.85; the cabinets at x=36.8
        # require returning to the centre lane only after the cargo gantry.
        ('starboard_cargo_exit', [34.8, 0, 13.5]),
        ('starboard_cabinet_clearance', [34.8, 0, 15.5]),
        ('starboard_arm', [43, 0, 15.5]),
        ('habitat_approach', [46, 0, 15.5]),
        ('habitat_threshold', [50, 0, 15.5]),
        ('habitat_corridor', [59.15, 0, 15.5]),
        ('Habitat', [67.65, 0, 15.5]),
        ('habitat_return_corridor', [59.15, 0, 15.5]),
        ('habitat_return_threshold', [50, 0, 15.5]),
        ('habitat_return_approach', [46, 0, 15.5]),
        ('starboard_return', [43, 0, 15.5]),
        ('starboard_return_cabinet', [34.8, 0, 15.5]),
        ('starboard_return_cargo', [34.8, 0, 13.5]),
        ('tractor_return_east', [6, 0, 13.5]),
        ('tractor_return_forward', [6, 0, 12.5]),
        ('tractor_return_west', [0, 0, 12.5]),
        ('central_return', [0, 0, 15.5]),
        ('port_cargo_entry', [0, 0, 13.5]),
        # The east apron at x=-35 clears the Arrow tail, branch cargo solids
        # and the berth's actual x=-34.6 edge. x=-33 is over space at z=22.
        ('port_arm', [-35, 0, 13.5]),
        ('arrow_aft_clearance', [-35, 0, 22]),
        ('registry_gallery', [-48, 0, 22]),
        ('registry_handoff', [-48, .38, 24]),
        ('freight_bypass_east', [-49, .38, 26]),
        ('freight_bypass_west', [-51.5, .38, 26]),
        ('freight_approach', [-53, .38, 27.5]),
        ('freight_connector', [-53, .38, 33.5]),
        ('Freight', [-53, .38, 40]),
        ('freight_return_connector', [-53, .38, 33.5]),
        ('freight_return_approach', [-53, .38, 27.5]),
        ('freight_return_west', [-51.5, .38, 26]),
        ('freight_return_east', [-49, .38, 26]),
        ('registry_return_handoff', [-48, .38, 24]),
        ('registry_return_gallery', [-48, 0, 22]),
        ('arrow_return_clearance', [-35, 0, 22]),
        ('port_return', [-35, 0, 13.5]),
        ('port_cargo_return', [0, 0, 13.5]),
        ('central_aft_turn', [0, 0, 15.5]),
        ('aft_spine', [0, 0, 39]),
        ('aft_approach', [0, 0, 46.3]),
        ('Aft', [0, 0, 51]),
        ('aft_stair_base', [-5.7, 0, 51]),
        ('aft_stair_top', [-5.7, 4.2, 61.2]),
        # The central route marker lies inside the live crew-workpost supply
        # crate. Its authored east aisle clears both the workpost and ribs.
        ('aft_upper_gate', [-3.5, 4.2, 61.5]),
        ('aft_upper_floor', [-3.5, 4.2, 64.2]),
        ('aft_upper_turn', [-3.5, 4.2, 68.3]),
        ('fleet_bridge', [6, 4.2, 68.3]),
        ('fleet_approach', [13, 4.2, 68.3]),
        ('fleet_trunk_forward', [22, 4.2, 68.3]),
        ('fleet_trunk_mid', [37, 4.2, 68.3]),
        ('Fleet Dock', [52, 4.2, 68.3]),
    )
    FLEET = frozenset(('torrent_provisional', 'arrow_provisional', 'jovian_provisional',
                      'zenith_b7_observed', 'halyard_new_design', 'bulwark_heavy_gunship',
                      'cinder_cargo_hauler', 'cinder_long_range_bomber', 'cinder_light_interceptor'))

    def __init__(self):
        super().__init__()
        self.index = 0
        self.fleet_ids = None
        self.player_id = None
        self.previous = None
        self.visited = []
        self.door_opened = False
        self.door_requested = False

    def walk_arrival_ready(self):
        return True

    def walk_motion_allowed(self, distance):
        return True

    def waypoint_reached(self, name, target, s):
        return False

    def update(self, s, now):
        self.frame = s['frame']
        sandbox = s.get('sandbox')
        require(sandbox is not None, 'sandbox-walk observer available in this package')
        fleet = sandbox['fleet']
        require(set(fleet) == self.FLEET, 'complete nine-craft fleet observed')
        ids = {key: craft['ship_id'] for key, craft in fleet.items()}
        if self.fleet_ids is None:
            self.fleet_ids, self.player_id = ids, s['player_id']
        require(self.fleet_ids == ids and self.player_id == s['player_id'], 'same world fleet and player')
        require(not s['seated'] and all(not c['piloted'] and not c['destroyed'] and c['parked_exact']
                and c['default_sampler'] and c['tuning_unchanged'] for c in fleet.values()),
                'walk preserves parked fleet and authored controls')
        if not self.phases or self.phases[-1] != s['phase']:
            self.phases.append(s['phase'])
        if self.previous is not None:
            frames = s['frame'] - self.previous['frame']
            require(frames > 0, 'fresh physics observation')
            require(norm(sub(s['player'], self.previous['player'])) <= 9.2 * frames / 60 + 1.5,
                    'continuous ordinary walking without recovery teleport')
        self.previous = s
        keys = set()
        dx = 0
        if self.stage == 'boot' and s['menu_ready']:
            self.enter('begin_shift', s)
            self.tap('e', now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP':
            self.enter('walk_station', s)
        elif self.stage == 'walk_station':
            require(s['control_enabled'] and s['phase'] == 'APPROACH_SHIP', 'ordinary on-foot free access')
            name, target = self.WAYPOINTS[self.index]
            off = sub(target, s['player'])
            horizontal = [off[0], 0, off[2]]
            distance = norm(horizontal)
            if distance <= .30 and abs(off[1]) <= .65 and sandbox['grounded'] and self.walk_arrival_ready():
                self.visited.append({'waypoint': name, 'frame': self.frame, 'player': s['player']})
                self.index += 1
                print(json.dumps(self.visited[-1]), flush=True)
                interrupted = self.waypoint_reached(name, target, s)
                if self.index == len(self.WAYPOINTS) and not interrupted:
                    require(self.door_opened, 'ordinary Habitat door interaction observed open')
                    self.enter('complete', s)
                    self.result = {'scope': 'five-branch ordinary station walk only',
                                   'completion_marker': 'NATIVE_SANDBOX_WALK_OK',
                                   'gate_c_sandbox': 'NOT_COMPLETED',
                                   'remaining': ['eight craft launch/land/exit', 'deliberate crash',
                                                 'on-foot recovery', 'regenerate and reuse'],
                                   'visited': self.visited, 'same_player_id': self.player_id,
                                   'same_fleet_ids': self.fleet_ids, 'phases': self.phases}
            else:
                direction = unit(horizontal)
                yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
                dx = round(max(-60, min(60, yaw * .5 / sandbox['walk_mouse'])))
                if abs(yaw) < .08 and self.walk_motion_allowed(distance):
                    keys.add('w')
                    if distance > 3: keys.add('Shift_L')
                for door in sandbox['doors']:
                    # Never send blind E while a ship or workstation is offered.
                    # The readonly candidate proves production selected this door.
                    if door['open']:
                        self.door_opened = True
                    elif not self.door_requested and door['candidate'] and norm(sub(door['position'], s['player'])) < 3:
                        # E reverses a moving StationDoor. One accepted physical
                        # press must finish its authored opening before passage.
                        self.tap('e', now)
                        self.door_requested = self.tap_key == 'e'
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        return keys, dx, 0, False


class SandboxPilot(SandboxWalkPilot):
    """One uninterrupted station/fleet/crash/reuse route through OS controls."""
    TRIGGERS = {
        'arrow_aft_clearance': 'arrow_provisional',
        'Freight': 'jovian_provisional',
        'fleet_trunk_forward': 'zenith_b7_observed',
        'fleet_trunk_mid': 'halyard_new_design',
        'Fleet Dock': 'bulwark_heavy_gunship',
    }
    CINDER = ('cinder_cargo_hauler', 'cinder_long_range_bomber', 'cinder_light_interceptor')
    GROUND_DECELERATION = 42.0
    WALK_SPEED = 5.8
    SPRINT_SPEED = 9.2
    SETTLED_WALK_SPEED = .35

    def __init__(self):
        super().__init__()
        self.craft_key = None
        self.resume_target = None
        self.pending_walk = []
        self.completed = []
        self.excursion = 0
        self.craft_departed = False
        self.shutdown_frame = None
        self.crashed = False
        self.recovered = False
        self.regenerated = False
        self.reusing = False
        self.recovery_walk = 0
        self.dive_previous = None
        self.crash_receipt = None
        self.foot_previous = None
        self.mouse_pending = None
        self.last_state = None
        self.foot_velocity = [0, 0, 0]
        self.foot_sample_seconds = 1/20

    def enter(self, stage, s):
        self.stage = stage
        craft = s['sandbox']['fleet'].get(self.craft_key)
        event = {'stage': stage, 'frame': s['frame'], 'phase': s['phase'],
                 'craft': self.craft_key, 'player': s['player'],
                 'position': craft['position'] if craft is not None else s['position']}
        self.stages.append(event)
        print(json.dumps(event), flush=True)

    def waypoint_reached(self, name, target, s):
        if name in self.TRIGGERS:
            self.resume_target = target
            self.begin_craft(self.TRIGGERS[name], s)
            return True
        return False

    def begin_craft(self, key, s):
        self.craft_key = key
        self.excursion = 0
        self.craft_departed = False
        self.shutdown_frame = None
        craft = s['sandbox']['fleet'][key]
        boarding = craft['boarding']
        # Stay on the existing freight apron and comb rungs before following
        # the physical boarding marker; these are walking goals only.
        if key == 'arrow_provisional':
            self.pending_walk = [[boarding[0], 0, 22], boarding]
        elif key == 'jovian_provisional':
            # The x=-40.6 bollard line and kiosk's x=-40.85 west face
            # must clear the capsule even after a .30m waypoint arrival and
            # ordinary braking drift. The old x=-41 lane grazed the bollards.
            self.pending_walk = [[-42, .38, 40], [-42, .38, boarding[2]], boarding]
        elif key == 'zenith_b7_observed':
            self.pending_walk = [[22, 4.2, 68.3], [20.2, 4.2, 59.2], [18.6, 4.2, 58.6], [18.2, 4.2, 58.2]]
        elif key == 'halyard_new_design':
            self.pending_walk = [[37, 4.2, 68.3], [32.4, 4.2, 68.2], [32, 4.2, 62.2], [32, 4.2, 54.2]]
        elif key == 'bulwark_heavy_gunship':
            self.pending_walk = [[52, 4.2, 68.3], [50.2, 6.6, 59.2], [49, 6.6, 59.2]]
        elif key == 'cinder_cargo_hauler':
            # Cross north of the hull from its clear eastern apron lane.
            self.pending_walk = [[46.5, 6.6, 58.75], [49.2, 6.6, 59.2], [50.2, 6.6, 59.2],
                                 [50.2, 4.2343, 66.2], [35.2, 4.2, 69.4], [25.4, 4.2, 70.6],
                                 [23, 4.18, 72.8], [22.2, 4.18, 75.2],
                                 [22.2, 4.18, 90], [8.8, 4.18, 90]]
        elif key == 'cinder_long_range_bomber':
            # Leave the cargo ramp to the north before crossing its outboard
            # deck. Follow the east Aft lane, then pass south of the workpost
            # before crossing to the west aisle. The diagonal clears the
            # muster locker; the 20mm bridge lip uses normal step-up.
            self.pending_walk = [[7, 4.18, 90], [22.2, 4.18, 90], [22.2, 4.18, 75.2],
                                 [23, 4.18, 72.8], [25.4, 4.2, 70.6], [25.4, 4.2, 68.3],
                                 [-3.5, 4.2, 68.3], [-3.5, 4.2, 64.2], [-4.1, 4.2, 62.8],
                                 [-5.7, 4.2, 61.2], [-9.2, 4.2, 61.2], [-9.2, 4.2, 61.4],
                                 [-10.8, 4.22, 61.4],
                                 [-10.8, 4.2, boarding[2]], boarding]
        elif key == 'cinder_light_interceptor':
            self.pending_walk = [[56, 4.2, 68.3], [56, 4.2, boarding[2]], boarding]
            if not self.reusing:
                self.pending_walk = [[-10.8, 4.2, s['player'][2]], [-10.8, 4.22, 61.4],
                                     [-9.2, 4.2, 61.4], [-9.2, 4.2, 61.2], [-5.7, 4.2, 61.2],
                                     [-4.1, 4.2, 62.8], [-3.5, 4.2, 64.2], [-3.5, 4.2, 68.3]] + self.pending_walk
        else:
            self.pending_walk = [boarding]
        self.approach_path = self.pending_walk[:]
        self.return_path = list(reversed(self.approach_path[:-1]))
        if key == 'zenith_b7_observed':
            # The disembarking pilot starts on the port side of the wing;
            # reversing the distant approach goal would cut through that wing.
            self.return_path = [[14.8, 4.2, 57.2], [20.4, 4.2, 59.2], [22, 4.2, 68.3]]
        self.enter('craft_approach', s)

    def walk_arrival_ready(self):
        return norm(self.foot_velocity) <= self.SETTLED_WALK_SPEED

    def walk_motion_allowed(self, distance):
        if distance <= .30:
            return False
        speed = norm(self.foot_velocity)
        if speed <= self.SETTLED_WALK_SPEED:
            return True
        # These are the unchanged production keyboard speeds/deceleration.
        # Account for travel until the next observed physics sample as well as
        # the body's natural braking after releasing the physical movement key.
        commanded_speed = self.SPRINT_SPEED if distance > 3 else self.WALK_SPEED
        stopping = speed*speed/(2*self.GROUND_DECELERATION)
        reaction = max(speed, commanded_speed) * self.foot_sample_seconds
        return distance > stopping + reaction + .10

    def walk(self, s, target, keys):
        off = sub(target, s['player'])
        horizontal = [off[0], 0, off[2]]
        distance = norm(horizontal)
        if distance <= .30 and abs(off[1]) <= .65 and s['sandbox']['grounded']:
            return 0, self.walk_arrival_ready()
        direction = unit(horizontal)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        dx = round(max(-60, min(60, yaw * .5 / s['sandbox']['walk_mouse'])))
        if abs(yaw) < .08 and self.walk_motion_allowed(distance):
            keys.add('w')
            if distance > 3: keys.add('Shift_L')
        return dx, False

    def clear_station_prompt(self, s):
        # Station interactions take priority over boarding in GameFlow. Look
        # away from that actual selected object before sending the ship's E.
        off = sub(s['player'], s['sandbox']['station_candidate']['position'])
        off[1] = 0
        direction = unit(off)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        return round(max(-60, min(60, yaw * .5 / s['sandbox']['walk_mouse'])))

    def pulse(self, keys, now):
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame

    def update(self, s, now):
        self.last_state = {'frame': s['frame'], 'phase': s['phase'], 'player': s['player'],
                           'craft': self.craft_key, 'fleet': s['sandbox']['fleet']}
        previous = self.foot_previous
        normal_foot = s['control_enabled'] and not s['seated'] and not s['transition_busy']
        if self.stage in ('walk_station', 'craft_approach', 'return_walk', 'crash_reboard_clear', 'crash_approach', 'recovery_walk'):
            require(normal_foot and s['phase'] in ('APPROACH_SHIP', 'COMPLETE'),
                    'ordinary foot legs cannot hide an unplanned control or recovery transition')
        self.foot_velocity = [0, 0, 0]
        if previous is not None and normal_foot and previous['normal']:
            frames = s['frame'] - previous['frame']
            require(frames > 0, 'fresh physics observation')
            require(norm(sub(s['player'], previous['player'])) <= 9.2 * frames / 60 + 1.5,
                    'continuous ordinary walking without recovery teleport')
            self.foot_sample_seconds = frames / 60
            self.foot_velocity = [v/self.foot_sample_seconds for v in sub(s['player'], previous['player'])]
            self.foot_velocity[1] = 0
        self.foot_previous = dict(frame=s['frame'], player=s['player'], normal=normal_foot)
        result = self._update_route(s, now)
        keys, dx, dy, fire = result
        # Several physics observations can precede one OS-event dispatch. A
        # repeated unacknowledged relative sweep would accumulate into a large
        # turn. Send the next sweep only after observed attitude changes.
        craft = s['sandbox']['fleet'].get(self.craft_key, {})
        facing = s['walk_forward'] if not s['seated'] else craft.get('back', s['back'])
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001:
                dx = dy = 0
            else:
                self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    def _update_route(self, s, now):
        if self.stage in ('boot', 'begin_shift', 'walk_station'):
            return super().update(s, now)
        self.frame = s['frame']
        fleet = s['sandbox']['fleet']
        require(set(fleet) == self.FLEET, 'complete nine-craft fleet observed')
        require(self.fleet_ids == {k: c['ship_id'] for k, c in fleet.items()}
                and self.player_id == s['player_id'], 'same world fleet and player')
        require(all(c['default_sampler'] and c['tuning_unchanged'] for c in fleet.values()),
                'authored fleet controls and tuning')
        require(all(not c['destroyed'] and not c['piloted'] and c['parked_exact']
                    for k, c in fleet.items() if k != self.craft_key), 'other craft remain safe and parked')
        craft = fleet[self.craft_key]
        if self.stage not in ('craft_approach', 'craft_board'):
            require(craft['active_ship'], 'same active craft throughout sortie lifecycle')
        if craft['active_ship']:
            require(craft['details_current'], 'fresh live active-craft acceptance telemetry')
        state = dict(s, **craft)
        keys = set()
        dx = dy = 0
        speed = norm(craft['velocity'])
        self.excursion = max(self.excursion, norm(sub(craft['position'], craft['parked'])))
        self.craft_departed |= craft['lease_free'] and not craft['landed'] and self.excursion > 8
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        require(not craft['destroyed'] or self.stage in ('crash_dive', 'recover', 'regenerate'),
                'only the deliberate crash may destroy a craft')
        if self.stage == 'craft_approach':
            require(craft['parked_exact'] and not craft['piloted'] and not craft['destroyed'],
                    'walk up to the live parked production craft')
            if craft['candidate'] and s['sandbox']['station_candidate']:
                dx = self.clear_station_prompt(s)
            elif craft['candidate'] and s['control_enabled']:
                self.tap('e', now)
                self.enter('craft_board', s)
            else:
                dx, reached = self.walk(s, self.pending_walk[0], keys)
                if reached and len(self.pending_walk) > 1: self.pending_walk.pop(0)
        elif self.stage == 'craft_board':
            if craft['piloted'] and s['seated'] and craft['active_ship'] and s['phase'] == 'START_ENGINES':
                self.enter('craft_launch', s)
            elif s['phase'] in ('APPROACH_SHIP', 'COMPLETE') and not s['transition_busy']:
                if s['sandbox']['station_candidate']: dx = self.clear_station_prompt(s)
                elif craft['candidate']: self.tap('e', now)
        elif self.stage == 'craft_launch':
            # Fly along the parked axis toward this berth's authored broad
            # capture centre. Reverse thrust is an ordinary default control.
            off = sub(craft['capture_position'], craft['position'])
            off[1] = 0
            forward = [-v for v in craft['back']]
            signed = dot(off, forward)
            if self.craft_departed and (craft['capture'] or abs(signed) < 6):
                keys.add('Prior')
                if speed <= .35 and craft['capture']:
                    self.enter('craft_land', s)
                    self.tap('l', now)
            else:
                keys.add('w' if signed >= 0 else 's')
        elif self.stage == 'craft_land':
            keys.add('Prior')
            if craft['landed'] and s['phase'] == 'SHUT_DOWN':
                require(self.craft_departed and craft['contract'] and craft['lease'] and craft['parked_exact'],
                        'physical departure followed by strict exact occupied home berth')
                keys.clear()
                self.shutdown_frame = self.frame
                self.enter('craft_shutdown', s)
            elif not craft['landing_active'] and craft['capture']:
                self.tap('l', now)
        elif self.stage == 'craft_shutdown':
            # Neutral input for the full authored 1.5 physics seconds. The
            # actual engine state must independently reach OFFLINE.
            if self.frame - self.shutdown_frame >= 90 and craft['telemetry']['engine'] == 'OFFLINE':
                self.enter('craft_exit', s)
                self.tap('e', now)
        elif self.stage == 'craft_exit':
            if not s['seated'] and not craft['piloted'] and s['control_enabled'] and not s['transition_busy']:
                require(craft['lease'] and craft['contract'] and craft['parked_exact'], 'secured berth retained after exit')
                require(norm(sub(s['player'], craft['exit'])) < .65, 'physical craft exit')
                self.completed.append({'craft': self.craft_key, 'frame': self.frame,
                                       'excursion_m': self.excursion, 'reuse': self.reusing})
                print(json.dumps(self.completed[-1]), flush=True)
                if self.reusing:
                    require(self.crashed and self.recovered and self.regenerated and self.recovery_walk > 8,
                            'deliberate crash, ordinary recall, on-foot recovery, regenerated craft reused')
                    require(set(c['craft'] for c in self.completed) == self.FLEET - {'torrent_provisional'},
                            'all eight required craft launched landed and exited')
                    require(len(self.visited) == len(self.WAYPOINTS) and self.door_opened, 'all five branches and Habitat door physically traversed')
                    self.enter('complete', s)
                    self.result = {'scope': 'full Gate C Sandbox', 'gate_c_sandbox': 'COMPLETED',
                                   'completion_marker': 'NATIVE_SANDBOX_OK', 'visited': self.visited,
                                   'craft_sorties': self.completed, 'same_player_id': self.player_id,
                                   'same_fleet_ids': self.fleet_ids, 'deliberate_crash': self.crash_receipt,
                                   'on_foot_recovery_m': self.recovery_walk, 'regenerated_and_reused': self.craft_key,
                                   'phases': self.phases, 'stages': self.stages}
                elif self.craft_key == self.CINDER[-1]:
                    self.enter('crash_reboard_clear', s)
                elif self.craft_key == 'bulwark_heavy_gunship' or self.craft_key in self.CINDER:
                    # All station waypoints are already visited. Continue from
                    # this actual exit to the next craft's clear walking route.
                    self.resume_target = None
                    next_key = self.CINDER[0] if self.craft_key == 'bulwark_heavy_gunship' else self.CINDER[self.CINDER.index(self.craft_key)+1]
                    self.begin_craft(next_key, s)
                else:
                    self.pending_walk = self.return_path[:]
                    if self.resume_target is not None: self.pending_walk.append(self.resume_target)
                    self.enter('return_walk', s)
            elif s['phase'] == 'SHUT_DOWN' and craft['telemetry']['engine'] == 'OFFLINE': self.tap('e', now)
        elif self.stage == 'return_walk':
            if self.pending_walk:
                dx, reached = self.walk(s, self.pending_walk[0], keys)
                if reached: self.pending_walk.pop(0)
            elif self.resume_target is not None:
                self.resume_target = None
                if self.index == len(self.WAYPOINTS): self.begin_craft(self.CINDER[0], s)
                else: self.enter('walk_station', s)
            else:
                self.begin_craft(self.CINDER[self.CINDER.index(self.craft_key)+1], s)
        elif self.stage == 'crash_reboard_clear':
            # Disembarking deliberately blocks immediate reboarding until the
            # player leaves the hatch sphere. Walk away, then acquire it again.
            target = [56, s['player'][1], craft['boarding'][2]]
            dx, reached = self.walk(s, target, keys)
            if reached:
                self.pending_walk = [craft['boarding']]
                self.enter('crash_approach', s)
        elif self.stage == 'crash_approach':
            if craft['candidate'] and s['sandbox']['station_candidate']:
                dx = self.clear_station_prompt(s)
            elif craft['candidate']:
                self.tap('e', now)
                self.enter('crash_board', s)
            else: dx, _ = self.walk(s, craft['boarding'], keys)
        elif self.stage == 'crash_board':
            if craft['piloted'] and s['seated'] and s['phase'] == 'START_ENGINES':
                self.enter('crash_launch', s)
        elif self.stage == 'crash_launch':
            keys.add('s')
            if not craft['landed'] and craft['lease_free'] and norm(sub(craft['position'], craft['parked'])) > craft['departure_lift'] + 2:
                self.mouse_pending = None
                self.enter('crash_climb', s)
        elif self.stage == 'crash_climb':
            surface = s['sandbox']['crash_surface']
            require(surface and dot(surface['normal'], [0, 1, 0]) > .99, 'observed existing upward crash surface')
            target = [surface['position'][0], surface['position'][1]+220, surface['position'][2]]
            off = sub(target, craft['position'])
            dx, dy, align = self.aim(state, [state['camera'][i]+off[i] for i in range(3)], .3)
            distance = norm(off)
            if distance < speed*speed/(2*craft['tuning']['brake']) + 3:
                keys.add('Prior')
            elif align > .99: keys.update(('w', 'Shift_L'))
            if distance < 5 and speed < .5:
                self.enter('crash_align', s)
        elif self.stage == 'crash_align':
            keys.add('Prior')
            dx, dy, align = self.aim(state, s['sandbox']['crash_surface']['position'], .3)
            if align > .9999 and speed < .2: self.enter('crash_dive', s)
        elif self.stage == 'crash_dive':
            dx, dy, align = self.aim(state, s['sandbox']['crash_surface']['position'], .15)
            if craft['destroyed']:
                previous = self.dive_previous
                require(previous is not None and previous['hull'] > 0 and previous['throttle'] > 0 and previous['boost'] and craft['telemetry']['hull'] <= 0,
                        'observed live hull then actual terminal destruction')
                normal = s['sandbox']['crash_surface']['normal']
                closing = -dot(previous['velocity'], normal)
                require(closing > craft['tuning']['impact_threshold'] + craft['tuning']['maximum_hull']/craft['tuning']['impact_scale'],
                        'ordinary boosted dive reached physically destructive normal speed')
                self.crash_receipt = dict(previous, destroyed_frame=self.frame,
                                          destroyed_position=craft['position'], destroyed_hull=craft['telemetry']['hull'],
                                          surface=s['sandbox']['crash_surface'])
                self.crashed = True
                self.enter('recover', s)
            else:
                self.dive_previous = {'frame': self.frame, 'velocity': craft['velocity'],
                                      'position': craft['position'], 'hull': craft['telemetry']['hull'],
                                      'throttle': craft['command_throttle'], 'boost': craft['command_boost']}
                keys.update(('w', 'Shift_L'))
        elif self.stage == 'recover':
            if not s['seated'] and s['control_enabled'] and s['sandbox']['grounded'] and not s['transition_busy']:
                require(norm(sub(s['player'], s['spawn'])) < 2, 'production destruction recall returns same player to deck')
                self.recovered = True
                self.enter('regenerate', s)
        elif self.stage == 'regenerate':
            if not craft['destroyed'] and not craft['regeneration_pending']:
                require(craft['lease'] and craft['parked_exact'] and craft['landed'], 'production regeneration restores exact occupied berth')
                self.regenerated = True
                self.reusing = True
                # Reuse the already walked central→Aft→Fleet Dock route after
                # production recall; no observer or driver writes the avatar.
                self.pending_walk = [p for name,p in self.WAYPOINTS[40:]]
                self.enter('recovery_walk', s)
        elif self.stage == 'recovery_walk':
            self.recovery_walk = max(self.recovery_walk, norm(sub(s['player'], s['spawn'])))
            dx, reached = self.walk(s, self.pending_walk[0], keys)
            if reached:
                self.pending_walk.pop(0)
                if not self.pending_walk: self.begin_craft(self.craft_key, s)
        self.pulse(keys, now)
        return keys, dx, dy, False


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    elif process:
        process.wait()


def run(binary, output, route="guided"):
    require(route in ("guided", "sandbox-walk", "sandbox"), "known ordinary-input route")
    output.mkdir(parents=True, exist_ok=False)
    game = xvfb = desktop = pilot = None
    temporary_profile = None
    result = {'driver_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'success': False, 'cap_seconds': CAP, 'binary': str(binary), 'native_gpu': 'NOT_RUN',
              'human_review': 'NOT_RUN', 'route': route, 'input_route': 'OS XTest → X11 → Godot Input → default sampler'}
    start = time.monotonic()
    def abort(_signal, _frame): raise TimeoutError('independent abort/deadline')
    old_signals = {sig: signal.signal(sig, abort) for sig in (signal.SIGALRM, signal.SIGTERM, signal.SIGINT)}
    signal.setitimer(signal.ITIMER_REAL, CAP)
    try:
        temporary_profile = tempfile.TemporaryDirectory(prefix='mudds-native-sortie-')
        if temporary_profile:
            profile = Path(temporary_profile.name)
            for name in ('data','config','cache','state','runtime','data-dirs','config-dirs','tmp'):
                (profile/name).mkdir(mode=0o700)
            env = {'PATH':'/usr/local/bin:/usr/bin:/bin', 'HOME':os.environ.get('HOME','/tmp'),
                   'MUDDS_PRIVATE_PROBE_INPUT':'native-sortie-x11', 'GODOT_SILENCE_ROOT_WARNING':'1'}
            for key, name in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),
                              ('XDG_STATE_HOME','state'),('XDG_RUNTIME_DIR','runtime'),('XDG_DATA_DIRS','data-dirs'),
                              ('XDG_CONFIG_DIRS','config-dirs'),('TMPDIR','tmp')]: env[key] = str(profile/name)
            # Pick an unoccupied loopback display, then verify the child owns it.
            for number in range(100+secrets.randbelow(200), 600):
                if Path(f'/tmp/.X{number}-lock').exists() or Path(f'/tmp/.X11-unix/X{number}').exists(): continue
                with socket.socket() as sock:
                    try: sock.bind(('127.0.0.1',6000+number))
                    except OSError: continue
                break
            else: raise RuntimeError('no private X display available')
            env['DISPLAY'] = f'127.0.0.1:{number}'
            auth = profile/'Xauthority'
            auth.touch(mode=0o600)
            env['XAUTHORITY'] = str(auth)
            subprocess.run(['xauth','-f',str(auth),'add',env['DISPLAY'],'MIT-MAGIC-COOKIE-1',secrets.token_hex(16)],check=True, env=env,timeout=5)
            with (output/'xvfb.log').open('wb') as xlog:
                xvfb = subprocess.Popen(['Xvfb',f':{number}','-screen','0','1280x720x24','-listen','tcp','-auth',str(auth),'-nolisten','unix'],env=env,stdout=xlog,stderr=subprocess.STDOUT)
                deadline = time.monotonic()+10
                while time.monotonic()<deadline:
                    lock = Path(f'/tmp/.X{number}-lock')
                    if xvfb.poll() is not None: raise RuntimeError('owned Xvfb exited')
                    if lock.exists() and lock.read_text().strip()==str(xvfb.pid):
                        try:
                            with socket.create_connection(('127.0.0.1',6000+number),timeout=.1): break
                        except OSError: pass
                    time.sleep(.05)
                else: raise RuntimeError('owned Xvfb did not become ready')
                # Remove X server pointer acceleration only on our private display.
                # Mouse pixels then retain the authored game's sensitivity.
                subprocess.run(['xset','m','1/1','0'],env=env,check=True,timeout=5)
                desktop = Desktop(env['DISPLAY'], str(auth))
                result['input_helper_pid'] = desktop.process.pid
                args = [str(binary),'--audio-driver','Dummy','--display-driver','x11',
                        '--rendering-driver','dummy','--disable-render-loop',
                        '--native-sortie-observer' if route == 'guided' else '--native-sortie-observer='+route]
                result.update(arguments=args, display=env['DISPLAY'], xvfb_pid=xvfb.pid,
                              binary_sha256=hashlib.file_digest(binary.open('rb'),'sha256').hexdigest())
                game = subprocess.Popen(args,cwd=binary.parent,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,bufsize=0)
                result['game_pid'] = game.pid
                deadline = time.monotonic()+15
                window = None
                while time.monotonic()<deadline:
                    if game.poll() is not None: raise RuntimeError('exported game exited before X window')
                    tree = subprocess.run(['xwininfo','-root','-tree'],env=env,capture_output=True,text=True,timeout=2).stdout
                    for candidate in re.findall(r'^\s*(0x[0-9a-f]+)',tree,re.M):
                        prop = subprocess.run(['xprop','-id',candidate,'_NET_WM_PID'],env=env,capture_output=True,text=True,timeout=2).stdout
                        if re.search(r'=\s*'+str(game.pid)+r'\s*$',prop):
                            stats = subprocess.run(['xwininfo','-id',candidate,'-stats'],env=env,capture_output=True,text=True,timeout=2).stdout
                            if 'Map State: IsViewable' in stats:
                                window=int(candidate,16)
                                break
                    if window: break
                    time.sleep(.05)
                if not window: raise RuntimeError('no X11 window owned by exact game PID')
                result['window'] = hex(window)
                desktop.focus(window)
                pilot = {"guided": Pilot, "sandbox-walk": SandboxWalkPilot, "sandbox": SandboxPilot}[route]()
                selector = selectors.DefaultSelector()
                selector.register(game.stdout,selectors.EVENT_READ)
                pending = b''
                with (output/'game.log').open('wb') as log:
                    while pilot.result is None:
                        if game.poll() is not None: raise RuntimeError(f'game exited during {pilot.stage}: {game.returncode}')
                        if xvfb.poll() is not None: raise RuntimeError('owned Xvfb exited during sortie')
                        if time.monotonic()-start >= CAP: raise TimeoutError('300-second sortie cap')
                        for key,_ in selector.select(.1):
                            chunk = os.read(key.fd,262144)
                            if not chunk: continue
                            log.write(chunk); log.flush()
                            pending += chunk
                            lines = pending.split(b'\n'); pending=lines.pop()
                            observations = observations_from_lines(lines)
                            if observations:
                                keys,dx,dy,fire=pilot.update(observations[-1],time.monotonic())
                                desktop.keys(keys); desktop.mouse(dx,dy,fire)
                    result.update(success=True,sortie=pilot.result)
    except Exception as error:
        if pilot is not None:
            result['partial_sortie'] = {'stage': pilot.stage, 'stages': pilot.stages, 'phases': pilot.phases}
            if isinstance(pilot, SandboxPilot):
                result['partial_sortie'].update(visited=pilot.visited, craft_sorties=pilot.completed,
                                               last_state=pilot.last_state, deliberate_crash=pilot.crash_receipt)
        result['error'] = f'{type(error).__name__}: {error}'
    finally:
        signal.setitimer(signal.ITIMER_REAL,0)
        # A second cancel must not strand the other owned child midway through
        # bounded cleanup. Each independent cleanup runs even if another fails.
        for sig in old_signals: signal.signal(sig,signal.SIG_IGN)
        cleanup_errors = []
        if desktop:
            try:
                desktop.close()
                result['inputs_released'] = True
            except Exception as error:
                cleanup_errors.append('release input: '+str(error))
        result['input_helper_reaped'] = desktop is None or not desktop.process.is_alive()
        if not result['input_helper_reaped']:
            cleanup_errors.append('private input helper remains alive after bounded cleanup')
        for name, process in [('game',game),('xvfb',xvfb)]:
            try:
                stop(process)
                if name == 'game' and process is not None and process.stdout is not None:
                    drain_game_output(process, output/'game.log')
            except Exception as error: cleanup_errors.append(name+': '+str(error))
            finally:
                if name == 'game' and process is not None and process.stdout is not None:
                    try: process.stdout.close()
                    except Exception as error: cleanup_errors.append('game output close: '+str(error))
            result[name+'_reaped'] = process is None or process.poll() is not None
        if temporary_profile:
            try: temporary_profile.cleanup()
            except Exception as error: cleanup_errors.append('profile: '+str(error))
        if cleanup_errors:
            result['cleanup_errors'] = cleanup_errors
            result['success'] = False
        log_path = output/'game.log'
        diagnostics = diagnostic_lines(log_path.read_bytes().splitlines()) if log_path.exists() else []
        result['diagnostic_count'] = len(diagnostics)
        if diagnostics:
            result['success'] = False
            result.setdefault('error', 'native game diagnostic: ' + diagnostics[0].decode('utf-8', errors='replace'))
        result['elapsed_seconds'] = round(time.monotonic()-start,3)
        for sig,handler in old_signals.items(): signal.signal(sig,handler)
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary')
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--route', choices=('guided', 'sandbox-walk', 'sandbox'), default='guided',
                        help='sandbox runs the full fleet/crash/reuse route; sandbox-walk covers station traversal only')
    args=parser.parse_args()
    try: binary=validate_binary(args.binary)
    except ValueError as error: parser.error(str(error))
    result=run(binary,args.output.absolute(),args.route)
    print(json.dumps(result,indent=2))
    return 0 if result['success'] and result.get('inputs_released') and result['game_reaped'] and result['xvfb_reaped'] and result['input_helper_reaped'] else 1


if __name__=='__main__': raise SystemExit(main())
