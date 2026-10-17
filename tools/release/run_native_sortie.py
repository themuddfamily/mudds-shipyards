#!/usr/bin/env python3
"""Fly the embedded Linux game with OS XTest keys/mouse on an owned Xvfb.

Usage: run_native_sortie.py GAME.x86_64 --output NEW_RESULT_DIRECTORY
Use --route sandbox for the full five-branch/eight-craft/crash/reuse scenario.
Use --route sandbox-walk for the on-foot prerequisite only.
Use --route hulk-arrival for the Guided prelude then the streamed HULK dock/exit.
Use --route hulk-breaker to continue that arrival through the interior breaker.
Use --route hulk-home to carry that earned cell back to a supported yard exit.
Use --route hulk-revisit to revisit a newly streamed HULK and refuse a second cell.
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


class HulkRevisitPilot(HulkHomePilot):
    """Preserve the complete home prefix, then make one ordinary new-generation visit."""
    MARKER = 'NATIVE_HULK_REVISIT_OK'
    CLEARANCE = [-11, -.02, -9.25]

    def __init__(self):
        super().__init__()
        self.home_result = None
        self.revisit_previous = None
        self.revisit_clearance = None
        self.revisit_board_press = None
        self.revisit_boarded = None
        self.revisit_departure = None
        self.revisit_lift_height = None
        self.revisit_lift_seen = False
        self.revisit_departure_complete = None
        self.revisit_reload = None
        self.revisit_ids = None
        self.revisit_leg_ready = None
        self.revisit_legs = []
        self.revisit_braking = False
        self.revisit_header_samples = []
        self.revisit_header_crossing = None
        self.revisit_landing_seen = False
        self.revisit_arrival = None
        self.revisit_exit = None
        self.revisit_route = None
        self.revisit_visited = []
        self.revisit_walked = 0
        self.revisit_support = set()
        self.revisit_max_step = 0
        self.revisit_press = None
        self.revisit_native_previous = None
        self.revisit_native_edges = []
        self.revisit_event_initial = None

    def update(self, s, now):
        self.last_state = s
        if self.home_result is None:
            commands = super().update(s, now)
            if self.result is None:
                return commands
            self.home_result = json.loads(json.dumps(self.result))
            self.home_result['completion_marker'] = HulkHomePilot.MARKER
            self.result = None
            require(self.cinder_unload is not None and not s['hulk']['available']
                    and not s['hulk_home']['streaming']['loaded'],
                    'actual original Cinder unload precedes the new sortie')
            self.require_home_dock(s)
            self.revisit_lift_height = self.home_departure_lift_height(s)
            self.revisit_previous = s
            self.tap_key = None
            self.tap_release_frame = s['frame']
            self.tap_cooldown = now + .3
            self.mouse_pending = None
            self.enter('revisit_clearance', s)
            return set(), 0, 0, False
        # Never call any prefix update after home: its old-world and unclaimed
        # predicates intentionally describe the previous journey only.
        keys, dx, dy, fire = self.update_revisit(s, now)
        facing = s['walk_forward'] if not s['seated'] else s['back']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001:
                dx = dy = 0
            else:
                self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    def home_departure_lift_height(self, s):
        height = s.get('home_departure_lift_height')
        require(type(height) in (int, float) and math.isfinite(height) and height >= 0,
                'finite nonnegative public home departure lift height')
        return height

    def observe_revisit_streaming(self, s):
        streaming = s['hulk_home']['streaming']
        initial, unloaded = self.streaming_initial, self.cinder_unload['streaming']
        require(streaming['unload_radius_m'] == initial['unload_radius_m'] == 650
                and streaming['unload_count'] == unloaded['unload_count']
                and streaming['load_failure_count'] == 0
                and streaming['load_request_count'] in (initial['load_request_count'], initial['load_request_count'] + 1),
                'one new Cinder request without another unload or load failure')
        require(streaming['generation'] >= unloaded['generation'],
                'Cinder generation cannot precede the observed actual unload')
        if streaming['loaded']:
            require(self.revisit_departure is not None
                    and streaming['generation'] > unloaded['generation']
                    and streaming['loaded_generation'] == streaming['generation']
                    and streaming['load_request_count'] == initial['load_request_count'] + 1
                    and streaming['loaded_instance_id'] not in (0, initial['loaded_instance_id']),
                    'new Cinder load follows actual prior unload with a newer live generation and distinct cluster')
        if self.revisit_reload is not None:
            observed = self.revisit_reload['streaming']
            require(streaming['loaded'] and not streaming['loading']
                    and streaming['generation'] == observed['generation']
                    and streaming['loaded_generation'] == observed['loaded_generation']
                    and streaming['loaded_instance_id'] == observed['loaded_instance_id'],
                    'same newly loaded Cinder generation throughout revisit')
        if not s['hulk']['available']:
            require(self.revisit_reload is None, 'new streamed HULK remains resident after binding')
            return
        hulk, interior = s['hulk'], s['hulk']['interior']
        require(streaming['loaded'] and not streaming['loading'], 'live new HULK belongs to completed Cinder load')
        ids = (hulk['hulk_id'], hulk['berth_instance_id'], interior['breaker_id'])
        require(hulk['berth_id'] == self.BERTH and ids[0] != self.hulk_ids[0]
                and ids[1] != self.hulk_ids[1] and ids[2] != self.interior_initial['breaker_id'],
                'distinct replacement HULK berth and breaker after old-world retirement')
        if self.revisit_ids is None:
            self.revisit_ids = ids
            self.revisit_reload = {'frame': s['frame'], 'streaming': json.loads(json.dumps(streaming)),
                                   'hulk_id': ids[0], 'berth_instance_id': ids[1], 'breaker_id': ids[2]}
            self.revisit_event_initial = json.loads(json.dumps(interior['breaker_event']))
            require(self.revisit_event_initial['count'] == 0,
                    'new breaker has no interaction before the ordinary revisit walk')
        require(ids == self.revisit_ids, 'same new HULK berth and breaker throughout revisit')

    def observe_revisit_header(self, s):
        previous = self.revisit_previous
        if max(previous['position'][2], s['position'][2]) < -130 \
                or min(previous['position'][2], s['position'][2]) > -110:
            return
        require(len(self.revisit_legs) >= 1 and self.revisit_leg_ready is not None,
                'settled outward staging and aligned leg before RangeHeader crossing')
        for sample in (previous, s):
            require(1.4 <= sample['position'][1] <= 3.8,
                    'outward RangeHeader crossing stays in ship-origin clearance band')
            require(sample['telemetry']['hull'] >= self.revisit_legs[0]['hull'],
                    'outward RangeHeader crossing has no extra hull loss')
            if not self.revisit_header_samples or self.revisit_header_samples[-1]['frame'] != sample['frame']:
                self.revisit_header_samples.append({'frame': sample['frame'], 'position': sample['position'][:],
                                                    'hull': sample['telemetry']['hull']})
        if previous['position'][2] >= -130 >= s['position'][2] and self.revisit_header_crossing is None:
            self.revisit_header_crossing = {'entry_frame': self.revisit_header_samples[0]['frame'],
                'exit_frame': s['frame'], 'origin_z_interval': [-130, -110], 'origin_y_band': [1.4, 3.8],
                'hull_before': self.revisit_legs[0]['hull'], 'hull_after': s['telemetry']['hull'],
                'min_y': min(v['position'][1] for v in self.revisit_header_samples),
                'max_y': max(v['position'][1] for v in self.revisit_header_samples),
                'samples': self.revisit_header_samples}

    def require_revisit_dock(self, s):
        hulk = s['hulk']
        require(s['landed'] and hulk['contract'] and hulk['lease'] and hulk['parked_exact']
                and hulk['occupant_id'] == s['ship_id'] and s['lease_free'],
                'strict token-bound exact occupied new HULK dock with released home lease')

    def update_revisit(self, s, now):
        self.frame = s['frame']
        previous = self.revisit_previous
        frames = self.frame - previous['frame']
        home, hulk = s['hulk_home'], s['hulk']
        initial = self.interior_initial
        require(frames > 0, 'fresh revisit physics observation')
        require(self.identities == (s['player_id'], s['ship_id']) and s['active_ship']
                and not s['destroyed'] and s['phase'] not in ('FAILED', 'RECOVERING'),
                'same live Player and Torrent throughout revisit without recovery')
        require(s['default_sampler'] and s['tuning_unchanged'] and s['guided_complete']
                and home['walk_tuning'] == initial['walk_tuning']
                and home['physics_ticks'] == 60 and home['time_scale'] == 1,
                'authored controls, normal physics and Guided completion retained throughout revisit')
        require((home['home']['berth_id'], home['home']['berth_instance_id']) == self.home_berth_identity
                and home['capsule_id'] == initial['capsule_id'] and home['shape_id'] == initial['shape_id'],
                'same home berth and Player collision capsule throughout revisit')
        require(self.home_departure_lift_height(s) == self.revisit_lift_height,
                'public home departure lift height unchanged since occupied home dock')
        self.require_retained_cell(home)
        self.observe_revisit_streaming(s)
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        keys = set()
        dx = dy = 0
        speed = norm(s['velocity'])
        walking = self.stage in ('revisit_clearance', 'revisit_board_approach', 'revisit_walk',
                                  'revisit_breaker_aim', 'revisit_breaker_press')
        if walking:
            require(s['phase'] == 'COMPLETE' and not s['piloted'] and not s['seated']
                    and s['control_enabled'] and not s['transition_busy'] and home['capsule_enabled'],
                    'ordinary controllable on-foot revisit walk')
            step = norm(sub(s['player'], previous['player']))
            require(step <= (initial['walk_tuning']['sprint']/60*1.25+.02)*frames,
                    'continuous ordinary revisit movement without placement or recovery teleport')
            if self.stage in ('revisit_clearance', 'revisit_board_approach'):
                self.require_home_dock(s)
                berth = home['home']
                require(berth['grounded'] and berth['supported'] and berth['support_collider']
                        and s['telemetry']['engine'] == 'OFFLINE', 'continuous supported home clearance walk')
            else:
                self.require_revisit_dock(s)
                interior = hulk['interior']
                self.require_claimed(interior)
                require(hulk['grounded'] and interior['support_owned'] and hulk['support_collider']
                        and s['telemetry']['engine'] == 'OFFLINE', 'continuous actual new HULK interior support')
                require(interior['capsule_enabled'] and interior['capsule_id'] == initial['capsule_id']
                        and interior['shape_id'] == initial['shape_id']
                        and interior['walk_tuning'] == initial['walk_tuning']
                        and interior['physics_ticks'] == 60 and interior['time_scale'] == 1,
                        'same enabled capsule and authored movement in new HULK')
                require(interior['route'] == self.revisit_authored_route
                        and tuple(interior['space_ids']) == self.SPACES,
                        'unchanged authored new HULK interior route')
                self.revisit_walked += step
                self.revisit_max_step = max(self.revisit_max_step, step/frames)
                self.revisit_support.add(hulk['support_collider'])
                native_pressed = bool(s['native_interact'])
                if native_pressed != self.revisit_native_previous:
                    self.revisit_native_edges.append({'pressed': native_pressed, 'frame': self.frame,
                        'breaker_candidate': interior['breaker_candidate']})
                self.revisit_native_previous = native_pressed
                event = interior['breaker_event']
                require(event['count'] == self.revisit_event_initial['count']
                        or self.stage == 'revisit_breaker_press',
                        'new breaker untouched before completed ordinary interior walk')
        if self.stage == 'revisit_clearance':
            dx, reached = self.home_walk_to(s, self.CLEARANCE, keys, frames)
            if reached:
                require(norm(s['walk_offset']) > 7,
                        'actual interaction-origin boarding offset exceeds production seven-metre reboard block')
                self.revisit_clearance = {'frame': self.frame, 'waypoint': self.CLEARANCE[:],
                    'player': s['player'][:], 'boarding': home['boarding'][:],
                    'walk_offset': s['walk_offset'][:], 'distance_m': norm(s['walk_offset']),
                    'speed_m_s': norm([home['player_velocity'][0], 0, home['player_velocity'][2]]),
                    'support_collider': home['home']['support_collider']}
                self.enter('revisit_board_approach', s)
        elif self.stage == 'revisit_board_approach':
            offset = s['walk_offset'][:]
            offset[1] = 0
            if norm(offset) <= 3.1 and s['candidate']:
                require(self.revisit_clearance is not None and not home['station_candidate'],
                        'cleared reboard block and live boarding candidate without conflicting station action')
                if norm([home['player_velocity'][0], 0, home['player_velocity'][2]]) <= .35:
                    self.tap('e', now)
                    if self.tap_key == 'e':
                        self.revisit_board_press = {'frame': self.frame, 'player': s['player'][:],
                            'boarding': home['boarding'][:], 'walk_offset': s['walk_offset'][:],
                            'candidate': True, 'station_candidate': home['station_candidate']}
                        self.enter('revisit_board', s)
            else:
                dx, reached = self.home_walk_to(s, home['boarding'], keys, frames)
                require(not reached, 'live home boarding point reached without an ordinary boarding candidate')
        elif self.stage == 'revisit_board':
            self.require_home_dock(s)
            if s['phase'] == 'START_ENGINES':
                require(s['piloted'] and s['seated'] and not s['transition_busy'],
                        'one ordinary E reboards the same home-docked Torrent into START_ENGINES')
                self.revisit_boarded = {'frame': self.frame, 'phase': s['phase']}
                self.enter('revisit_departure', s)
            else:
                require(s['phase'] in ('COMPLETE', 'BOARDING'), 'ordinary home reboarding without another tutorial')
                if s['phase'] == 'COMPLETE' and not s['transition_busy']:
                    require(self.frame <= self.revisit_board_press['frame'] + 120,
                            'ordinary home E did not begin reboarding; no retry')
                require(self.frame <= self.revisit_board_press['frame'] + 600,
                        'ordinary home E did not finish reboarding; no retry')
        elif self.stage == 'revisit_departure':
            require(s['piloted'] and s['seated'] and not s['transition_busy']
                    and s['phase'] in ('START_ENGINES', 'FREE_FLIGHT'),
                    'ordinary home departure keeps seated controls through the authored lift')
            self.revisit_lift_seen |= s['departure_lift_active']
            if self.revisit_departure is None and not s['landed'] and s['phase'] == 'FREE_FLIGHT':
                require(s['lease_free'] and not home['home']['lease'] and home['home']['occupant_id'] == 0
                        and norm(sub(s['position'], home['home']['dock'])) > .01,
                        'physical outward departure releases home occupant and reservation')
                self.revisit_departure = {'frame': self.frame, 'position': s['position'][:],
                    'phase': s['phase'], 'home_lease_free': s['lease_free'], 'occupant_id': 0}
            lift_expected = self.revisit_lift_height > 0
            require(lift_expected or not self.revisit_lift_seen,
                    'zero-height home departure has no active lift')
            if (not lift_expected or self.revisit_lift_seen) and not s['departure_lift_active'] \
                    and self.revisit_departure is not None:
                require(not s['landed'] and s['phase'] == 'FREE_FLIGHT' and s['lease_free'],
                        'observed configured departure completion follows actual home lease release')
                self.revisit_departure_complete = {'frame': self.frame, 'position': s['position'][:],
                    'phase': s['phase'], 'landed': s['landed'], 'departure_lift_active': False,
                    'configured_lift_height': self.revisit_lift_height, 'lift_expected': lift_expected,
                    'observed_path': 'active_then_inactive' if lift_expected else 'plain_departure',
                    'lift_active_observed': self.revisit_lift_seen, 'home_lease_free': s['lease_free']}
                self.enter('revisit_flight_0', s)
                keys.add('Prior')
            else:
                keys.add('w')
        elif self.stage.startswith('revisit_flight_'):
            require(s['piloted'] and s['seated'] and not s['transition_busy']
                    and s['phase'] in ('START_ENGINES', 'FREE_FLIGHT'),
                    'later outward thrust uses START_ENGINES then FREE_FLIGHT')
            require(self.revisit_departure_complete is not None and not s['departure_lift_active']
                    and s['phase'] == 'FREE_FLIGHT' and not s['landed'] and s['lease_free'],
                    'completed actual departure lift precedes every translational readiness fence')
            index = int(self.stage.rsplit('_', 1)[1])
            target = ([0, 2.7, -64], [0, 2.7, -150], hulk['approach'])[index]
            off = sub(target, s['position'])
            distance = norm(off)
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if self.revisit_leg_ready is None:
                direction = unit(off)
                nose_pitch = math.degrees(math.asin(max(-1, min(1, -s['back'][1]))))
                target_pitch = math.degrees(math.asin(max(-1, min(1, direction[1]))))
                pitch_error = abs(nose_pitch - target_pitch)
                if speed <= .01 and align >= .9999 and pitch_error <= .5:
                    self.revisit_leg_ready = {'frame': self.frame, 'position': s['position'][:],
                        'velocity': s['velocity'][:], 'speed_m_s': speed, 'direction_alignment': align,
                        'nose_pitch_deg': nose_pitch, 'target_pitch_deg': target_pitch, 'pitch_error_deg': pitch_error}
            if index == 1: self.observe_revisit_header(s)
            stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
            if distance < stopping+1.75: self.revisit_braking = True
            if speed <= .45 and distance > 1: self.revisit_braking = False
            if self.revisit_leg_ready is None or distance <= 1 or self.revisit_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if distance <= 1 and speed <= .35 and self.revisit_leg_ready is not None:
                require(self.revisit_departure is not None, 'actual released home departure precedes outward staging')
                if index == 1:
                    require(self.revisit_header_crossing is not None, 'safe outward RangeHeader crossing before HULK transit')
                if index != 2 or self.revisit_reload is not None:
                    self.revisit_legs.append({'index': index, 'frame': self.frame, 'waypoint': target[:],
                        'position': s['position'][:], 'distance_m': distance, 'speed_m_s': speed,
                        'hull': s['telemetry']['hull'], 'ready': self.revisit_leg_ready})
                    self.revisit_leg_ready = None
                    self.revisit_braking = False
                    self.enter('revisit_align' if index == 2 else 'revisit_flight_'+str(index+1), s)
        elif self.stage == 'revisit_align':
            require(s['phase'] == 'FREE_FLIGHT' and s['piloted'] and s['seated'] and not s['landed'],
                    'ordinary new HULK approach in FREE_FLIGHT')
            keys.update(('Prior', 'h'))
            target = [s['camera'][i]+hulk['dock_forward'][i]*100 for i in range(3)]
            dx, dy, align = self.aim(s, target)
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(hulk['capture'] and hulk['selected_berth_id'] == self.BERTH,
                        'production preview selects actual new HULK berth')
                self.tap('l', now)
                if self.tap_key == 'l':
                    self.request_frame = self.frame
                    self.enter('revisit_land', s)
        elif self.stage == 'revisit_land':
            keys.add('Prior')
            self.revisit_landing_seen |= s['landing_active']
            require(not hulk['landing_abort_reason'], 'new HULK landing aborted: '+hulk['landing_abort_reason'])
            if self.revisit_landing_seen and not s['landing_active'] and not s['landed']:
                require(False, 'new HULK landing ended without docking')
            if s['landed'] and s['phase'] == 'SHUT_DOWN':
                require(self.revisit_landing_seen, 'one ordinary L starts observed new HULK landing')
                self.require_revisit_dock(s)
                self.revisit_arrival = {'frame': self.frame, 'position': s['position'][:],
                    'berth_id': hulk['berth_id'], 'berth_instance_id': hulk['berth_instance_id'],
                    'contract': hulk['contract'], 'lease': hulk['lease'],
                    'occupant_id': hulk['occupant_id'], 'parked_exact': hulk['parked_exact']}
                self.shutdown_frame = self.frame
                self.enter('revisit_shutdown', s)
                keys.clear()
            elif not self.revisit_landing_seen:
                require(self.frame <= self.request_frame + 120, 'ordinary L did not start new HULK landing; no retry')
        elif self.stage == 'revisit_shutdown':
            self.require_revisit_dock(s)
            require(s['phase'] == 'SHUT_DOWN' and s['piloted'] and s['seated'], 'secured new HULK during neutral shutdown')
            if self.frame - self.shutdown_frame >= 90 and s['telemetry']['engine'] == 'OFFLINE':
                self.tap('e', now)
                if self.tap_key == 'e':
                    self.request_frame = self.frame
                    self.enter('revisit_exit', s)
        elif self.stage == 'revisit_exit':
            self.require_revisit_dock(s)
            require(s['telemetry']['engine'] == 'OFFLINE', 'powered-down new HULK retained throughout ordinary exit')
            if not s['piloted'] and not s['seated'] and s['control_enabled'] and not s['transition_busy'] \
                    and hulk['grounded'] and hulk['shelf_supported']:
                interior = hulk['interior']
                require(s['phase'] == 'COMPLETE' and home['capsule_enabled']
                        and norm(interior['player_velocity']) <= .35 and interior['support_owned']
                        and len(interior['route']) == 6 and tuple(interior['space_ids']) == self.SPACES,
                        'ordinary new HULK exit settles on the supported shelf before authored walk')
                self.revisit_exit = {'frame': self.frame, 'player': s['player'][:],
                                     'support_collider': hulk['support_collider']}
                self.revisit_authored_route = json.loads(json.dumps(interior['route']))
                self.revisit_route = [[s['player'][0], s['player'][1]+1, s['player'][2]]] + self.revisit_authored_route[1:]
                self.revisit_visited.append({'index': 0, 'frame': self.frame, 'player': s['player'][:],
                    'support_collider': hulk['support_collider'], 'speed': norm(interior['player_velocity'])})
                self.revisit_native_previous = bool(s['native_interact'])
                self.tap_key = None
                self.tap_release_frame = self.frame
                self.tap_cooldown = now + .3
                self.enter('revisit_walk', s)
            else:
                require(self.frame <= self.request_frame + 600, 'ordinary E did not finish supported new HULK exit; no retry')
        elif self.stage == 'revisit_walk':
            target = self.revisit_route[len(self.revisit_visited)]
            dx, reached = self.home_walk_to(s, target, keys, frames)
            if reached:
                self.revisit_visited.append({'index': len(self.revisit_visited), 'frame': self.frame,
                    'player': s['player'][:], 'support_collider': hulk['support_collider'],
                    'speed': norm([home['player_velocity'][0], 0, home['player_velocity'][2]])})
                if len(self.revisit_visited) == len(self.revisit_route):
                    minimum = sum(norm(sub(a, b)) for a, b in zip(self.revisit_route, self.revisit_route[1:])) - .6*(len(self.revisit_route)-1)
                    require(self.revisit_walked >= minimum, 'ordinary revisit walk covers every authored interior space')
                    self.enter('revisit_breaker_aim', s)
        elif self.stage == 'revisit_breaker_aim':
            interior = hulk['interior']
            off = sub(interior['breaker_position'], s['player'])
            off[1] = 0
            yaw = math.atan2(dot(unit(off), s['walk_right']), dot(unit(off), s['walk_forward']))
            dx = round(max(-360, min(360, yaw/initial['walk_tuning']['mouse'])))
            if abs(yaw) < .08 and norm([home['player_velocity'][0], 0, home['player_velocity'][2]]) <= .35 \
                    and interior['breaker_candidate'] and not s['native_interact']:
                self.tap('e', now)
                if self.tap_key == 'e':
                    self.revisit_press = {'frame': self.frame, 'breaker_id': interior['breaker_id'],
                        'candidate': True, 'event_before': json.loads(json.dumps(interior['breaker_event']))}
                    self.enter('revisit_breaker_press', s)
        elif self.stage == 'revisit_breaker_press':
            interior = hulk['interior']
            event, repeated = interior['breaker_event'], interior['last_breaker_result']
            before = self.revisit_press['event_before']
            require(event['count'] in (before['count'], before['count']+1), 'one ordinary new-breaker interaction only')
            dispatched = event['count'] == before['count']+1
            if dispatched:
                require(self.revisit_press['frame'] <= event['frame'] <= self.frame
                        and event['breaker_id'] == self.revisit_ids[2] and event['actor_id'] == s['player_id'],
                        'fresh public breaker event belongs to new breaker and same Player after ordinary E')
                if any(e['pressed'] and e['frame'] > self.revisit_press['frame'] for e in self.revisit_native_edges) \
                        and not s['native_interact'] and self.tap_key is None:
                    require(not repeated.get('accepted') and repeated.get('reason') == 'power_already_restored',
                            'fresh ordinary new-breaker E refuses duplicate cell')
                    self.enter('complete', s)
                    self.result = {'scope': 'Torrent full home prefix and ordinary new-generation HULK revisit',
                        'completion_marker': self.MARKER, 'home': self.home_result,
                        'clearance': self.revisit_clearance, 'boarding_press': self.revisit_board_press,
                        'boarded': self.revisit_boarded, 'home_departure': self.revisit_departure,
                        'departure_complete': self.revisit_departure_complete,
                        'cinder_reload': self.revisit_reload, 'outward_legs': self.revisit_legs,
                        'outward_header_crossing': self.revisit_header_crossing,
                        'arrival': self.revisit_arrival, 'exit': self.revisit_exit,
                        'authored_route': self.revisit_authored_route, 'walk_route': self.revisit_route,
                        'visited': self.revisit_visited, 'space_ids': list(self.SPACES),
                        'walked_interior_m': self.revisit_walked, 'max_step_per_physics_tick_m': self.revisit_max_step,
                        'support_colliders': sorted(self.revisit_support), 'breaker_press': self.revisit_press,
                        'breaker_event': event, 'native_interact_edges': self.revisit_native_edges,
                        'repeated_result': repeated, 'same_player_id': s['player_id'], 'same_ship_id': s['ship_id'],
                        'same_capsule_id': initial['capsule_id'], 'same_shape_id': initial['shape_id'],
                        'new_hulk_id': self.revisit_ids[0], 'new_berth_instance_id': self.revisit_ids[1],
                        'new_breaker_id': self.revisit_ids[2], 'final_reward_count': interior['reward_count'],
                        'final_generation': interior['activity']['generation'], 'reward_receipt': interior['reward_receipt'],
                        'lights': interior['lights'], 'restored_bus_lighting': True,
                        'authored_tuning': s['tuning'], 'walk_tuning': home['walk_tuning'], 'default_sampler': True,
                        'phases': self.phases, 'stages': self.stages,
                        'remaining': ['disk reload and OS interruption', 'native hardware and human review']}
            require(self.result is not None or self.frame <= self.revisit_press['frame'] + 120,
                    'ordinary new-breaker E did not dispatch duplicate refusal; no retry')
        else:
            require(False, 'known revisit stage')
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6:
                keys.add(self.tap_key)
            else:
                self.tap_key = None
                self.tap_cooldown = now + .3
                self.tap_release_frame = self.frame
        self.revisit_previous = s
        return keys, dx, dy, False


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
    require(route in ("guided", "sandbox-walk", "sandbox", "hulk-arrival", "hulk-breaker", "hulk-home", "hulk-revisit"), "known ordinary-input route")
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
                pilot = {"guided": Pilot, "sandbox-walk": SandboxWalkPilot, "sandbox": SandboxPilot, "hulk-arrival": HulkArrivalPilot, "hulk-breaker": HulkBreakerPilot, "hulk-home": HulkHomePilot, "hulk-revisit": HulkRevisitPilot}[route]()
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
            if isinstance(pilot, HulkArrivalPilot):
                result['partial_sortie']['last_state'] = pilot.last_state
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
    parser.add_argument('--route', choices=('guided', 'sandbox-walk', 'sandbox', 'hulk-arrival', 'hulk-breaker', 'hulk-home', 'hulk-revisit'), default='guided',
                        help='hulk-revisit carries the full home prefix into a new-generation HULK duplicate refusal; hulk-home carries the earned HULK cell back to a supported home exit; hulk-breaker continues HULK arrival through its breaker; hulk-arrival flies the normal Guided prelude then docks/exits at HULK; sandbox runs fleet/crash/reuse; sandbox-walk covers station traversal')
    args=parser.parse_args()
    try: binary=validate_binary(args.binary)
    except ValueError as error: parser.error(str(error))
    result=run(binary,args.output.absolute(),args.route)
    print(json.dumps(result,indent=2))
    return 0 if result['success'] and result.get('inputs_released') and result['game_reaped'] and result['xvfb_reaped'] and result['input_helper_reaped'] else 1


if __name__=='__main__': raise SystemExit(main())
