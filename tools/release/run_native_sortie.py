#!/usr/bin/env python3
"""Fly the embedded Linux game with OS XTest keys/mouse on an owned Xvfb.

Usage: run_native_sortie.py GAME.x86_64 --output NEW_RESULT_DIRECTORY
Use --route beacon-entry for normal Torrent departure and actual first Beacon HUD start.
Use --route beacon-settlement to continue through all four beacons and durable settlement.
Use --route arrow-return-reuse for one Arrow precision hit, two home exits and normal UI quit.
Use --route sandbox for the full five-branch/eight-craft/crash/reuse scenario.
Use --route sandbox-walk for the on-foot prerequisite only.
Use --route hulk-arrival for the Guided prelude then the streamed HULK dock/exit.
Use --route hulk-breaker to continue that arrival through the interior breaker.
Use --route hulk-home to carry that earned cell back to a supported yard exit.
Use --route life-gantry for Freight gantry coexistence and original Jovian boarding.
Use --route life-patrol for Habitat door walking beside live patrol and original Torrent boarding.
Use --route life-arm for Aft service-arm coexistence and original Zenith boarding.
Use --route life-tow for Central service coexistence during real walking/boarding.
Use --route habitat-loop for fresh hub/door/bunk sleep-wake/common-room/hub walking.
Use --route habitat-restart for real bunk sleep, normal UI quit, and cold awake controls.
Use --route station-defense for the full ordinary four-hostile defense, reward, home, reset and UI exit.
The default is Guided.
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


def drain_game_output(process, log_path, pending=b'', observe=None):
    # The direct child has been waited for. Read its remaining pipe bytes without
    # blocking cleanup on an unexpected descendant holding the write end open.
    os.set_blocking(process.stdout.fileno(), False)
    deadline = time.monotonic() + 2
    def accept(chunk, final=False):
        nonlocal pending
        if observe is None: return
        pending += chunk
        lines = pending.split(b'\n')
        pending = lines.pop()
        if final and pending:
            lines.append(pending)
            pending = b''
        for sample in observations_from_lines(lines): observe(sample)
    with log_path.open('ab') as log:
        while time.monotonic() < deadline:
            try: chunk = os.read(process.stdout.fileno(), 262144)
            except BlockingIOError:
                accept(b'', final=True)
                return
            if not chunk:
                accept(b'', final=True)
                return
            log.write(chunk)
            accept(chunk)
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


class BeaconEntryPilot(Pilot):
    """Ordinary Torrent departure, physical Beacon 1 approach and actual HUD start."""
    MARKER = 'NATIVE_BEACON_ENTRY_OK'
    MODE = 'beacon-entry'
    ACTIVITY = 'cinder_debris_beacon_traversal'

    def __init__(self):
        super().__init__()
        self.sequence = -1
        self.process_identity = None
        self.beacon_identity = None
        self.last_state = None
        self.receipts = {}
        self.ui_edges = []
        self.ui_key = None
        self.ui_until = self.ui_release_until = 0
        self.ui_pending = None
        self.focus_seen = set()
        self.beacon_braking = False
        self.mouse_pending = None
        self.resume_frame = None

    def beacon_stage(self, stage, s):
        self.stage = stage
        event = {'stage': stage, 'frame': s['frame'], 'sequence': s['sequence']}
        self.stages.append(event)
        self.focus_seen.clear()
        print(json.dumps(event), flush=True)

    def ui_press(self, key, s, now, kind, expected=None):
        require(self.ui_pending is None, 'one outstanding ordinary UI press')
        self.ui_key, self.ui_until = key, now + .08
        self.ui_pending = {'kind': kind, 'expected': expected, 'until': now + 3,
                           'focus': s['ui']['focus_path'], 'sequence': s['sequence']}
        self.ui_edges.append({'sequence': s['sequence'], 'key': key, 'pressed': True,
                              'focus': s['ui']['focus_path'], 'kind': kind})
        return {key}, 0, 0, False

    def ui_update(self, s, now):
        # Paused production physics does not advance. Pulse/release in wall time,
        # and acknowledge actual focus/page changes before sending another key.
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key}, 0, 0, False
            self.ui_edges.append({'sequence': s['sequence'], 'key': self.ui_key, 'pressed': False})
            self.ui_key = None
            self.ui_release_until = now + .10
            return set(), 0, 0, False
        if now < self.ui_release_until or any(s['native_keys'].values()):
            return set(), 0, 0, False
        ui, beacon = s['ui'], s['beacon']
        pending = self.ui_pending
        if pending is not None:
            kind = pending['kind']
            if kind == 'tab':
                accepted = bool(ui['focus_path']) and ui['focus_path'] != pending['focus']
            elif kind == 'select':
                accepted = beacon['selected_id'] == self.ACTIVITY
            elif kind == 'start':
                accepted = (beacon['state'] == 1 and beacon['generation'] == 1
                            and beacon['next_beacon_index'] == 0
                            and beacon['feedback'] == 'DEBRIS BEACON RUN  //  STARTED')
            elif kind == 'resume':
                accepted = not s['paused']
            else:
                accepted = s['paused'] and ui[pending['expected']]
            if not accepted:
                require(now < pending['until'], 'ordinary UI press was not acknowledged: '+kind+'; no retry')
                return set(), 0, 0, False
            self.ui_pending = None
            if kind == 'select':
                self.receipts['selected'] = s
                self.beacon_stage('beacon_start', s)
            elif kind == 'start':
                self.receipts['started_paused'] = s
                self.beacon_stage('beacon_back_activity', s)
            elif kind == 'resume':
                self.resume_frame = s['frame']
                self.receipts['resumed'] = s
                self.beacon_stage('beacon_physics', s)
                return set(), 0, 0, False
            elif kind != 'tab':
                next_stage = {'pause': 'beacon_board', 'board': 'beacon_nearby',
                              'nearby': 'beacon_select', 'back_activity': 'beacon_back_main',
                              'back_main': 'beacon_resume'}[kind]
                self.beacon_stage(next_stage, s)
        if self.stage == 'beacon_pause':
            require(not s['paused'], 'normal unpaused flight before first Escape')
            return self.ui_press('Escape', s, now, 'pause', 'main_visible')
        require(s['paused'], 'pause retained through actual Beacon selection and start')
        if self.stage in ('beacon_back_activity', 'beacon_back_main', 'beacon_resume'):
            page, kind, expected = {
                'beacon_back_activity': ('nearby_visible', 'back_activity', 'activity_visible'),
                'beacon_back_main': ('activity_visible', 'back_main', 'main_visible'),
                'beacon_resume': ('main_visible', 'resume', None),
            }[self.stage]
            require(ui[page], 'expected page before one ordinary Escape: '+page)
            return self.ui_press('Escape', s, now, kind, expected)
        page, name, action = {
            'beacon_board': ('main_visible', 'ActivityBoardButton', 'board'),
            'beacon_nearby': ('activity_visible', 'NearbyActivityOpenButton', 'nearby'),
            'beacon_select': ('nearby_visible', None, 'select'),
            'beacon_start': ('nearby_visible', None, 'start'),
        }[self.stage]
        require(ui[page] and ui['focus_path'], 'current actual page and keyboard focus')
        target = (ui['focus_name'] == name if name else
                  ui['focus_activity'] == self.ACTIVITY and ui['focus_text'] == action.upper())
        if target:
            require(ui['focus_enabled'] and ui['focus_visible'], 'actual enabled visible UI action')
            if action == 'start':
                require(beacon['selected_id'] == self.ACTIVITY and beacon['state'] == 0
                        and beacon['generation'] == 0 and beacon['next_beacon_index'] == 0,
                        'selected fresh Beacon before single START press')
                self.receipts['before_start'] = s
            expected = {'board': 'activity_visible', 'nearby': 'nearby_visible'}.get(action)
            return self.ui_press('Return', s, now, action, expected)
        require(ui['focus_path'] not in self.focus_seen and len(self.focus_seen) < 64,
                'target UI action reachable without cycling keyboard focus')
        self.focus_seen.add(ui['focus_path'])
        return self.ui_press('Tab', s, now, 'tab')

    def update(self, s, now):
        self.last_state = s
        require(s.get('mode') == self.MODE and s['sequence'] > self.sequence,
                'fresh explicit Beacon entry observation including paused UI')
        self.sequence = s['sequence']
        identity = (s['pid'], s['main_id'], s['player_id'], s['ship_id'])
        require(all(identity), 'current process Main Player and Torrent identities')
        if self.process_identity is None: self.process_identity = identity
        require(identity == self.process_identity, 'same process Main Player and Torrent throughout entry')
        beacon = s['beacon']
        if beacon['available']:
            beacon_identity = (beacon['binding_id'], beacon['owner_id'])
            require(all(beacon_identity) and beacon['activity_id'] == self.ACTIVITY
                    and beacon['beacon_count'] == 4, 'actual four-beacon production owner')
            if self.beacon_identity is None:
                require(beacon['state'] == 0 and beacon['generation'] == 0
                        and beacon['next_beacon_index'] == 0, 'initial live Beacon IDLE generation zero')
                self.beacon_identity = beacon_identity
                self.receipts['initial_beacon'] = s
            require(beacon_identity == self.beacon_identity, 'same live Beacon binding and activity owner')
            require(not beacon['reward_requested'], 'entry never requests Beacon reward')
        elif self.beacon_identity is not None:
            require(False, 'same live Beacon owner remains available')
        if not self.stage.startswith('beacon_'):
            require(not s['paused'], 'normal Guided departure remains unpaused')
            if self.stage != 'range': return super().update(s, now)
            require(self.departed and self.max_walk > 8 and s['lease_free']
                    and s['piloted'] and s['seated'] and not s['landed'],
                    'actual walk boarding and ordinary departed Torrent before Beacon transit')
            self.receipts['departed'] = s
            self.tap_key = None
            self.beacon_stage('beacon_transit', s)
        # The authored destination is known before its streamed owner loads.
        # Navigate normally until arrival; UI/physics proof requires that owner.
        if self.stage != 'beacon_transit':
            require(beacon['available'], 'live Beacon owner during entry')
        if s['paused']:
            require(math.isfinite(beacon['distance_m']) and 0 <= beacon['distance_m'] <= 32,
                    'actual same-craft first-beacon approach retained while paused')
        if self.stage in ('beacon_back_activity', 'beacon_back_main', 'beacon_resume'):
            require(beacon['state'] == 1 and beacon['generation'] == 1
                    and beacon['next_beacon_index'] in ((0,) if s['paused'] else (0, 1)),
                    'accepted first-beacon start retained through ordinary resume')
        if beacon['available'] and self.stage not in (
                'beacon_back_activity', 'beacon_back_main', 'beacon_resume', 'beacon_physics'):
            # Only the single outstanding START Return may change this owner.
            starting = self.ui_pending is not None and self.ui_pending['kind'] == 'start'
            if starting:
                require((beacon['state'], beacon['generation'], beacon['next_beacon_index'])
                        in ((0, 0, 0), (1, 1, 0)), 'only expected transition from actual START Return')
            require(starting or (beacon['state'] == 0 and beacon['generation'] == 0
                                and beacon['next_beacon_index'] == 0),
                    'Beacon remains fresh until the actual START Return')
        if self.stage not in ('beacon_transit', 'beacon_physics'):
            return self.ui_update(s, now)
        require(not s['paused'] and self.identities == (s['player_id'], s['ship_id'])
                and s['default_sampler'] and s['tuning_unchanged'], 'ordinary unpaused same-actor controls')
        require(s['phase'] not in ('FAILED', 'RECOVERING') and not s['destroyed']
                and s['piloted'] and s['seated'] and s['active_ship']
                and s['lease_free'] and not s['landed'], 'live departed seated Torrent without recovery')
        speed = norm(s['velocity'])
        require(math.isfinite(beacon['distance_m']) and beacon['distance_m'] >= 0,
                'finite actual authored-frame first-beacon distance')
        if self.stage == 'beacon_physics':
            require(beacon['state'] == 1 and beacon['generation'] == 1
                    and beacon['next_beacon_index'] in (0, 1), 'only first physical beacon can advance')
            require(beacon['distance_m'] <= 32, 'same craft remains within actual first-beacon radius')
            if beacon['next_beacon_index'] == 1:
                require(s['frame'] > self.receipts['started_paused']['frame'],
                        'production physics advances after paused START and real resume')
                self.receipts['first_physics_beacon'] = s
                self.beacon_stage('complete', s)
                self.result = {'completion_marker': self.MARKER,
                               'scope': 'ordinary home departure and actual first Beacon start only',
                               'same_pid': identity[0], 'same_main_id': identity[1],
                               'same_player_id': identity[2], 'same_ship_id': identity[3],
                               'same_binding_id': self.beacon_identity[0],
                               'same_beacon_owner_id': self.beacon_identity[1],
                               'walked_m': self.max_walk, 'excursion_m': self.max_excursion,
                               'default_sampler': True, 'authored_tuning': s['tuning'],
                               'receipts': self.receipts, 'ui_edges': self.ui_edges,
                               'stages': self.stages, 'phases': self.phases,
                               'remaining': ['remaining three beacons', 'reward', 'home return and exit']}
            else:
                require(s['frame'] <= self.resume_frame + 120,
                        'production first-beacon physics did not advance after resume; no retry')
            return {'Prior'}, 0, 0, False
        self.max_excursion = max(self.max_excursion, norm(sub(s['position'], s['parked'])))
        target = beacon['first_world']
        off = sub(target, s['position'])
        distance = norm(off)
        dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
        stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
        if distance < stopping+10: self.beacon_braking = True
        if speed <= .45 and distance > 10: self.beacon_braking = False
        keys = set()
        if distance <= 10 or self.beacon_braking: keys.add('Prior')
        elif align > .72: keys.add('w')
        # Coalesced observations must not multiply an unconsumed OS mouse sweep.
        facing = s['back']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        if beacon['available'] and distance <= 12 and beacon['distance_m'] <= 12 and speed <= .45:
            self.receipts['approached'] = s
            self.beacon_stage('beacon_pause', s)
            return self.ui_update(s, now)
        return keys, dx, dy, False


class BeaconSettlementPilot(BeaconEntryPilot):
    """Retain the accepted entry, then fly and observe the real settlement."""
    MODE = 'beacon-settlement'
    SETTLEMENT_MARKER = 'NATIVE_BEACON_SETTLEMENT_OK'
    REWARD = 'debris_route_navigation_data'

    def __init__(self):
        super().__init__()
        self.entry_result = None
        self.paid_state = None
        self.settlement_identity = None
        self.previous_cursor = 1
        self.previous_frame = None
        self.physical_beacons = []

    @classmethod
    def require_zero(cls, s):
        settlement = s['settlement']
        record = settlement['record']
        require(settlement['configured'] and settlement['store']['source'] == 'primary'
                and record['receipt_serial'] == 0 and record['total_receipts'] == 0
                and record['reward_counts'] == {} and record['last_receipt'] == {},
                'actual fresh zero-receipt production baseline')

    @classmethod
    def require_paid(cls, s):
        settlement = s['settlement']
        record, terminal = settlement['record'], settlement['terminal']
        receipt = {'receipt_id': 1, 'activity_id': cls.ACTIVITY, 'activity_generation': 1,
                   'reward_id': cls.REWARD, 'reward_label': 'Debris navigation data recorded',
                   'granted': True, 'replay_allowed': False}
        require(record == {'schema_version': 1, 'payload_kind': 'game_flow_reward_store',
                           'authority_id': 'game_flow_reward_authority',
                           'store_id': 'game_flow_reward_store', 'receipt_serial': 1,
                           'total_receipts': 1, 'reward_counts': {cls.REWARD: 1},
                           'last_receipt': receipt}, 'exact once-only generation-one navigation receipt')
        require(terminal['schema_version'] == 1 and len(terminal['activities']) == 1,
                'actual single Beacon persisted session')
        entry = terminal['activities'][0]
        require(entry['activity_id'] == cls.ACTIVITY and entry['generation'] == 1
                and entry['state'] == 2 and entry['reward_requested'] is True
                and entry['reward_granted'] is True
                and entry['progress']['state'] == 2 and entry['progress']['generation'] == 1
                and entry['progress']['next_beacon_index'] == 4
                and entry['progress']['reward_requested'] is True,
                'paid terminal and raw progress acknowledge the actual completed generation')
        handoff = settlement['handoff']
        authority = handoff['authority_result']
        require(handoff['accepted'] is True and handoff['reward_committed'] is True
                and authority['accepted'] is True and authority['granted'] is True
                and authority['receipt'] == receipt
                and authority['reason'] == 'reward_receipt_committed',
                'retained actual accepted production reward handoff')

    def update(self, s, now):
        if self.entry_result is None:
            controls = super().update(s, now)
            if self.result is not None:
                self.entry_result = json.loads(json.dumps(self.result))
                self.result = None
                self.require_zero(s)
                self.receipts['settlement_baseline'] = s
                self.previous_frame = s['frame']
                self.beacon_braking = False
                self.beacon_stage('settlement_flight', s)
            return controls
        self.last_state = s
        require(s.get('mode') == self.MODE and s['sequence'] > self.sequence,
                'fresh settlement observation')
        self.sequence = s['sequence']
        identity = (s['pid'], s['main_id'], s['player_id'], s['ship_id'])
        beacon, settlement = s['beacon'], s['settlement']
        require(identity == self.process_identity and beacon['available']
                and (beacon['binding_id'], beacon['owner_id']) == self.beacon_identity
                and beacon['activity_id'] == self.ACTIVITY and beacon['generation'] == 1
                and beacon['beacon_count'] == 4, 'same generation-one process and physical Beacon owners')
        reward_identity = (settlement['authority_id'], settlement['store_id'])
        require(settlement['configured'] and all(reward_identity)
                and settlement['store']['source'] == 'primary', 'actual configured primary reward owners')
        if self.settlement_identity is None:
            baseline = self.receipts['settlement_baseline']['settlement']
            self.settlement_identity = (baseline['authority_id'], baseline['store_id'])
        require(reward_identity == self.settlement_identity, 'same live reward authority and store')
        require(not s['paused'] and s['frame'] > self.previous_frame
                and self.identities == (s['player_id'], s['ship_id'])
                and s['default_sampler'] and s['tuning_unchanged']
                and s['tuning'] == self.receipts['settlement_baseline']['tuning'],
                'normal advancing unpaused physics and unchanged authored controls')
        self.previous_frame = s['frame']
        require(s['phase'] not in ('FAILED', 'RECOVERING') and not s['destroyed']
                and s['piloted'] and s['seated'] and s['active_ship']
                and s['lease_free'] and not s['landed'], 'live departed seated Torrent without recovery')
        cursor = beacon['next_beacon_index']
        require(cursor in (self.previous_cursor, self.previous_cursor + 1) and 1 <= cursor <= 4,
                'each remaining physical beacon observed in order without skips')
        points = beacon['beacons_world']
        require(len(points) == 4 and all(len(p) == 3 and all(math.isfinite(v) for v in p) for p in points),
                'four finite actual transformed beacon positions')
        if cursor > self.previous_cursor:
            require(norm(sub(s['position'], points[cursor-1])) <= 32,
                    'same actual craft physically reaches the newly observed beacon')
            self.physical_beacons.append(s)
            self.beacon_braking = False
        self.previous_cursor = cursor
        if cursor == 4:
            require(beacon['state'] == 2 and beacon['reward_requested'] is True,
                    'actual physical completion and raw paid acknowledgement')
            self.require_paid(s)
            if self.paid_state is None:
                self.paid_state = s
                self.receipts['settlement_paid'] = s
                self.beacon_stage('settlement_stable', s)
            require(settlement['record'] == self.paid_state['settlement']['record']
                    and settlement['terminal'] == self.paid_state['settlement']['terminal'],
                    'complete reward record and paid terminal remain unchanged')
            if s['frame'] - self.paid_state['frame'] >= 60:
                self.receipts['settlement_stable'] = s
                self.beacon_stage('complete', s)
                self.result = {'completion_marker': self.SETTLEMENT_MARKER,
                               'scope': 'ordinary four physical beacons and once-only durable settlement',
                               'entry': self.entry_result, 'receipts': self.receipts,
                               'physical_beacons': self.physical_beacons, 'stages': self.stages,
                               'stable_physics_frames': s['frame'] - self.paid_state['frame'],
                               'remaining': ['home return and exit']}
            return {'Prior'}, 0, 0, False
        require(beacon['state'] == 1 and not beacon['reward_requested'],
                'unpaid active route until actual fourth physical beacon')
        self.require_zero(s)
        speed = norm(s['velocity'])
        require(math.isfinite(speed), 'finite current physical flight speed')
        off = sub(points[cursor], s['position'])
        distance = norm(off)
        dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
        stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
        if distance < stopping+10: self.beacon_braking = True
        if speed <= .45 and distance > 10: self.beacon_braking = False
        keys = set()
        if distance <= 10 or self.beacon_braking: keys.add('Prior')
        elif align > .72: keys.add('w')
        facing = s['back']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, False


class HulkArrivalPilot(Pilot):
    """Normal Torrent Guided prelude, then physical travel to the HULK shelf.

    A fresh Torrent's ordinary landing control unlocks at RETURN_TO_YARD.
    Preserve that full prelude and diverge before its home-return approach.
    There is one landing press and one exit press, with no automatic retries.
    """
    MARKER = 'NATIVE_HULK_ARRIVAL_OK'
    BERTH = 'cinder_hulk_dock'

    def __init__(self):
        super().__init__()
        self.hulk_ids = None
        self.hulk_braking = False
        self.hulk_landing_seen = False
        self.request_frame = None
        self.shutdown_frame = None
        self.mouse_pending = None
        self.last_state = None
        self.departure_receipt = None
        self.arrival_receipt = None

    def update(self, s, now):
        self.last_state = s
        hulk = s.get('hulk')
        require(hulk is not None, 'explicit hulk-arrival observer available in this package')
        if self.stage == 'return_align':
            require(s['phase'] == 'RETURN_TO_YARD' and self.departed,
                    'normal Guided prelude unlocks landing after physical departure')
            require(self.shot and self.fired and s['destroyed_targets'] == 4 and not s['opponent_active'],
                    'normal Guided range and interceptor prelude completed')
            self.departure_receipt = {'frame': s['frame'], 'position': s['position'],
                                      'home_lease_free': s['lease_free'],
                                      'destroyed_targets': s['destroyed_targets'],
                                      'shot_accepted': self.shot, 'opponent_active': s['opponent_active']}
            self.enter('hulk_transit', s)
        if not self.stage.startswith('hulk_'):
            # Preserve Guided commands through the tick that unlocks return_align.
            return super().update(s, now)
        result = self.update_arrival(s, now)
        # During HULK stages a busy engine may produce several observations before
        # one OS mouse event is consumed. Acknowledge attitude before another sweep.
        keys, dx, dy, fire = result
        facing = s['walk_forward'] if not s['seated'] else s['back']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001:
                dx = dy = 0
            else:
                self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    def update_arrival(self, s, now):
        self.frame = s['frame']
        phase, hulk = s['phase'], s['hulk']
        if not self.phases or self.phases[-1] != phase: self.phases.append(phase)
        require(self.identities == (s['player_id'], s['ship_id']), 'same Torrent and Player throughout arrival')
        require(s['default_sampler'] and s['tuning_unchanged'], 'authored Torrent controls and tuning')
        require(phase not in ('FAILED', 'RECOVERING') and not s['destroyed'], 'live arrival without recovery')
        require(s['active_ship'] and s['lease_free'], 'same active Torrent and released home berth')
        if self.stage != 'hulk_exit':
            require(s['piloted'] and s['seated'], 'same seated Torrent pilot until normal exit')
        self.max_excursion = max(self.max_excursion, norm(sub(s['position'], s['parked'])))
        if hulk['available']:
            ids = (hulk['hulk_id'], hulk['berth_instance_id'])
            if self.hulk_ids is None: self.hulk_ids = ids
            require(ids == self.hulk_ids and hulk['berth_id'] == self.BERTH,
                    'same live streamed HULK and exact destination berth')
        elif self.hulk_ids is not None:
            require(False, 'streamed HULK lost during arrival')
        keys = set()
        dx = dy = 0
        speed = norm(s['velocity'])
        if self.stage == 'hulk_transit':
            require(phase == 'RETURN_TO_YARD' and not s['landed'], 'ordinary outbound flight before HULK landing')
            target = hulk['approach']
            off = sub(target, s['position'])
            distance = norm(off)
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
            if distance < stopping+2: self.hulk_braking = True
            if speed <= .45 and distance > 1: self.hulk_braking = False
            if distance <= 1 or self.hulk_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if hulk['available'] and distance <= 1 and speed <= .45:
                self.enter('hulk_align', s)
        elif self.stage == 'hulk_align':
            keys.update(('Prior', 'h'))
            target = [s['camera'][i]+hulk['dock_forward'][i]*100 for i in range(3)]
            dx, dy, align = self.aim(s, target)
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(hulk['capture'] and hulk['selected_berth_id'] == self.BERTH,
                        'production landing preview selects streamed cinder_hulk_dock')
                self.landing_distance = norm(sub(s['position'], hulk['dock']))
                self.enter('hulk_land', s)
                self.request_frame = self.frame
                self.tap('l', now)
        elif self.stage == 'hulk_land':
            keys.add('Prior')
            self.hulk_landing_seen |= s['landing_active']
            require(not hulk['landing_abort_reason'], 'production HULK landing aborted: '+hulk['landing_abort_reason'])
            if self.hulk_landing_seen and not s['landing_active'] and not s['landed']:
                require(False, 'production HULK landing ended without docking')
            if s['landed'] and phase == 'SHUT_DOWN':
                require(self.hulk_landing_seen and hulk['contract'] and hulk['lease'] and hulk['parked_exact'],
                        'production strict HULK landing contract and exact occupied dock')
                self.arrival_receipt = {'frame': self.frame, 'position': s['position'],
                                        'berth_id': hulk['berth_id'], 'contract': hulk['contract'],
                                        'lease': hulk['lease'], 'occupant_id': hulk['occupant_id'],
                                        'parked_exact': hulk['parked_exact']}
                self.shutdown_frame = self.frame
                self.enter('hulk_shutdown', s)
                keys.clear()
            elif not self.hulk_landing_seen and self.frame > self.request_frame + 120:
                require(False, 'ordinary L input did not start HULK landing; no retry')
        elif self.stage == 'hulk_shutdown':
            require(phase == 'SHUT_DOWN' and hulk['contract'] and hulk['lease'] and hulk['parked_exact'],
                    'secured HULK berth during normal neutral shutdown')
            if self.frame - self.shutdown_frame >= 90 and s['telemetry']['engine'] == 'OFFLINE':
                self.enter('hulk_exit', s)
                self.request_frame = self.frame
                self.tap('e', now)
        elif self.stage == 'hulk_exit':
            require(hulk['contract'] and hulk['lease'] and hulk['parked_exact']
                    and s['telemetry']['engine'] == 'OFFLINE', 'secured powered-down HULK dock retained during exit')
            if not s['piloted'] and not s['seated'] and s['control_enabled'] and not s['transition_busy'] and hulk['grounded'] and hulk['shelf_supported']:
                require(phase in ('APPROACH_SHIP', 'COMPLETE'), 'normal production disembarkation completed')
                require(hulk['occupant_id'] == s['ship_id'] and self.max_excursion > 350,
                        'flown Torrent occupies HULK after real outbound travel')
                self.enter('complete', s)
                self.result = {'scope': 'Torrent Guided prelude and HULK arrival only',
                               'completion_marker': self.MARKER, 'berth_id': self.BERTH,
                               'guided_prelude': self.departure_receipt, 'arrival': self.arrival_receipt,
                               'same_player_id': s['player_id'], 'same_ship_id': s['ship_id'],
                               'same_hulk_id': self.hulk_ids[0], 'same_berth_instance_id': self.hulk_ids[1],
                               'shelf_support_collider': hulk['support_collider'],
                               'exit_frame': self.frame, 'player_exit_position': s['player'],
                               'player_grounded': hulk['grounded'], 'player_control_enabled': s['control_enabled'],
                               'player_seated': s['seated'], 'ship_piloted': s['piloted'],
                               'engine': s['telemetry']['engine'], 'walked_m': self.max_walk,
                               'excursion_m': self.max_excursion, 'landing_approach_m': self.landing_distance,
                               'authored_tuning': s['tuning'], 'default_sampler': True,
                               'phases': self.phases, 'stages': self.stages,
                               'remaining': ['breaker and reward', 'return and revisit']}
            elif self.frame > self.request_frame + 600:
                require(False, 'ordinary Interact did not finish supported HULK exit; no retry')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        return keys, dx, dy, False


class HulkBreakerPilot(HulkArrivalPilot):
    """Extend the accepted arrival through the live interior with OS input only."""
    MARKER = 'NATIVE_HULK_BREAKER_OK'
    SPACES = ('dock_vestibule', 'spine_corridor', 'reactor_gallery')
    REWARD = 'hulk_auxiliary_power_cell'
    INTERIOR_STAGES = frozenset(('hulk_walk', 'hulk_breaker_aim', 'hulk_breaker_press',
                                'hulk_restoring', 'hulk_repeat_release', 'hulk_repeat_press'))

    def __init__(self):
        super().__init__()
        self.arrival_result = None
        self.interior_initial = None
        self.interior_previous = None
        self.route = None
        self.visited = []
        self.walked_interior = 0
        self.max_step_per_tick = 0
        self.support_colliders = set()
        self.first_press = None
        self.first_active = None
        self.claimed = None
        self.repeat_release = None
        self.repeat_press = None
        self.native_edges = []
        self.native_previous = None

    @staticmethod
    def require_unclaimed(interior):
        activity = interior['activity']
        require(activity['state_id'] == 'idle' and activity['generation'] == 0
                and activity['elapsed_seconds'] == 0 and not activity['reward_claimed']
                and activity['claimed_receipts'] == 0 and interior['reward_count'] == 0
                and not interior['power_restored'] and interior['emergency_lights'],
                'breaker and reward untouched before the complete ordinary interior walk')

    def update(self, s, now):
        self.last_state = s
        if self.stage not in self.INTERIOR_STAGES:
            if s.get('hulk', {}).get('available'):
                interior = s['hulk'].get('interior')
                require(interior is not None, 'explicit hulk-breaker observer available in this package')
                self.require_unclaimed(interior)
            commands = super().update(s, now)
            if self.result is None:
                return commands
            # Actual supported disembarkation is the first navigation point.
            # The authored shelf centre is under the parked hull's gear; match
            # the production hulk-loop route convention without moving anyone.
            self.arrival_result = json.loads(json.dumps(self.result))
            self.arrival_result['completion_marker'] = HulkArrivalPilot.MARKER
            self.result = None
            interior = s['hulk']['interior']
            require(len(interior['route']) == 6 and tuple(interior['space_ids']) == self.SPACES,
                    'all six authored route points and three interior spaces available')
            require(norm(interior['player_velocity']) <= .35, 'actual supported shelf exit settled before interior walking')
            self.interior_initial = json.loads(json.dumps(interior))
            self.route = [[s['player'][0], s['player'][1]+1, s['player'][2]]] + interior['route'][1:]
            self.interior_previous = s
            self.visited.append({'index': 0, 'frame': s['frame'], 'player': s['player'],
                                 'support_collider': s['hulk']['support_collider'],
                                 'speed': norm(interior['player_velocity']),
                                 'meaning': 'actual supported shelf exit'})
            self.tap_key = None
            self.tap_release_frame = s['frame']
            self.tap_cooldown = now + .3
            self.native_previous = bool(s['native_interact'])
            self.enter('hulk_walk', s)
            return set(), 0, 0, False
        keys, dx, dy, fire = self.update_interior(s, now)
        # Preserve the accepted arrival's OS-mouse acknowledgement fence.
        facing = s['walk_forward']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001:
                dx = dy = 0
            else:
                self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    def update_interior(self, s, now):
        self.frame = s['frame']
        hulk = s['hulk']
        interior = hulk['interior']
        activity = interior['activity']
        initial = self.interior_initial
        previous = self.interior_previous
        frames = self.frame - previous['frame']
        require(frames > 0, 'fresh interior physics observation')
        require(self.identities == (s['player_id'], s['ship_id'])
                and self.hulk_ids == (hulk['hulk_id'], hulk['berth_instance_id'])
                and hulk['available'] and hulk['berth_id'] == self.BERTH,
                'same Player Torrent streamed HULK and berth throughout interior')
        require(s['default_sampler'] and s['tuning_unchanged']
                and interior['walk_tuning'] == initial['walk_tuning']
                and interior['physics_ticks'] == 60 and interior['time_scale'] == 1,
                'authored controls and normal physics throughout interior')
        require(s['phase'] in ('COMPLETE', 'APPROACH_SHIP') and not s['destroyed']
                and not s['piloted'] and not s['seated'] and s['control_enabled']
                and not s['transition_busy'], 'ordinary on-foot interior without recovery or seating')
        require(s['active_ship'] and s['lease_free'] and s['landed']
                and hulk['contract'] and hulk['lease'] and hulk['parked_exact']
                and hulk['occupant_id'] == s['ship_id'] and s['telemetry']['engine'] == 'OFFLINE',
                'same powered-down Torrent retains exact occupied HULK berth')
        require(hulk['grounded'] and interior['support_owned'] and hulk['support_collider'],
                'continuous actual HULK support throughout interior')
        require(interior['capsule_enabled'] and interior['capsule_id'] == initial['capsule_id']
                and interior['shape_id'] == initial['shape_id'], 'same enabled Player collision capsule')
        require(interior['breaker_id'] == initial['breaker_id']
                and interior['route'] == initial['route'] and tuple(interior['space_ids']) == self.SPACES,
                'same live breaker and unchanged authored interior route')
        step = norm(sub(s['player'], previous['player']))
        require(step <= (initial['walk_tuning']['sprint']/60*1.25+.02)*frames,
                'continuous ordinary interior movement without placement or recovery teleport')
        self.walked_interior += step
        self.max_step_per_tick = max(self.max_step_per_tick, step/frames)
        self.support_colliders.add(hulk['support_collider'])
        native_pressed = bool(s['native_interact'])
        if native_pressed != self.native_previous:
            self.native_edges.append({'pressed': native_pressed, 'frame': self.frame,
                                      'breaker_candidate': interior['breaker_candidate']})
        self.native_previous = native_pressed
        previous_elapsed = previous['hulk']['interior']['activity']['elapsed_seconds']
        require(activity['restore_seconds'] == 3
                and activity['elapsed_seconds'] <= previous_elapsed + frames/60 + .0001,
                'normal three-second restoration without accelerated activity timer')
        self.interior_previous = s
        keys = set()
        dx = 0
        speed = norm([interior['player_velocity'][0], 0, interior['player_velocity'][2]])
        if self.stage in ('hulk_walk', 'hulk_breaker_aim'):
            self.require_unclaimed(interior)
        if self.stage == 'hulk_walk':
            target = self.route[len(self.visited)]
            off = sub(target, s['player'])
            off[1] = 0
            distance = norm(off)
            if distance <= .30 and speed <= .35:
                self.visited.append({'index': len(self.visited), 'frame': self.frame,
                                     'player': s['player'], 'speed': speed,
                                     'support_collider': hulk['support_collider']})
                print(json.dumps(self.visited[-1]), flush=True)
                if len(self.visited) == len(self.route):
                    minimum = sum(norm(sub(a, b)) for a, b in zip(self.route, self.route[1:])) - .6*(len(self.route)-1)
                    require(self.walked_interior >= minimum, 'sampled movement covers every authored interior space')
                    self.enter('hulk_breaker_aim', s)
            else:
                direction = unit(off)
                yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
                dx = round(max(-360, min(360, yaw/interior['walk_tuning']['mouse'])))
                tuning = interior['walk_tuning']
                commanded_speed = tuning['sprint'] if distance > 3 else tuning['walk']
                stopping = speed*speed/(2*tuning['deceleration']) + max(speed, commanded_speed)*frames/60 + .10
                if abs(yaw) < .08 and distance > .30 and (speed <= .35 or distance > stopping):
                    keys.add('w')
                    if distance > 3: keys.add('Shift_L')
        elif self.stage == 'hulk_breaker_aim':
            off = sub(interior['breaker_position'], s['player'])
            off[1] = 0
            yaw = math.atan2(dot(unit(off), s['walk_right']), dot(unit(off), s['walk_forward']))
            dx = round(max(-360, min(360, yaw/interior['walk_tuning']['mouse'])))
            if abs(yaw) < .08 and speed <= .35 and interior['breaker_candidate'] and not native_pressed:
                self.tap('e', now)
                if self.tap_key == 'e':
                    self.first_press = self.frame
                    self.enter('hulk_breaker_press', s)
        elif self.stage == 'hulk_breaker_press':
            if activity['state_id'] == 'idle':
                self.require_unclaimed(interior)
                require(self.frame <= self.first_press + 120, 'ordinary E did not engage live breaker; no retry')
            else:
                require(activity['state_id'] == 'active' and activity['generation'] == 1
                        and interior['breaker_engaged'] and interior['reward_count'] == 0
                        and any(e['pressed'] and e['frame'] > self.first_press for e in self.native_edges),
                        'observed ordinary E press engages live breaker after complete interior walk')
                self.first_active = {'frame': self.frame, 'elapsed_seconds': activity['elapsed_seconds'],
                                     'generation': activity['generation']}
                self.enter('hulk_restoring', s)
        elif self.stage == 'hulk_restoring':
            require(activity['generation'] == 1 and activity['state_id'] in ('active', 'complete', 'claimed'),
                    'same one-shot restoration generation')
            if activity['state_id'] != 'claimed':
                require(interior['reward_count'] == 0 and not interior['power_restored']
                        and interior['emergency_lights'], 'no premature cell or restored bus lighting')
            else:
                self.require_claimed(interior)
                require(self.frame - self.first_press >= 180
                        and math.isclose(activity['elapsed_seconds'], 3, rel_tol=0, abs_tol=1e-12),
                        'normal three-second production restoration completed before reward')
                self.claimed = {'frame': self.frame, 'reward_count': interior['reward_count'],
                                'generation': activity['generation'], 'receipt': interior['reward_receipt']}
                self.enter('hulk_repeat_release', s)
        elif self.stage == 'hulk_repeat_release':
            self.require_claimed(interior)
            if not native_pressed and self.tap_key is None and self.frame >= self.tap_release_frame + 6:
                self.repeat_release = self.frame
                self.tap('e', now)
                if self.tap_key == 'e':
                    require(interior['breaker_candidate'], 'same live breaker selected for separate repeated E')
                    self.repeat_press = self.frame
                    self.enter('hulk_repeat_press', s)
        elif self.stage == 'hulk_repeat_press':
            self.require_claimed(interior)
            repeated = interior['last_breaker_result']
            if any(e['pressed'] and e['frame'] > self.repeat_press for e in self.native_edges):
                if repeated.get('reason') == 'power_already_restored' and not native_pressed and self.tap_key is None:
                    require(not repeated.get('accepted') and self.repeat_release > self.first_press,
                            'separate released-then-pressed E refuses duplicate breaker reward')
                    self.enter('complete', s)
                    self.result = {'scope': 'Torrent Guided prelude, HULK arrival and interior breaker only',
                                   'completion_marker': self.MARKER, 'arrival': self.arrival_result,
                                   'authored_route': initial['route'], 'walk_route': self.route,
                                   'route_start': 'actual supported shelf exit replaces occupied authored shelf centre',
                                   'visited': self.visited, 'space_ids': list(self.SPACES),
                                   'walked_interior_m': self.walked_interior,
                                   'max_step_per_physics_tick_m': self.max_step_per_tick,
                                   'support_colliders': sorted(self.support_colliders),
                                   'same_capsule_id': initial['capsule_id'], 'same_shape_id': initial['shape_id'],
                                   'same_breaker_id': initial['breaker_id'], 'walk_tuning': initial['walk_tuning'],
                                   'initial_reward_count': initial['reward_count'],
                                   'initial_generation': initial['activity']['generation'],
                                   'first_press_frame': self.first_press,
                                   'first_active': self.first_active, 'claimed': self.claimed,
                                   'repeat_release_frame': self.repeat_release, 'repeat_press_frame': self.repeat_press,
                                   'native_interact_edges': self.native_edges,
                                   'repeated_result': repeated, 'final_reward_count': interior['reward_count'],
                                   'final_generation': activity['generation'], 'lights': interior['lights'],
                                   'restored_bus_lighting': True, 'phases': self.phases, 'stages': self.stages,
                                   'remaining': ['return and revisit', 'disk reload and OS interruption']}
            require(self.result is not None or self.frame <= self.repeat_press + 120,
                    'ordinary repeated E did not dispatch duplicate refusal; no retry')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        return keys, dx, 0, False

    def require_claimed(self, interior):
        activity, receipt = interior['activity'], interior['reward_receipt']
        require(activity['state_id'] == 'claimed' and activity['generation'] == 1
                and activity['reward_claimed'] and activity['claimed_receipts'] == 1
                and interior['reward_count'] == 1 and receipt.get('granted')
                and receipt.get('activity_id') == 'cinder_hulk_power_restoration'
                and receipt.get('reward_id') == self.REWARD and receipt.get('activity_generation') == 1
                and interior['power_restored'] and interior['bus_lights_restored'],
                'exactly one committed hulk_auxiliary_power_cell and restored bus lighting')
        if self.claimed is not None:
            require(receipt == self.claimed['receipt'], 'repeated E retains the same committed cell receipt')


class HulkHomePilot(HulkBreakerPilot):
    """Accepted breaker prefix, ordinary reverse walk and physical home return."""
    MARKER = 'NATIVE_HULK_HOME_OK'

    def __init__(self):
        super().__init__()
        self.breaker_result = None
        self.reverse_route = None
        self.reverse_visited = []
        self.home_previous = None
        self.streaming_initial = None
        self.home_berth_identity = None
        self.home_board_press = None
        self.home_boarded = None
        self.hulk_departure = None
        self.fade_retirement = None
        self.cinder_unload = None
        self.home_arrival = None
        self.home_exit = None
        self.home_landing_seen = False
        self.home_walked = 0
        self.reverse_walked = 0
        self.home_clearance_target = None
        self.home_clearance_staging = None
        self.home_clearance_ready = None
        self.home_header_samples = []
        self.home_header_crossing = None

    def update(self, s, now):
        self.last_state = s
        if self.breaker_result is None:
            commands = super().update(s, now)
            if self.result is None:
                return commands
            # Capture the complete accepted prefix before dispatching any home
            # stages. Parent updates would require an unclaimed resident HULK.
            self.breaker_result = json.loads(json.dumps(self.result))
            self.breaker_result['completion_marker'] = HulkBreakerPilot.MARKER
            self.result = None
            home = s['hulk_home']
            require(s['guided_complete'], 'accepted HULK exit completed Guided before the later free sortie')
            self.streaming_initial = json.loads(json.dumps(home['streaming']))
            require(self.streaming_initial['loaded'] and not self.streaming_initial['loading']
                    and self.streaming_initial['loaded_generation'] == self.streaming_initial['generation']
                    and self.streaming_initial['generation'] > 0
                    and self.streaming_initial['load_request_count'] == 1
                    and self.streaming_initial['load_failure_count'] == 0
                    and self.streaming_initial['unload_count'] == 0,
                    'one live original Cinder generation before ordinary home return')
            self.home_berth_identity = (home['home']['berth_id'], home['home']['berth_instance_id'])
            # Settle outside RangeHeader before crossing under it. The existing
            # home approach is y2/z-18 in the yard frame; the documented shared
            # ship-origin clearance band is y1.4..3.8, with an authored aim2.7.
            approach = home['home']['approach']
            self.home_clearance_target = [approach[0], approach[1]+.7, approach[2]-132]
            self.reverse_route = [point[:] for point in reversed(self.route)]
            self.home_previous = s
            self.mouse_pending = None
            self.enter('home_reverse_walk', s)
            return set(), 0, 0, False
        commands = self.update_home(s, now)
        facing = s['walk_forward'] if not s['seated'] else s['back']
        keys, dx, dy, fire = commands
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001:
                dx = dy = 0
            else:
                self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    def require_retained_cell(self, home):
        activity, receipt = home['activity'], home['reward_receipt']
        require(home['reward_count'] == 1 and receipt == self.claimed['receipt']
                and activity['state_id'] == 'claimed' and activity['generation'] == 1
                and activity['reward_claimed'] and activity['claimed_receipts'] == 1
                and activity['restore_seconds'] == 3
                and math.isclose(activity['elapsed_seconds'], 3, rel_tol=0, abs_tol=1e-12),
                'earned cell count one, exact receipt and claimed generation one retained throughout home return')

    def observe_home_streaming(self, s):
        streaming, initial = s['hulk_home']['streaming'], self.streaming_initial
        require(streaming['unload_radius_m'] == initial['unload_radius_m'] == 650
                and streaming['load_request_count'] == initial['load_request_count']
                and streaming['load_failure_count'] == 0 and not streaming['loading'],
                'unchanged Cinder policy with no reload, failure or extra generation')
        if streaming['loaded']:
            require(self.cinder_unload is None and s['hulk']['available']
                    and self.hulk_ids == (s['hulk']['hulk_id'], s['hulk']['berth_instance_id'])
                    and streaming['loaded_instance_id'] == initial['loaded_instance_id']
                    and streaming['generation'] == initial['generation']
                    and streaming['loaded_generation'] == initial['loaded_generation']
                    and streaming['unload_count'] == initial['unload_count'],
                    'same original streamed HULK until actual Cinder retirement')
        else:
            require(self.hulk_departure is not None and not s['hulk']['available']
                    and streaming['loaded_instance_id'] == 0 and streaming['loaded_generation'] == -1
                    and streaming['generation'] == initial['generation'] + 1
                    and streaming['unload_count'] == initial['unload_count'] + 1,
                    'actual Cinder unload follows observed release of the old HULK lease')
            presentation = streaming['presentation']
            require(presentation.get('accepted') and presentation.get('generation') == initial['generation']
                    and presentation.get('phase') == 'fade_out_complete'
                    and presentation.get('opacity') == 0 and presentation.get('retire_ready')
                    and streaming['distance_m'] > streaming['unload_radius_m'],
                    'actual zero-opacity fade retirement and subsequent outside tick before Cinder unload')
            if self.cinder_unload is None:
                self.fade_retirement = {'frame': s['frame'], 'presentation': presentation,
                                        'distance_m': streaming['distance_m']}
                self.cinder_unload = {'frame': s['frame'], 'streaming': json.loads(json.dumps(streaming)),
                                      'old_hulk_absent': True}

    def observe_home_header(self, s):
        previous = self.home_previous
        # RangeHeader is z-120, 1m deep. This 20m ship-origin interval also
        # clears Torrent's 9m hull on both sides of the beam, with margin.
        near_z, far_z = self.home_clearance_target[2]+20, self.home_clearance_target[2]+40
        if max(previous['position'][2], s['position'][2]) < near_z \
                or min(previous['position'][2], s['position'][2]) > far_z:
            return
        require(self.home_clearance_staging is not None,
                'physical clearance staging must be reached and fully settled before header crossing')
        floor_y = round(self.home_clearance_target[1]-1.3, 10)
        ceiling_y = round(self.home_clearance_target[1]+1.1, 10)
        for sample in (previous, s):
            require(floor_y <= sample['position'][1] <= ceiling_y,
                    'sampled RangeHeader crossing stays in the documented ship-origin clearance band')
            require(sample['telemetry']['hull'] >= self.home_clearance_staging['hull'],
                    'sampled RangeHeader crossing has no extra hull loss after clearance staging')
            if not self.home_header_samples or self.home_header_samples[-1]['frame'] != sample['frame']:
                self.home_header_samples.append({'frame': sample['frame'], 'position': sample['position'][:],
                                                 'hull': sample['telemetry']['hull']})
        if previous['position'][2] <= far_z <= s['position'][2] and self.home_header_crossing is None:
            self.home_header_crossing = {
                'entry_frame': self.home_header_samples[0]['frame'], 'exit_frame': s['frame'],
                'origin_z_interval': [near_z, far_z], 'origin_y_band': [floor_y, ceiling_y],
                'min_y': min(sample['position'][1] for sample in self.home_header_samples),
                'max_y': max(sample['position'][1] for sample in self.home_header_samples),
                'hull_before': self.home_clearance_staging['hull'], 'hull_after': s['telemetry']['hull'],
                'samples': self.home_header_samples,
            }

    def home_walk_to(self, s, target, keys, frames):
        home = s['hulk_home']
        tuning = home['walk_tuning']
        off = sub(target, s['player'])
        off[1] = 0
        distance = norm(off)
        speed = norm([home['player_velocity'][0], 0, home['player_velocity'][2]])
        if distance <= .30 and speed <= .35:
            return 0, True
        direction = unit(off)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        dx = round(max(-360, min(360, yaw/tuning['mouse'])))
        commanded_speed = tuning['sprint'] if distance > 3 else tuning['walk']
        stopping = speed*speed/(2*tuning['deceleration']) + max(speed, commanded_speed)*frames/60 + .10
        if abs(yaw) < .08 and distance > .30 and (speed <= .35 or distance > stopping):
            keys.add('w')
            if distance > 3: keys.add('Shift_L')
        return dx, False

    def require_home_dock(self, s):
        home = s['hulk_home']['home']
        require(self.cinder_unload is not None and s['landed'] and home['contract'] and home['lease']
                and home['parked_exact'] and home['occupant_id'] == s['ship_id'],
                'strict token-bound exact occupied home berth after actual Cinder unload')

    def update_home(self, s, now):
        self.frame = s['frame']
        previous = self.home_previous
        frames = self.frame - previous['frame']
        home, hulk = s['hulk_home'], s['hulk']
        berth, initial = home['home'], self.interior_initial
        require(frames > 0, 'fresh home-return physics observation')
        require(self.identities == (s['player_id'], s['ship_id']) and s['active_ship']
                and not s['destroyed'] and s['phase'] not in ('FAILED', 'RECOVERING'),
                'same live Player and Torrent throughout home return without recovery')
        require(s['default_sampler'] and s['tuning_unchanged']
                and home['walk_tuning'] == initial['walk_tuning']
                and home['physics_ticks'] == 60 and home['time_scale'] == 1,
                'authored default controls, walk tuning and normal physics throughout home return')
        require((berth['berth_id'], berth['berth_instance_id']) == self.home_berth_identity
                and home['capsule_id'] == initial['capsule_id'] and home['shape_id'] == initial['shape_id'],
                'same home berth and Player collision capsule throughout home return')
        require(s['guided_complete'], 'Guided completion retained during the later free sortie')
        self.require_retained_cell(home)
        self.observe_home_streaming(s)
        self.observe_home_header(s)
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        keys = set()
        dx = dy = 0
        speed = norm(s['velocity'])
        if self.stage in ('home_reverse_walk', 'home_board_approach', 'home_walk'):
            require(not s['piloted'] and not s['seated'] and s['control_enabled']
                    and not s['transition_busy'] and home['capsule_enabled']
                    and s['phase'] == 'COMPLETE', 'ordinary controllable on-foot home-return walk')
            step = norm(sub(s['player'], previous['player']))
            require(step <= (initial['walk_tuning']['sprint']/60*1.25+.02)*frames,
                    'continuous ordinary home-return walk without placement or recovery teleport')
            if self.stage != 'home_walk':
                self.reverse_walked += step
                require(hulk['grounded'] and hulk['interior']['support_owned'] and hulk['support_collider']
                        and s['landed'] and hulk['contract'] and hulk['lease'] and hulk['parked_exact']
                        and hulk['occupant_id'] == s['ship_id'] and s['telemetry']['engine'] == 'OFFLINE',
                        'actual supported reverse interior walk retains the powered-down HULK dock')
                self.require_claimed(hulk['interior'])
            else:
                self.home_walked += step
                require(berth['grounded'] and berth['supported'] and berth['support_collider'],
                        'continuous actual home-yard support during the usable exit walk')
        if self.stage == 'home_reverse_walk':
            index = len(self.reverse_visited)
            dx, reached = self.home_walk_to(s, self.reverse_route[index], keys, frames)
            if reached:
                self.reverse_visited.append({'index': 5-index, 'frame': self.frame, 'player': s['player'],
                                             'support_collider': hulk['support_collider']})
                if len(self.reverse_visited) == len(self.reverse_route):
                    require(hulk['shelf_supported'], 'reverse route reaches the original actual supported shelf exit')
                    self.enter('home_board_approach', s)
        elif self.stage == 'home_board_approach':
            offset = s['walk_offset'][:]
            offset[1] = 0
            walking_speed = norm(home['player_velocity'])
            if norm(offset) <= 3.1 and s['candidate']:
                require(not home['station_candidate'], 'live Torrent boarding candidate without a conflicting station candidate')
                if walking_speed <= .35:
                    self.tap('e', now)
                    if self.tap_key == 'e':
                        self.home_board_press = {'frame': self.frame, 'player': s['player'],
                                                 'boarding': home['boarding'], 'candidate': True,
                                                 'station_candidate': home['station_candidate']}
                        self.enter('home_board', s)
            else:
                dx, reached = self.home_walk_to(s, home['boarding'], keys, frames)
                require(not reached, 'ordinary walk reached the live Torrent boarding point without a boarding candidate')
        elif self.stage == 'home_board':
            if s['phase'] == 'START_ENGINES':
                require(s['piloted'] and s['seated'] and not s['transition_busy'] and s['landed']
                        and hulk['lease'] and hulk['parked_exact'],
                        'ordinary E boards the same docked Torrent into START_ENGINES')
                self.home_boarded = {'frame': self.frame, 'phase': s['phase']}
                self.enter('home_flight', s)
            else:
                require(s['phase'] in ('COMPLETE', 'BOARDING'), 'ordinary reboarding without a second Guided tutorial')
                if s['phase'] == 'COMPLETE' and not s['transition_busy']:
                    require(self.frame <= self.home_board_press['frame'] + 120,
                            'ordinary E did not start Torrent reboarding; no retry')
                require(self.frame <= self.home_board_press['frame'] + 600,
                        'ordinary E did not finish Torrent reboarding; no retry')
        elif self.stage in ('home_flight', 'home_approach'):
            require(s['piloted'] and s['seated'] and not s['transition_busy']
                    and s['phase'] in ('START_ENGINES', 'FREE_FLIGHT'),
                    'later ordinary thrust follows START_ENGINES to FREE_FLIGHT without another tutorial')
            if self.hulk_departure is None and not s['landed'] and s['phase'] == 'FREE_FLIGHT':
                require(hulk['available'] and hulk['lease_free'] and hulk['occupant_id'] == 0
                        and norm(sub(s['position'], hulk['dock'])) > .01,
                        'physical departure releases the actual old HULK occupant and reservation')
                self.hulk_departure = {'frame': self.frame, 'position': s['position'], 'phase': s['phase'],
                                       'hulk_id': hulk['hulk_id'], 'berth_instance_id': hulk['berth_instance_id'],
                                       'lease_free': hulk['lease_free'], 'occupant_id': hulk['occupant_id']}
            if self.hulk_departure is not None:
                require(s['phase'] == 'FREE_FLIGHT' and not s['landed'] and s['lease_free'],
                        'physical free flight retains released home berth until the home landing')
                if hulk['available']:
                    require(hulk['lease_free'], 'old HULK lease stays free until its streamed berth retires')
            target = self.home_clearance_target if self.stage == 'home_flight' else berth['approach']
            off = sub(target, s['position'])
            distance = norm(off)
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            clearance_ready = True
            if self.stage == 'home_approach' and self.home_clearance_ready is None:
                # Staging settles position, but its inbound attitude can still
                # point down. Thrust acts along that observed nose before the
                # next mouse correction, so brake while aiming at home first.
                direction = unit(off)
                nose_pitch = math.degrees(math.asin(max(-1, min(1, -s['back'][1]))))
                target_pitch = math.degrees(math.asin(max(-1, min(1, direction[1]))))
                pitch_error = abs(nose_pitch - target_pitch)
                # Half a degree permits the existing rounded mouse controller's
                # ~.42 degree deadband without admitting the failed descent.
                clearance_ready = align >= .9999 and pitch_error <= .5 and speed <= .01
                if clearance_ready:
                    self.home_clearance_ready = {
                        'frame': self.frame, 'position': s['position'][:],
                        'velocity': s['velocity'][:], 'speed_m_s': speed,
                        'direction_alignment': align, 'nose_pitch_deg': nose_pitch,
                        'target_pitch_deg': target_pitch, 'pitch_error_deg': pitch_error,
                    }
            stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
            if distance < stopping+1.75: self.return_braking = True
            if speed <= .45 and distance > 1: self.return_braking = False
            if not clearance_ready or distance <= 1 or self.return_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if self.stage == 'home_flight' and distance <= 1 and speed <= .35:
                require(self.hulk_departure is not None, 'released HULK departure precedes physical clearance staging')
                self.home_clearance_staging = {'frame': self.frame, 'waypoint': target[:],
                                               'position': s['position'][:], 'velocity': s['velocity'][:],
                                               'distance_m': distance, 'speed_m_s': speed,
                                               'hull': s['telemetry']['hull']}
                self.return_braking = False
                self.enter('home_approach', s)
            elif self.stage == 'home_approach' and distance <= 1 and speed <= .45 and self.cinder_unload is not None:
                require(self.hulk_departure is not None, 'released HULK departure precedes physical home approach')
                require(self.home_header_crossing is not None, 'sampled safe RangeHeader crossing precedes home alignment')
                self.enter('home_align', s)
        elif self.stage == 'home_align':
            require(s['phase'] == 'FREE_FLIGHT' and s['piloted'] and s['seated'] and not s['landed'],
                    'physical free-flight home approach before ordinary landing')
            keys.update(('Prior', 'h'))
            off = sub(berth['dock'], s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(berth['capture'] and berth['selected_berth_id'] == berth['berth_id'],
                        'production preview selects the actual home berth')
                require(dot([-v for v in s['back']], berth['dock_forward']) < -.95,
                        'ordinary nose-first home approach opposite the parked heading')
                self.tap('l', now)
                if self.tap_key == 'l':
                    self.request_frame = self.frame
                    self.enter('home_land', s)
        elif self.stage == 'home_land':
            keys.add('Prior')
            self.home_landing_seen |= s['landing_active']
            require(not berth['landing_abort_reason'], 'production home landing aborted: '+berth['landing_abort_reason'])
            if self.home_landing_seen and not s['landing_active'] and not s['landed']:
                require(False, 'production home landing ended without docking')
            if s['landed'] and s['phase'] == 'SHUT_DOWN':
                require(self.home_landing_seen, 'ordinary one-L home landing was observed active')
                self.require_home_dock(s)
                self.home_arrival = {'frame': self.frame, 'position': s['position'],
                                     'berth_id': berth['berth_id'], 'berth_instance_id': berth['berth_instance_id'],
                                     'contract': berth['contract'], 'lease': berth['lease'],
                                     'occupant_id': berth['occupant_id'], 'parked_exact': berth['parked_exact']}
                self.shutdown_frame = self.frame
                self.enter('home_shutdown', s)
                keys.clear()
            elif not self.home_landing_seen:
                require(self.frame <= self.request_frame + 120, 'ordinary L did not start home landing; no retry')
        elif self.stage == 'home_shutdown':
            self.require_home_dock(s)
            require(s['phase'] == 'SHUT_DOWN' and s['piloted'] and s['seated'],
                    'secured home berth during ordinary neutral shutdown')
            if self.frame - self.shutdown_frame >= 90 and s['telemetry']['engine'] == 'OFFLINE':
                self.tap('e', now)
                if self.tap_key == 'e':
                    self.request_frame = self.frame
                    self.enter('home_exit', s)
        elif self.stage == 'home_exit':
            self.require_home_dock(s)
            require(s['telemetry']['engine'] == 'OFFLINE', 'powered-down home dock throughout normal exit')
            if not s['piloted'] and not s['seated'] and s['control_enabled'] and not s['transition_busy']:
                require(s['phase'] == 'COMPLETE' and home['capsule_enabled']
                        and berth['grounded'] and berth['supported'] and berth['support_collider'],
                        'ordinary home E finishes at a controllable unseated supported yard exit')
                self.home_exit = {'frame': self.frame, 'player': s['player'],
                                  'support_collider': berth['support_collider'], 'engine': s['telemetry']['engine']}
                self.enter('home_walk', s)
            else:
                require(self.frame <= self.request_frame + 600, 'ordinary E did not finish supported home exit; no retry')
        elif self.stage == 'home_walk':
            self.require_home_dock(s)
            require(s['telemetry']['engine'] == 'OFFLINE', 'powered-down home dock retained during exit walk')
            displacement = norm(sub(s['player'], self.home_exit['player']))
            require(displacement < 5, 'bounded supported home exit walk below five metres')
            if self.frame - self.home_exit['frame'] >= 20:
                require(displacement > .25, 'twenty-tick ordinary home exit walk moves more than a quarter metre')
                self.enter('complete', s)
                self.result = {'scope': 'Torrent Guided prelude, HULK breaker and physical home return',
                               'completion_marker': self.MARKER, 'breaker': self.breaker_result,
                               'reverse_route': self.reverse_route, 'reverse_visited': self.reverse_visited,
                               'reverse_walked_m': self.reverse_walked, 'boarding_press': self.home_board_press,
                               'boarded': self.home_boarded, 'hulk_departure': self.hulk_departure,
                               'fade_retirement': self.fade_retirement, 'cinder_unload': self.cinder_unload,
                               'home_clearance_staging': self.home_clearance_staging,
                               'home_clearance_ready': self.home_clearance_ready,
                               'home_header_crossing': self.home_header_crossing,
                               'home_arrival': self.home_arrival, 'home_exit': self.home_exit,
                               'home_walk_ticks': self.frame - self.home_exit['frame'],
                               'home_walk_displacement_m': displacement, 'home_walked_m': self.home_walked,
                               'home_support_collider': berth['support_collider'],
                               'same_player_id': s['player_id'], 'same_ship_id': s['ship_id'],
                               'same_capsule_id': initial['capsule_id'], 'same_shape_id': initial['shape_id'],
                               'final_reward_count': home['reward_count'], 'final_generation': home['activity']['generation'],
                               'reward_receipt': home['reward_receipt'], 'authored_tuning': s['tuning'],
                               'walk_tuning': home['walk_tuning'], 'default_sampler': True,
                               'phases': self.phases, 'stages': self.stages,
                               'remaining': ['HULK revisit', 'disk reload and OS interruption']}
            else:
                keys.add('w')
        else:
            require(False, 'known home-return stage')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        self.home_previous = s
        return keys, dx, dy, False


class HabitatLoopPilot(Pilot):
    """Fresh Start Shift and the full physical Habitat loop, using OS input only."""
    MARKER = 'NATIVE_HABITAT_LOOP_OK'
    OUTBOUND = (
        ('central_forward', [0, 0, 12.5]),
        ('tractor_forward_clearance', [6, 0, 12.5]),
        ('tractor_east_clearance', [6, 0, 13.5]),
        ('starboard_cargo_exit', [34.8, 0, 13.5]),
        ('starboard_cabinet_clearance', [34.8, 0, 15.5]),
        ('starboard_arm', [43, 0, 15.5]),
        ('habitat_approach', [46, 0, 15.5]),
        ('door_near', [48, 0, 15.5]),
    )

    def __init__(self):
        super().__init__()
        self.initial = self.previous = self.last_state = None
        self.mouse_pending = None
        self.native_previous = False
        self.native_edges = []
        self.visited = []
        self.receipts = {}
        self.route = []
        self.index = 0
        self.walked = 0
        self.support_colliders = set()
        self.sleep_release_frame = None

    def receipt(self, s):
        return {'frame': self.frame, 'player': s['player'], 'grounded': s['grounded'],
                'supported': s['supported'], 'support_collider': s['support_collider'],
                'door': s['door'].copy(), 'bunk': s['bunk'].copy(),
                'sleeping': s['sleeping'], 'control_enabled': s['control_enabled'],
                'native_interact': s['native_interact'], 'common_occupied': s['common_occupied']}

    def begin_walk(self, stage, route, s):
        self.route, self.index = list(route), 0
        self.enter(stage, s)

    def floor_ready(self, s):
        # Start Shift and animated wake can expose ON_FOOT before its first
        # move_and_slide has acquired floor contact. Let normal physics settle.
        return (s['grounded'] and s['supported'] and s['control_enabled']
                and s['capsule_enabled'] and s['mouse_captured'])

    def require_awake(self, s):
        b = s['bunk']
        require(not s['sleeping'] and not s['seated'] and not s['station_seated']
                and not s['game_station_seated'] and not s['transition_busy']
                and s['control_enabled'] and s['mouse_captured'] and s['capsule_enabled'],
                'ordinary awake supported walking controls')
        require(not b['reserved'] and b['occupant_id'] == 0 and b['active_seat_id'] == 0
                and b['available'] and not b['transitioning'], 'no borrowed or retained station reservation')
        require(s['grounded'] and s['supported'] and s['support_collider'],
                'actual physical station floor support throughout walking')

    def yaw_to(self, s, target):
        off = sub(target, s['player'])
        off[1] = 0
        direction = unit(off)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        return round(max(-360, min(360, yaw/s['walk_tuning']['mouse']))), yaw, norm(off)

    def walk_to(self, s, target, keys, frames):
        speed = norm([s['velocity'][0], 0, s['velocity'][2]])
        dx, yaw, distance = self.yaw_to(s, target)
        if distance <= .30 and abs(target[1]-s['player'][1]) <= .65 and speed <= .35:
            return 0, True
        tuning = s['walk_tuning']
        commanded = tuning['sprint'] if distance > 3 else tuning['walk']
        stopping = speed*speed/(2*tuning['deceleration']) + max(speed, commanded)*frames/60 + .10
        if abs(yaw) < .08 and distance > .30 and (speed <= .35 or distance > stopping):
            keys.add('w')
            if distance > 3: keys.add('Shift_L')
        return dx, False

    def update(self, s, now):
        self.last_state = s
        require(s.get('mode') == 'habitat-loop' and s.get('actors_current'),
                'Habitat loop observer available with current production actors')
        self.frame = s['frame']
        if self.initial is None:
            require(s['phase'] == 'INTRO' and not s['door']['open'] and s['door']['state'] == 0,
                    'fresh production title with initially closed Habitat door')
            require(math.hypot(s['spawn'][0]+8.5, s['spawn'][2]-11) < .1
                    and abs(s['spawn'][1]-.18) <= .65
                    and norm(sub(s['player'], s['spawn'])) < .75,
                    'actual authored fresh hub spawn without scenario placement')
            self.initial = s
        initial = self.initial
        require(tuple(s[k] for k in ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id'))
                == tuple(initial[k] for k in ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id'))
                and s['door']['id'] == initial['door']['id'] and s['bunk']['id'] == initial['bunk']['id'],
                'same current Main, world, Player capsule, Habitat door and exact bunk')
        require(s['walk_tuning'] == initial['walk_tuning'] and s['physics_ticks'] == 60 and s['time_scale'] == 1,
                'authored walking controls and normal physics pacing')
        require(s['phase'] in ('INTRO', 'APPROACH_SHIP'), 'ordinary fresh shift without recovery or boarding')
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        frames = self.frame - self.previous['frame'] if self.previous else 1
        require(frames > 0, 'fresh Habitat physics observation')
        if bool(s['native_interact']) != self.native_previous:
            self.native_edges.append({'frame': self.frame, 'pressed': bool(s['native_interact']),
                                      'stage': self.stage, 'door_candidate': s['door']['candidate'],
                                      'bunk_candidate': s['bunk']['candidate']})
        self.native_previous = bool(s['native_interact'])
        walking = self.stage in ('walk_outbound', 'door_aim', 'door_wait', 'walk_bunk', 'bunk_aim',
                                 'walk_common', 'walk_return')
        if walking:
            self.require_awake(s)
            if self.previous and not self.previous['seated'] and not self.previous['transition_busy']:
                step = norm(sub(s['player'], self.previous['player']))
                require(step <= (initial['walk_tuning']['sprint']/60*1.25+.02)*frames,
                        'continuous actual walking without placement or recovery teleport')
                self.walked += step
            self.support_colliders.add(s['support_collider'])
        keys, dx = set(), 0
        if self.stage == 'boot' and s['menu_ready']:
            self.enter('begin_shift', s)
            self.tap('e', now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP' and self.floor_ready(s):
            self.require_awake(s)
            self.receipts['hub_start'] = self.receipt(s)
            self.begin_walk('walk_outbound', self.OUTBOUND, s)
        elif self.stage.startswith('walk_'):
            name, target = self.route[self.index]
            dx, reached = self.walk_to(s, target, keys, frames)
            if reached:
                visit = {'waypoint': name, **self.receipt(s)}
                self.visited.append(visit)
                print(json.dumps(visit), flush=True)
                self.index += 1
                if self.index == len(self.route):
                    if self.stage == 'walk_outbound':
                        require(not s['door']['open'], 'closed door physically approached before interaction')
                        self.enter('door_aim', s)
                    elif self.stage == 'walk_bunk':
                        self.enter('bunk_aim', s)
                    elif self.stage == 'walk_common':
                        require(s['common_occupied'], 'actual observation-common volume occupied on physical floor')
                        self.receipts['common'] = self.receipt(s)
                        reverse = [('common_return_corridor', [59.15, 0, 15.5]),
                                   ('return_bunk_centre', [54.1, 0, 15.5]),
                                   ('return_inner_threshold', [50.5, 0, 15.5])]
                        reverse += [('return_'+name, target) for name, target in reversed(self.OUTBOUND)]
                        reverse += [('original_hub_spawn', initial['spawn'])]
                        self.begin_walk('walk_return', reverse, s)
                    else:
                        require(s['door']['open'] and not s['common_occupied'], 'ordinary reverse doorway and hub return')
                        require(self.walked > 145, 'full out-and-back sampled physical journey')
                        self.receipts['hub_return'] = self.receipt(s)
                        self.enter('complete', s)
                        self.result = {'completion_marker': self.MARKER, 'same_player_id': s['player_id'],
                                       'same_main_id': s['main_id'], 'same_world_id': s['world_id'],
                                       'walked_m': self.walked, 'visited': self.visited,
                                       'receipts': self.receipts, 'native_interact_edges': self.native_edges,
                                       'support_colliders': sorted(self.support_colliders),
                                       'authored_walk_tuning': initial['walk_tuning'], 'phases': self.phases}
        elif self.stage in ('door_aim', 'bunk_aim'):
            target = s['door'] if self.stage == 'door_aim' else s['bunk']
            dx, yaw, _distance = self.yaw_to(s, target['position'])
            if abs(yaw) < .08 and target['candidate'] and not s['native_interact']:
                self.tap('e', now)
                if self.tap_key == 'e':
                    self.receipts['door_press' if self.stage == 'door_aim' else 'sleep_press'] = self.receipt(s)
                    self.enter('door_wait' if self.stage == 'door_aim' else 'sleep_wait', s)
        elif self.stage == 'door_wait' and s['door']['open']:
            require(any(edge['pressed'] and edge['stage'] == 'door_wait' for edge in self.native_edges),
                    'actual OS Interact press opens the selected door')
            self.receipts['door_open'] = self.receipt(s)
            self.begin_walk('walk_bunk', [('inner_threshold', [50.5, 0, 15.5]),
                                        ('bunk_corridor', [s['bunk']['wake'][0], 0, 15.5]),
                                        ('bunk_wake', s['bunk']['wake'])], s)
        elif self.stage == 'sleep_wait' and s['sleeping'] and not s['transition_busy']:
            b = s['bunk']
            require(s['seated'] and s['game_station_seated'] and s['station_seated']
                    and b['reserved'] and b['occupant_id'] == s['player_id'] and b['active']
                    and b['seated_at_bunk'] and not b['transitioning'] and s['control_enabled'],
                    'actual sleep on exact reserved StationBunk anchor')
            require(any(edge['pressed'] and edge['stage'] == 'sleep_wait' for edge in self.native_edges),
                    'actual OS Interact press admitted sleep')
            self.receipts['sleep'] = self.receipt(s)
            self.enter('sleep_release', s)
        elif self.stage == 'sleep_release':
            require(s['sleeping'] and s['bunk']['reserved'] and s['bunk']['active']
                    and s['bunk']['seated_at_bunk'] and not s['transition_busy'],
                    'sleep claim retained until a distinct wake press')
            if self.tap_key is None and not s['native_interact']:
                if self.sleep_release_frame is None: self.sleep_release_frame = self.frame
                if self.frame >= self.sleep_release_frame + 6:
                    self.tap('e', now)
                    if self.tap_key == 'e':
                        self.receipts['wake_press'] = self.receipt(s)
                        self.enter('wake_wait', s)
        elif self.stage == 'wake_wait' and not s['seated'] and not s['transition_busy'] and self.floor_ready(s):
            self.require_awake(s)
            require(any(edge['pressed'] and edge['stage'] == 'wake_wait' for edge in self.native_edges)
                    and self.sleep_release_frame is not None,
                    'released and repressed actual OS Interact wakes')
            require(norm(sub(s['player'], s['bunk']['wake'])) <= .25,
                    'normal bunk wake restores supported authored standing point')
            self.receipts['wake'] = self.receipt(s)
            self.begin_walk('walk_common', [('wake_to_corridor', [s['bunk']['wake'][0], 0, 15.5]),
                                          ('common_corridor', [59.15, 0, 15.5]),
                                          ('common_occupied', [67.8, 0, 15.5])], s)
        if self.stage in ('walk_bunk', 'bunk_aim', 'sleep_wait', 'sleep_release', 'wake_wait', 'walk_common', 'walk_return'):
            require(s['door']['open'], 'opened Habitat access stays physically clear for the full journey')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        # Wait for actual camera motion before sending another mouse sweep.
        if self.mouse_pending is not None:
            if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = None
        if dx: self.mouse_pending = s['walk_forward'][:]
        self.previous = s
        return keys, dx, 0, False


class LifeTowPilot(Pilot):
    """Shared ordinary station walking and original-craft boarding beside live service."""
    MARKER = 'NATIVE_LIFE_TOW_OK'
    OUTBOUND = (('central_forward', [0, 0, 12.5]),
                ('tractor_forward_clearance', [6, 0, 12.5]),
                ('tractor_east_clearance', [6, 0, 13.5]))
    RETURN = (('return_tractor_clearance', [6, 0, 12.5]),
              ('return_central_forward', [0, 0, 12.5]))
    GANTRY_GOALS = (('hub_forward', [0, 0, 13.5]),
                    ('freight_west', [-35, 0, 13.5]),
                    ('freight_north', [-35, 0, 22]),
                    ('freight_rail', [-48, 0, 22]),
                    ('freight_step', [-48, .38, 24]),
                    ('freight_corner', [-49, .38, 26]),
                    ('gantry_approach', [-51.5, .38, 26]),
                    ('gantry_near_start', [-53, .38, 27.5]),
                    ('gantry_near_middle', [-53, .38, 33.5]),
                    ('gantry_near_end', [-53, .38, 40]),
                    ('freight_return', [-42, .38, 40]),
                    ('freight_boarding_z', None), ('freight_boarding_marker', None))
    ARM_GOALS = (('central_aft_turn', [0, 0, 15.5]),
                 ('aft_spine', [0, 0, 39]), ('aft_approach', [0, 0, 46.3]),
                 ('Aft', [0, 0, 51]), ('aft_stair_base', [-5.7, 0, 51]),
                 ('aft_stair_top', [-5.7, 4.2, 61.2]),
                 ('aft_upper_gate', [-3.5, 4.2, 61.5]),
                 ('aft_upper_floor', [-3.5, 4.2, 64.2]),
                 ('aft_upper_turn', [-3.5, 4.2, 68.3]),
                 ('fleet_bridge', [6, 4.2, 68.3]),
                 ('fleet_approach', [13, 4.2, 68.3]),
                 ('fleet_trunk_forward', [22, 4.2, 68.3]),
                 ('zenith_approach', [20.2, 4.2, 59.2]),
                 ('zenith_clearance', [18.6, 4.2, 58.6]),
                 ('zenith_candidate', [18.2, 4.2, 58.2]))
    PATROL_GOALS = (('central_forward', [0, 0, 12.5]),
                    ('tractor_forward_clearance', [6, 0, 12.5]),
                    ('tractor_east_clearance', [6, 0, 13.5]),
                    ('habitat_branch', [34.8, 0, 13.5]),
                    ('habitat_turn', [34.8, 0, 15.5]),
                    ('habitat_approach', [43, 0, 15.5]),
                    ('habitat_outer', [46, 0, 15.5]),
                    ('patrol_door_near', [48, 0, 15.5]),
                    ('patrol_inner_threshold', [50.5, 0, 15.5]),
                    ('patrol_center', [59.15, 0, 15.5]),
                    ('patrol_common', [67.8, 0, 15.5]),
                    ('patrol_center_return', [59.15, 0, 15.5]),
                    ('patrol_corridor_return', [54.1, 0, 15.5]),
                    ('patrol_inner_return', [50.5, 0, 15.5]),
                    ('patrol_door_return', [48, 0, 15.5]),
                    ('habitat_outer_return', [46, 0, 15.5]),
                    ('habitat_approach_return', [43, 0, 15.5]),
                    ('habitat_turn_return', [34.8, 0, 15.5]),
                    ('habitat_branch_return', [34.8, 0, 13.5]),
                    ('tractor_east_return', [6, 0, 13.5]),
                    ('tractor_forward_return', [6, 0, 12.5]),
                    ('central_forward_return', [0, 0, 12.5]))
    ROUTES = {
        'life-tow': {'craft': 'Torrent', 'service': 'Central tow', 'movers': 7,
                     'marker': 'NATIVE_LIFE_TOW_OK', 'goals': (), 'near': ()},
        'life-gantry': {'craft': 'Jovian', 'service': 'Freight gantry', 'movers': 2,
                        'marker': 'NATIVE_LIFE_GANTRY_OK', 'goals': GANTRY_GOALS,
                        'near': ('gantry_near_start', 'gantry_near_end'),
                        'profile': 'gantry', 'path': 'OperationalLattice/Activities/FreightApproachGantry',
                        'ship_name': 'JovianLightFreighter', 'candidate_only': False},
        'life-arm': {'craft': 'Zenith', 'service': 'Aft service arm', 'movers': 3,
                     'marker': 'NATIVE_LIFE_ARM_OK', 'goals': ARM_GOALS,
                     'near': ('aft_stair_top', 'fleet_bridge'),
                     'profile': 'service_arm', 'path': 'OperationalLattice/Activities/AftOperationsActivity',
                     'origin': [5.8, 4.99, 61.2], 'ship_name': 'ZenithInterceptor',
                     'ship_definition_id': 'zenith_b7_observed', 'home_berth_id': 'zenith_fleet_dock_berth',
                     'candidate_only': True, 'motion_proof': True},
        'life-patrol': {'craft': 'Torrent', 'service': 'Habitat patrol', 'movers': 2,
                        'marker': 'NATIVE_LIFE_PATROL_OK', 'goals': PATROL_GOALS,
                        'near': ('patrol_inner_threshold', 'patrol_common'),
                        'profile': 'drone_patrol', 'path': 'OperationalLattice/Activities/HabitatServicePatrol',
                        'origin': [59.15, 4.88, 15.5], 'ship_name': 'TorrentInterceptor',
                        'ship_definition_id': 'torrent_provisional', 'home_berth_id': 'central_berth',
                        'seed': 3301, 'motion_proof': True, 'door_goal': 'patrol_door_near',
                        'door_path': 'HabitatSpine/MainAccess',
                        'mover_paths': ('PresentationRoot/AnimatedServiceDrone01',
                                        'PresentationRoot/AnimatedServiceDrone02')},
    }
    DEFAULT_WALK = {'walk': 5.8, 'sprint': 9.2, 'acceleration': 34.0,
                    'deceleration': 42.0, 'air_acceleration': 9.0, 'jump': 7.4,
                    'gravity': 1.0, 'terminal': 42.0, 'facing': 14.0,
                    'mouse': .0025, 'invert_y': False}

    def __init__(self, route="life-tow"):
        super().__init__()
        require(route in self.ROUTES, "known station service route")
        self.config = self.ROUTES[route]
        self.bounded = bool(self.config["goals"])
        self.mode = route
        self.craft_label = self.config["craft"]
        self.service_label = self.config["service"]
        self.MARKER = self.config["marker"]
        self.goal_started = self.board_started = None
        self.settled_frames = 0
        self.near_active = False
        self.boarding_observed = False
        self.initial = self.previous = self.last_state = self.observed_previous = None
        self.mouse_pending = None
        self.visited = []
        self.receipts = {}
        self.native_edges = []
        self.native_previous = False
        self.route, self.index = [], 0
        self.walked = 0
        self.support_colliders = set()
        self.walk_service = self.seated_service = None
        self.seated_frame = None
        self.near_walked = 0
        self.motion_lag = None
        self.consumed_step_frames = set()

    def receipt(self, s):
        fields = ('frame', 'player', 'grounded', 'supported',
                  'support_collider', 'seated', 'piloted', 'active_ship', 'seated_at_pilot', 'candidate',
                  'player_id', 'ship_id', 'service')
        if self.bounded:
            fields += ('ship_name', 'engine', 'parked_exact', 'home_lease',
                       'home_berth_id', 'home_berth_instance_id', 'boarding')
        if 'ship_definition_id' in self.config:
            fields += ('ship_definition_id', 'station_candidate')
        if 'door_goal' in self.config:
            fields += ('door',)
        return {k: s[k] for k in fields}

    def begin_walk(self, stage, route, s):
        self.route, self.index = list(route), 0
        self.enter(stage, s)
        self.goal_started = None
        self.settled_frames = 0

    def service_goal(self, index, s):
        name, target = self.config["goals"][index]
        if target is None:
            target = [-42, .38, s['boarding'][2]] if index == 11 else s['boarding'][:]
        return name, target

    def require_walking(self, s):
        require(not s['seated'] and not s['station_seated'] and not s['game_station_seated']
                and not s['sleeping'] and not s['transition_busy'] and s['control_enabled']
                and s['mouse_captured'] and s['capsule_enabled'] and not s['piloted'],
                'ordinary awake walking controls without ship ownership')
        require(s['grounded'] and s['supported'] and s['support_collider'],
                'actual physical station floor support throughout walking')

    def yaw_to(self, s, target):
        off = sub(target, s['player'])
        off[1] = 0
        direction = unit(off)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        return round(max(-360, min(360, yaw/s['walk_tuning']['mouse']))), yaw, norm(off)

    def walk_to(self, s, target, keys, frames):
        speed = norm([s['velocity'][0], 0, s['velocity'][2]])
        dx, yaw, distance = self.yaw_to(s, target)
        vertical_error = abs(target[1]-s['player'][1])
        vertical_ok = vertical_error < .8 if self.bounded else vertical_error <= .65
        if distance <= .30 and vertical_ok:
            if self.bounded:
                return 0, self.settled_frames >= 15
            if speed <= .35: return 0, True
        tuning = s['walk_tuning']
        commanded = tuning['sprint'] if distance > 3 else tuning['walk']
        stopping = speed*speed/(2*tuning['deceleration']) + max(speed, commanded)*frames/60 + .10
        if abs(yaw) < .08 and distance > .30 and (speed <= .35 or distance > stopping):
            keys.add('w')
            if distance > 3: keys.add('Shift_L')
        return dx, False

    @staticmethod
    def require_service_interval(start, end, name, all_movers=False):
        require(end['clock'] > start['clock'], name+' has strictly increasing live service clock')
        changed = [a['pose'] != b['pose'] for a, b in zip(start['movers'], end['movers'])]
        require(all(changed) if all_movers else any(changed),
                name+' has actual changed drawn mover transforms')

    def observe_service(self, s):
        service = s['service']
        require(all(service[k] for k in ('enabled', 'advancing', 'processing', 'visible')),
                self.service_label+' service remains visible enabled and advancing')
        require(isinstance(service['clock'], (int, float)) and math.isfinite(service['clock'])
                and service['clock'] >= 0, 'finite live '+self.service_label+' clock')
        movers = service['movers']
        require(len(movers) == self.config['movers'] and all(m['id'] and m['visible'] and m['drawn_mesh_ids'] for m in movers),
                self.service_label+' current service movers retain actual drawn geometry')
        require(all(len(m['pose']) == 4 and all(len(v) == 3 and all(math.isfinite(x) for x in v)
                    for v in m['pose']) for m in movers), 'finite actual drawn mover transforms')
        if self.bounded:
            require(service['profile'] == self.config['profile']
                    and service['path'] == self.config['path'],
                    'actual '+self.service_label+' activity profile')
            require(len(service['origin']) == 3 and all(math.isfinite(x) for x in service['origin']),
                    'finite actual service origin')
            require(service['origin'] == self.initial['service']['origin'], 'unchanged actual service origin')
            if 'origin' in self.config:
                require(norm(sub(service['origin'], self.config['origin'])) < .001, 'authored actual service origin')
        if 'seed' in self.config:
            require(service['seed'] == self.config['seed'], 'authored actual patrol seed')
        if 'mover_paths' in self.config:
            require(tuple(m['path'] for m in movers) == self.config['mover_paths'],
                    'actual authored patrol drone roots')
        initial = self.initial['service'] if self.initial else service
        signature = lambda a: [(m['id'], m['path'], m['drawn_mesh_ids']) for m in a['movers']]
        require(service['id'] == initial['id'] and signature(service) == signature(initial),
                'same current '+self.service_label+' activity and actual drawn movers')
        if self.observed_previous:
            require(service['clock'] >= self.observed_previous['service']['clock'], 'live service clock never rewinds')

    def require_pilot(self, s):
        require(s['phase'] == 'START_ENGINES' and s['seated'] and s['seated_at_pilot']
                and s['piloted'] and not s['remote_piloted'] and s['active_ship']
                and not s['transition_busy'] and not s['station_seated']
                and not s['game_station_seated'] and not s['sleeping'],
                'actual local seated pilot ownership of the original '+self.craft_label)

    @staticmethod
    def finite_vector(value):
        return isinstance(value, list) and len(value) == 3 and all(
            isinstance(x, (int, float)) and not isinstance(x, bool) and math.isfinite(x) for x in value)

    def require_motion_epoch(self, s):
        motion = s.get('completed_motion')
        require(isinstance(motion, dict) and type(motion.get('frame')) is int
                and motion['frame'] >= 0 and isinstance(motion.get('step_up'), dict)
                and self.finite_vector(motion.get('start')) and self.finite_vector(motion.get('end'))
                and self.finite_vector(s['player']) and motion['end'] == s['player'],
                'LIFE completed-motion finite completed actor motion epoch matches observed position')
        lag = s['frame'] - motion['frame']
        require(lag in (0, 1) and (self.motion_lag is None or lag == self.motion_lag),
                'LIFE completed-motion consistent completed actor epoch lag zero or one')
        if self.observed_previous:
            previous_motion = self.observed_previous['completed_motion']
            require(motion['frame'] == previous_motion['frame'] + 1,
                    'LIFE completed-motion consecutive completed actor motion epochs')
        self.motion_lag = lag
        return motion

    def require_step_event(self, s, motion):
        """Admit only a retained successful solver return for this exact tick."""
        previous = self.observed_previous
        event = motion['step_up']
        require(previous is not None and event, 'LIFE completed-motion actual successful step-up event required')
        self.require_walking(previous)
        self.require_walking(s)
        require(previous['default_controls'] and s['default_controls'], 'ordinary step-up endpoint controls')
        require(type(event.get('frame')) is int and event['frame'] == motion['frame']
                and event['frame'] not in self.consumed_step_frames,
                'fresh once-consumed LIFE completed-motion actual step-up frame')
        require(all(type(event.get(k)) is int and event[k] != 0 and event[k] == s[k] == previous[k]
                    for k in ('player_id', 'capsule_id', 'shape_id')),
                'actual step-up current Player capsule and shape identities')
        require(all(self.finite_vector(event.get(k))
                    for k in ('start', 'landing', 'intended', 'up', 'tick_start', 'tick_end')),
                'finite actual step-up vectors')
        require(event['tick_start'] == motion['start'] == previous['player'] == event['start']
                and event['tick_end'] == motion['end'] == s['player'] == event['landing'],
                'exact observed step-up tick start end and committed landing')
        collision_frame = event.get('collision_transform')
        require(isinstance(collision_frame, list) and len(collision_frame) == 4
                and all(self.finite_vector(v) for v in collision_frame)
                and collision_frame == [[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1]],
                'LIFE completed-motion step-up uses identity collision frame')
        require(event['up'] == [0, 1, 0], 'LIFE completed-motion unit world-up actual step-up')
        bounds = event.get('bounds')
        expected = {'max_step_height': .30, 'min_clearance': .02, 'min_advance': .01,
                    'probe_reach': .40, 'capsule_radius': .38, 'capsule_height': 1.94,
                    'floor_max_angle_rad': .872665, 'safe_margin': .002}
        require(isinstance(bounds, dict) and all(
                    isinstance(bounds.get(k), (int, float)) and not isinstance(bounds[k], bool)
                    and math.isfinite(bounds[k]) and abs(bounds[k]-v) <= .000001
                    for k, v in expected.items())
                and self.finite_vector(bounds.get('movement_up')) and bounds['movement_up'] == [0, 1, 0]
                and all(bounds.get(k) is True for k in ('requires_floor_contact', 'requires_wall_contact',
                                                       'requires_walkable_landing', 'within_capsule_radius'))
                and bounds.get('steps_into_void') is False,
                'actual step-up default capsule-derived live bounds')
        geometry = s['capsule_geometry']
        require(isinstance(geometry, list) and len(geometry) == 2
                and all(isinstance(a, (int, float)) and not isinstance(a, bool) and math.isfinite(a)
                        and abs(a-b) <= .000001 for a, b in zip(geometry, [.38, 1.94]))
                and abs(bounds['probe_reach']-bounds['capsule_radius']-bounds['min_clearance']) <= .000001,
                'actual step-up live capsule matches default geometry and probe reach')
        intended = event['intended']
        offset = sub(event['landing'], event['start'])
        tangent = [offset[0], 0, offset[2]]
        advance = norm(tangent)
        require(abs(intended[1]) <= .000001 and norm(intended) > bounds['safe_margin']
                and norm(intended) <= self.DEFAULT_WALK['sprint']/60+.000001
                and dot(tangent, intended) > 0,
                'actual step-up positive intended tangent forward motion')
        # These are the solver's existing .001 rise and min-advance tolerances.
        require(.001 < offset[1] <= bounds['max_step_height']+.001
                and bounds['min_advance'] <= advance <= bounds['probe_reach']+bounds['min_advance'],
                'actual step-up rise and advance remain inside original probe tolerances')
        self.consumed_step_frames.add(event['frame'])

    def validate_observation(self, s):
        """Check every emitted physics sample without staging unsent OS input."""
        self.last_state = s
        require(s.get('mode') == self.mode and s.get('actors_current'),
                self.mode.upper()+' observer has current production actors')
        self.frame = s['frame']
        if self.initial is None:
            require(s['phase'] == 'INTRO' and norm(sub(s['player'], s['spawn'])) < .75
                    and math.hypot(s['spawn'][0]+8.5, s['spawn'][2]-11) < .1
                    and abs(s['spawn'][1]-.18) <= .65,
                    'fresh normal title and authored hub spawn without placement')
            self.initial = s
        initial = self.initial
        require(tuple(s[k] for k in ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id', 'ship_id'))
                == tuple(initial[k] for k in ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id', 'ship_id'))
                and s['capsule_geometry'] == initial['capsule_geometry'],
                'same current Main world Player capsule shape and original '+self.craft_label)
        require(s['walk_tuning'] == self.DEFAULT_WALK and s['physics_ticks'] == 60 and s['time_scale'] == 1
                and s['default_controls'] and s['default_sampler'] and s['tuning_unchanged']
                and s['ship_tuning'] == initial['ship_tuning'], 'default controls and unchanged authored tuning')
        frames = self.frame - self.observed_previous['frame'] if self.observed_previous else 1
        require(frames > 0, 'fresh '+self.mode.upper()+' physics observation')
        if self.bounded:
            require(frames == 1, 'every consecutive '+self.mode.upper()+' physics sample retained')
        motion = self.require_motion_epoch(s) if self.config.get('motion_proof', False) else None
        self.observe_service(s)
        if self.bounded:
            require(s['ship_name'] == self.config['ship_name'] and s['engine'] == 'OFFLINE'
                    and s['parked_exact'] and s['home_lease']
                    and s['home_berth_id'] == initial['home_berth_id']
                    and s['home_berth_instance_id'] == initial['home_berth_instance_id']
                    and s['home_berth_instance_id'],
                    'original '+self.craft_label+' remains offline parked with original occupied reserved home berth')
        if 'ship_definition_id' in self.config:
            require(s['ship_definition_id'] == self.config['ship_definition_id']
                    and s['home_berth_id'] == self.config['home_berth_id'],
                    'original craft definition and authored home berth')
        if 'door_goal' in self.config:
            door, original = s['door'], initial['door']
            require(door['id'] and door['id'] == original['id']
                    and door['path'] == original['path'] == self.config['door_path']
                    and door['position'] == original['position'] and not door['locked'],
                    'same current unlocked Habitat MainAccess door')
            require(door['state'] in (0, 1, 2), 'Habitat door never closes or retries')
            if self.observed_previous:
                require(door['state'] >= self.observed_previous['door']['state'],
                        'Habitat door never closes or retries')
            if self.observed_previous is None:
                require(door['state'] == 0 and not door['open'] and door['blocked'],
                        'fresh Habitat door initially CLOSED and blocked')
            if 'door_open' in self.receipts:
                require(door['state'] == 2 and door['open'] and not door['blocked'],
                        'same Habitat door stays OPEN and portal clear through return and boarding')
            elif door['state'] != 0 or door['open'] or not door['blocked']:
                press = self.receipts.get('door_press', {})
                # Current native edge is appended just below. The opening may
                # begin on that same physics sample.
                edge = bool(s['native_interact']) and not self.native_previous
                require(self.stage == 'door_wait' and press.get('door', {}).get('candidate')
                        and press['door']['id'] == door['id'] and press['frame'] < self.frame
                        and (edge or any(e['pressed'] and e['stage'] == 'door_wait'
                                         and press['frame'] < e['frame'] <= self.frame
                                         for e in self.native_edges)),
                        'Habitat door motion only follows actual candidate receipt and door-stage OS press')
        if bool(s['native_interact']) != self.native_previous:
            self.native_edges.append({'frame': self.frame, 'pressed': bool(s['native_interact']),
                                      'stage': self.stage, 'candidate': s['candidate']})
        self.native_previous = bool(s['native_interact'])
        # Production accepts the ordinary press by entering BOARDING on that
        # same physics sample. Record the real edge before judging that phase.
        if s['phase'] == 'BOARDING':
            press = self.receipts.get('board_press', {})
            require(self.stage == 'board' and press.get('candidate')
                    and press.get('player_id') == s['player_id'] and press.get('ship_id') == s['ship_id']
                    and press.get('frame', self.frame) < self.frame
                    and any(e['pressed'] and e['stage'] == 'board'
                            and press['frame'] < e['frame'] <= self.frame for e in self.native_edges)
                    and s['transition_busy'] and not s['control_enabled'],
                    'BOARDING only follows the original candidate receipt and actual board-stage OS press')
            self.boarding_observed = True
        else:
            require(s['phase'] in ('INTRO', 'APPROACH_SHIP', 'START_ENGINES'), 'no Guided flight or recovery')
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        walking = self.stage in ('walk_outbound', 'walk_return', 'walk_service', 'approach_ship',
                                 'door_aim', 'door_wait')
        if walking or (self.stage == 'board' and not s['transition_busy'] and not s['seated']):
            self.require_walking(s)
            if self.observed_previous:
                step = norm(sub(s['player'], self.observed_previous['player']))
                ordinary_limit = (initial['walk_tuning']['sprint']/60*1.25+.02)*frames
                if motion is not None and motion['step_up']:
                    self.require_step_event(s, motion)
                else:
                    require(step <= ordinary_limit, 'continuous real walking without teleport or placement')
                if motion is not None:
                    require(motion['start'] == self.observed_previous['player'],
                            'continuous LIFE completed-motion actual tick starts at previous observed position')
                self.walked += step
                if (self.near_active if self.bounded else
                        self.walk_service is not None and walking and self.stage != 'approach_ship'):
                    self.near_walked += step
            self.support_colliders.add(s['support_collider'])
        if self.bounded and self.near_active:
            require(norm(sub(s['player'], s['service']['origin'])) <= 12,
                    'every local walking sample within 12m of actual service origin')
        if self.bounded and self.stage == 'walk_service':
            _name, target = self.route[self.index]
            planar = math.hypot(target[0]-s['player'][0], target[2]-s['player'][2])
            settled = planar <= .30 and abs(target[1]-s['player'][1]) < .8 \
                and math.hypot(s['velocity'][0], s['velocity'][2]) < .1
            self.settled_frames = self.settled_frames + 1 if settled and frames == 1 else 0
        if self.stage == 'seated_observe':
            self.require_pilot(s)
        if motion is not None and motion['step_up']:
            require(motion['frame'] in self.consumed_step_frames,
                    'LIFE completed-motion actual step-up event admitted only during supported ordinary walking')
        self.observed_previous = s

    def next_service_goal(self, s, now):
        goal = len(self.visited)
        if goal == len(self.config['goals']):
            self.enter('approach_ship', s)
            self.board_started = now
        else:
            self.route, self.index = [self.service_goal(goal, s)], 0
            self.goal_started, self.settled_frames = now, 0
            if self.stage != 'walk_service':
                self.enter('walk_service', s)

    def update(self, s, now):
        # run() validates the complete batch first. Only its final sample can
        # stage a new command, because that is the command actually sent to X11.
        if self.observed_previous is not s:
            self.validate_observation(s)
        initial = self.initial
        frames = self.frame - self.previous['frame'] if self.previous else 1
        keys, dx = set(), 0
        if self.stage == 'boot' and s['menu_ready']:
            self.enter('begin_shift', s)
            self.tap('e', now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP':
            # Normal Start Shift exposes ON_FOOT just before its first supported frame.
            if s['grounded'] and s['supported'] and s['control_enabled'] and s['mouse_captured'] and s['capsule_enabled']:
                self.require_walking(s)
                self.receipts['hub_start'] = self.receipt(s)
                if self.bounded:
                    self.begin_walk('walk_service', [self.service_goal(0, s)], s)
                    self.goal_started = now
                else:
                    self.begin_walk('walk_outbound', self.OUTBOUND, s)
        elif self.bounded and self.stage == 'walk_service':
            require(now-self.goal_started <= 15, '15-second authored '+self.craft_label+' goal deadline')
            name, target = self.route[self.index]
            dx, reached = self.walk_to(s, target, keys, frames)
            if reached:
                self.visited.append({'waypoint': name, **self.receipt(s)})
                if name == self.config['near'][0]:
                    self.walk_service = s['service']
                    self.receipts['nearby_walk_start'] = self.receipt(s)
                    require(norm(sub(s['player'], s['service']['origin'])) <= 12,
                            'local walking starts within 12m of actual service origin')
                    self.near_active = True
                elif name == self.config['near'][1]:
                    require(self.near_walked > 11, 'actual local service walking exceeds 11m')
                    self.require_service_interval(self.walk_service, s['service'], 'nearby walking', all_movers=True)
                    self.receipts['nearby_walk_end'] = self.receipt(s)
                    self.near_active = False
                if name == self.config.get('door_goal'):
                    require(not s['door']['open'] and s['door']['blocked'],
                            'closed blocked Habitat door physically approached')
                    self.enter('door_aim', s)
                else:
                    self.next_service_goal(s, now)
        elif self.stage in ('door_aim', 'door_wait') and 'door_goal' in self.config:
            require(now-self.goal_started <= 15, '15-second authored Habitat door goal deadline')
            door = s['door']
            if self.stage == 'door_aim':
                dx, yaw, _distance = self.yaw_to(s, door['position'])
                if abs(yaw) < .08 and door['candidate'] and not s['native_interact']:
                    self.tap('e', now)
                    if self.tap_key == 'e':
                        self.receipts['door_press'] = self.receipt(s)
                        self.enter('door_wait', s)
            elif door['state'] == 2 and door['open'] and not door['blocked']:
                press = self.receipts.get('door_press', {})
                require(press.get('door', {}).get('candidate')
                        and any(e['pressed'] and e['stage'] == 'door_wait'
                                and press['frame'] < e['frame'] <= self.frame for e in self.native_edges),
                        'actual door-stage OS Interact opens and clears Habitat portal')
                self.receipts['door_open'] = self.receipt(s)
                self.next_service_goal(s, now)
        elif self.stage in ('walk_outbound', 'walk_return'):
            name, target = self.route[self.index]
            dx, reached = self.walk_to(s, target, keys, frames)
            if reached:
                visit = {'waypoint': name, **self.receipt(s)}
                self.visited.append(visit)
                print(json.dumps(visit), flush=True)
                self.index += 1
                if name == 'central_forward':
                    self.walk_service = s['service']
                if self.index == len(self.route):
                    if self.stage == 'walk_outbound':
                        self.begin_walk('walk_return', self.RETURN, s)
                    else:
                        require(self.walk_service is not None and self.near_walked > 10,
                                'actual nearby out-and-back Central walking interval')
                        self.require_service_interval(self.walk_service, s['service'], 'nearby walking')
                        self.receipts['nearby_walk_start'] = self.walk_service
                        self.receipts['nearby_walk_end'] = self.receipt(s)
                        self.enter('approach_ship', s)
        elif self.stage == 'approach_ship':
            if self.bounded:
                require(now-self.board_started <= 12, '12-second ordinary '+self.craft_label+' boarding deadline')
            off = s['walk_offset'][:]
            off[1] = 0
            candidate_only = self.config.get('candidate_only', False)
            settled = math.hypot(s['velocity'][0], s['velocity'][2]) < .1
            if candidate_only and s['station_candidate']:
                # GameFlow gives the actual station prompt priority over ship
                # boarding. Use the established Sandbox look-away maneuver
                # before the one ordinary E; retain this goal and deadline.
                away = [2*a-b for a, b in zip(s['player'], s['station_candidate']['position'])]
                dx, _yaw, _distance = self.yaw_to(s, away)
            elif s['candidate'] and not s['native_interact'] and ((candidate_only and settled) or
                                                               (not candidate_only and norm(off) <= 3.1)):
                self.receipts['board_press'] = self.receipt(s)
                self.enter('board', s)
                self.tap('e', now)
            elif not candidate_only:
                direction = unit(off)
                x, z = dot(direction, s['walk_right']), dot(direction, s['walk_forward'])
                keys.add('Shift_L')
                if x > .2: keys.add('d')
                if x < -.2: keys.add('a')
                if z > .2: keys.add('w')
                if z < -.2: keys.add('s')
        elif self.stage == 'board' and s['phase'] == 'START_ENGINES' and not s['transition_busy']:
            self.require_pilot(s)
            if self.bounded:
                require(now-self.board_started <= 12, '12-second ordinary '+self.craft_label+' boarding deadline')
                require(self.boarding_observed, 'actual authenticated BOARDING before '+self.craft_label+' pilot ownership')
            require(self.receipts['board_press']['candidate']
                    and any(e['pressed'] and e['stage'] == 'board' for e in self.native_edges),
                    'actual OS Interact press boards the original candidate')
            self.seated_frame, self.seated_service = self.frame, s['service']
            self.receipts['seated_start'] = self.receipt(s)
            self.enter('seated_observe', s)
        elif self.stage == 'seated_observe':
            self.require_pilot(s)
            if self.frame >= self.seated_frame + 90:
                self.require_service_interval(self.seated_service, s['service'], '90 seated physics frames', all_movers=self.bounded)
                self.receipts['seated_end'] = self.receipt(s)
                self.enter('complete', s)
                self.result = {'completion_marker': self.MARKER, 'phases': self.phases, 'stages': self.stages,
                               'same_player_id': s['player_id'], 'same_ship_id': s['ship_id'],
                               'same_service_id': s['service']['id'], 'walked_m': self.walked,
                               'nearby_walked_m': self.near_walked, 'visited': self.visited,
                               'receipts': self.receipts, 'native_interact_edges': self.native_edges,
                               'seated_physics_frames': self.frame-self.seated_frame,
                               'support_colliders': sorted(self.support_colliders),
                               'authored_walk_tuning': initial['walk_tuning']}
        if self.bounded and self.stage == 'board':
            require(now-self.board_started <= 12, '12-second ordinary '+self.craft_label+' boarding deadline')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        if self.mouse_pending is not None:
            if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = None
        if dx: self.mouse_pending = s['walk_forward'][:]
        self.previous = s
        return keys, dx, 0, False


class HabitatRestartFiles:
    """Read the actual game-owned document; copies go only to result storage."""
    MUTABLE = {'solo_safe_recovery', 'crash_recovery', 'session_diagnostics', 'safe_start_recovery'}

    def __init__(self, profile, output):
        self.profile, self.output = profile.resolve(), output
        self.profile_identity = self.identity(self.profile)
        self.path = None
        self.snapshots = {}

    @staticmethod
    def identity(path):
        info = path.stat()
        return [info.st_dev, info.st_ino]

    @classmethod
    def protected(cls, document):
        return {k: v for k, v in document['payload'].items() if k not in cls.MUTABLE}

    def capture(self, label, sample=None):
        require(self.identity(self.profile) == self.profile_identity, 'same original private profile directory')
        if sample is not None:
            candidate = Path(sample['path'])
            require(candidate.is_absolute() and candidate.name == 'mudds_user_data.json'
                    and candidate.is_relative_to(self.profile/'data'), 'real save belongs to the original XDG profile')
            require(all(not parent.is_symlink() for parent in (candidate, *candidate.parents)),
                    'no symlink or substituted save namespace')
            if self.path is None: self.path = candidate
            require(candidate == self.path, 'same actual save path across both processes')
        require(self.path is not None and self.path.is_file(), 'actual game-owned primary save exists')
        require(list((self.profile/'data').rglob('mudds_user_data.json')) == [self.path],
                'one original profile document without replacement namespace')
        raw = self.path.read_bytes()
        document = json.loads(raw)
        require(set(document) == {'schema_version', 'generation', 'commit', 'payload'}
                and document['schema_version'] == 1 and isinstance(document['payload'], dict),
                'actual production document envelope')
        require(document['generation'] > 0 and document['commit']['id'], 'committed actual document')
        if sample is not None:
            require(sample['source'] == 'primary' and document['generation'] >= sample['generation'],
                    'live production store uses the actual primary generation')
        self.output.joinpath(label+'.json').write_bytes(raw)
        snapshot = {'path': str(self.path), 'profile_identity': self.profile_identity,
                    'sha256': hashlib.sha256(raw).hexdigest(), 'document': document}
        self.snapshots[label] = snapshot
        return document

    def require_preserved(self, before, after):
        require(self.protected(before) == self.protected(after),
                'unrelated actual-file payload retained without fabrication')
        require(after['generation'] >= before['generation'], 'actual-file generations never regress')

    @staticmethod
    def require_orderly(document, running):
        payload, previous = document['payload'], running['payload']
        crash, safe = payload['crash_recovery'], payload['safe_start_recovery']
        require(crash['state'] == 'clean' and crash['unclean_start_count'] == 0
                and crash['session_id'] == previous['crash_recovery']['session_id']
                and crash['startup_generation'] == previous['crash_recovery']['startup_generation'],
                'actual current session clean shutdown marker')
        require(safe['state'] == 'clean_shutdown' and safe['consecutive_failure_count'] == 0
                and not safe['safe_settings_recommended']
                and safe['startup_generation'] == previous['safe_start_recovery']['startup_generation'],
                'actual current safe-start orderly shutdown marker')
        require(any(e['event_code'] == 'session_ended' and e['session_id'] == crash['session_id']
                    for e in payload['session_diagnostics']['events']),
                'actual current-session orderly diagnostic event')
        require(document['generation'] > running['generation'], 'orderly close committed a later real-file generation')

    @staticmethod
    def require_cold(document, closed):
        payload, previous = document['payload'], closed['payload']
        crash, safe = payload['crash_recovery'], payload['safe_start_recovery']
        require(crash['state'] == 'running' and crash['unclean_start_count'] == 0
                and crash['session_id'] == previous['crash_recovery']['session_id'] + 1
                and crash['startup_generation'] == previous['crash_recovery']['startup_generation'] + 1,
                'distinct cold session consumes actual clean shutdown without recovery')
        require(safe['startup_generation'] == previous['safe_start_recovery']['startup_generation'] + 1
                and safe['state'] in ('starting', 'stable') and safe['consecutive_failure_count'] == 0
                and not safe['safe_settings_recommended'], 'cold safe-start has no unclean-start recommendation')
        require(payload['solo_safe_recovery'] == {'mode': 'unavailable'},
                'cold title retains accepted unavailable station rest context')


class BeaconSettlementFiles(HabitatRestartFiles):
    MUTABLE = HabitatRestartFiles.MUTABLE | {'cinder_beacon_session', 'game_flow_reward_store'}

    def observe(self, s, pilot):
        if pilot.entry_result is None: return
        require(s['pid'] == pilot.process_identity[0], 'real-file observation belongs to the same game')
        label = None
        if 'baseline' not in self.snapshots: label = 'baseline'
        elif pilot.paid_state is not None and 'paid' not in self.snapshots: label = 'paid'
        elif pilot.result is not None: label = 'stable'
        if label is None: return
        settlement = s['settlement']
        document = self.capture(label, settlement['store'])
        payload = document['payload']
        # The authority exposes its empty record before the first ledger slot
        # exists on disk. An absent baseline slot is the genuine zero ledger.
        ledger_matches = payload.get('game_flow_reward_store') == settlement['record']
        if label == 'baseline' and 'game_flow_reward_store' not in payload:
            pilot.require_zero(s)
            ledger_matches = True
        require(ledger_matches
                and payload.get('cinder_beacon_session', {}) == settlement['terminal'],
                'independent actual file exactly matches live reward record and terminal')
        if label == 'baseline':
            pilot.require_zero(s)
        else:
            pilot.require_paid(s)
            self.require_preserved(self.snapshots['baseline']['document'], document)
            if label == 'stable':
                paid = self.snapshots['paid']['document']['payload']
                require(payload['game_flow_reward_store'] == paid['game_flow_reward_store']
                        and payload['cinder_beacon_session'] == paid['cinder_beacon_session'],
                        'independent actual disk retains the same once-only receipt and paid terminal')


class StationDefensePilot(Pilot):
    """One complete ordinary defense sortie; every receipt is observed before input."""
    MARKER = 'NATIVE_STATION_DEFENSE_OK'
    MODE = 'station-defense'
    ACTIVITY = 'shipyard_perimeter_defense'
    REWARD = 'return_defense_report_to_shipyard'
    WEAPON = 'arrow_precision_recon_emitter'
    TO_BOARD = [[-8.5, .18, 12.5], [6, .18, 12.5], [9, .18, 12.5], [9, .18, -24], [12, .18, -24.5]]

    def __init__(self):
        super().__init__()
        self.initial = self.observed_previous = self.last_state = None
        self.sequence = 0
        self.event_sequence = 0
        self.source_sequences = {}
        self.presentation_receipts = set()
        self.events = []
        self.kills = {}
        self.actor_ids = {}
        self.actor_handles = {}
        self.native_edges = []
        self.receipts = {}
        self.visited = []
        self.route = []
        self.mouse_pending = None
        self.request_frame = None
        self.deployed = self.completed = self.paid = self.reset_state = None
        self.departure = self.home_exit = None
        self.quit_requested = False
        self.ui_key = None
        self.ui_until = self.ui_release_until = 0
        self.ui_focus = None
        self.ui_edges = []
        self.landing_seen = False
        self.last_input_frame = 0
        self.walked = 0.0

    @staticmethod
    def receipt(s):
        return {k: s[k] for k in ('sequence', 'frame', 'phase', 'player', 'position', 'native_interact',
                                  'grounded', 'supported', 'board', 'home', 'defense', 'settlement')}

    @classmethod
    def require_zero(cls, s):
        record = s['settlement']['record']
        require(s['settlement']['configured'] and record['receipt_serial'] == 0
                and record['total_receipts'] == 0 and record['reward_counts'] == {}
                and record['last_receipt'] == {}, 'genuine fresh zero-receipt ledger')

    @classmethod
    def require_paid(cls, s, generation):
        record = s['settlement']['record']
        receipt = record['last_receipt']
        require(record['receipt_serial'] == record['total_receipts'] == 1
                and record['reward_counts'] == {cls.REWARD: 1}
                and receipt['receipt_id'] == 1 and receipt['activity_id'] == cls.ACTIVITY
                and receipt['activity_generation'] == generation and receipt['reward_id'] == cls.REWARD
                and receipt['granted'] is True and receipt['replay_allowed'] is False,
                'one genuine generation-bound defense reward entitlement')
        reward = s['board']['reward']
        completion = s['board']['session']['completion']
        require(not reward['reward_pending'] and reward['highest_reward_generation'] == generation
                and completion['generation'] == generation and completion['reward_granted'] is True,
                'board and durable completion acknowledge the same paid generation')

    def validate_observation(self, s):
        require(s.get('mode') == self.MODE and s.get('actors_current'), 'current dedicated defense actors')
        require(s['sequence'] == self.sequence + 1, 'every defense observation retained in order')
        self.sequence = s['sequence']
        if self.initial is None:
            require(not s['paused'], 'ordinary unpaused title before gameplay')
            self.initial = s
            self.actor_ids = {a['hostile_id']: a['instance_id'] for a in s['defense']['actors']}
            self.actor_handles = {a['hostile_id']: (a['instance_id'], a['generation'], a['source_id'])
                                  for a in s['defense']['actors']}
            # The authored heavy ID is read from the roster, never guessed from a scene name.
            require(len(self.actor_ids) == 4 and len(set(self.actor_ids.values())) == 4
                    and all(self.actor_ids.values()), 'four distinct original hostile actors')
            require(sorted((a['generation'], a['source_id']) for a in s['defense']['actors'])
                    == [(1, 2121), (2, 2122), (3, 2123), (4, 2124)], 'exact four authored hostile handles/sources')
            require(s['home']['lease'] and s['home']['parked_exact'] and not s['guided_complete']
                    and s['defense']['activity']['state_id'] == 'idle', 'empty-profile original Arrow and idle defense')
            self.require_zero(s)
        require((s['pid'], s['main_id']) == (self.initial['pid'], self.initial['main_id']),
                'same exact game process and Main including normal pause')
        for event in s['shot_events']:
            self.observe_event(event)
        self.last_state = s
        if s['paused']:
            require(self.stage in ('ui_pause', 'ui_exit_wait'), 'pause only after complete physical route')
            ui = s['ui']
            require(ui['main_visible'] and ui['exit_visible'] and ui['exit_enabled']
                    and ui['exit_text'] == 'EXIT TO DESKTOP' and ui['exit_path'], 'actual enabled normal Exit button')
            return
        initial = self.initial
        require(all(s[k] == initial[k] for k in ('world_id', 'player_id', 'ship_id'))
                and s['board']['id'] == initial['board']['id']
                and s['defense']['content_id'] == initial['defense']['content_id']
                and s['defense']['host_id'] == initial['defense']['host_id']
                and s['defense']['core_id'] == initial['defense']['core_id']
                and s['home']['id'] == initial['home']['id'], 'original player/craft/board/host/core/home identities')
        require(s['default_sampler'] and s['tuning_unchanged'] and s['tuning'] == initial['tuning']
                and s['walk_tuning'] == initial['walk_tuning']
                and s['walk_tuning'] == {'walk': 5.8, 'sprint': 9.2, 'deceleration': 42.0, 'mouse': .0025}
                and s['physics_ticks'] == 60 and s['time_scale'] == 1 and not s['guided_complete'],
                'unchanged authored controls, normal pacing and pending Guided')
        require(s['player_source_id'] == 1102 and s['player_weapon'] == initial['player_weapon']
                and s['player_weapon']['range'] == 480 and s['player_weapon']['damage'] == 24,
                'exact original registered Arrow source and authored combat profile')
        require(not s['destroyed'] and s['telemetry']['hull'] > 0 and s['phase'] not in ('FAILED', 'RECOVERING'),
                'live original Arrow without recovery')
        defense, activity = s['defense'], s['defense']['activity']
        require(defense['core']['health'] > 0 and not defense['core']['destroyed']
                and norm(sub(defense['core_position'], [90, 8, -70])) < .001,
                'original protected core survives at authored world position')
        require(activity['timeout_seconds'] == 34 and activity['wave_count'] == 3
                and activity['state_id'] not in ('failed', 'aborted', 'timed_out'),
                'unchanged whole 34-second encounter; first failure stops')
        require({a['hostile_id']: (a['instance_id'], a['generation'], a['source_id'])
                 for a in defense['actors']} == self.actor_handles
                and all(a['current'] for a in defense['actors']), 'same four original hostile actors')
        if activity['state_id'] == 'completed':
            require(all(a['live_source_id'] == 0 for a in defense['actors'])
                    and defense['registration']['registered_source_key_count'] == 0,
                    'completed generation legitimately retires its hostile sources')
        else:
            require(all(a['exact_registration'] for a in defense['actors']) and defense['registration']['valid'],
                    'idle/active generation has exact authored live or lifecycle-scoped registrations')
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        previous = self.observed_previous
        if self.stage in ('walk_board', 'walk_arrow', 'walk_reset'):
            require(s['grounded'] and s['supported'] and s['control_enabled'] and not s['seated'],
                    'every ordinary walking sample has actual physical support')
        if previous is not None:
            require(s['frame'] == previous['frame'] + 1, 'every consecutive unpaused physics sample')
            if not previous['seated'] and not s['seated'] and not previous['transition_busy'] and not s['transition_busy']:
                displacement = norm(sub(s['player'], previous['player']))
                require(displacement <= 9.2/60 + .10, 'continuous actual ordinary walking without relocation')
                self.walked += displacement
            if s['native_interact'] != previous['native_interact']:
                self.native_edges.append({'pressed': s['native_interact'], 'sample': self.receipt(s)})
        self.observed_previous = s
        if activity['state_id'] == 'active':
            require(self.receipts.get('deploy_press') is not None, 'real E Deploy precedes encounter clock')
            if self.deployed is None:
                require(s['native_interact'] and s['board']['last_result'].get('accepted')
                        and s['board']['distance'] <= 2.6 and s['board']['candidate'] and s['board']['facing'] >= .05,
                        'accepted actual E Deploy with current candidate, 3D range and facing')
                self.deployed = self.receipt(s)
            require(activity['generation'] == self.deployed['defense']['activity']['generation']
                    and activity['elapsed_seconds'] < 34, 'one active unmodified encounter generation within timeout')
        if activity['state_id'] == 'completed':
            require(self.deployed is not None and len(self.kills) == 4
                    and activity['remaining_hostile_count'] == 0
                    and activity['generation'] == self.deployed['defense']['activity']['generation']
                    and activity['elapsed_seconds'] < 34
                    and all(a['health'] == 0 for a in defense['actors'])
                    and all(a['state_id'] == 'destroyed' for a in defense['roster']),
                    'four real resolver terminal kills before the whole 34 seconds')
            if self.completed is None: self.completed = self.receipt(s)
            self.require_paid(s, activity['generation'])
            if self.paid is None: self.paid = self.receipt(s)
        if self.paid is not None:
            require(s['settlement']['record'] == self.paid['settlement']['record'], 'once-only ledger retained after payment and Reset')
        else:
            self.require_zero(s)
        if self.departure is None and self.receipts.get('boarded') and not s['landed'] and s['home']['lease_free']:
            require(s['command_thrust'] > 0 and s['active_ship'] and s['piloted'] and s['seated'],
                    'ordinary positive thrust causes physical original Arrow departure')
            self.departure = self.receipt(s)

    def observe_event(self, event):
        require(event['event'] == self.event_sequence + 1, 'no skipped or replayed resolver signal receipt')
        self.event_sequence = event['event']
        source = event['request_source_id']
        sequence = event['sequence']
        require(sequence > self.source_sequences.get(source, -1), 'monotonic real resolver source sequence')
        self.source_sequences[source] = sequence
        self.events.append(event)
        if event['request_source_entity_id'] != self.initial['ship_id']:
            return
        require(source == event['source_id'] == 1102 and event['source_entity_id'] == self.initial['ship_id']
                and event['weapon_id'] == self.WEAPON and event['presentation_receipt_id'] > 0
                and event['presentation_receipt_id'] not in self.presentation_receipts
                and event['accepted'] and event['resolved'] and event['command_fire'],
                'fresh actual authored Arrow weapon receipt; any player rejection stops')
        self.presentation_receipts.add(event['presentation_receipt_id'])
        if event['applied_damage'] <= 0: return
        handle = event['target_handle']
        require(self.deployed is not None and event['generation'] == self.deployed['defense']['activity']['generation']
                and handle and self.actor_handles.get(handle['hostile_id'])
                    == (event['target_entity_id'], handle['generation'], handle['source_id'])
                and handle['source_id'] in (2121, 2122, 2123, 2124)
                and (handle['generation'], handle['source_id']) in ((1, 2121), (2, 2122), (3, 2123), (4, 2124))
                and event['damaged'] and event['damage_accepted'], 'positive actual damage to exact registered defense actor')
        if event['destroyed']:
            require(event['remaining_health'] == event['damage_health'] == 0 and event['damage_destroyed']
                    and event['target_entity_id'] not in self.kills, 'one real zero-health terminal kill per original target')
            self.kills[event['target_entity_id']] = event

    def begin_walk(self, stage, route, s):
        self.route = [p[:] for p in route]
        self.enter(stage, s)

    def walk_to(self, s, target, keys, frames):
        require(s['grounded'] and s['supported'] and s['control_enabled'] and not s['seated'],
                'actual supported ordinary on-foot route')
        walking = dict(s, velocity=s['walk_velocity'])
        return HabitatLoopPilot.walk_to(self, walking, target, keys, frames)

    yaw_to = HabitatLoopPilot.yaw_to

    def press(self, key, stage, s, now, receipt):
        self.tap(key, now)
        if self.tap_key == key and self.tap_frame == s['frame']:
            self.receipts[receipt] = self.receipt(s)
            self.request_frame = s['frame']
            self.enter(stage, s)

    def update(self, s, now):
        require(s is self.last_state, 'only final validated sample drives fresh OS input')
        self.frame = s['frame']
        if self.stage in ('ui_pause', 'ui_exit_wait'): return self.ui_update(s, now)
        keys, dx, dy, fire = set(), 0, 0, False
        frames = max(1, self.frame - self.last_input_frame)
        self.last_input_frame = self.frame
        speed = norm(s['velocity'])
        activity = s['defense']['activity']
        if self.stage == 'boot' and s['menu_ready']:
            self.press('e', 'begin_shift', s, now, 'begin_shift_press')
        elif self.stage == 'begin_shift':
            if s['phase'] == 'APPROACH_SHIP' and s['grounded'] and s['supported']:
                self.begin_walk('walk_board', self.TO_BOARD, s)
            else: require(self.frame <= self.request_frame + 180, 'normal Begin Shift did not admit on-foot play')
        elif self.stage in ('walk_board', 'walk_arrow', 'walk_reset'):
            if self.route:
                dx, arrived = self.walk_to(s, self.route[0], keys, frames)
                if arrived:
                    self.visited.append({'stage': self.stage, 'target': self.route.pop(0), 'frame': self.frame})
            elif self.stage in ('walk_board', 'walk_reset'):
                board = s['board']
                dx, yaw, _ = self.yaw_to(s, board['position'])
                if board['candidate'] and board['distance'] <= 2.6 and board['facing'] >= .05 and abs(yaw) < .08:
                    if self.stage == 'walk_board':
                        require(board['action'] == 'deploy', 'physical initial Deploy available')
                        self.press('e', 'deploy_wait', s, now, 'deploy_press')
                    else:
                        require(board['action'] == 'reset' and self.paid is not None, 'same physical board offers completed-generation Reset')
                        self.press('e', 'reset_wait', s, now, 'reset_press')
            elif s['candidate'] and norm(s['walk_offset']) <= 3.1:
                self.press('e', 'board_wait', s, now, 'board_press')
            else:
                dx, _ = self.walk_to(s, s['boarding'], keys, frames)
        elif self.stage == 'deploy_wait':
            if self.deployed is not None:
                # Turn inboard below DockMastFoot03 before crossing its lamp hood.
                # The direct diagonal grazes its solid corner at capsule radius .38;
                # this supported westward leg clears the hardware before heading north.
                self.begin_walk('walk_arrow', [[9, .18, -24.5], [9, .18, 12.5],
                                               [-35, .18, 13.5], [-35, .18, 20]], s)
            else:
                result = s['board']['last_result']
                deploy_edge = any(edge['pressed'] and edge['sample']['frame'] > self.receipts['deploy_press']['frame']
                                  for edge in self.native_edges)
                # XTest dispatch can precede Godot's first observed E edge.
                # An empty receipt is still pending, never an actual rejection.
                require(not (deploy_edge and result and not result.get('accepted', False)),
                        'physical Deploy rejected; no retry')
                require(self.frame <= self.request_frame + 90, 'physical E did not deploy; no retry')
        elif self.stage == 'board_wait':
            if s['piloted'] and s['seated'] and s['active_ship'] and s['seated_at_pilot'] and not s['transition_busy']:
                self.receipts['boarded'] = self.receipt(s)
                self.enter('depart', s)
            else: require(self.frame <= self.request_frame + 300, 'ordinary Arrow E boarding rejected or timed out; no retry')
        elif self.stage in ('depart', 'combat'):
            require(activity['state_id'] in ('active', 'completed'), 'active real defense during ordinary combat')
            if self.paid is not None:
                require(self.departure is not None and len(self.kills) == 4, 'departed genuine four-kill defense before return')
                self.enter('home_flight', s)
                self.return_braking = False
            else:
                # Fly clear of the port berth along its authored forward vector,
                # then brake and engage actual current actor poses with the gun.
                if self.departure is None or norm(sub(s['position'], s['parked'])) < 16:
                    keys.add('w')
                else:
                    self.stage = 'combat'
                    keys.add('Prior')
                    targets = [a for a in s['defense']['actors'] if a['active'] and a['health'] > 0]
                    if targets:
                        target = min(targets, key=lambda a:a['source_id'])
                        dx, dy, align = self.aim(s, target['position'], .35)
                        fire = align >= .999
        elif self.stage == 'home_flight':
            home = s['home']
            off = sub(home['approach'], s['position'])
            distance = norm(off)
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)], .25)
            stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
            if distance < stopping + 2: self.return_braking = True
            if speed <= .45 and distance > 1: self.return_braking = False
            if distance <= 1 or self.return_braking: keys.add('Prior')
            elif align > .98: keys.add('w')
            if distance <= 1 and speed <= .35: self.enter('home_align', s)
        elif self.stage == 'home_align':
            keys.update(('Prior', 'h'))
            off = sub(s['home']['dock'], s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(s['home']['capture'] and s['home']['selected_berth_id'] == s['home']['berth_id']
                        and dot([-v for v in s['back']], s['home']['dock_forward']) < -.95,
                        'normal nose-first selected Arrow home landing preview')
                self.press('l', 'home_land', s, now, 'land_press')
        elif self.stage == 'home_land':
            keys.add('Prior')
            self.landing_seen |= s['landing_active']
            require(not s['home']['landing_abort_reason'], 'normal Arrow landing aborted; no retry')
            if s['landed'] and s['phase'] == 'SHUT_DOWN':
                require(self.landing_seen, 'one ordinary L drove observed home landing')
                self.require_docked(s)
                self.receipts['docked'] = self.receipt(s)
                self.enter('shutdown', s)
                keys.clear()
            else:
                require(self.landing_seen or self.frame <= self.request_frame + 120, 'ordinary L rejected; no retry')
                require(not self.landing_seen or s['landing_active'], 'home landing stopped without docking')
        elif self.stage == 'shutdown':
            self.require_docked(s)
            if s['telemetry']['engine'] == 'OFFLINE': self.press('e', 'exit_wait', s, now, 'exit_press')
        elif self.stage == 'exit_wait':
            self.require_docked(s)
            if not s['piloted'] and not s['seated'] and s['control_enabled'] and not s['transition_busy']:
                require(s['phase'] == 'COMPLETE' and s['exit_error'] < .25, 'ordinary physical Arrow exit at its real anchor')
                if s['grounded'] and s['supported']:
                    self.home_exit = self.receipt(s)
                    self.begin_walk('walk_reset', [[-35, .18, 20], [-35, .18, 13.5], [9, .18, 12.5],
                                                   [9, .18, -24], [12, .18, -24.5]], s)
            require(self.frame <= self.request_frame + 600, 'ordinary home exit rejected or unsupported; no retry')
        elif self.stage == 'reset_wait':
            if activity['state_id'] == 'idle':
                require(s['board']['last_result'].get('accepted') and s['native_interact']
                        and s['board']['candidate'] and s['board']['distance'] <= 2.6 and s['board']['facing'] >= .05
                        and activity['generation'] > self.completed['defense']['activity']['generation']
                        and s['board']['action'] == 'deploy', 'one real physical Reset exposes usable next Deploy in a new idle generation')
                self.reset_state = self.receipt(s)
                self.receipts['next_deploy_available'] = self.reset_state
                self.tap_key = None
                self.enter('ui_pause', s)
            else:
                require(s['board']['last_result'].get('accepted', False), 'physical Reset rejected; no retry')
                require(self.frame <= self.request_frame + 90, 'ordinary E did not reset; no retry')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6: keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        facing = s['walk_forward'] if not s['seated'] else s['back']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    @staticmethod
    def require_docked(s):
        require(s['home']['contract'] and s['home']['lease'] and s['home']['parked_exact'] and s['landed'],
                'strict exact Arrow home berth and bound live lease')

    def ui_update(self, s, now):
        keys = set()
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key}, 0, 0, False
            self.ui_edges.append({'sequence': s['sequence'], 'key': self.ui_key, 'pressed': False})
            self.ui_key = None
            self.ui_release_until = now + .10
            return keys, 0, 0, False
        if now < self.ui_release_until or self.quit_requested: return keys, 0, 0, False
        if s['paused'] and any(s['native_keys'].values()): return keys, 0, 0, False
        key = None
        if not s['paused']:
            require(self.stage == 'ui_pause', 'pause remains active until actual Exit to Desktop')
            key = 'Escape'
        elif s['ui']['focus_is_exit']:
            self.receipts['exit_ui'] = s
            self.quit_requested = True
            self.stage = 'ui_exit_wait'
            key = 'Return'
        elif s['ui']['focus_path'] != self.ui_focus:
            require(s['ui']['focus_path'], 'actual pause keyboard focus')
            self.ui_focus = s['ui']['focus_path']
            key = 'Tab'
        if key:
            self.ui_key, self.ui_until = key, now + .08
            self.ui_edges.append({'sequence': s['sequence'], 'key': key, 'pressed': True})
            keys.add(key)
        return keys, 0, 0, False

    def report(self):
        return {'stages': self.stages, 'phases': self.phases, 'walked_m': self.walked,
                'visited': self.visited, 'receipts': self.receipts, 'deployed': self.deployed,
                'completed': self.completed, 'paid': self.paid, 'reset': self.reset_state,
                'departure': self.departure, 'home_exit': self.home_exit,
                'kills': list(self.kills.values()), 'resolver_events': self.events,
                'native_interact_edges': self.native_edges, 'ui_edges': self.ui_edges,
                'quit_requested': self.quit_requested, 'last_state': self.last_state}

    def finish_normal_exit(self):
        require(self.quit_requested and self.stage == 'ui_exit_wait' and self.reset_state is not None
                and self.home_exit is not None and len(self.kills) == 4 and self.paid is not None,
                'full original route complete before normal UI process exit')
        self.result = dict(self.report(), completion_marker=self.MARKER, normal_ui_exit=True)


class StationDefenseFiles(HabitatRestartFiles):
    MUTABLE = HabitatRestartFiles.MUTABLE | {'station_defense_session', 'game_flow_reward_store'}

    def observe(self, s, pilot):
        if s['paused']: return
        label = 'baseline' if 'baseline' not in self.snapshots else (
            'paid' if pilot.paid is not None and 'paid' not in self.snapshots else None)
        if label is None: return
        document = self.capture(label, s['settlement']['store'])
        record = document['payload'].get('game_flow_reward_store')
        if label == 'baseline':
            pilot.require_zero(s)
            require(record is None or record == s['settlement']['record'], 'independent actual empty defense ledger')
        else:
            pilot.require_paid(s, pilot.paid['defense']['activity']['generation'])
            require(record == s['settlement']['record'], 'independent actual disk contains the exact once-only entitlement')
            terminal = document['payload']['station_defense_session']['session']['completion']
            require(terminal['generation'] == pilot.paid['defense']['activity']['generation']
                    and terminal['reward_granted'] is True, 'actual saved terminal pays the exact encounter generation')

    def finish(self, pilot):
        require('paid' in self.snapshots, 'actual paid primary was independently read before shutdown')
        document = self.capture('orderly-close')
        paid = self.snapshots['paid']['document']
        self.require_orderly(document, paid)
        require(document['payload']['game_flow_reward_store'] == paid['payload']['game_flow_reward_store'],
                'real orderly shutdown retains exactly one entitlement after physical Reset')


class HabitatRestartPilot(HabitatLoopPilot):
    """Accepted ordinary admission, UI shutdown, and a fresh process continuation."""
    MARKER = 'NATIVE_HABITAT_RESTART_OK'

    def __init__(self, cold=False):
        super().__init__()
        self.cold = cold
        self.sequence = 0
        self.pid = None
        self.file_context_accepted = False
        self.quit_requested = False
        self.ui_key = None
        self.ui_until = 0
        self.ui_release_until = 0
        self.ui_last_focus = None
        self.ui_edges = []
        self.look_origin = self.walk_origin = None
        self.look_changed = False
        self.walk_displacement = 0
        self.cold_identity = None
        self.cold_ready = False
        self.interaction_complete = False

    def require_current(self, s):
        require(s.get('actors_current'), 'restart current production actors')
        fields = ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id')
        require(all(s[k] != 0 for k in fields)
                and tuple(s[k] for k in fields) == tuple(self.initial[k] for k in fields)
                and s['door']['id'] == self.initial['door']['id']
                and s['bunk']['id'] == self.initial['bunk']['id'],
                'stable current actors within this process leg')
        require(s['walk_tuning'] == self.initial['walk_tuning'] and s['physics_ticks'] == 60
                and s['time_scale'] == 1, 'restart authored walking and physics pacing')
        require(s['phase'] == 'APPROACH_SHIP' and not s['piloting']
                and not s['crew_claim'] and not s['cabin_claim'] and not s['recovery_pending'],
                'cold continuation without old crew ship cabin or recovery claim')
        tractor = s['tractor']
        identity = (tractor['id'], tractor['station_id'], tractor['station_path'])
        require(tractor['current'] and all(identity), 'exact current production tractor interaction owner')
        if self.cold_identity is None: self.cold_identity = identity
        require(identity == self.cold_identity, 'same current tractor and interaction within cold leg')

    def require_resting(self, s):
        b = s['bunk']
        require(s['sleeping'] and s['seated'] and s['station_seated'] and s['game_station_seated']
                and not s['transition_busy'] and b['reserved'] and b['active']
                and b['active_seat_id'] == b['id'] and b['occupant_id'] == s['player_id']
                and b['seated_at_bunk'] and not b['transitioning'],
                'exact accepted station bunk sleep retained until UI quit')

    def begin_quit(self, s):
        self.tap_key = None
        self.stage = 'restart_pause'
        self.receipts['before_quit'] = self.receipt(s)
        self.ui_key = None
        self.ui_release_until = 0

    def ui_update(self, s, now):
        # UI keys use observed releases and wall time. Physics frame numbers
        # are deliberately irrelevant while the production tree is paused.
        keys = set()
        paused = s['paused']
        if paused:
            require(s['main_id'] == self.initial['main_id'], 'paused UI belongs to this process Main')
            if not self.cold: require(s['rest_retained'], 'normal UI quit while still resting')
            ui = s['ui']
            require(ui['main_visible'] and ui['exit_visible'] and ui['exit_enabled']
                    and ui['exit_text'] == 'EXIT TO DESKTOP' and ui['exit_path'],
                    'actual enabled EXIT TO DESKTOP pause button')
        if self.ui_key is not None:
            if now < self.ui_until:
                keys.add(self.ui_key)
                return keys, 0, 0, False
            self.ui_edges.append({'sequence': s['sequence'], 'key': self.ui_key, 'pressed': False})
            self.ui_key = None
            self.ui_release_until = now + .10
            return keys, 0, 0, False
        if now < self.ui_release_until or self.quit_requested: return keys, 0, 0, False
        if paused and any(s['native_keys'].values()): return keys, 0, 0, False
        key = None
        if not paused:
            require(self.stage == 'restart_pause', 'pause remains active until actual EXIT TO DESKTOP')
            key = 'Escape'
        elif s['ui']['focus_is_exit']:
            # The held Tab is released and observed before the ordinary accept.
            self.receipts['exit_ui'] = s
            self.quit_requested = True
            self.stage = 'restart_exit_wait'
            key = 'Return'
        else:
            focus = s['ui']['focus_path']
            require(focus, 'current pause UI has keyboard focus')
            if focus != self.ui_last_focus:
                self.ui_last_focus = focus
                self.receipts.setdefault('pause_focus', []).append(s['ui'].copy())
                key = 'Tab'
        if key:
            self.ui_key, self.ui_until = key, now + .08
            self.ui_edges.append({'sequence': s['sequence'], 'key': key, 'pressed': True,
                                  'focus': s.get('ui', {}).get('focus_path', '')})
            keys.add(key)
        return keys, 0, 0, False

    def update(self, s, now):
        self.last_state = s
        require(s.get('mode') == 'habitat-restart', 'restart-only observation selector')
        require(s['sequence'] > self.sequence, 'fresh restart observer sequence including paused UI')
        self.sequence = s['sequence']
        if self.pid is None: self.pid = s['pid']
        require(s['pid'] == self.pid, 'same observed OS process within each leg')
        if self.stage.startswith('restart_pause') or self.stage == 'restart_exit_wait':
            if not s['paused']:
                self.require_current(s)
                if not self.cold: self.require_resting(s)
            return self.ui_update(s, now)
        require(not s['paused'], 'ordinary gameplay is unpaused before UI shutdown')
        if self.stage == 'restart_context':
            self.require_current(s)
            self.require_resting(s)
            if self.file_context_accepted:
                self.begin_quit(s)
            return set(), 0, 0, False
        if self.stage in ('boot', 'begin_shift') or not self.cold:
            command = super().update(dict(s, mode='habitat-loop'), now)
            if not self.cold and self.stage == 'sleep_release':
                self.stage = 'restart_context'
                self.tap_key = None
                return set(), 0, 0, False
            if self.cold and self.stage == 'walk_outbound':
                self.require_current(s)
                require(s['camera_current'] and not s['driving'], 'fresh awake camera and controls without driver claim')
                self.cold_ready = True
                self.look_origin = s['walk_forward'][:]
                self.walk_origin = s['player'][:]
                self.stage = 'restart_look'
                self.tap_key = None
                self.previous = s
                return set(), 80, 0, False
            return command
        self.require_current(s)
        self.frame = s['frame']
        frames = self.frame - self.previous['frame']
        require(frames > 0, 'fresh cold gameplay physics sample')
        keys, dx = set(), 0
        if self.stage in ('restart_look', 'restart_walk', 'restart_aim'):
            self.require_awake(s)
            require(s['camera_current'] and not s['driving'], 'current awake walking camera')
            step = norm(sub(s['player'], self.previous['player']))
            require(step <= (s['walk_tuning']['sprint']/60*1.25+.02)*frames,
                    'continuous supported cold walk without placement')
            self.walked += step
            self.walk_displacement = max(self.walk_displacement, norm(sub(s['player'], self.walk_origin)))
            self.support_colliders.add(s['support_collider'])
        if self.stage == 'restart_look':
            if norm(sub(s['walk_forward'], self.look_origin)) > .05:
                self.look_changed = True
                self.receipts['cold_look'] = self.receipt(s)
                self.stage = 'restart_walk'
        elif self.stage == 'restart_walk':
            # Same accepted central-floor approach, then the live driver's step
            # on the tractor's south side; no traversal through its chassis.
            target = [s['tractor']['approach'][0], 0, s['tractor']['approach'][2]]
            dx, reached = self.walk_to(s, target, keys, frames)
            if reached:
                require(self.look_changed and self.walk_displacement > .6,
                        'actual cold look and supported walk greater than 0.6 metres before Interact')
                self.receipts['cold_walk'] = self.receipt(s)
                self.stage = 'restart_aim'
        elif self.stage == 'restart_aim':
            tractor = s['tractor']
            dx, yaw, _distance = self.yaw_to(s, tractor['position'])
            if abs(yaw) < .08 and tractor['candidate'] and tractor['available'] and not s['native_interact']:
                self.tap('e', now)
                if self.tap_key == 'e':
                    self.receipts['cold_interact_press'] = {**self.receipt(s), 'tractor': tractor.copy()}
                    self.stage = 'restart_board'
        elif self.stage == 'restart_board':
            if s['driving'] and not s['transition_busy']:
                require(s['seated'] and s['tractor']['driven'] and s['tractor']['seated_at_driver'],
                        'actual ordinary Interact acquired the current tractor driver anchor')
                require(s['native_interact'] or any(e['stage'] == 'restart_board' and e['pressed'] for e in self.native_edges),
                        'actual OS Interact observed for current tractor admission')
                self.receipts['cold_interaction'] = {**self.receipt(s), 'tractor': s['tractor'].copy()}
                self.stage = 'restart_driver_release'
        elif self.stage == 'restart_driver_release':
            require(s['driving'] and s['tractor']['seated_at_driver'], 'current new driver retained until separate exit press')
            if self.tap_key is None and not s['native_interact']:
                self.tap('e', now)
                if self.tap_key == 'e': self.stage = 'restart_dismount'
        elif self.stage == 'restart_dismount':
            if not s['driving'] and not s['seated'] and not s['transition_busy'] and self.floor_ready(s):
                self.require_awake(s)
                require(s['camera_current'] and not s['tractor']['driven'], 'ordinary supported tractor exit restores current player controls')
                require(any(e['stage'] == 'restart_dismount' and e['pressed'] for e in self.native_edges),
                        'released and repressed actual OS Interact exits current tractor')
                self.receipts['cold_exit'] = self.receipt(s)
                self.interaction_complete = True
                self.begin_quit(s)
        if bool(s['native_interact']) != self.native_previous:
            self.native_edges.append({'frame': self.frame, 'pressed': bool(s['native_interact']), 'stage': self.stage})
        self.native_previous = bool(s['native_interact'])
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6: keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        if self.mouse_pending is not None:
            if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = None
        if dx: self.mouse_pending = s['walk_forward'][:]
        self.previous = s
        return keys, dx, 0, False

    def report(self):
        return {'pid': self.pid, 'stage': self.stage, 'initial': self.initial,
                'receipts': self.receipts, 'visited': self.visited, 'walked_m': self.walked,
                'native_interact_edges': self.native_edges, 'ui_key_edges': self.ui_edges,
                'support_colliders': sorted(self.support_colliders),
                'look_changed': self.look_changed, 'walk_displacement_m': self.walk_displacement,
                'interaction_complete': self.interaction_complete}



class ArrowReturnReusePilot(Pilot):
    """One native precision hit, two physical Arrow sorties and normal UI exit."""
    MARKER = 'NATIVE_ARROW_RETURN_REUSE_OK'
    IDS = ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id',
           'ship_id', 'berth_id', 'source_id', 'seat_id', 'pid',
           'target_instance_id', 'target_adapter_id', 'camera_id')
    WEAPON_STAGES = ('weapon_brake', 'weapon_aim', 'weapon_fire', 'weapon_restore')
    WEAPON_CAP = 25
    OUTBOUND = (('central_forward', [0, 0, 13.5]),
                ('port_arm', [-35, 0, 13.5]), ('arrow_clearance', [-35, 0, 22]))

    def __init__(self):
        super().__init__()
        self.initial = self.observed_previous = self.last_state = None
        self.receipts, self.visited, self.trips, self.native_edges = {}, [], [], []
        self.walked = self.excursion = 0
        self.walk_index = self.flight = 0
        self.departed = self.thrust_seen = self.landing_seen = False
        self.neutral_start = None
        self.clear_seen = False
        self.boarding_seen = self.disembarking_seen = False
        self.mouse_pending = None
        self.ui_key = None
        self.ui_until = self.ui_release_until = 0
        self.quit_requested = False
        self.observations = 0
        self.weapon_started = self.weapon_start_frame = None
        self.weapon_native_seen = False
        self.weapon = {}
        self.target_moved = False

    def receipt(self, s):
        fields = self.IDS + ('frame', 'sequence', 'phase', 'player', 'position', 'candidate',
                            'boarding_distance', 'station_candidate', 'reboard_blocked',
                            'native_interact', 'native_landing', 'native_thrust', 'engine',
                            'lease', 'lease_free', 'lease_token', 'contract', 'parked_exact',
                            'seated', 'seated_at_pilot', 'boarding_reserved', 'grounded',
                            'supported', 'support_collider', 'boarding_confirmation')
        return {key: s[key] for key in fields}

    def key_for(self, event): return event+'_'+str(self.flight+1)

    def weapon_receipt(self, s):
        return {**self.receipt(s), 'native_fire': s['native_fire'],
                'shot': s['shot'], 'target': s['target'],
                'right': s['right'], 'up': s['up'], 'back': s['back'],
                'camera': s['camera'], 'camera_right': s['camera_right'],
                'camera_up': s['camera_up'], 'camera_back': s['camera_back']}

    def check_weapon_deadline(self, now):
        if self.weapon_started is not None and self.stage in self.WEAPON_STAGES:
            require(now-self.weapon_started <= self.WEAPON_CAP,
                    'Arrow brake aim fire and attitude restoration within 25 seconds')

    def validate_weapon(self, s):
        target, shot = s['target'], s['shot']
        require(target['name'] == 'TargetDrone01' and target['target_id'] == 'DRONE-01'
                and target['base_position'] == [-13, 7, -95]
                and target['maximum_health'] == 100 and not target['destroyed']
                and s['ship_tuning']['cooldown'] == .38 and not s['ship_invert_y'],
                'same authored moving DRONE-01 and default precision emitter')
        self.target_moved |= norm(sub(target['position'], self.initial['target']['position'])) > .01
        if self.stage in self.WEAPON_STAGES:
            require(self.flight == 0 and s['phase'] == 'FREE_FLIGHT' and s['engine'] == 'ONLINE'
                    and not s['landed'] and not s['landing_active'] and s['lease_free']
                    and not s['native_landing'], 'first-flight free Arrow during bounded weapon phase')
        if self.weapon_start_frame is not None and self.stage in self.WEAPON_STAGES:
            require(s['frame']-self.weapon_start_frame <= self.WEAPON_CAP*60,
                    'Arrow weapon phase physics budget within original route cap')
        if s['native_fire']:
            require(self.flight == 0 and self.stage == 'weapon_fire'
                    and 'pre_fire' in self.weapon,
                    'native fire confined to first-flight weapon request')
            if not self.weapon_native_seen:
                self.weapon['native_fire'] = self.weapon_receipt(s)
            self.weapon_native_seen = True
        if 'hit' in self.weapon:
            require(shot == self.weapon['hit']['shot'] and target['health'] == 76
                    and target['hit_source'] == self.weapon['hit']['target']['hit_source'],
                    'single Arrow hit retained unchanged through both return flights')
            return
        if not shot['present']:
            require(target['health'] == 100 and target['hit_source']['sequence'] == -1,
                    'untouched target health before native Arrow shot')
            return
        request = shot['request']
        before = self.weapon.get('pre_fire')
        require(self.stage == 'weapon_fire' and self.flight == 0 and before is not None
                and self.weapon_native_seen and s['frame'] > before['frame']
                and s['sequence'] > before['sequence'] and self.target_moved,
                'fresh result follows observed native first-flight fire on moving target')
        baseline = before['shot']['request'].get('sequence', -1)
        context = target['hit_source']
        require(request['sequence'] == baseline+1 and request['presentation_receipt_id'] >= 0
                and all(request[key] == context[key] for key in
                        ('source_id', 'source_entity_id', 'weapon_id', 'sequence', 'presentation_receipt_id'))
                and request['source_id'] == shot['source_id'] == 1102
                and request['source_entity_id'] == shot['source_entity_id'] == s['ship_id']
                and request['weapon_id'] == 'arrow_precision_recon_emitter'
                and request['range'] == 480 and request['damage'] == 24,
                'fresh matching Arrow request source sequence and presentation hit receipt')
        damage = shot['damage_result']
        require(shot['accepted'] and shot['resolved'] and shot['hit'] and shot['damaged']
                and shot['status'] == 'damaged' and not shot['destroyed']
                and shot['target_entity_id'] == s['target_instance_id']
                and shot['damageable_id'] == s['target_adapter_id']
                and shot['applied_damage'] == 24 and shot['remaining_health'] == 76
                and damage.get('accepted') and damage.get('applied_damage') == 24
                and damage.get('health') == 76 and damage.get('maximum_health') == 100
                and not damage.get('destroyed') and before['target']['health'] == 100
                and target['health'] == 76,
                'authoritative actual DRONE-01 hit applies precisely 24 damage from 100 to 76')
        self.weapon['hit'] = self.weapon_receipt(s)

    def weapon_aim(self, s, direction):
        local = [dot(unit(direction), s[a]) for a in ('camera_right', 'camera_up', 'camera_back')]
        yaw = math.atan2(local[0], -local[2])
        pitch = math.atan2(local[1], math.hypot(local[0], local[2]))
        sensitivity = s['ship_tuning']['mouse']
        clamp = lambda value: round(max(-35, min(35, value*.4/sensitivity)))
        return clamp(yaw), clamp(-pitch), -local[2]

    def restore_attitude(self, s, keys):
        original = self.initial
        axes = ('right', 'up', 'back')
        cross = lambda a,b: [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
        rotation = [sum(cross(s[axis], original[axis])[i] for axis in axes)/2 for i in range(3)]
        local = [dot(rotation, s[axis]) for axis in axes]
        if abs(local[2]) > .025: keys.add('q' if local[2] > 0 else 'r')
        sensitivity = s['ship_tuning']['mouse']
        clamp = lambda value: round(max(-35, min(35, value*.4/sensitivity)))
        dx, dy = clamp(-local[1]), clamp(-local[0])
        restored = all(norm(sub(s[axis], original[axis])) < .04 for axis in axes)
        return dx, dy, restored

    def require_home(self, s, contract=True):
        require(s['landed'] and s['parked_exact'] and s['lease'] and s['lease_token']
                and (not contract or s['contract']), 'strict exact occupied Arrow home lease')

    def require_foot(self, s):
        require(s['phase'] == 'APPROACH_SHIP' and not s['seated'] and not s['piloted']
                and not s['transition_busy'] and s['control_enabled'] and s['capsule_enabled']
                and s['grounded'] and s['supported'] and s['support_collider']
                and s['player_camera'], 'ordinary supported Arrow walking and exterior controls')

    def validate_observation(self, s):
        """Validate all receipts, including intermediate batches and the quit tail."""
        self.last_state = s
        require(s.get('mode') == 'arrow-return-reuse' and s.get('actors_current'),
                'current ordinary Arrow observer actors')
        self.frame = s['frame']
        if self.initial is None:
            require(s['phase'] == 'INTRO' and not s['paused'] and not s['guided_complete']
                    and norm(sub(s['player'], s['spawn'])) < .75
                    and math.hypot(s['spawn'][0]+8.5, s['spawn'][2]-11) < .1
                    and abs(s['spawn'][1]-.18) < .65, 'fresh authored Arrow title and hub spawn')
            self.require_home(s, False)
            require(norm(sub(s['back'], [1, 0, 0])) < .001
                    and norm(sub(s['up'], [0, 1, 0])) < .001,
                    'authored west-facing upright Arrow starting attitude')
            self.initial = s
        initial, previous = self.initial, self.observed_previous
        require(all(s[k] == initial[k] and s[k] for k in self.IDS)
                and s['capsule_geometry'] == initial['capsule_geometry'],
                'same Main world Player capsule Arrow seat input owner and home berth')
        require(s['definition_id'] == 'arrow_provisional' and s['home_id'] == 'arrow_recon_berth'
                and s['default_sampler'] and s['default_controls'] and s['tuning_unchanged']
                and s['walk_tuning'] == LifeTowPilot.DEFAULT_WALK
                and s['ship_tuning'] == initial['ship_tuning'] and s['physics_ticks'] == 60
                and s['time_scale'] == 1, 'default sampler controls and authored Arrow tuning')
        require(not s['destroyed'] and s['hull'] == initial['hull'] and not s['remote_piloted']
                and not s['guided_complete'], 'live unchanged ordinary Arrow hull without recovery')
        require(s['sequence'] == (previous['sequence']+1 if previous else s['sequence']),
                'every consecutive Arrow receipt retained')
        if previous:
            require(s['frame'] == previous['frame']+1, 'every consecutive Arrow physics frame retained')
        self.validate_weapon(s)
        self.observations += 1
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        require(s['phase'] in ('INTRO', 'APPROACH_SHIP', 'BOARDING', 'START_ENGINES',
                               'FREE_FLIGHT', 'SHUT_DOWN', 'DISEMBARKING'), 'ordinary Arrow lifecycle phases only')
        if s['paused']:
            require(self.stage in ('pause', 'quit_wait') and len(self.trips) == 2,
                    'pause follows both completed Arrow returns')
        pressed = s['native_interact'] and not (previous and previous['native_interact'])
        if pressed:
            self.native_edges.append({'frame': s['frame'], 'stage': self.stage, 'flight': self.flight+1})
        confirmation = s['boarding_confirmation'].get('adapter', {}).get('view', {}).get('state')
        require(confirmation != 'rejected', 'production Arrow boarding confirmation must not reject')
        if s['phase'] == 'BOARDING':
            request = self.receipts.get(self.key_for('board'))
            require(self.stage == 'board' and request is not None and request['candidate']
                    and request['boarding_distance'] <= 7 and not request['station_candidate']
                    and not request['reboard_blocked'] and request['frame'] < s['frame']
                    and all(request[k] == s[k] for k in self.IDS)
                    and any(e['stage'] == 'board' and e['flight'] == self.flight+1 for e in self.native_edges)
                    and s['transition_busy'] and s['boarding_reserved'],
                    'BOARDING requires current candidate and distinct actual E with retained reservation')
            require(confirmation == 'boarding', 'actual Arrow boarding presentation')
            self.boarding_seen = True
        if s['seated'] and not s['transition_busy']:
            require(s['seated_at_pilot'] and s['piloted'] and s['active_ship'] and s['ship_camera']
                    and not s['capsule_enabled'], 'actual same Arrow pilot seat camera and command owner')
        if s['phase'] in ('START_ENGINES', 'FREE_FLIGHT', 'SHUT_DOWN'):
            require(s['active_ship'] and s['seated_at_pilot'] and s['piloted'],
                    'same active seated Arrow throughout flight')
        if self.stage in ('walk', 'approach', 'clear', 'reapproach', 'pause', 'quit_wait'):
            self.require_foot(s)
            self.require_home(s, self.flight > 0 or len(self.trips) == 2)
            if previous and previous['phase'] == 'APPROACH_SHIP' and not previous['transition_busy']:
                step = norm(sub(s['player'], previous['player']))
                require(step <= LifeTowPilot.DEFAULT_WALK['sprint']/60*1.25+.02,
                        'continuous supported Arrow walking without teleport')
                self.walked += step
        if self.stage == 'launch':
            self.thrust_seen |= s['native_thrust'] and s['flight_demand'] and s['engine'] == 'ONLINE'
            self.excursion = max(self.excursion, norm(sub(s['position'], s['parked'])))
            self.departed |= (self.thrust_seen and s['lease_free'] and not s['landed']
                              and s['phase'] == 'FREE_FLIGHT' and self.excursion > 8)
        if self.stage in ('land', 'shutdown', 'exit'):
            self.landing_seen |= s['native_landing']
        if self.stage == 'shutdown':
            if s['flight_demand']:
                self.neutral_start = None
            elif self.neutral_start is None:
                self.neutral_start = s['frame']
            self.require_home(s)
        if s['phase'] == 'DISEMBARKING':
            request = self.receipts.get(self.key_for('exit'))
            require(self.stage == 'exit' and request is not None and request['engine'] == 'OFFLINE'
                    and request['contract'] and request['lease'] and request['parked_exact']
                    and all(request[k] == s[k] for k in self.IDS)
                    and any(e['stage'] == 'exit' and e['flight'] == self.flight+1 for e in self.native_edges),
                    'DISEMBARKING requires strict offline home and separate actual E')
            require(confirmation == 'disembarking', 'actual Arrow exit presentation')
            self.disembarking_seen = True
        self.observed_previous = s

    def walk_to(self, s, target, keys):
        off = sub(target, s['player']); off[1] = 0
        distance, speed = norm(off), math.hypot(s['velocity'][0], s['velocity'][2])
        if distance <= .30 and abs(target[1]-s['player'][1]) <= .65 and speed <= .35:
            return 0, True
        direction = unit(off)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        dx = round(max(-360, min(360, yaw/s['walk_tuning']['mouse'])))
        commanded = s['walk_tuning']['sprint'] if distance > 3 else s['walk_tuning']['walk']
        stopping = speed*speed/(2*s['walk_tuning']['deceleration']) + max(speed, commanded)/20 + .10
        if abs(yaw) < .08 and distance > .30 and (speed <= .35 or distance > stopping):
            keys.add('w')
            if distance > 3: keys.add('Shift_L')
        return dx, False

    def request_e(self, event, s, now):
        if self.tap_key is None and not s['native_interact']:
            self.tap('e', now)
            if self.tap_key == 'e':
                self.receipts[self.key_for(event)] = self.receipt(s)
                self.enter(event, s)

    def ui_update(self, s, now):
        keys = set()
        if s['paused']:
            ui = s['ui']
            require(ui['main_visible'] and ui['exit_visible'] and ui['exit_enabled']
                    and ui['exit_text'] == 'EXIT TO DESKTOP' and ui['exit_path'],
                    'actual enabled normal EXIT TO DESKTOP control')
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key}, 0, 0, False
            self.ui_key = None
            self.ui_release_until = now+.10
            return keys, 0, 0, False
        if self.quit_requested or now < self.ui_release_until or any(s['native_keys'].values()):
            return keys, 0, 0, False
        key = None
        if not s['paused']:
            require(self.stage == 'pause', 'normal pause stays open until requested UI exit')
            key = 'Escape'
        elif s['ui']['focus_is_exit']:
            self.receipts['exit_ui'] = {'sequence': s['sequence'], 'ui': s['ui'].copy()}
            self.quit_requested = True
            self.stage = 'quit_wait'
            key = 'Return'
        else:
            require(s['ui']['focus_path'], 'ordinary pause keyboard focus')
            key = 'Tab'
        self.ui_key, self.ui_until = key, now+.08
        keys.add(key)
        return keys, 0, 0, False

    def update(self, s, now):
        # The supervisor validates every receipt before this one OS-input update.
        require(self.last_state is s, 'latest already-validated Arrow observation')
        self.check_weapon_deadline(now)
        if self.stage in ('pause', 'quit_wait'): return self.ui_update(s, now)
        keys, dx, dy = set(), 0, 0
        if self.stage == 'boot' and s['menu_ready']:
            self.enter('begin_shift', s)
            self.request_e('begin_shift', s, now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP' and s['grounded'] and s['supported']:
            require(any(e['stage'] == 'begin_shift' for e in self.native_edges), 'actual Begin Shift E')
            self.enter('walk', s)
        elif self.stage == 'walk':
            name, target = self.OUTBOUND[self.walk_index]
            dx, reached = self.walk_to(s, target, keys)
            if reached:
                self.visited.append({'name': name, **self.receipt(s)})
                self.walk_index += 1
                if self.walk_index == len(self.OUTBOUND):
                    self.enter('approach', s)
                    self.walk_index = 0
        elif self.stage in ('approach', 'reapproach'):
            if s['candidate'] and not s['station_candidate'] and s['boarding_distance'] <= 7 \
                    and not s['reboard_blocked'] and norm(s['velocity']) <= .35:
                clear = self.receipts.get('walk_clear', {})
                require(self.flight == 0 or (self.clear_seen and clear.get('boarding_distance', 0) > 7
                        and not clear.get('reboard_blocked', True)
                        and all(clear.get(k) == s[k] for k in self.IDS)
                        and self.receipts['exited_1']['frame'] < clear['frame'] < s['frame']),
                        'actual clear walk before second boarding')
                self.request_e('board', s, now)
            else:
                goals = [[s['boarding'][0], 0, 22], s['boarding']]
                dx, reached = self.walk_to(s, goals[self.walk_index], keys)
                if reached and self.walk_index == 0: self.walk_index = 1
        elif self.stage == 'board' and s['phase'] == 'START_ENGINES' and not s['transition_busy']:
            require(self.boarding_seen and any(e['stage'] == 'board' and e['flight'] == self.flight+1 for e in self.native_edges)
                    and s['boarding_confirmation'].get('adapter', {}).get('view', {}).get('state') == 'seated',
                    'actual boarding transition and E before Arrow seated receipt')
            self.require_home(s, self.flight > 0)
            self.receipts[self.key_for('seated')] = self.receipt(s)
            self.enter('launch', s)
        elif self.stage == 'launch':
            off = sub(s['capture_position'], s['position']); off[1] = 0
            signed = dot(off, [-v for v in s['back']])
            if self.departed and (s['capture'] or abs(signed) < 6):
                keys.add('Prior')
                if norm(s['ship_velocity']) <= .35 and s['capture']:
                    if self.flight == 0:
                        self.weapon_started, self.weapon_start_frame = now, s['frame']
                        self.weapon['brake'] = self.weapon_receipt(s)
                        self.mouse_pending = None
                        self.enter('weapon_aim', s)
                    else:
                        self.tap('l', now)
                        if self.tap_key == 'l':
                            self.receipts[self.key_for('landing')] = self.receipt(s)
                            self.enter('land', s)
                elif self.flight == 0:
                    self.weapon_started, self.weapon_start_frame = now, s['frame']
                    self.weapon['brake'] = self.weapon_receipt(s)
                    self.mouse_pending = None
                    self.enter('weapon_brake', s)
            else: keys.add('w' if signed >= 0 else 's')
        elif self.stage == 'weapon_brake':
            keys.add('Prior')
            if norm(s['ship_velocity']) <= .35:
                require(s['capture'], 'Arrow brake stays within existing capture approach')
                self.enter('weapon_aim', s)
        elif self.stage == 'weapon_aim':
            keys.add('Prior')
            dx, dy, alignment = self.weapon_aim(s, sub(s['target']['position'], s['camera']))
            if alignment > .99998 and norm(s['ship_velocity']) <= .35 and self.mouse_pending is None:
                require(not s['native_fire'] and not s['shot']['present'] and s['target']['health'] == 100,
                        'unfired native weapon and full target health at fire baseline')
                self.tap('f', now)
                if self.tap_key == 'f':
                    self.weapon['pre_fire'] = self.weapon_receipt(s)
                    self.enter('weapon_fire', s)
                    dx = dy = 0
        elif self.stage == 'weapon_fire':
            keys.add('Prior')
            # Shared tap timing retains this one continuous F press for at
            # least .15 seconds and six observed physics frames. Never rearm it.
            if 'hit' in self.weapon and self.tap_key != 'f' and not s['native_fire']:
                self.mouse_pending = None
                self.enter('weapon_restore', s)
        elif self.stage == 'weapon_restore':
            keys.add('Prior')
            dx, dy, restored = self.restore_attitude(s, keys)
            if restored and self.mouse_pending is None and norm(s['ship_velocity']) <= .35:
                require(s['capture'] and 'hit' in self.weapon, 'hit and original Arrow capture before landing')
                dx = dy = 0
                keys.discard('q'); keys.discard('r')
                self.weapon['restored'] = self.weapon_receipt(s)
                self.weapon['elapsed_seconds'] = now-self.weapon_started
                self.check_weapon_deadline(now)
                self.tap('l', now)
                if self.tap_key == 'l':
                    self.receipts[self.key_for('landing')] = self.receipt(s)
                    self.enter('land', s)
        elif self.stage == 'land':
            keys.add('Prior')
            if s['phase'] == 'SHUT_DOWN' and s['landed']:
                require(self.departed and self.landing_seen, 'actual departure and native landing request before return')
                self.require_home(s)
                self.receipts[self.key_for('docked')] = self.receipt(s)
                keys.clear()
                self.enter('shutdown', s)
            elif not s['landing_active'] and s['capture']: self.tap('l', now)
        elif self.stage == 'shutdown' and s['engine'] == 'OFFLINE':
            if self.neutral_start is not None and s['frame']-self.neutral_start >= 89:
                self.receipts[self.key_for('offline')] = self.receipt(s)
                self.request_e('exit', s, now)
        elif self.stage == 'exit' and s['phase'] == 'APPROACH_SHIP' and not s['transition_busy']:
            self.require_foot(s); self.require_home(s)
            require(self.disembarking_seen and norm(sub(s['player'], s['exit'])) < .65
                    and any(e['stage'] == 'exit' and e['flight'] == self.flight+1 for e in self.native_edges),
                    'actual separate E and supported physical Arrow exit')
            self.receipts[self.key_for('exited')] = self.receipt(s)
            self.trips.append({'flight': self.flight+1, 'excursion_m': self.excursion,
                               'neutral_frames': s['frame']-self.neutral_start})
            if len(self.trips) == 2:
                self.tap_key = None
                self.enter('pause', s)
            else:
                self.flight += 1
                self.excursion = 0
                self.departed = self.thrust_seen = self.landing_seen = False
                self.boarding_seen = self.disembarking_seen = False
                self.neutral_start = None
                self.enter('clear', s)
        elif self.stage == 'clear':
            dx, reached = self.walk_to(s, [-35, 0, 22], keys)
            if reached and s['boarding_distance'] > 7 and not s['reboard_blocked']:
                self.clear_seen = True
                self.receipts['walk_clear'] = self.receipt(s)
                self.walk_index = 0
                self.enter('reapproach', s)
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame+6: keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now+.3
                self.tap_release_frame = self.frame
        facing = s['camera_back'] if self.stage in self.WEAPON_STAGES else s['walk_forward']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        self.check_weapon_deadline(now)
        return keys, dx, dy, False

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and len(self.trips) == 2 and self.clear_seen and 'exit_ui' in self.receipts
                and 'hit' in self.weapon and 'restored' in self.weapon
                and self.weapon['elapsed_seconds'] <= self.WEAPON_CAP
                and all(t['excursion_m'] > 8 for t in self.trips),
                'two ordinary Arrow flights and normal UI exit zero before success')
        self.result = {'completion_marker': self.MARKER, 'trips': self.trips,
                       'receipts': self.receipts, 'visited': self.visited, 'walked_m': self.walked,
                       'native_interact_edges': self.native_edges, 'phases': self.phases,
                       'physics_observations': self.observations, 'normal_ui_exit': True,
                       'weapon': self.weapon, 'weapon_hit_qualification': 'ARROW_DRONE_01_24_DAMAGE',
                       'weapons_damage_recovery_crosscraft_acceptance': 'NOT_RUN'}
        return self.result


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

    def walk_arrival_ready(self, through=False):
        return True

    def walk_motion_allowed(self, distance, through=False):
        return True

    def station_following_target(self, s):
        return None

    def walk_mouse_delta(self, yaw, sensitivity):
        return round(max(-60, min(60, yaw * .5 / sensitivity)))

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
            following = self.station_following_target(s)
            off = sub(target, s['player'])
            horizontal = [off[0], 0, off[2]]
            distance = norm(horizontal)
            if distance <= .30 and abs(off[1]) <= .65 and sandbox['grounded'] and self.walk_arrival_ready(following is not None):
                self.visited.append({'waypoint': name, 'frame': self.frame, 'player': s['player']})
                self.index += 1
                print(json.dumps(self.visited[-1]), flush=True)
                interrupted = self.waypoint_reached(name, target, s)
                if following is not None:
                    direction = unit(sub(following, s['player']))
                    yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
                    dx = self.walk_mouse_delta(yaw, sandbox['walk_mouse'])
                    if abs(yaw) < .08:
                        keys.add('w')
                        if norm(sub(following, s['player'])) > 3: keys.add('Shift_L')
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
                dx = self.walk_mouse_delta(yaw, sandbox['walk_mouse'])
                if abs(yaw) < .08 and self.walk_motion_allowed(distance, following is not None):
                    keys.add('w')
                    if distance > 3 or following is not None and norm(sub(following, s['player'])) > 3:
                        keys.add('Shift_L')
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
        'aft_stair_top': 'cinder_long_range_bomber',
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
        self.walk_origin = None

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
            # Visit while the station route already passes this stair top.
            # The 20mm bridge lip still uses the ordinary physical step-up.
            self.pending_walk = [[-5.7, 4.2, 61.2], [-9.2, 4.2, 61.2], [-9.2, 4.2, 61.4],
                                 [-10.8, 4.22, 61.4],
                                 [-10.8, 4.2, boarding[2]], boarding]
        elif key == 'cinder_light_interceptor':
            self.pending_walk = [[56, 4.2, 68.3], [56, 4.2, boarding[2]], boarding]
            if not self.reusing:
                # Bomber is already secured. Leave Cargo north of its hull
                # and use the proven eastern apron to the Light's clear lane.
                self.pending_walk = [[7, 4.18, 90], [22.2, 4.18, 90], [22.2, 4.18, 75.2],
                                     [23, 4.18, 72.8], [25.4, 4.2, 70.6], [25.4, 4.2, 68.3]] + self.pending_walk
        else:
            self.pending_walk = [boarding]
        self.approach_path = self.pending_walk[:]
        self.return_path = list(reversed(self.approach_path[:-1]))
        self.walk_origin = s['player'][:]
        if key == 'zenith_b7_observed':
            # The disembarking pilot starts on the port side of the wing;
            # reversing the distant approach goal would cut through that wing.
            self.return_path = [[14.8, 4.2, 57.2], [20.4, 4.2, 59.2], [22, 4.2, 68.3]]
        self.enter('craft_approach', s)

    def walk_arrival_ready(self, through=False):
        return through or norm(self.foot_velocity) <= self.SETTLED_WALK_SPEED

    def straight_following_target(self, s, previous, target, following):
        if previous is None or following is None:
            return None
        if max(previous[1], target[1], following[1]) - min(previous[1], target[1], following[1]) > .000001:
            return None
        incoming, outgoing = sub(target, previous), sub(following, target)
        if norm(incoming) <= .000001 or norm(outgoing) <= .000001 or dot(unit(incoming), unit(outgoing)) <= .999:
            return None
        # Continue only on the observed floor and close to the straight lane;
        # a displaced approach defaults to the established stop-and-settle path.
        off = sub(s['player'], target)
        lateral = sub(off, [v * dot(off, unit(outgoing)) for v in unit(outgoing)])
        if not s['sandbox']['grounded'] or abs(off[1]) > .65 or norm(lateral) > .10:
            return None
        return following

    def station_following_target(self, s):
        if self.index == 0 or self.index + 1 == len(self.WAYPOINTS):
            return None
        name, target = self.WAYPOINTS[self.index]
        if name in self.TRIGGERS:
            return None
        return self.straight_following_target(s, self.WAYPOINTS[self.index-1][1], target,
                                              self.WAYPOINTS[self.index+1][1])

    def walk_mouse_delta(self, yaw, sensitivity):
        # PlayerController applies relative pixels directly to yaw. Keep each
        # sweep inside the isolated display's half-width; update() waits for
        # the observed attitude change before sending another sweep.
        return round(max(-360, min(360, yaw / sensitivity)))

    def walk_motion_allowed(self, distance, through=False):
        if through:
            return True
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

    def walk(self, s, target, keys, following=None):
        following = self.straight_following_target(s, self.walk_origin, target, following)
        off = sub(target, s['player'])
        horizontal = [off[0], 0, off[2]]
        distance = norm(horizontal)
        if distance <= .30 and abs(off[1]) <= .65 and s['sandbox']['grounded']:
            if following is None:
                return 0, self.walk_arrival_ready()
            horizontal = sub(following, s['player'])
            horizontal[1] = 0
            distance = norm(horizontal)
            reached = True
        else:
            reached = False
        direction = unit(horizontal)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        dx = self.walk_mouse_delta(yaw, s['sandbox']['walk_mouse'])
        if abs(yaw) < .08 and self.walk_motion_allowed(distance, following is not None):
            keys.add('w')
            if distance > 3 or following is not None and norm(sub(following, s['player'])) > 3:
                keys.add('Shift_L')
        return dx, reached

    def walk_pending(self, s, keys):
        target = self.pending_walk[0]
        following = self.pending_walk[1] if len(self.pending_walk) > 1 else None
        dx, reached = self.walk(s, target, keys, following)
        if reached:
            self.walk_origin = target
        return dx, reached

    def clear_station_prompt(self, s):
        # Station interactions take priority over boarding in GameFlow. Look
        # away from that actual selected object before sending the ship's E.
        off = sub(s['player'], s['sandbox']['station_candidate']['position'])
        off[1] = 0
        direction = unit(off)
        yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
        return self.walk_mouse_delta(yaw, s['sandbox']['walk_mouse'])

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
                if self.walk_arrival_ready():
                    self.tap('e', now)
                    self.enter('craft_board', s)
            else:
                dx, reached = self.walk_pending(s, keys)
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
                    require(set(c['craft'] for c in self.completed) == self.FLEET - {'torrent_provisional'},
                            'all eight required craft secured before deliberate crash')
                    require(len(self.visited) == len(self.WAYPOINTS) and self.door_opened,
                            'complete station walk before deliberate crash')
                    self.enter('crash_reboard_clear', s)
                elif self.craft_key in ('bulwark_heavy_gunship', 'cinder_cargo_hauler'):
                    # All station waypoints are already visited. Continue from
                    # this actual exit to the next craft's clear walking route.
                    self.resume_target = None
                    next_key = self.CINDER[0] if self.craft_key == 'bulwark_heavy_gunship' else self.CINDER[-1]
                    if next_key == self.CINDER[-1]:
                        require(any(c['craft'] == 'cinder_long_range_bomber' for c in self.completed),
                                'early Bomber sortie completed before Cargo-to-Light handoff')
                    self.begin_craft(next_key, s)
                else:
                    self.pending_walk = self.return_path[:]
                    if self.craft_key == 'cinder_long_range_bomber':
                        self.pending_walk = [[-10.8, 4.2, s['player'][2]], [-10.8, 4.22, 61.4],
                                             [-9.2, 4.2, 61.4], [-9.2, 4.2, 61.2], [-5.7, 4.2, 61.2]]
                    if self.resume_target is not None: self.pending_walk.append(self.resume_target)
                    self.walk_origin = s['player'][:]
                    self.enter('return_walk', s)
            elif s['phase'] == 'SHUT_DOWN' and craft['telemetry']['engine'] == 'OFFLINE': self.tap('e', now)
        elif self.stage == 'return_walk':
            if self.pending_walk:
                dx, reached = self.walk_pending(s, keys)
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
                self.walk_origin = s['player'][:]
                self.enter('recovery_walk', s)
        elif self.stage == 'recovery_walk':
            self.recovery_walk = max(self.recovery_walk, norm(sub(s['player'], s['spawn'])))
            dx, reached = self.walk_pending(s, keys)
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
    require(route in ("arrow-return-reuse", "station-defense", "guided", "beacon-entry", "beacon-settlement", "sandbox-walk", "sandbox", "hulk-arrival", "hulk-breaker", "hulk-home", "habitat-loop", "habitat-restart", "life-tow", "life-gantry", "life-arm", "life-patrol"), "known ordinary-input route")
    output.mkdir(parents=True, exist_ok=False)
    game = xvfb = desktop = pilot = None
    temporary_profile = None
    restart_files = None
    settlement_files = None
    defense_files = None
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
                settlement_files = BeaconSettlementFiles(profile, output) if route == 'beacon-settlement' else None
                restart_files = HabitatRestartFiles(profile, output) if route == 'habitat-restart' else None
                defense_files = StationDefenseFiles(profile, output) if route == 'station-defense' else None
                result['game_legs'] = []
                for leg in range(2 if restart_files else 1):
                    # These are the exact same args/env/profile/display/helper.
                    # The single timer above remains armed across both games.
                    desktop.keys([]); desktop.mouse(0, 0, False)
                    game = subprocess.Popen(args,cwd=binary.parent,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,bufsize=0)
                    leg_result = {'pid': game.pid, 'leg': leg + 1, 'exit_code': None, 'reaped': False}
                    result['game_legs'].append(leg_result)
                    if leg == 0: result['game_pid'] = game.pid
                    else:
                        result['restart_game_pid'] = game.pid
                        require(game.pid != result['game_pid'], 'restart launches a distinct OS game process')
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
                    leg_result['window'] = hex(window)
                    desktop.focus(window)
                    pilot = HabitatRestartPilot(cold=bool(leg)) if restart_files else {
                        "arrow-return-reuse": ArrowReturnReusePilot, "station-defense": StationDefensePilot, "guided": Pilot, "beacon-entry": BeaconEntryPilot, "beacon-settlement": BeaconSettlementPilot, "sandbox-walk": SandboxWalkPilot, "sandbox": SandboxPilot,
                        "hulk-arrival": HulkArrivalPilot, "hulk-breaker": HulkBreakerPilot,
                        "hulk-home": HulkHomePilot, "habitat-loop": HabitatLoopPilot, "life-tow": LifeTowPilot, "life-gantry": lambda: LifeTowPilot("life-gantry"), "life-arm": lambda: LifeTowPilot("life-arm"), "life-patrol": lambda: LifeTowPilot("life-patrol")}[route]()
                    with selectors.DefaultSelector() as selector:
                        selector.register(game.stdout,selectors.EVENT_READ)
                        pending = b''
                        with (output/'game.log').open('ab') as log:
                            while pilot.result is None:
                                if game.poll() is not None:
                                    if isinstance(pilot, ArrowReturnReusePilot):
                                        require(pilot.quit_requested, 'Arrow process exits only after normal UI request')
                                        drain_game_output(game, output/'game.log')
                                        tail = (output/'game.log').read_bytes().splitlines()
                                        for observation in observations_from_lines(tail):
                                            if observation['sequence'] > pilot.last_state['sequence']:
                                                pilot.validate_observation(observation)
                                        pilot.finish(game.wait())
                                        leg_result.update(exit_code=0, reaped=True, normal_ui_exit=True)
                                        break
                                    if defense_files:
                                        require(pilot.quit_requested and pilot.stage == 'ui_exit_wait',
                                                'defense game exits only after actual EXIT TO DESKTOP')
                                        require(game.wait() == 0, 'normal defense UI exit returns zero and reaps game')
                                        leg_result.update(exit_code=0, reaped=True, normal_ui_exit=True)
                                        drain_game_output(game, output/'game.log', pending,
                                            lambda sample: (pilot.validate_observation(sample), defense_files.observe(sample, pilot)))
                                        pending = b''
                                        pilot.finish_normal_exit()
                                        defense_files.finish(pilot)
                                        break
                                    if not restart_files: raise RuntimeError(f'game exited during {pilot.stage}: {game.returncode}')
                                    require(pilot.quit_requested and pilot.stage == 'restart_exit_wait',
                                            'game exits only after actual EXIT TO DESKTOP activation')
                                    require(game.wait() == 0, 'normal UI shutdown exits zero and reaps game')
                                    leg_result.update(exit_code=0, reaped=True, normal_ui_exit=True)
                                    break
                                if xvfb.poll() is not None: raise RuntimeError('owned Xvfb exited during sortie')
                                if time.monotonic()-start >= CAP: raise TimeoutError('300-second sortie cap')
                                if isinstance(pilot, ArrowReturnReusePilot):
                                    pilot.check_weapon_deadline(time.monotonic())
                                for key,_ in selector.select(.1):
                                    chunk = os.read(key.fd,262144)
                                    if not chunk: continue
                                    log.write(chunk); log.flush()
                                    pending += chunk
                                    lines = pending.split(b'\n'); pending=lines.pop()
                                    observations = observations_from_lines(lines)
                                    if observations:
                                        if isinstance(pilot, (LifeTowPilot, ArrowReturnReusePilot, StationDefensePilot)):
                                            for observation in observations:
                                                pilot.validate_observation(observation)
                                                if defense_files: defense_files.observe(observation, pilot)
                                        state = observations[-1]
                                        if restart_files:
                                            require(state['pid'] == game.pid, 'observer belongs to exact running game PID')
                                            if leg and 'cold-title' not in restart_files.snapshots and state.get('menu_ready'):
                                                cold_title = restart_files.capture('cold-title', state['save'])
                                                closed = restart_files.snapshots['first-orderly-close']['document']
                                                restart_files.require_cold(cold_title, closed)
                                                restart_files.require_preserved(closed, cold_title)
                                        keys,dx,dy,fire=pilot.update(state,time.monotonic())
                                        if settlement_files: settlement_files.observe(state, pilot)
                                        if restart_files:
                                            if not leg and 'sleep_press' in pilot.receipts and 'before-sleep' not in restart_files.snapshots:
                                                before = restart_files.capture('before-sleep', state['save'])
                                                require(before['payload']['solo_safe_recovery']['mode'] == 'on_foot',
                                                        'independent real-file awake context before ordinary bunk admission')
                                            if pilot.stage == 'restart_context' and not pilot.file_context_accepted:
                                                saved = state['save']
                                                before = restart_files.snapshots['before-sleep']['document']
                                                if saved['context'] == {'mode': 'unavailable'}:
                                                    resting = restart_files.capture('resting', saved)
                                                    require(saved['retry_seconds'] == 0 and saved['source'] == 'primary'
                                                            and saved['context_generation'] > before['generation']
                                                            and resting['payload']['solo_safe_recovery'] == {'mode': 'unavailable'}
                                                            and resting['generation'] >= saved['context_generation'],
                                                            'accepted unavailable rest context independently read from actual file')
                                                    restart_files.require_preserved(before, resting)
                                                    pilot.file_context_accepted = True
                                            if leg and pilot.cold_ready and 'cold-awake' not in restart_files.snapshots:
                                                require('cold-title' in restart_files.snapshots, 'normal cold title observed before Begin Shift')
                                                awake = restart_files.capture('cold-awake', state['save'])
                                                restart_files.require_preserved(restart_files.snapshots['resting']['document'], awake)
                                            if pilot.quit_requested: leg_result['exit_ui'] = pilot.receipts['exit_ui']
                                        desktop.keys(keys); desktop.mouse(dx,dy,fire)
                    if restart_files:
                        desktop.keys([]); desktop.mouse(0, 0, False)
                        drain_game_output(game, output/'game.log')
                        game.stdout.close()
                        require(not diagnostic_lines((output/'game.log').read_bytes().splitlines()),
                                'no game diagnostics across orderly process boundary')
                        label = 'first-orderly-close' if not leg else 'second-orderly-close'
                        closed = restart_files.capture(label)
                        running = restart_files.snapshots['resting' if not leg else 'cold-title']['document']
                        restart_files.require_orderly(closed, running)
                        restart_files.require_preserved(restart_files.snapshots['resting']['document'], closed)
                        if not leg:
                            require(closed['payload']['solo_safe_recovery'] == {'mode': 'unavailable'},
                                    'orderly UI quit retains unavailable real station sleep context')
                        else:
                            require(pilot.interaction_complete, 'cold continuation complete before final normal shutdown')
                        leg_result['sortie'] = pilot.report()
                        game = None
                    else:
                        if defense_files:
                            desktop.keys([]); desktop.mouse(0, 0, False)
                            drain_game_output(game, output/'game.log')
                            game.stdout.close()
                            require(not diagnostic_lines((output/'game.log').read_bytes().splitlines()),
                                    'no diagnostics across complete defense normal UI exit')
                            game = None
                        result.update(success=True,sortie=pilot.result)
                if restart_files:
                    result['actual_file_snapshots'] = restart_files.snapshots
                    result['sortie'] = {'completion_marker': HabitatRestartPilot.MARKER,
                                        'legs': [item['sortie'] for item in result['game_legs']],
                                        'distinct_processes': True, 'same_profile': str(profile),
                                        'same_input_helper_pid': desktop.process.pid,
                                        'same_xvfb_pid': xvfb.pid}
                    result['success'] = True
    except Exception as error:
        if settlement_files is not None:
            result['actual_file_snapshots'] = settlement_files.snapshots
        if restart_files is not None:
            result['actual_file_snapshots'] = restart_files.snapshots
        if defense_files is not None:
            result['actual_file_snapshots'] = defense_files.snapshots
        if pilot is not None:
            result['partial_sortie'] = {'stage': pilot.stage, 'stages': pilot.stages, 'phases': pilot.phases}
            if isinstance(pilot, ArrowReturnReusePilot):
                result['partial_sortie'].update(last_state=pilot.last_state, receipts=pilot.receipts, trips=pilot.trips, weapon=pilot.weapon)
            if isinstance(pilot, HabitatRestartPilot):
                result['partial_restart'] = pilot.report()
            if isinstance(pilot, StationDefensePilot):
                result['partial_sortie'].update(pilot.report())
            if isinstance(pilot, (HabitatLoopPilot, LifeTowPilot)):
                result['partial_sortie'].update(last_state=pilot.last_state, visited=pilot.visited,
                                               receipts=pilot.receipts, native_interact_edges=pilot.native_edges,
                                               walked_m=pilot.walked)
            if isinstance(pilot, BeaconEntryPilot):
                result['partial_sortie'].update(last_state=pilot.last_state, receipts=pilot.receipts,
                                               ui_edges=pilot.ui_edges, sequence=pilot.sequence)
            if isinstance(pilot, HulkArrivalPilot):
                result['partial_sortie']['last_state'] = pilot.last_state
            if isinstance(pilot, SandboxPilot):
                result['partial_sortie'].update(visited=pilot.visited, craft_sorties=pilot.completed,
                                               last_state=pilot.last_state, deliberate_crash=pilot.crash_receipt)
        result['error'] = f'{type(error).__name__}: {error}'
    finally:
        if settlement_files is not None:
            result['actual_file_snapshots'] = settlement_files.snapshots
        if defense_files is not None:
            result['actual_file_snapshots'] = defense_files.snapshots
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
    parser.add_argument('--route', choices=('arrow-return-reuse', 'station-defense', 'guided', 'beacon-entry', 'beacon-settlement', 'sandbox-walk', 'sandbox', 'hulk-arrival', 'hulk-breaker', 'hulk-home', 'habitat-loop', 'habitat-restart', 'life-tow', 'life-gantry', 'life-arm', 'life-patrol'), default='guided',
                        help='station-defense requires ordinary board Deploy, Arrow departure, four real kills/reward, strict home return/exit, physical Reset and normal UI shutdown; beacon-settlement continues the accepted entry through four physical beacons and durable reward; beacon-entry departs normally and physically reaches/starts the first Beacon through actual pause controls; life-patrol walks Habitat through the real door beside patrol drones and boards Torrent; life-arm walks Aft stairs past the live service arm and boards Zenith; life-gantry walks Freight past the live gantry and boards Jovian; life-tow walks Central beside live tow service and boards Torrent; hulk-home carries the earned HULK cell back to a supported home exit; hulk-breaker continues HULK arrival through its breaker; hulk-arrival flies the normal Guided prelude then docks/exits at HULK; sandbox runs fleet/crash/reuse; sandbox-walk covers station traversal')
    args=parser.parse_args()
    try: binary=validate_binary(args.binary)
    except ValueError as error: parser.error(str(error))
    result=run(binary,args.output.absolute(),args.route)
    print(json.dumps(result,indent=2))
    return 0 if result['success'] and result.get('inputs_released') and result['game_reaped'] and result['xvfb_reaped'] and result['input_helper_reaped'] else 1


if __name__=='__main__': raise SystemExit(main())
