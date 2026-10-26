#!/usr/bin/env python3
"""Fly the embedded Linux game with OS XTest keys/mouse on an owned Xvfb.

Usage: run_native_sortie.py GAME.x86_64 --output NEW_RESULT_DIRECTORY
Use --route heavy-breach for physical Heavy arm, real picket kill/payment and home/next posting.
Use --route retained-heavy --retained-data FILE to load the accepted paid Heavy save and walk normally.
Use --route corrupt-retained-heavy --retained-data FILE for confirmed backup repair and cold Heavy continuation.
Use --route unsupported-save --retained-data FILE --future-artifact primary|temporary|backup
for one canonical future-envelope placement, real Save/Reset refusal and cold ordinary continuation.
Add --future-format settings --future-artifact primary with the source-produced nested fixture.
Use --route cinder-supply for the full first funded Jovian/Cinder terminal/home journey.
Use --route beacon-entry for normal Torrent departure and actual first Beacon HUD start.
Use --route beacon-settlement to continue through all four beacons and durable settlement.
Use --route beacon-home to retain payment through genuine Guided combat, home dock and usable exit.
Use --route patrol-relay-home for real pause-board relay selection, five continuous holds and home/UI exit.
Use --route race-home for genuine Guided prerequisite, same-Torrent timed race, durable payment and home/UI exit.
Use --route zenith-return-reuse for LIFE-ARM admission, real repeater hit, two strict Zenith flights and UI exit.
Use --route arrow-return-reuse for one Arrow precision hit, two home exits and normal UI quit.
Use --route torrent-return-reuse for the full Guided prefix, same-Torrent reuse and normal UI quit.
Use --route torrent-damaged-return for one real incoming hit, passive home repair and same-Torrent reuse.
Use --route torrent-arrow-handoff to add physical Arrow boarding/exit and original Torrent reclaim.
Use --route courier-withdraw-distance for actual seven-second distance withdrawal and original Guided home.
Use --route courier-withdraw-phase for a post-dispatch defender kill and real phase withdrawal through home.
Use --route courier-escape for the live first runner boundary, standdown and original Guided home.
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
Use --route crew-recovery for ordinary Jovian engineer admission, owned kill and cold helm continuation.
The default is Guided through normal HUD Exit and actual process exit zero.
No source/pack overrides. 300 seconds is the fixed whole-process sortie cap.
This establishes Linux/Xvfb OS-input behavior, not native GPU or human acceptance.
"""
import argparse
import copy
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


def observations_from_lines(lines, allowed_warnings=()):
    diagnostics = [line for line in diagnostic_lines(lines) if line not in allowed_warnings]
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


def record_terminal_game_exit(process, leg_result, log_path):
    code = process.poll()
    require(code is not None, 'game exit is recorded only after the process is terminal')
    # poll() has reaped this direct child. Retain its actual status even when a
    # later output, UI or normal-shutdown assertion rejects the run.
    leg_result.update(exit_code=code, reaped=True)
    drain_game_output(process, log_path)
    return code


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


class BeaconOutboundTiming:
    """Conservative receipt-clock qualification on the unchanged full home route."""
    LIMIT_SECONDS = 60.0

    def __init__(self, pid):
        self.pid = pid
        self.identity = self.home_identity = self.tuning = None
        self.beacon_identity = None
        self.sequence = -1
        self.start = self.stop = None
        self.input_acknowledged = False

    def report(self):
        elapsed = None if self.stop is None else self.stop['monotonic_seconds'] - self.start['monotonic_seconds']
        report = {'maximum_seconds': self.LIMIT_SECONDS,
                'clock': 'Python time.monotonic; outgoing input to raw observation receipt',
                'measurement': 'conservative observed upper bound; IPC, receipt latency and CPU/GPU stalls count',
                'paused_intervals': [], 'paused_seconds_subtracted': 0.0,
                'boost_check': 'driver-issued inputs only; no boost key issued during the leg',
                'start': self.start, 'stop': self.stop,
                'input_acknowledged': self.input_acknowledged,
                'observed_upper_bound_seconds': elapsed,
                'qualified': bool(self.input_acknowledged and elapsed is not None and elapsed <= self.LIMIT_SECONDS)}
        return json.loads(json.dumps(report))

    def check_deadline(self, now):
        if self.start is not None and self.stop is None:
            require(now - self.start['monotonic_seconds'] <= self.LIMIT_SECONDS,
                    'Beacon outbound exceeds approved 60.0-second monotonic maximum')

    @staticmethod
    def controls(s):
        require(s['piloted'] and s['seated'] and s['active_ship']
                and s['source_enabled'] and s['application_focused'] and not s['transition_busy'],
                'Beacon outbound has valid same-craft pilot controls')

    def observe(self, s, received_at):
        if self.stop is not None: return
        require(s['pid'] == self.pid and s['mode'] == 'beacon-home'
                and s['sequence'] > self.sequence, 'fresh Beacon timing sample from exact running PID')
        self.sequence = s['sequence']
        # Paused observations are intentionally sparse. Never infer an interval
        # from physics frames or subtract a pause that was not measured.
        require(not s['paused'], 'zero pauses before outbound approach')
        identity = (s['pid'], s['main_id'], s['player_id'], s['ship_id'])
        home = (s['home']['berth_id'], s['home']['berth_instance_id'], s['home']['berth_parent_id'])
        require(all(identity) and all(home) and home[0] == 'central_berth',
                'actual Torrent actors and central home berth')
        if self.identity is None:
            require(s['lease'] and s['parked_exact'], 'fresh occupied parked home berth')
            self.identity, self.home_identity = identity, home
            self.tuning = json.loads(json.dumps(s['tuning']))
        require(identity == self.identity and home == self.home_identity,
                'same PID Main Player Torrent and original home berth')
        require(s['default_sampler'] and s['tuning_unchanged'] and s['tuning'] == self.tuning,
                'unchanged default outbound sampler and authored tuning')
        require(s['phase'] not in ('FAILED', 'RECOVERING') and not s['destroyed'],
                'outbound never fails recovers or replaces destroyed craft')
        beacon = s['beacon']
        if beacon['available']:
            owner = (beacon['binding_id'], beacon['owner_id'])
            require(all(owner) and beacon['activity_id'] == BeaconEntryPilot.ACTIVITY
                    and beacon['beacon_count'] == 4, 'live production first-Beacon owner')
            if self.beacon_identity is None: self.beacon_identity = owner
            require(owner == self.beacon_identity, 'same outbound Beacon binding and owner')
        else:
            require(self.beacon_identity is None, 'outbound Beacon owner never disappears')
        if self.start is None: return
        self.controls(s)
        speed = norm(s['velocity'])
        distance = beacon['distance_m']
        physical_distance = norm(sub(s['position'], beacon['first_world']))
        if (beacon['available'] and s['lease_free'] and not s['landed']
                and math.isfinite(distance) and 0 <= distance <= 32
                and math.isfinite(physical_distance) and physical_distance <= 32
                and math.isfinite(speed) and speed <= .45):
            self.stop = {'monotonic_seconds': received_at,
                         'observation': json.loads(json.dumps(s))}
            require(self.report()['qualified'], 'Beacon outbound exceeds approved 60.0-second monotonic maximum')
        self.check_deadline(received_at)

    def send_input(self, desktop, stage, s, keys, dx, dy, fire):
        # The ordinary launch only emits W/brake/mouse. Count any other
        # non-interact output conservatively too: steering/brake can wake the
        # automatic engine before the first thrust (HeroShip predicate).
        demand = bool(set(keys) - {'e'}) or bool(dx or dy or fire)
        starting = self.start is None and s['seated'] and demand
        if starting:
            require(stage == 'launch' and s['phase'] == 'START_ENGINES'
                    and s['telemetry']['engine'] == 'OFFLINE'
                    and s['lease'] and s['parked_exact'] and not s['lease_free'] and s['landed'],
                    'first engine-demand edge at seated occupied OFFLINE home berth')
            self.controls(s)
        if (starting or self.start is not None) and self.stop is None:
            require(not set(keys) & {'Shift_L', 'Shift_R'}, 'no driver-issued outbound boost')
        if starting:
            self.start = {'observation': json.loads(json.dumps(s)),
                          'keys': sorted(keys), 'mouse': [dx, dy], 'fire': fire,
                          'monotonic_seconds': time.monotonic()}
        desktop.keys(keys)
        desktop.mouse(dx, dy, fire)
        if starting: self.input_acknowledged = True


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


class CourierPilot(Pilot):
    """Real first-dispatch courier kill, then the unchanged Guided home journey."""
    MARKER = 'NATIVE_COURIER_INTERCEPT_OK'
    CONFIG = {'escape_distance': 1400., 'dispatch_delay': 4.5,
              'distress_threshold': .82, 'escort_delay': 2.4,
              'disengage_distance': 700., 'disengage_seconds': 7.,
              'backstop_seconds': 150.}

    def __init__(self):
        super().__init__()
        self.courier_identity = None
        self.courier_clear = None
        self.last_courier = None
        self.wait_frame = None
        self.defender_id = None
        self.defender_wounds = []
        self.defender_pulse = None
        self.defender_ready_frame = None

    def defender_wait_controls(self, s, allow_fire):
        frame, health = s['frame'], s['opponent_health']
        cooldown = math.ceil(s['tuning']['cooldown'] * 60)
        dx, dy, align = self.aim(s, s['opponent'], .2)
        pulse = self.defender_pulse
        if pulse is not None:
            if s['command_fire'] and frame > pulse['frame'] and pulse['ack_frame'] is None:
                pulse['ack_frame'] = frame
            if pulse['ack_frame'] is not None and not s['command_fire'] and frame > pulse['ack_frame']:
                if pulse['release_frame'] is None:
                    pulse['release_frame'] = frame
            if frame > pulse['frame'] and math.isclose(pulse['before_health'] - health, 34., abs_tol=1e-6):
                if pulse['damage_frame'] is None:
                    pulse.update(after_health=health, damage_frame=frame)
            if all(pulse[key] is not None for key in ('ack_frame', 'release_frame', 'damage_frame')):
                self.defender_wounds.append(dict(pulse))
                self.defender_ready_frame = max(pulse['frame'] + cooldown + 6, pulse['release_frame'] + 6)
                self.defender_pulse = None
            else:
                # Stop on acknowledgement or after six physics frames. A miss
                # remains unresolved; unchanged/stale health never rearms fire.
                fire = (allow_fire and health > 34 and pulse['ack_frame'] is None
                        and frame < pulse['frame'] + 6)
                return {'Prior'}, dx, dy, fire
        expected = 85. - 34. * len(self.defender_wounds)
        if (allow_fire and len(self.defender_wounds) < 2 and health > 34
                and s['courier']['weapon_ready'] is True
                and math.isclose(health, expected, abs_tol=1e-6)
                and frame >= self.defender_ready_frame and not s['command_fire'] and align >= .997):
            self.defender_pulse = {'frame': frame, 'before_health': health, 'after_health': None,
                                   'source_entity_id': s['ship_id'], 'target_id': s['opponent_id'],
                                   'ack_frame': None, 'release_frame': None, 'damage_frame': None}
            return {'Prior'}, dx, dy, True
        return {'Prior'}, dx, dy, False

    def damage_receipt(self, receipt, s, killed=False):
        c = s['courier']
        require(bool(receipt), 'courier-specific resolved player damage receipt')
        require(receipt['source_entity_id'] == s['ship_id']
                and receipt['target_id'] == c['actor_id']
                and receipt['scenario_generation'] == c['generation'],
                'actual source ship, courier target and scenario generation')
        require(receipt['accepted'] is True and receipt['resolved'] is True
                and receipt['sequence'] >= 0 and math.isfinite(receipt['applied_damage'])
                and receipt['applied_damage'] > 0
                and math.isfinite(receipt['remaining_health'])
                and math.isfinite(receipt['escape_progress'])
                and 0 <= receipt['escape_progress'] < 1
                and self.wait_frame <= receipt['frame'] <= s['frame'],
                'positive actual courier damage before escape during this sortie')
        if killed:
            require(receipt['destroyed'] is True and receipt['remaining_health'] <= 0,
                    'resolved player shot actually destroyed courier')

    def update(self, s, now):
        self.last_courier = s['courier']
        # Base handles all actor/control invariants and the original journey.
        previous_stage = self.stage
        controls = super().update(s, now)
        if previous_stage == 'range' and self.stage == 'interceptor':
            self.wait_frame = s['frame']
            require(s['opponent_id'] > 0 and math.isclose(s['opponent_health'], 85., abs_tol=1e-6),
                    'actual initial defender identity and authored hull before nonlethal pulses')
            self.defender_id = s['opponent_id']
            self.defender_ready_frame = s['frame'] + math.ceil(s['tuning']['cooldown'] * 60) + 6
            self.enter('courier_wait', s)
            return {'Prior'}, 0, 0, False
        if self.stage in ('courier_wait', 'courier_attack'):
            c = s['courier']
            require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active'],
                    'initial defender remains alive until courier clear')
            require(s['opponent_id'] == self.defender_id and self.defender_id > 0
                    and math.isfinite(s['opponent_health']) and s['opponent_health'] > 0
                    and s['telemetry']['hull'] > 0, 'same live defender and positive player hull')
            require(all(math.isfinite(c[k]) and math.isclose(c[k], v, rel_tol=1e-6, abs_tol=1e-6)
                        for k, v in self.CONFIG.items()), 'original encounter configuration')
            if self.stage == 'courier_wait':
                require(c['outcome'] == 'pending', 'no terminal outcome before ordinary courier dispatch')
                wait_controls = self.defender_wait_controls(s, c['state'] != 'running')
                if c['state'] != 'running':
                    require(c['state'] in ('idle', 'arming'), 'ordinary courier arming state')
                    return wait_controls
                require(len(self.defender_wounds) == 2 and self.defender_pulse is None
                        and math.isclose(s['opponent_health'], 17., abs_tol=1e-6) and not s['command_fire'],
                        'two observed nonlethal defender wounds and released fire before courier dispatch')
                require(c['scenario'] == 'courier_intercept' and c['active']
                        and c['seen_alive'] and c['health'] > 0
                        and c['actor_id'] > 0 and c['director_id'] > 0,
                        'actual live first courier dispatch')
                self.courier_identity = (c['director_id'], c['actor_id'], c['generation'])
                self.enter('courier_attack', s)
            require(self.courier_identity == (c['director_id'], c['actor_id'], c['generation'])
                    and c['scenario'] == 'courier_intercept' and c['seen_alive'],
                    'same observed courier and dispatch throughout intercept')
            require(c['outcome'] in ('pending', 'cleared'), 'courier did not escape, withdraw, expire or abort')
            require(math.isfinite(c['escape_progress']) and 0 <= c['escape_progress'] < 1,
                    'courier intercepted before escape boundary')
            if c['outcome'] == 'cleared':
                require(c['state'] == 'concluded' and not c['active'], 'director concluded courier clear')
                self.damage_receipt(c['hit'], s)
                self.damage_receipt(c['kill'], s, killed=True)
                require(c['hit']['sequence'] <= c['kill']['sequence'], 'ordered courier damage and kill')
                self.courier_clear = dict(c)
                self.enter('interceptor', s)
                return {'Prior'}, 0, 0, False
            require(c['state'] == 'running', 'pending courier remains in running scenario')
            # A destroyed actor may stand down one physics step before the
            # director observes it. Wait for CLEARED; disappearance alone fails.
            if not c['active']:
                self.damage_receipt(c['kill'], s, killed=True)
                return {'Prior'}, 0, 0, False
            require(c['health'] > 0, 'live courier has positive hull')
            dx, dy, align = self.aim(s, c['position'], .2)
            distance = norm(sub(c['position'], s['position']))
            keys = set()
            if align > .9 and distance > 160:
                keys.update(('w', 'Shift_L'))
            else:
                keys.add('Prior')
            return keys, dx, dy, align >= .997
        if self.result is not None:
            require(self.courier_clear is not None, 'courier clear precedes complete home journey')
            self.result.update(completion_marker=self.MARKER, courier=self.courier_clear,
                               defender_wounds=[dict(wound) for wound in self.defender_wounds])
        return controls


class CourierEscapePilot(CourierPilot):
    """Let the actual first runner escape, observe standdown, then fly home."""
    MARKER = 'NATIVE_COURIER_ESCAPE_OK'
    STANDDOWN_FRAMES = 60

    def __init__(self):
        super().__init__()
        self.courier_escape = None
        self.dispatched_ids = set()
        self.escape_origin = None
        self.running_frame = None
        self.standdown_until_frame = None
        self.defender_misses = []
        self.defender_miss_sequence = -1
        self.saved_attack_position = None
        self.initial_wait_waypoint = None
        self.scenario_origin = None
        self.wait_waypoints = []
        self.wait_waypoint_index = 0
        self.wait_visited = []
        self.attack_return_waypoints = []
        self.attack_return_index = 0
        self.attack_return_visited = []
        self.wait_braking = False
        self.maximum_wait_radius = 0.
        self.courier_launch_health = None

    def waiting_flight_report(self):
        return dict(saved_attack_position=self.saved_attack_position,
                    initial_waypoint=self.initial_wait_waypoint, scenario_origin=self.scenario_origin,
                    wait_waypoints=self.wait_waypoints, wait_waypoint_index=self.wait_waypoint_index,
                    wait_visited=self.wait_visited, return_waypoints=self.attack_return_waypoints,
                    return_visited=self.attack_return_visited, maximum_radius_m=self.maximum_wait_radius)

    def require_wait_radius(self, position, origin):
        distance = norm(sub(position, origin))
        require(math.isfinite(distance) and distance <= 450.,
                'ordinary Courier Escape waiting flight stays within 450m of its frozen origin')
        return distance

    def wait_flight_controls(self, s, waypoint):
        # The existing ordinary waypoint controller: mouse steering, normal W
        # and braking. Waypoints are never moved to rescue an unsuccessful leg.
        require(not s['command_fire'], 'released ordinary fire throughout Courier Escape waiting flight')
        off = sub(waypoint, s['position'])
        distance, speed = norm(off), norm(s['velocity'])
        if distance <= 1 and speed <= .45:
            return ({'Prior'}, 0, 0, False), True
        dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
        stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
        if distance < stopping+1.75: self.wait_braking = True
        if speed <= .45 and distance > 1: self.wait_braking = False
        keys = set()
        if distance <= 1 or self.wait_braking: keys.add('Prior')
        elif align > .72: keys.add('w')
        return (keys, dx, dy, False), distance <= 1 and speed <= .45

    def advance_wait_flight(self, s):
        index = min(self.wait_waypoint_index, len(self.wait_waypoints)-1)
        controls, reached = self.wait_flight_controls(s, self.wait_waypoints[index])
        if reached and self.wait_waypoint_index < len(self.wait_waypoints):
            self.wait_visited.append(dict(index=index, frame=s['frame'], position=s['position'][:]))
            self.wait_waypoint_index += 1
            self.wait_braking = False
        return controls

    def defender_wait_controls(self, s, allow_fire):
        pulse = self.defender_pulse
        shot = json.loads(json.dumps(s['courier'].get('prep_shot', {})))
        request = shot.get('request', {})
        if pulse is not None:
            pulse['last_observed_shot'] = shot
            baseline = pulse['prepress_shot'].get('request', {})
            sequence = request.get('sequence')
            if (pulse['resolved_shot'] is None and s['frame'] > pulse['frame']
                    and type(sequence) is int and sequence > 0
                    and type(baseline.get('sequence')) is int
                    and sequence > baseline['sequence']
                    and pulse['prepress_shot'].get('present') is True
                    and pulse['prepress_shot'].get('source_id') == 1101
                    and pulse['prepress_shot'].get('source_entity_id') == s['ship_id']
                    and baseline.get('source_id') == 1101
                    and baseline.get('source_entity_id') == s['ship_id']):
                pulse['resolved_shot'] = shot
                pulse['result_frame'] = s['frame']
        controls = super().defender_wait_controls(s, allow_fire)
        if pulse is None and self.defender_pulse is not None:
            self.defender_pulse.update(prepress_shot=shot, resolved_shot=None,
                                       result_frame=None, last_observed_shot=shot)
        elif pulse is not None and self.defender_pulse is pulse:
            result = pulse['resolved_shot'] or {}
            resolved_request = result.get('request', {})
            sequence = resolved_request.get('sequence', -1)
            damage = result.get('applied_damage')
            if (pulse['ack_frame'] is not None and pulse['release_frame'] is not None
                    and pulse['result_frame'] is not None
                    and pulse['result_frame'] >= pulse['ack_frame']
                    and result.get('present') is True
                    and result.get('accepted') is True and result.get('resolved') is True
                    and result.get('status') == 'miss' and result.get('hit') is False
                    and result.get('damaged') is False and result.get('destroyed') is False
                    and result.get('source_id') == resolved_request.get('source_id') == 1101
                    and result.get('source_entity_id') == resolved_request.get('source_entity_id') == s['ship_id']
                    and resolved_request.get('weapon_id') == 'torrent_compact_pulse_cannon'
                    and type(sequence) is int and sequence > self.defender_miss_sequence
                    and result.get('target_entity_id') == 0 and result.get('damageable_id') == 0
                    and result.get('collider_id') == 0
                    and type(damage) in (int, float) and math.isfinite(damage) and damage == 0
                    and pulse['damage_frame'] is None
                    and math.isclose(s['opponent_health'], pulse['before_health'], abs_tol=1e-6)):
                self.defender_misses.append(json.loads(json.dumps(pulse)))
                self.defender_miss_sequence = sequence
                cooldown = math.ceil(s['tuning']['cooldown'] * 60)
                self.defender_ready_frame = max(pulse['frame'] + cooldown + 6,
                                                pulse['release_frame'] + 6)
                self.defender_pulse = None
        return controls

    def check_standdown(self, c, s):
        terminal = c['terminal']
        require(terminal and self.wait_frame < terminal['frame'] <= s['frame'],
                'actual observed terminal frame after ordinary dispatch')
        require((terminal['director_id'], terminal['actor_id'], terminal['generation']) == self.courier_identity,
                'terminal belongs to the same original runner and dispatch')
        require(terminal['escape_origin'] == self.escape_origin,
                'terminal retains original runner launch origin')
        distance = norm(sub(terminal['position'], terminal['escape_origin']))
        require(math.isfinite(distance) and distance >= self.CONFIG['escape_distance']
                and terminal['escape_progress'] == 1
                and math.isfinite(terminal['health']) and terminal['health'] == self.courier_launch_health,
                'same live runner physically reached original boundary with positive hull')
        require(c['state'] == 'concluded' and c['outcome'] == 'escaped' and not c['active']
                and math.isfinite(c['health']) and c['health'] > 0
                and not c['roster_ids'] and not c['standdown_violation'],
                'escaped director retains total standdown without transient violations')
        self.check_actor_standdown(c, terminal)
        if self.courier_escape is not None:
            require(terminal == self.courier_escape['terminal'], 'original terminal witness never changes')

    def check_actor_standdown(self, c, terminal):
        baseline = {a['id']: a for a in terminal['actors']}
        actors = {a['id']: a for a in c['actors']}
        require(len(baseline) == len(terminal['actors']) and set(baseline) == set(actors) == self.dispatched_ids,
                'every actually dispatched actor retained through terminal and home')
        for actor_id, actor in actors.items():
            original = baseline[actor_id]
            require(original['present'] is True and original['active'] is False
                    and original['fire_authorized'] is False and original['pending_receipts'] == 0,
                    'all dispatched actors stood down at the actual terminal frame')
            require(actor['present'] is True and actor['active'] is False
                    and actor['fire_authorized'] is False and actor['pending_receipts'] == 0
                    and actor['shots_fired'] == baseline[actor_id]['shots_fired'],
                    'all dispatched actors remain inactive unauthorized and fire no further shots')

    def update(self, s, now):
        c = self.last_courier = s['courier']
        previous_stage = self.stage
        controls = Pilot.update(self, s, now)
        if previous_stage == 'range' and self.stage == 'interceptor':
            self.wait_frame = s['frame']
            require(s['opponent_id'] > 0 and math.isclose(s['opponent_health'], 85., abs_tol=1e-6),
                    'actual initial defender identity and authored hull before nonlethal pulses')
            self.defender_id = s['opponent_id']
            self.defender_ready_frame = s['frame'] + math.ceil(s['tuning']['cooldown'] * 60) + 6
            self.enter('courier_wait', s)
            return {'Prior'}, 0, 0, False
        if self.wait_frame is None:
            return controls
        require(all(math.isfinite(c[k]) and math.isclose(c[k], v, rel_tol=1e-6, abs_tol=1e-6)
                    for k, v in self.CONFIG.items()), 'original encounter configuration')
        require(s['opponent_id'] == self.defender_id, 'same original defender throughout escape and home')
        if (self.stage in ('courier_wait', 'courier_escape_wait', 'courier_standdown',
                           'courier_return_attack', 'interceptor')
                and s['opponent_health'] > 0):
            require(c.get('weapon_status', {}).get('reason') != 'weapon_component_failed',
                    'authoritative weapon_component_failed with original defender alive; '
                    'Courier Escape caller has no weapon recovery route')
        if self.scenario_origin is not None:
            self.maximum_wait_radius = max(self.maximum_wait_radius,
                                          self.require_wait_radius(s['position'], self.scenario_origin))
        if self.saved_attack_position is not None and self.stage in (
                'courier_wait', 'courier_escape_wait', 'courier_standdown', 'courier_return_attack'):
            if self.scenario_origin is None:
                self.maximum_wait_radius = max(self.maximum_wait_radius,
                                              self.require_wait_radius(s['position'], self.saved_attack_position))
            require(math.isclose(s['opponent_health'], 17., abs_tol=1e-6),
                    'the original twice-wounded defender stays at 17 hull during ordinary waiting and return flight')
        if self.stage in ('courier_wait', 'courier_escape_wait', 'courier_standdown', 'courier_return_attack'):
            require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                    and math.isfinite(s['opponent_health']) and s['opponent_health'] > 0
                    and s['telemetry']['hull'] > 0, 'original defender and player remain alive through escape standdown')
        if self.stage == 'courier_wait':
            require(c['outcome'] == 'pending', 'no premature terminal before first live courier dispatch')
            wait_controls = self.defender_wait_controls(s, c['state'] != 'running')
            if len(self.defender_wounds) == 2 and self.defender_pulse is None and not s['command_fire']:
                if self.saved_attack_position is None:
                    self.saved_attack_position = s['position'][:]
                    self.initial_wait_waypoint = [self.saved_attack_position[i]+v
                                                  for i, v in enumerate((-220., 180., -220.))]
                    self.require_wait_radius(self.initial_wait_waypoint, self.saved_attack_position)
                wait_controls, _ = self.wait_flight_controls(s, self.initial_wait_waypoint)
            if c['state'] != 'running':
                require(c['state'] in ('idle', 'arming'), 'ordinary courier arming state')
                return wait_controls
            require(len(self.defender_wounds) == 2 and self.defender_pulse is None
                    and math.isclose(s['opponent_health'], 17., abs_tol=1e-6) and not s['command_fire'],
                    'two observed nonlethal defender wounds and released fire before courier dispatch')
            require(c['scenario'] == 'courier_intercept' and c['generation'] == 1
                    and c['director_id'] > 0 and c['actor_id'] > 0
                    and c['active'] and c['seen_alive'] and c['health'] > 0
                    and not c['terminal'], 'actual live first courier dispatch before any terminal')
            self.courier_identity = (c['director_id'], c['actor_id'], c['generation'])
            self.escape_origin = list(c['escape_origin'])
            self.scenario_origin = list(c['scenario_origin'])
            self.courier_launch_health = c['health']
            self.wait_waypoints = [[self.scenario_origin[i]+offset[i] for i in range(3)]
                                   for offset in ((-220., 180., -220.), (220., 180., -220.),
                                                  (220., 180., 220.), (-220., 180., 220.))]
            self.attack_return_waypoints = [[self.saved_attack_position[i]+v
                                             for i, v in enumerate((0., 180., 0.))],
                                            self.saved_attack_position[:]]
            for point in [s['position'], self.initial_wait_waypoint] + self.wait_waypoints + self.attack_return_waypoints:
                self.require_wait_radius(point, self.scenario_origin)
            self.wait_braking = False
            self.running_frame = s['frame']
            self.enter('courier_escape_wait', s)
        if self.courier_identity is not None:
            require(self.courier_identity == (c['director_id'], c['actor_id'], c['generation'])
                    and c['scenario'] == 'courier_intercept' and c['seen_alive']
                    and c['escape_origin'] == self.escape_origin and c['scenario_origin'] == self.scenario_origin,
                    'same original courier director generation and launch origin throughout home')
            require(math.isfinite(c['health']) and c['health'] == self.courier_launch_health == c['maximum_health']
                    and not c['hit'] and not c['kill'], 'the first escaping courier remains entirely unhurt')
            actor_ids = [a['id'] for a in c['actors']]
            require(len(set(actor_ids)) == len(actor_ids) and self.dispatched_ids <= set(actor_ids)
                    and c['actor_id'] in actor_ids and set(c['roster_ids']) <= set(actor_ids),
                    'actual dispatched roster includes original courier without loss or duplicates')
            if self.courier_escape is None:
                self.dispatched_ids.update(actor_ids)
        if self.stage == 'courier_escape_wait':
            require(math.isfinite(c['health']) and c['health'] > 0, 'live escaping runner has positive hull')
            if c['outcome'] == 'pending':
                require(c['state'] == 'running' and c['active'] and not c['terminal']
                        and math.isfinite(c['escape_progress']) and 0 <= c['escape_progress'] <= 1,
                        'same live courier remains in ordinary running scenario until escape')
                return self.advance_wait_flight(s)
            require(c['outcome'] == 'escaped' and s['frame'] > self.running_frame,
                    'only subsequent actual escape can conclude this route')
            self.check_standdown(c, s)
            self.courier_escape = json.loads(json.dumps(c))
            self.standdown_until_frame = c['terminal']['frame'] + self.STANDDOWN_FRAMES
            self.enter('courier_standdown', s)
        if self.courier_escape is not None:
            self.check_standdown(c, s)
        if self.stage == 'courier_standdown':
            if s['frame'] >= self.standdown_until_frame:
                self.wait_braking = False
                self.enter('courier_return_attack', s)
            else:
                return self.advance_wait_flight(s)
        if self.stage == 'courier_return_attack':
            controls, reached = self.wait_flight_controls(s, self.attack_return_waypoints[self.attack_return_index])
            if reached:
                self.attack_return_visited.append(dict(index=self.attack_return_index, frame=s['frame'],
                                                      position=s['position'][:], speed_m_s=norm(s['velocity'])))
                self.attack_return_index += 1
                self.wait_braking = False
                if self.attack_return_index == len(self.attack_return_waypoints):
                    self.enter('interceptor', s)
            return controls
        if self.result is not None:
            require(self.courier_escape is not None and s['frame'] >= self.standdown_until_frame,
                    'actual escape and sustained standdown precede complete home journey')
            self.result.update(completion_marker=self.MARKER, courier=self.courier_escape,
                               courier_home=c, defender_wounds=self.defender_wounds,
                               defender_misses=self.defender_misses,
                               waiting_flight=self.waiting_flight_report(),
                               standdown_observed_frames=s['frame'] - c['terminal']['frame'])
        return controls


class CourierWithdrawPhasePilot(CourierEscapePilot):
    """Kill the original defender after first dispatch, then observe phase withdrawal."""
    MARKER = 'NATIVE_COURIER_WITHDRAW_PHASE_OK'

    def __init__(self):
        super().__init__()
        self.dispatch = None
        self.defender_kill = None
        self.courier_withdrawal = None
        self.dispatch_sequence = None
        self.final_fire_frame = None
        self.withdraw_context = None

    def check_defender_kill(self, receipt, s):
        request = receipt.get('request', {})
        require(self.final_fire_frame is not None
                and self.running_frame < self.final_fire_frame < receipt.get('frame', -1) <= s['frame']
                and type(request.get('sequence')) is int
                and request['sequence'] > self.dispatch_sequence
                and receipt.get('last_sequence') == request['sequence'],
                'fresh authoritative defender kill follows observed first dispatch and ordinary fire')
        require(receipt.get('present') is True and receipt.get('accepted') is True
                and receipt.get('resolved') is True and receipt.get('hit') is True
                and receipt.get('damaged') is True and receipt.get('destroyed') is True
                and receipt.get('status') == 'destroyed'
                and receipt.get('source_id') == request.get('source_id') == 1101
                and receipt.get('source_entity_id') == request.get('source_entity_id') == s['ship_id']
                and request.get('weapon_id') == 'torrent_compact_pulse_cannon'
                and receipt.get('target_entity_id') == self.defender_id
                and receipt.get('damageable_id', 0) > 0 and receipt.get('collider_id', 0) > 0
                and receipt.get('command_fire') is True
                and math.isfinite(receipt.get('applied_damage', float('nan')))
                and receipt['applied_damage'] > 0
                and math.isfinite(receipt.get('remaining_health', float('nan')))
                and receipt['remaining_health'] <= 0,
                'actual original defender destroyed by authoritative ordinary Torrent FIRE receipt')
        require((receipt.get('main_id'), receipt.get('authority_id')) == self.withdraw_context
                and (receipt.get('director_id'), receipt.get('actor_id'), receipt.get('generation')) == self.courier_identity
                and receipt.get('phase') == 'RETURN_TO_YARD'
                and receipt.get('state') == 'running' and receipt.get('outcome') == 'pending'
                and receipt.get('courier_active') is True
                and receipt.get('courier_health') == receipt.get('courier_maximum_health') == self.courier_launch_health
                and math.isfinite(receipt.get('escape_progress', float('nan')))
                and 0 <= receipt['escape_progress'] < 1
                and receipt.get('scenario_origin') == self.scenario_origin,
                'same live unhurt first runner before escape at normal defender-kill return transition')
        self.require_wait_radius(receipt['ship_position'], self.scenario_origin)
        require(not s['opponent_active'] and s['opponent_health'] <= 0
                and s['phase'] in ('RETURN_TO_YARD', 'SHUT_DOWN', 'DISEMBARKING', 'COMPLETE'),
                'actual original defender death retains the normal Guided return and home phases')
        if self.defender_kill is not None:
            require(receipt == self.defender_kill, 'original authoritative defender kill witness never changes')

    def check_standdown(self, c, s):
        terminal = c['terminal']
        require(self.defender_kill is not None and terminal
                and self.defender_kill['frame'] <= terminal['frame'] <= s['frame']
                and terminal['frame'] > self.running_frame,
                'actual withdrawal terminal follows the fresh post-dispatch defender kill')
        require((terminal['director_id'], terminal['actor_id'], terminal['generation']) == self.courier_identity
                and terminal['escape_origin'] == self.escape_origin
                and terminal['scenario_origin'] == self.scenario_origin
                and terminal['phase'] == 'RETURN_TO_YARD' and terminal['outcome'] == 'withdrawn'
                and terminal['health'] == self.courier_launch_health
                and math.isfinite(terminal['escape_progress']) and 0 <= terminal['escape_progress'] < 1,
                'same unhurt first runner withdrawn by normal RETURN_TO_YARD before escape')
        self.require_wait_radius(terminal['ship_position'], self.scenario_origin)
        require(c['state'] == 'concluded' and c['outcome'] == 'withdrawn' and not c['active']
                and not c['roster_ids'] and not c['standdown_violation'],
                'phase-withdrawn director retains total standdown without transient violations')
        baseline = {a['id']: a for a in terminal['actors']}
        actors = {a['id']: a for a in c['actors']}
        require(len(baseline) == len(terminal['actors']) and set(baseline) == set(actors) == self.dispatched_ids,
                'every actually dispatched actor retained through phase withdrawal and home')
        for actor_id, actor in actors.items():
            original = baseline[actor_id]
            require(original['present'] is True and original['active'] is False
                    and original['fire_authorized'] is False and original['pending_receipts'] == 0,
                    'all dispatched actors stood down at the actual withdrawal frame')
            require(actor['present'] is True and actor['active'] is False
                    and actor['fire_authorized'] is False and actor['pending_receipts'] == 0
                    and actor['shots_fired'] == original['shots_fired'],
                    'all dispatched actors remain inactive unauthorized and fire no further shots')
        if self.courier_withdrawal is not None:
            require(terminal == self.courier_withdrawal['terminal'], 'original withdrawal terminal witness never changes')

    def update(self, s, now):
        c = self.last_courier = s['courier']
        if s['phase'] == 'COMPLETE':
            require(self.courier_withdrawal is not None and s['frame'] >= self.standdown_until_frame
                    and s['telemetry']['engine'] == 'OFFLINE',
                    'actual phase withdrawal sustained standdown and OFFLINE precede complete strict home journey')
        previous_stage = self.stage
        controls = Pilot.update(self, s, now)
        if previous_stage == 'range' and self.stage == 'interceptor':
            require(s['destroyed_targets'] == 4 and s['opponent_id'] > 0
                    and math.isclose(s['opponent_health'], 85., abs_tol=1e-6),
                    'four actual range kills and original live defender before ordinary preparation')
            self.wait_frame = s['frame']
            self.defender_id = s['opponent_id']
            self.defender_ready_frame = s['frame'] + math.ceil(s['tuning']['cooldown'] * 60) + 6
            self.enter('courier_wait', s)
            return {'Prior'}, 0, 0, False
        if self.wait_frame is None:
            return controls
        require(all(math.isfinite(c[k]) and math.isclose(c[k], v, rel_tol=1e-6, abs_tol=1e-6)
                    for k, v in self.CONFIG.items()), 'original encounter configuration')
        require(s['opponent_id'] == self.defender_id and s['telemetry']['hull'] > 0,
                'same original defender and positive player hull throughout withdrawal and home')
        if self.stage == 'courier_wait':
            require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                    and s['opponent_health'] > 0 and c['outcome'] == 'pending'
                    and not c.get('defender_kill'),
                    'original defender stays alive before first ordinary live dispatch')
            require(c.get('weapon_status', {}).get('reason') != 'weapon_component_failed',
                    'authoritative weapon_component_failed; phase withdrawal has no weapon recovery route')
            wait_controls = self.defender_wait_controls(s, c['state'] != 'running')
            if c['state'] != 'running':
                require(c['state'] in ('idle', 'arming') and c['generation'] == 0,
                        'ordinary first-generation courier arming')
                return wait_controls
            require(len(self.defender_wounds) == 2 and self.defender_pulse is None
                    and math.isclose(s['opponent_health'], 17., abs_tol=1e-6) and not s['command_fire'],
                    'two ordinary nonlethal defender wounds and released fire before first dispatch')
            require(c['scenario'] == 'courier_intercept' and c['generation'] == 1
                    and c['active'] and c['seen_alive'] and c['health'] == c['maximum_health'] > 0
                    and c['director_id'] > 0 and c['actor_id'] > 0 and not c['terminal']
                    and math.isfinite(c['escape_progress']) and 0 <= c['escape_progress'] < 1,
                    'actual live unhurt first courier dispatch before any terminal')
            baseline = c.get('prep_shot', {})
            request = baseline.get('request', {})
            require(baseline.get('present') is True and baseline.get('accepted') is True
                    and baseline.get('resolved') is True
                    and baseline.get('source_id') == request.get('source_id') == 1101
                    and baseline.get('source_entity_id') == request.get('source_entity_id') == s['ship_id']
                    and type(request.get('sequence')) is int and request['sequence'] > 0,
                    'actual authoritative pre-attack player shot sequence at first dispatch')
            self.dispatch_sequence = request['sequence']
            self.courier_identity = (c['director_id'], c['actor_id'], c['generation'])
            self.withdraw_context = (c['main_id'], c['authority_id'])
            require(all(value > 0 for value in self.withdraw_context), 'actual current Main and combat authority identities')
            self.escape_origin, self.scenario_origin = list(c['escape_origin']), list(c['scenario_origin'])
            self.courier_launch_health = c['health']
            self.running_frame = s['frame']
            self.dispatch = json.loads(json.dumps(s))
            self.enter('courier_withdraw_attack', s)
            controls = ({'Prior'}, 0, 0, False)
        require(self.courier_identity == (c['director_id'], c['actor_id'], c['generation'])
                and self.withdraw_context == (c['main_id'], c['authority_id'])
                and c['scenario'] == 'courier_intercept' and c['seen_alive']
                and c['escape_origin'] == self.escape_origin and c['scenario_origin'] == self.scenario_origin,
                'same original courier current Main authority generation and origins through home')
        require(math.isfinite(c['health']) and c['health'] == c['maximum_health'] == self.courier_launch_health
                and not c['hit'] and not c['kill']
                and math.isfinite(c['escape_progress']) and 0 <= c['escape_progress'] < 1,
                'original phase-withdrawn runner remains entirely unhurt and never escapes')
        self.maximum_wait_radius = max(self.maximum_wait_radius,
                                      self.require_wait_radius(s['position'], self.scenario_origin))
        require(math.isfinite(c['maximum_withdraw_radius']) and 0 <= c['maximum_withdraw_radius'] <= 450.,
                'every physics frame stays within 450m of actual scenario origin; no distance withdrawal')
        self.maximum_wait_radius = max(self.maximum_wait_radius, c['maximum_withdraw_radius'])
        actor_ids = [a['id'] for a in c['actors']]
        require(len(set(actor_ids)) == len(actor_ids) and self.dispatched_ids <= set(actor_ids)
                and c['actor_id'] in actor_ids and set(c['roster_ids']) <= set(actor_ids),
                'actual dispatched roster includes original courier without loss or duplicates')
        if self.courier_withdrawal is None:
            self.dispatched_ids.update(actor_ids)
        if c['defender_kill']:
            self.check_defender_kill(c['defender_kill'], s)
            if self.defender_kill is None:
                self.defender_kill = json.loads(json.dumps(c['defender_kill']))
        if self.stage == 'courier_withdraw_attack':
            if self.defender_kill is None:
                require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                        and math.isclose(s['opponent_health'], 17., abs_tol=1e-6)
                        and c['state'] == 'running' and c['outcome'] == 'pending' and c['active']
                        and not c['terminal'], 'original defender alive until fresh authoritative kill before withdrawal')
                require(c.get('weapon_status', {}).get('reason') != 'weapon_component_failed',
                        'authoritative weapon_component_failed; phase withdrawal has no weapon recovery route')
                if s['frame'] == self.running_frame:
                    return controls
                dx, dy, align = self.aim(s, s['opponent'], .2)
                fire = align >= .997 and c['weapon_ready'] is True
                if fire and self.final_fire_frame is None:
                    self.final_fire_frame = s['frame']
                return {'Prior'}, dx, dy, fire
            if c['outcome'] == 'pending':
                require(c['state'] == 'running' and c['active'] and not c['terminal']
                        and s['phase'] == 'RETURN_TO_YARD', 'await ordinary director phase withdrawal after actual kill')
                return {'Prior'}, 0, 0, False
            self.check_standdown(c, s)
            self.courier_withdrawal = json.loads(json.dumps(c))
            self.standdown_until_frame = c['terminal']['frame'] + self.STANDDOWN_FRAMES
            self.enter('courier_withdraw_standdown', s)
        if self.courier_withdrawal is not None:
            require(c['defender_kill'] == self.defender_kill, 'retained actual defender kill through home')
            self.check_standdown(c, s)
        if self.stage == 'courier_withdraw_standdown':
            if s['frame'] >= self.standdown_until_frame:
                self.enter('return_align', s)
            return {'Prior'}, 0, 0, False
        if self.result is not None:
            require(self.courier_withdrawal is not None and s['frame'] >= self.standdown_until_frame
                    and s['telemetry']['engine'] == 'OFFLINE',
                    'actual phase withdrawal sustained standdown and OFFLINE precede complete strict home journey')
            self.result.update(completion_marker=self.MARKER, courier_dispatch=self.dispatch,
                               defender_kill=self.defender_kill, courier=self.courier_withdrawal,
                               courier_home=c, defender_wounds=self.defender_wounds,
                               defender_misses=self.defender_misses, maximum_withdraw_radius_m=self.maximum_wait_radius,
                               standdown_observed_frames=s['frame'] - c['terminal']['frame'])
        return controls


class CourierWithdrawDistancePilot(CourierEscapePilot):
    """Ordinary departure beyond every live contact; actual grace, then return."""
    MARKER = 'NATIVE_COURIER_WITHDRAW_DISTANCE_OK'

    def __init__(self):
        super().__init__()
        self.dispatch = None
        self.courier_withdrawal = None
        self.escape_heading = None
        self.withdraw_waypoint = None
        self.withdraw_context = None
        self.defender_kill = None
        self.final_fire_frame = None
        self.dispatch_sequence = None

    @staticmethod
    def distance_waypoint(origin, heading):
        require(len(heading) == 3 and all(math.isfinite(v) for v in heading)
                and math.isclose(norm(heading), 1., abs_tol=1e-5), 'actual unit courier launch heading')
        axis = [0., 1., 0.] if abs(heading[1]) < .95 else [1., 0., 0.]
        direction = unit([axis[i]-dot(axis, heading)*heading[i] for i in range(3)])
        return [origin[i]+900.*direction[i] for i in range(3)]

    def check_distance_geometry(self, witness):
        require(witness['scenario_origin'] == self.scenario_origin
                and norm(sub(witness['ship_position'], self.scenario_origin)) > self.CONFIG['disengage_distance'],
                'actual ship beyond 700m from frozen director origin')
        actors = {a['id']: a for a in witness['actors']}
        roster = witness['roster_ids']
        require(roster and len(set(roster)) == len(roster) and set(roster) <= set(actors)
                and self.courier_identity[1] in roster, 'actual complete live roster before withdrawal')
        for actor_id in roster:
            actor = actors[actor_id]
            require(actor['present'] is True, 'every actual roster craft remains present')
            if actor['active']:
                require(norm(sub(witness['ship_position'], actor['position'])) > self.CONFIG['disengage_distance'],
                        'actual ship beyond 700m from every active roster craft')

    def check_standdown(self, c, s):
        terminal = c['terminal']
        require(terminal and self.running_frame < terminal['frame'] <= s['frame']
                and (terminal['director_id'], terminal['actor_id'], terminal['generation']) == self.courier_identity
                and terminal['escape_origin'] == self.escape_origin
                and terminal['scenario_origin'] == self.scenario_origin
                and terminal['phase'] == 'INTERCEPTOR_ENGAGEMENT' and terminal['outcome'] == 'withdrawn'
                and terminal['defender_active'] is True and terminal['defender_health'] == 17.
                and terminal['health'] == self.courier_launch_health
                and math.isfinite(terminal['escape_progress']) and 0 <= terminal['escape_progress'] < 1,
                'same unhurt first runner actually withdraws while original engagement remains authorized')
        pending = terminal['pending']
        grace, previous = terminal['disengaged_elapsed'], pending['disengaged_elapsed']
        require(math.isfinite(grace) and math.isfinite(previous)
                and self.CONFIG['disengage_seconds'] <= grace <= self.CONFIG['disengage_seconds']+1/60+1e-5
                and grace-1/60-1e-5 <= previous < self.CONFIG['disengage_seconds']
                and pending['frame'] == terminal['frame']-1
                and pending['phase'] == 'INTERCEPTOR_ENGAGEMENT'
                and pending['state'] == 'running' and pending['outcome'] == 'pending'
                and pending['courier_active'] is True and pending['courier_health'] == self.courier_launch_health
                and pending['defender_active'] is True and pending['defender_health'] == 17.
                and 0 <= pending['escape_progress'] < 1,
                'actual seven physics seconds grace follows immediately preceding live pending authorized runner')
        self.check_distance_geometry(pending)
        # Production clears the live roster on conclusion. Use the retained
        # actual roster IDs and actual terminal positions, with no inferred actors.
        self.check_distance_geometry(dict(ship_position=terminal['ship_position'],
            scenario_origin=terminal['scenario_origin'], roster_ids=pending['roster_ids'],
            actors=[dict(actor, active=actor['id'] in pending['roster_ids']) for actor in terminal['actors']]))
        require(c['state'] == 'concluded' and c['outcome'] == 'withdrawn' and not c['active']
                and not c['roster_ids'] and not c['standdown_violation'] and not c['distance_violation']
                and c['elapsed_seconds'] < self.CONFIG['backstop_seconds'],
                'distance withdrawal retains actual complete standdown without escape expiry or transient violation')
        self.check_actor_standdown(c, terminal)
        if self.courier_withdrawal is not None:
            require(terminal == self.courier_withdrawal['terminal'], 'original distance terminal witness never changes')

    def check_defender_kill(self, receipt, s):
        request = receipt.get('request', {})
        require(self.courier_withdrawal is not None and self.attack_return_index == len(self.attack_return_waypoints)
                and self.final_fire_frame is not None
                and self.attack_return_visited[-1]['frame'] < self.final_fire_frame < receipt.get('frame', -1) <= s['frame']
                and type(request.get('sequence')) is int and request['sequence'] > self.dispatch_sequence
                and receipt.get('last_sequence') == request['sequence']
                and receipt.get('present') is True and receipt.get('accepted') is True
                and receipt.get('resolved') is True and receipt.get('hit') is True
                and receipt.get('damaged') is True and receipt.get('destroyed') is True
                and receipt.get('status') == 'destroyed'
                and receipt.get('source_id') == request.get('source_id') == 1101
                and receipt.get('source_entity_id') == request.get('source_entity_id') == s['ship_id']
                and request.get('weapon_id') == 'torrent_compact_pulse_cannon'
                and receipt.get('target_entity_id') == self.defender_id
                and receipt.get('damageable_id', 0) > 0 and receipt.get('collider_id', 0) > 0
                and receipt.get('command_fire') is True
                and math.isfinite(receipt.get('applied_damage', float('nan'))) and receipt['applied_damage'] > 0
                and math.isfinite(receipt.get('remaining_health', float('nan'))) and receipt['remaining_health'] <= 0
                and (receipt.get('main_id'), receipt.get('authority_id')) == self.withdraw_context
                and (receipt.get('director_id'), receipt.get('actor_id'), receipt.get('generation')) == self.courier_identity
                and receipt.get('phase') == 'RETURN_TO_YARD' and receipt.get('state') == 'concluded'
                and receipt.get('outcome') == 'withdrawn' and receipt.get('courier_active') is False
                and receipt.get('courier_health') == receipt.get('courier_maximum_health') == self.courier_launch_health
                and receipt.get('scenario_origin') == self.scenario_origin,
                'actual fresh ordinary player kill of original defender follows withdrawal and physical attack return')
        require(not s['opponent_active'] and s['opponent_health'] <= 0
                and s['phase'] in ('RETURN_TO_YARD', 'SHUT_DOWN', 'DISEMBARKING', 'COMPLETE'),
                'original defender kill retains ordinary Guided home phases')
        if self.defender_kill is not None:
            require(receipt == self.defender_kill, 'original actual defender kill receipt never changes')

    def update(self, s, now):
        c = self.last_courier = s['courier']
        if s['phase'] == 'COMPLETE':
            require(self.courier_withdrawal is not None and self.defender_kill is not None
                    and s['telemetry']['engine'] == 'OFFLINE',
                    'actual distance withdrawal defender kill and OFFLINE precede strict physical home COMPLETE')
        previous_stage = self.stage
        controls = Pilot.update(self, s, now)
        if previous_stage == 'range' and self.stage == 'interceptor':
            require(s['destroyed_targets'] == 4 and s['opponent_id'] > 0 and s['opponent_health'] == 85.,
                    'four actual range kills and original live defender before ordinary preparation')
            self.wait_frame, self.defender_id = s['frame'], s['opponent_id']
            self.defender_ready_frame = s['frame'] + math.ceil(s['tuning']['cooldown']*60) + 6
            self.enter('courier_wait', s)
            return {'Prior'}, 0, 0, False
        if self.wait_frame is None:
            return controls
        require(all(math.isfinite(c[k]) and math.isclose(c[k], v, rel_tol=1e-6, abs_tol=1e-6)
                    for k, v in self.CONFIG.items()), 'original encounter configuration')
        require(s['opponent_id'] == self.defender_id and s['telemetry']['hull'] > 0,
                'same original defender and positive player hull through distance withdrawal and home')
        if self.stage == 'courier_wait':
            require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                    and s['opponent_health'] > 0 and c['outcome'] == 'pending' and not c.get('defender_kill'),
                    'original defender remains alive before actual first dispatch')
            controls = self.defender_wait_controls(s, c['state'] != 'running')
            if len(self.defender_wounds) == 2 and self.defender_pulse is None and not s['command_fire']:
                if self.saved_attack_position is None:
                    self.saved_attack_position = s['position'][:]
            if c['state'] != 'running':
                require(c['state'] in ('idle', 'arming'), 'ordinary first courier arming')
                return controls
            require(len(self.defender_wounds) == 2 and self.defender_pulse is None
                    and s['opponent_health'] == 17. and not s['command_fire']
                    and c['scenario'] == 'courier_intercept' and c['generation'] == 1
                    and c['active'] and c['seen_alive'] and c['health'] == c['maximum_health'] > 0
                    and c['director_id'] > 0 and c['actor_id'] > 0 and not c['terminal'],
                    'actual unhurt first running courier after two released nonlethal defender wounds')
            self.courier_identity = (c['director_id'], c['actor_id'], c['generation'])
            self.withdraw_context = (c['main_id'], c['authority_id'])
            require(all(v > 0 for v in self.withdraw_context), 'actual current Main and authority')
            self.escape_origin, self.scenario_origin = list(c['escape_origin']), list(c['scenario_origin'])
            self.escape_heading = list(c['escape_heading'])
            self.withdraw_waypoint = self.distance_waypoint(self.scenario_origin, self.escape_heading)
            self.courier_launch_health, self.running_frame = c['health'], s['frame']
            self.dispatch = json.loads(json.dumps(s))
            request = c.get('prep_shot', {}).get('request', {})
            require(type(request.get('sequence')) is int and request['sequence'] > 0,
                    'actual authoritative pre-dispatch player shot sequence')
            self.dispatch_sequence = request['sequence']
            self.attack_return_waypoints = [self.saved_attack_position[:]]
            self.wait_braking = False
            self.enter('courier_distance_out', s)
        require(self.courier_identity == (c['director_id'], c['actor_id'], c['generation'])
                and self.withdraw_context == (c['main_id'], c['authority_id'])
                and c['scenario'] == 'courier_intercept' and c['seen_alive']
                and c['escape_origin'] == self.escape_origin and c['scenario_origin'] == self.scenario_origin
                and c['escape_heading'] == self.escape_heading,
                'frozen original director authority runner generation origins and heading through home')
        require(math.isfinite(c['health']) and c['health'] == c['maximum_health'] == self.courier_launch_health
                and not c['hit'] and not c['kill']
                and math.isfinite(c['escape_progress']) and 0 <= c['escape_progress'] < 1
                and not c['distance_violation'], 'same entirely unhurt distance-withdrawn runner never escapes')
        actor_ids = [a['id'] for a in c['actors']]
        require(len(set(actor_ids)) == len(actor_ids) and self.dispatched_ids <= set(actor_ids)
                and c['actor_id'] in actor_ids and set(c['roster_ids']) <= set(actor_ids),
                'all actual dispatched actors retained without substitutions')
        if self.courier_withdrawal is None:
            self.dispatched_ids.update(actor_ids)
        if self.stage in ('courier_distance_out', 'courier_distance_standdown', 'courier_distance_return'):
            require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                    and s['opponent_health'] == 17. and not s['command_fire'] and not c['defender_kill'],
                    'original twice-wounded defender alive and ordinary fire released through distance outcome and return')
        if s['opponent_active']:
            require(c.get('weapon_status', {}).get('reason') != 'weapon_component_failed',
                    'authoritative weapon_component_failed; no weapon recovery route')
        if self.stage == 'courier_distance_out':
            if c['outcome'] == 'pending':
                require(c['state'] == 'running' and c['active'] and not c['terminal']
                        and c['elapsed_seconds'] < self.CONFIG['backstop_seconds']
                        and math.isfinite(c['disengaged_elapsed']) and 0 <= c['disengaged_elapsed'] < 7.,
                        'actual live pending authorized courier until real distance grace concludes')
                if c['disengaged_elapsed'] > 0:
                    self.check_distance_geometry(dict(ship_position=s['position'], scenario_origin=c['scenario_origin'],
                        actors=c['actors'], roster_ids=c['roster_ids']))
                return self.wait_flight_controls(s, self.withdraw_waypoint)[0]
            self.check_standdown(c, s)
            self.courier_withdrawal = json.loads(json.dumps(c))
            self.standdown_until_frame = c['terminal']['frame'] + self.STANDDOWN_FRAMES
            self.enter('courier_distance_standdown', s)
        if self.courier_withdrawal is not None:
            self.check_standdown(c, s)
        if self.stage == 'courier_distance_standdown':
            if s['frame'] < self.standdown_until_frame:
                return {'Prior'}, 0, 0, False
            self.wait_braking = False
            self.enter('courier_distance_return', s)
        if self.stage == 'courier_distance_return':
            controls, reached = self.wait_flight_controls(s, self.attack_return_waypoints[self.attack_return_index])
            if reached:
                self.attack_return_visited.append(dict(index=self.attack_return_index, frame=s['frame'],
                    position=s['position'][:], speed_m_s=norm(s['velocity'])))
                self.attack_return_index += 1
                self.enter('interceptor', s)
            return controls
        if previous_stage == 'interceptor' and controls[3] and self.final_fire_frame is None:
            self.final_fire_frame = s['frame']
        if c['defender_kill']:
            self.check_defender_kill(c['defender_kill'], s)
            if self.defender_kill is None:
                self.defender_kill = json.loads(json.dumps(c['defender_kill']))
        if self.result is not None:
            require(self.defender_kill is not None, 'actual original defender kill before completed strict home')
            self.result.update(completion_marker=self.MARKER, courier_dispatch=self.dispatch,
                courier=self.courier_withdrawal, courier_home=c, defender_kill=self.defender_kill,
                defender_wounds=self.defender_wounds, defender_misses=self.defender_misses,
                withdraw_waypoint=self.withdraw_waypoint, escape_heading=self.escape_heading,
                waiting_flight=self.waiting_flight_report(),
                standdown_observed_frames=s['frame']-c['terminal']['frame'])
        return controls


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


class BeaconHomePilot(BeaconSettlementPilot):
    """Accepted Beacon payment followed by the ordinary Guided home journey."""
    MODE = 'beacon-home'
    HOME_MARKER = 'NATIVE_BEACON_HOME_OK'
    HOME_RETURN_PHASES = ('RETURN_TO_YARD',)
    HOME_CLEARANCE_PHASE = 'TARGET_PRACTICE'
    HOME_RANGE_REQUIRED = True
    GUIDED_STAGES = frozenset(('range', 'interceptor', 'return_align', 'return'))

    def __init__(self):
        super().__init__()
        self.settlement_result = None
        self.home_initial = self.home_previous = None
        self.home_landing_seen = False
        self.home_shutdown_frame = None
        self.home_pressed = {}
        self.home_pending = None
        self.home_native_previous = None
        self.home_edges = []
        self.home_braking = False
        self.home_clearance_ready = False
        self.home_header_samples = []
        self.home_header_crossing = None
        self.home_walked = 0
        self.file_snapshots = {}

    def observe_home_identity(self, s):
        home = s['home']
        if self.home_initial is None:
            self.home_initial = json.loads(json.dumps(home))
        initial = self.home_initial
        for key in ('berth_id', 'berth_instance_id', 'berth_parent_id', 'capsule_id', 'shape_id'):
            require(home[key] and home[key] == initial[key], 'same actual home identity: '+key)
        require(home['berth_id'] == 'central_berth', 'original Torrent central home berth')
        for key in ('range_staging', 'range_clearance', 'range_clearance_exit', 'approach',
                    'dock', 'walk_tuning'):
            require(home[key] == initial[key], 'unchanged authored home geometry/controls: '+key)

    def update(self, s, now):
        self.last_state = s
        if not s['paused']:
            self.observe_home_identity(s)
        if self.settlement_result is None:
            controls = super().update(s, now)
            if self.result is not None:
                self.settlement_result = json.loads(json.dumps(self.result))
                self.result = None
                self.home_previous = s
                self.mouse_pending = None
                self.tap_key = None
                self.home_native_previous = {'l': s['home']['native_land'],
                                             'e': s['home']['native_interact']}
                require(not any(self.home_native_previous.values()), 'released landing/exit keys before home return')
                self.enter('beacon_home_clearance', s)
            return controls
        self.last_state = s
        require(s.get('mode') == self.MODE and s['sequence'] > self.sequence,
                'fresh Beacon home observation')
        self.sequence = s['sequence']
        self.frame = s['frame']
        previous = self.home_previous
        frames = self.frame - previous['frame']
        require(frames > 0 and not s['paused'], 'normal advancing unpaused home physics')
        require((s['pid'], s['main_id'], s['player_id'], s['ship_id']) == self.process_identity
                and self.identities == (s['player_id'], s['ship_id'])
                and s['active_ship'] and not s['destroyed'] and s['phase'] not in ('FAILED', 'RECOVERING'),
                'same live process and actors without recovery throughout home return')
        require(s['default_sampler'] and s['tuning_unchanged']
                and s['tuning'] == self.receipts['settlement_baseline']['tuning'],
                'unchanged authored flight controls throughout home return')
        self.require_paid(s)
        settlement, paid = s['settlement'], self.paid_state['settlement']
        require(settlement['configured'] and settlement['store']['source'] == 'primary'
                and settlement['store']['path'] == paid['store']['path']
                and (settlement['authority_id'], settlement['store_id']) == self.settlement_identity
                and all(settlement[key] == paid[key] for key in ('record', 'terminal', 'handoff')),
                'same primary store and exact paid record terminal and handoff throughout home return')
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        self.observe_home_input(s)
        if self.stage in self.GUIDED_STAGES:
            require(s['piloted'] and s['seated'] and not s['landed'] and s['lease_free'],
                    'ordinary departed pilot throughout genuine range/interceptor and return')
            controls = Pilot.update(self, s, now)
        else:
            if self.stage == 'align_berth':
                self.enter('beacon_home_align', s)
            controls = self.update_home(s, now, frames)
        keys, dx, dy, fire = controls
        self.home_pulse(keys, s, now)
        facing = s['walk_forward'] if not s['seated'] else s['back']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        self.home_previous = s
        return keys, dx, dy, fire

    def observe_home_input(self, s):
        current = {'l': s['home']['native_land'], 'e': s['home']['native_interact']}
        for key, pressed in current.items():
            if pressed != self.home_native_previous[key]:
                self.home_edges.append({'frame': self.frame, 'sequence': s['sequence'],
                                        'key': key, 'pressed': pressed, 'stage': self.stage})
                require(key in self.home_pressed, 'only requested physical landing/exit edges')
                press = self.home_pressed[key]
                if pressed:
                    require('acknowledged_frame' not in press, 'single distinct physical '+key+' press; no retry')
                    press['acknowledged_frame'] = self.frame
                else:
                    require('acknowledged_frame' in press and press.get('release_commanded'),
                            'physical release follows acknowledged ordinary '+key+' press')
                    press['released_frame'] = self.frame
                    self.home_pending = None
        self.home_native_previous = current
        if self.home_pending is not None:
            press = self.home_pressed[self.home_pending]
            require(self.frame <= press['frame'] + 120 or 'released_frame' in press,
                    'ordinary '+self.home_pending+' press/release was not acknowledged; no retry')

    def home_press(self, key, s, now):
        require(self.home_pending is None and key not in self.home_pressed
                and not any(self.home_native_previous.values()) and self.tap_key is None,
                'one released distinct ordinary home '+key+' press')
        self.home_pressed[key] = {'frame': self.frame, 'sequence': s['sequence'], 'until': now+.15}
        self.home_pending = key

    def home_pulse(self, keys, s, now):
        if self.home_pending is None: return
        key = self.home_pending
        press = self.home_pressed[key]
        if (now < press['until'] or self.frame < press['frame'] + 6
                or 'acknowledged_frame' not in press):
            keys.add(key)
        else:
            press['release_commanded'] = True

    def home_fly_to(self, s, target, keys, ready=True):
        off = sub(target, s['position'])
        speed, distance = norm(s['velocity']), norm(off)
        target_aim = [s['camera'][i]+off[i] for i in range(3)]
        dx, dy, align = self.aim(s, target_aim)
        if not ready and dx == 0 and dy == 0:
            # Integer mouse pixels can stall just outside the departure guard.
            # Keep braking and use the same authored mouse controls at full gain.
            dx, dy, _ = self.aim(s, target_aim, gain=1)
        stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
        if distance < stopping+1.75: self.home_braking = True
        if speed <= .45 and distance > .75: self.home_braking = False
        if not ready or distance <= .75 or self.home_braking: keys.add('Prior')
        elif align > .72: keys.add('w')
        return dx, dy, distance <= .75 and speed <= .35

    def observe_home_header(self, s):
        previous = self.home_previous
        clearance = s['home']['range_clearance']
        near_z, far_z = clearance[2]+20, clearance[2]+40
        if max(previous['position'][2], s['position'][2]) < near_z \
                or min(previous['position'][2], s['position'][2]) > far_z:
            return
        require('home_clearance' in self.receipts, 'settled physical staging before RangeHeader crossing')
        for sample in (previous, s):
            require(clearance[1]-1.3 <= sample['position'][1] <= clearance[1]+1.1,
                    'actual RangeHeader crossing stays within the y1.4..3.8 clearance band')
            require(sample['telemetry']['hull'] >= self.receipts['home_clearance']['telemetry']['hull'],
                    'no additional hull loss during the actual RangeHeader crossing')
            if not self.home_header_samples or self.home_header_samples[-1]['frame'] != sample['frame']:
                self.home_header_samples.append({'frame': sample['frame'], 'position': sample['position'],
                                                 'hull': sample['telemetry']['hull']})
        if previous['position'][2] <= far_z <= s['position'][2]:
            self.home_header_crossing = {'frame': self.frame, 'origin_z_interval': [near_z, far_z],
                                         'samples': self.home_header_samples}

    def require_home_dock(self, s):
        home = s['home']
        require(s['landed'] and s['contract'] and s['lease'] and s['parked_exact']
                and home['token_bound'], 'actual strict token-bound exact occupied home dock')

    def require_home_walk(self, s):
        home = s['home']
        require(s['phase'] == 'COMPLETE' and s['guided_complete'] and not s['piloted']
                and not s['seated'] and s['control_enabled'] and not s['transition_busy']
                and home['capsule_enabled'] and home['grounded'] and home['supported']
                and home['support_collider'], 'ordinary controllable exterior walking on actual home floor')
        self.require_home_dock(s)
        require(home['exit_position'] == self.home_initial['exit_position']
                and home['walk_target'] == self.home_initial['walk_target'],
                'exact parked home craft retains its original exterior exit and walk target')
        require(s['telemetry']['engine'] == 'OFFLINE', 'secured powered-down home craft throughout exterior walking')

    def update_home(self, s, now, frames):
        home, phase = s['home'], s['phase']
        keys = set()
        dx = dy = 0
        speed = norm(s['velocity'])
        if self.stage in ('beacon_home_clearance', 'beacon_home_clearance_exit', 'beacon_home_range_staging'):
            require(phase == self.HOME_CLEARANCE_PHASE and s['piloted'] and s['seated']
                    and not s['landed'] and s['lease_free'], 'ordinary paid flight back to the still-live Guided range')
            target = home[{'beacon_home_clearance': 'range_clearance',
                           'beacon_home_clearance_exit': 'range_clearance_exit',
                           'beacon_home_range_staging': 'range_staging'}[self.stage]]
            ready = True
            if self.stage == 'beacon_home_clearance_exit':
                if not self.home_clearance_ready:
                    off = sub(target, s['position'])
                    direction = unit(off)
                    _, _, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
                    nose_pitch = math.degrees(math.asin(max(-1, min(1, -s['back'][1]))))
                    target_pitch = math.degrees(math.asin(max(-1, min(1, direction[1]))))
                    self.home_clearance_ready = align >= .9999 and abs(nose_pitch-target_pitch) <= .5 and speed <= .01
                    if self.home_clearance_ready: self.receipts['home_clearance_ready'] = s
                ready = self.home_clearance_ready
                self.observe_home_header(s)
            dx, dy, reached = self.home_fly_to(s, target, keys, ready)
            if reached:
                self.home_braking = False
                if self.stage == 'beacon_home_clearance':
                    self.receipts['home_clearance'] = s
                    self.enter('beacon_home_clearance_exit', s)
                elif self.stage == 'beacon_home_clearance_exit':
                    require(self.home_header_crossing is not None, 'observed safe RangeHeader crossing before rising to range staging')
                    self.receipts['home_clearance_exit'] = s
                    self.enter('beacon_home_range_staging', s)
                else:
                    if self.HOME_RANGE_REQUIRED:
                        require(len(s['targets']) == 4 and s['destroyed_targets'] == 0 and not s['opponent_active'],
                                'actual physical range staging precedes all four genuine range kills')
                    else:
                        require(s['guided_complete'] and s['destroyed_targets'] == 4 and not s['opponent_active'],
                                'genuine prior Guided victory retained during safe race return')
                    self.receipts['home_range_staging'] = s
                    self.enter('range' if self.HOME_RANGE_REQUIRED else 'return_align', s)
        elif self.stage == 'beacon_home_align':
            require(phase in self.HOME_RETURN_PHASES and self.shot and self.fired
                    and s['destroyed_targets'] == 4 and not s['opponent_active']
                    and s['piloted'] and s['seated'] and not s['landed'] and s['lease_free'],
                    'real Guided combat victory admits the ordinary home landing')
            keys.update(('Prior', 'h'))
            off = sub(home['dock'], s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(home['capture'] and s['capture'] and home['selected_berth_id'] == home['berth_id'],
                        'pure production preview selects the actual central home berth')
                require(dot([-v for v in s['back']], self.parked_forward) < -.95,
                        'ordinary nose-first home return opposite the original parked heading')
                self.landing_distance = norm(off)
                self.receipts['home_landing_request'] = s
                self.home_press('l', s, now)
                self.enter('beacon_home_land', s)
        elif self.stage == 'beacon_home_land':
            keys.add('Prior')
            require(not home['landing_abort_reason'], 'ordinary home landing aborted: '+home['landing_abort_reason'])
            self.home_landing_seen |= s['landing_active']
            if self.home_landing_seen and not s['landing_active'] and not s['landed']:
                require(False, 'ordinary home landing ended without securing the dock')
            if s['landed'] and phase == 'SHUT_DOWN':
                require(self.home_landing_seen and 'acknowledged_frame' in self.home_pressed['l'],
                        'one acknowledged native L started an observed actual physics landing')
                self.require_home_dock(s)
                self.receipts['home_docked'] = s
                self.home_shutdown_frame = self.frame
                self.enter('beacon_home_shutdown', s)
                keys.clear()
            elif not self.home_landing_seen:
                require(self.frame <= self.home_pressed['l']['frame'] + 120,
                        'ordinary L did not admit the home landing; no retry')
        elif self.stage == 'beacon_home_shutdown':
            self.require_home_dock(s)
            require(phase == 'SHUT_DOWN' and s['piloted'] and s['seated'], 'ordinary neutral home shutdown')
            if self.frame - self.home_shutdown_frame >= 90 and s['telemetry']['engine'] == 'OFFLINE':
                require('released_frame' in self.home_pressed['l'], 'landing key physically released before distinct exit press')
                self.receipts['home_shutdown'] = s
                self.home_press('e', s, now)
                self.enter('beacon_home_exit', s)
        elif self.stage == 'beacon_home_exit':
            self.require_home_dock(s)
            require(s['telemetry']['engine'] == 'OFFLINE', 'powered-down exact home dock retained during ordinary exit')
            if not s['piloted'] and not s['seated'] and s['control_enabled'] and not s['transition_busy']:
                self.require_home_walk(s)
                require('acknowledged_frame' in self.home_pressed['e'] and s['exit_error'] < .25,
                        'one acknowledged ordinary E completes the actual supported exterior exit')
                self.receipts['home_exit'] = s
                self.enter('beacon_home_walk', s)
            else:
                require(self.frame <= self.home_pressed['e']['frame'] + 600,
                        'ordinary E did not finish the supported home exit; no retry')
        elif self.stage == 'beacon_home_walk':
            self.require_home_walk(s)
            step = norm(sub(s['player'], self.home_previous['player']))
            require(step <= (home['walk_tuning']['sprint']/60*1.25+.02)*frames,
                    'continuous actual exterior walking without placement or recovery teleport')
            self.home_walked += step
            off = sub(home['walk_target'], s['player'])
            off[1] = 0
            distance = norm(off)
            direction = unit(off)
            yaw = math.atan2(dot(direction, s['walk_right']), dot(direction, s['walk_forward']))
            dx = round(max(-360, min(360, yaw/home['walk_tuning']['mouse'])))
            walk_speed = norm([home['player_velocity'][0], 0, home['player_velocity'][2]])
            stopping = walk_speed*walk_speed/(2*home['walk_tuning']['deceleration']) + home['walk_tuning']['walk']*frames/60 + .10
            if abs(yaw) < .08 and distance > .25 and (walk_speed <= .35 or distance > stopping): keys.add('w')
            displacement = norm(sub(s['player'], self.receipts['home_exit']['player']))
            require(displacement < 2, 'bounded ordinary home exterior walk')
            if distance <= .30 and walk_speed <= .35 and displacement >= .5 and self.frame-self.receipts['home_exit']['frame'] >= 20:
                require('released_frame' in self.home_pressed['e'], 'exit key physically released before usable walking completes')
                require(all(label in self.file_snapshots for label in ('baseline', 'paid', 'stable')),
                        'independent baseline paid and stable real-file checks precede home success')
                expected = ('APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
                            'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN', 'COMPLETE')
                require(all(phase in self.phases for phase in expected), 'all genuine ordinary Guided gameplay phases')
                self.receipts['home_walk'] = s
                self.enter('complete', s)
                self.result = {'completion_marker': self.HOME_MARKER,
                               'scope': 'ordinary Beacon entry traversal payment Guided combat home dock shutdown and usable exterior walk',
                               'settlement': self.settlement_result, 'receipts': self.receipts,
                               'same_pid': s['pid'], 'same_main_id': s['main_id'],
                               'same_player_id': s['player_id'], 'same_ship_id': s['ship_id'],
                               'home_berth_id': home['berth_id'], 'home_berth_instance_id': home['berth_instance_id'],
                               'same_capsule_id': home['capsule_id'], 'same_shape_id': home['shape_id'],
                               'home_landing_active_seen': self.home_landing_seen,
                               'landing_approach_m': self.landing_distance,
                               'native_home_edges': self.home_edges, 'home_presses': self.home_pressed,
                               'header_crossing': self.home_header_crossing,
                               'home_walked_m': self.home_walked, 'home_walk_displacement_m': displacement,
                               'home_support_collider': home['support_collider'],
                               'authored_tuning': s['tuning'], 'walk_tuning': home['walk_tuning'],
                               'default_sampler': True, 'phases': self.phases, 'stages': self.stages,
                               'remaining': ['cold restart', 'ten-run endurance', 'native hardware and human review']}
                keys.clear()
        else:
            require(False, 'known ordinary Beacon home stage')
        return keys, dx, dy, False


class RaceHomePilot(BeaconHomePilot):
    """Genuine Guided prerequisite, then same-Torrent timed race and strict home."""
    MODE = 'race-home'
    HOME_MARKER = MARKER = 'NATIVE_RACE_HOME_OK'
    ACTIVITY = 'cinder_reach_checkpoint_route'
    REWARD = 'return_race_record_to_shipyard'
    REWARD_ACTIVITY = ACTIVITY
    REWARD_LABEL = 'Race record accepted'
    HOME_RETURN_PHASES = ('FREE_FLIGHT',)
    HOME_CLEARANCE_PHASE = 'FREE_FLIGHT'
    HOME_RANGE_REQUIRED = False
    POINTS = [[16, -9, -240], [32, -26, -372], [46, -44, -498],
              [30, -46, -600], [60, -70, -700]]

    def __init__(self):
        super().__init__()
        self.raw_sequence = -1
        self.raw_previous = None
        self.race_identity = None
        self.countdown = self.active = None
        self.gates = []
        self.guided_result = self.home_result = None
        self.quit_requested = False
        self.file_home = False
        self.race_braking = False
        self.clear_target = self.clear_started = self.clear_previous = None
        self.tutorial_binding = self.tutorial_tick = None
        self.tutorial_approaches = []

    @classmethod
    def require_paid(cls, s):
        settlement = s['settlement']
        record, terminal = settlement['record'], settlement['terminal']
        receipt = record['last_receipt']
        require(record == {'schema_version': 1, 'payload_kind': 'game_flow_reward_store',
                          'authority_id': 'game_flow_reward_authority', 'store_id': 'game_flow_reward_store',
                          'receipt_serial': 1, 'total_receipts': 1, 'reward_counts': {cls.REWARD: 1},
                          'last_receipt': receipt}
                and receipt.get('reward_label') == cls.REWARD_LABEL,
                'exact production race reward ledger namespace and player-visible record')
        require(record['receipt_serial'] == record['total_receipts'] == 1
                and record['reward_counts'] == {cls.REWARD: 1}
                and receipt['receipt_id'] == 1 and receipt['activity_id'] == cls.REWARD_ACTIVITY
                and receipt['activity_generation'] == 1 and receipt['reward_id'] == cls.REWARD
                and receipt['granted'] is True and receipt['replay_allowed'] is False,
                'exact once-only generation-one production race receipt')
        require(terminal['schema_version'] == 1 and len(terminal['activities']) == 1,
                'one actual timed race persisted session')
        cls.require_terminal_paid(s, terminal['activities'][0])
        cls.require_reward_handoff(s, receipt)

    @classmethod
    def require_terminal_paid(cls, s, entry):
        state = entry['progress']['session_state']
        require(entry['activity_id'] == cls.ACTIVITY and entry['generation'] == 1
                and entry['state'] == 3 and entry['reward_requested'] is True
                and entry['reward_granted'] is True
                and state == s['race']['capture'] and state['session_generation'] == 1
                and state['activity_state']['state'] == 2
                and state['activity_state']['next_checkpoint_index'] == 5
                and state['race_state']['state'] == 3
                and 0 < state['race_state']['last_time_seconds'] < 120,
                'actual completed five-gate race capture atomically acknowledges payment')
    @classmethod
    def require_reward_handoff(cls, s, receipt):
        settlement = s['settlement']
        record = settlement['record']
        handoff = settlement['handoff']
        require(set(handoff) == {'accepted', 'reason', 'reward_request', 'callback'}
                and handoff['accepted'] is True and handoff['reason'] == 'reward_request_committed',
                'actual direct race adapter handoff contains its committed request and callback')
        request, callback = handoff['reward_request'], handoff['callback']
        require(request == {'activity_id': cls.REWARD_ACTIVITY, 'activity_generation': 1,
                            'reward_id': cls.REWARD, 'reward_authority': False, 'granted': False}
                and request['reward_authority'] is False and request['granted'] is False,
                'exact generation-one race request delegates payment to the production authority')
        require(isinstance(callback, dict)
                and set(callback) == {'accepted', 'reason', 'reward_authority_id', 'reward_store_id',
                                      'granted', 'store_generation', 'receipt'}
                and callback['accepted'] is True and callback['granted'] is True
                and callback['reason'] == 'reward_receipt_committed'
                and callback['reward_authority_id'] == record['authority_id']
                and callback['reward_store_id'] == record['store_id']
                and type(callback['store_generation']) is int
                and 0 < callback['store_generation'] <= settlement['store']['generation']
                and callback['receipt'] == receipt,
                'actual race authority callback committed the exact durable receipt and store identity')

    def observe_tutorial_approaches(self, s):
        sample = s['tutorial_approach']
        tick, binding = sample['tick'], sample['binding_id']
        previous = self.tutorial_tick
        if self.tutorial_binding is None and binding:
            self.tutorial_binding = binding
        require(not binding or binding == self.tutorial_binding, 'same retained tutorial streaming sample owner')
        if not binding: return
        require(previous is None or tick >= previous, 'retained tutorial caller ticks never regress')
        self.tutorial_tick = tick
        # Early binding rejections retain old fields. Only a newly completed
        # caller tick may authorize an approach from that retained position.
        if previous is None or tick <= previous or s['paused']: return
        if not (binding and sample['activated'] and sample['caller_mode'] and sample['accepted']
                and sample['sample_reason'] == 'available' and sample['actor_id'] == s['ship_id']
                and sample['piloting'] and sample['enabled'] and sample['cluster_id']): return
        require(sample['range'] == 250 and len(sample['position']) == 3
                and all(math.isfinite(v) for v in sample['position']),
                'actual finite accepted tutorial actor sample and unchanged approach radius')
        families = {'nearby_hulk_dock': 'cinder_hulk_power_restoration',
                    'nearby_belt_bore': 'cinder_asteroid_field_threading_run'}
        for marker in sample['markers']:
            require(families.get(marker['family']) == marker['prompt_id']
                    and len(marker['position']) == 3 and all(math.isfinite(v) for v in marker['position']),
                    'actual first resident destination marker maps to its production briefing')
            if (norm(sub(sample['position'], marker['position'])) <= sample['range']
                    and marker['prompt_id'] not in {r['prompt_id'] for r in self.tutorial_approaches}):
                self.tutorial_approaches.append({'sequence': s['sequence'], 'sample': sample,
                                                 'marker': marker, 'prompt_id': marker['prompt_id']})

    def validate_observation(self, s):
        require(s.get('mode') == self.MODE and s['sequence'] > self.raw_sequence,
                'every fresh race raw observation validated, including coalesced samples')
        identity = tuple(s[k] for k in ('pid', 'main_id', 'player_id', 'ship_id'))
        require(all(identity), 'current process Main Player and original Torrent')
        if self.process_identity is None: self.process_identity = identity
        require(identity == self.process_identity, 'same race process and physical actors throughout')
        race = s['race']; snapshot = race['snapshot']; capture = race['capture']
        owners = tuple(race[k] for k in ('owner_id', 'clock_id', 'director_id'))
        reward_owners = tuple(s['settlement'][k] for k in ('authority_id', 'store_id'))
        require(all(owners) and all(reward_owners), 'live Main timed race director clock and reward owners')
        if self.race_identity is None:
            self.race_identity = owners
            self.settlement_identity = reward_owners
        require(owners == self.race_identity and reward_owners == self.settlement_identity,
                'exact original timed race and reward owners, never the streamed progress fixture')
        require(race['selected_kind'] == 'timed_race' and snapshot['attached']
                and not snapshot['closed'] and snapshot['activity_id'] == self.ACTIVITY
                and race['route_path'] == 'res://assets/activities/cinder_reach_checkpoint_route.tres'
                and race['points'] == self.POINTS and race['radius'] == 32
                and capture['configured_laps'] == 1
                and capture['configured_countdown_seconds'] == 2
                and capture['configured_timeout_seconds'] == 120
                and s['physics_ticks'] == 60 and s['time_scale'] == 1,
                'unchanged actual authored five 32m gates and production 2s/120s clock')
        require(s['settlement']['configured'] and s['settlement']['store']['source'] == 'primary',
                'actual configured primary production reward store')
        if s['paused']:
            require(self.stage in ('pause', 'quit_wait') and self.home_result is not None,
                    'race pauses only for normal final UI exit')
        else:
            require(s['default_sampler'] and s['tuning_unchanged'] and not s['destroyed']
                    and s['phase'] not in ('FAILED', 'RECOVERING'),
                    'ordinary unchanged live race controls without recovery')
            self.observe_home_identity(s)
            if self.raw_previous is not None:
                require(s['frame'] > self.raw_previous['frame'], 'advancing actual race physics')
            if self.stage == 'race_reboard_clear':
                home = s['home']
                require(home['grounded'] and home['supported'] and home['support_collider']
                        and home['capsule_enabled'] and s['control_enabled'] and not s['seated'],
                        'every actual clearance-walk sample has supported ordinary controls')
                frames = s['frame']-self.raw_previous['frame']
                require(norm(sub(s['player'], self.raw_previous['player']))
                        <= (home['walk_tuning']['sprint']/60*1.25+.02)*frames,
                        'every actual clearance-walk sample moves continuously')
        state = snapshot['state_id']
        if self.countdown is None and state == 'idle':
            require(snapshot['session_generation'] == snapshot['activity_generation']
                    == snapshot['race_generation'] == 0 and not self.gates,
                    'race stays genuinely fresh throughout required Guided prerequisite')
            self.require_zero(s)
        else:
            require(state in ('countdown', 'active', 'completed')
                    and snapshot['session_generation'] == snapshot['activity_generation']
                    == snapshot['race_generation'] == race['active_generation'] == 1
                    and race['active_id'] == self.ACTIVITY
                    and race['director']['generation'] == capture['session_generation'] == 1
                    and snapshot['penalty_seconds'] == 0 and not snapshot['failure_reason'],
                    'single actual automatic generation-one race without reset failure or penalties')
            if self.countdown is None:
                require(state == 'countdown' and self.guided_result is not None
                        and 2-2/60-1e-6 <= snapshot['countdown_remaining_seconds'] <= 2,
                        'observe actual initial production countdown after same-Torrent ordinary re-departure')
                self.countdown = s
                self.entry_result = self.guided_result
                self.receipts['settlement_baseline'] = s
            previous_snapshot = self.raw_previous['race']['snapshot'] if self.raw_previous is not None else {}
            if previous_snapshot.get('state_id') == 'countdown' and not s['paused']:
                remaining = max(0, previous_snapshot['countdown_remaining_seconds']
                                - (s['frame']-self.raw_previous['frame'])/60)
                require(math.isclose(snapshot['countdown_remaining_seconds'], remaining, abs_tol=1e-5),
                        'actual countdown consumes only the unchanged production physics clock')
            if state == 'countdown':
                require(snapshot['next_checkpoint_index'] == 0 and not self.gates
                        and snapshot['current_time_seconds'] == 0,
                        'production countdown never consumes early checkpoint overlaps')
            elif self.active is None:
                require(s['frame']-self.countdown['frame'] >= 118
                        and snapshot['countdown_remaining_seconds'] == 0,
                        'full actual two-second physics countdown precedes active race')
                self.active = s
            cursor = race['director']['next_checkpoint_index']
            require(cursor in (len(self.gates), len(self.gates)+1) and 0 <= cursor <= 5,
                    'all five physical checkpoint transitions observed in order without skips')
            if cursor > len(self.gates):
                require(state in ('active', 'completed') and not s['paused']
                        and s['phase'] == 'FREE_FLIGHT' and s['piloted'] and s['seated']
                        and s['active_ship'] and s['lease_free'] and not s['landed']
                        and norm(sub(s['position'], race['points'][cursor-1])) <= 32,
                        'same actual departed Torrent physically crosses each production 32m gate')
                self.gates.append(s)
                self.race_braking = False
            if state == 'completed':
                require(len(self.gates) == 5 and snapshot['progress_unitless'] == 1
                        and 0 < snapshot['last_time_seconds'] < 120,
                        'all five actual timed checkpoints completed within unchanged 120s')
                self.require_paid(s)
            else:
                self.require_zero(s)
                require(snapshot['current_time_seconds'] < 120, 'original race timeout remains binding')
        if self.paid_state is not None:
            self.require_paid(s)
            require(all(s['settlement'][k] == self.paid_state['settlement'][k]
                        for k in ('record', 'terminal', 'handoff')),
                    'exact race reward and terminal persist through usable home and UI exit')
        self.observe_tutorial_approaches(s)
        self.raw_sequence = s['sequence']
        self.raw_previous = self.last_state = s

    def update_home(self, s, now, frames):
        if self.stage == 'beacon_home_shutdown' and (s['flight_demand'] or s['telemetry']['engine'] != 'OFFLINE'):
            self.home_shutdown_frame = s['frame']
        return super().update_home(s, now, frames)

    def update(self, s, now):
        require(self.last_state is s, 'latest race observation already independently validated')
        self.frame = s['frame']
        if self.stage in ('pause', 'quit_wait'):
            return ArrowReturnReusePilot.ui_update(self, s, now)
        if self.settlement_result is not None:
            controls = super().update(s, now)
            if self.result is not None:
                self.home_result = self.result
                self.home_result['scope'] = 'genuine Guided prerequisite, same-Torrent timed five-gate race, durable payment, strict home and supported exit walk'
                self.result = None
                self.enter('pause', s)
                self.ui_key = None; self.ui_release_until = 0
            return controls
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        self.sequence = s['sequence']
        if self.guided_result is None:
            controls = Pilot.update(self, s, now)
            if self.result is not None:
                self.guided_result = self.result; self.result = None
                self.receipts['guided_exit'] = s
                self.enter('race_reboard_release', s)
            return controls
        if self.stage == 'race_reboard_release':
            # Preserve the first ordinary E's full physical release before walking/reboarding.
            controls = Pilot.update(self, s, now)
            if self.tap_key is None and not s['native_interact']:
                require(s['home']['supported'] and s['home']['grounded'], 'supported Guided prerequisite exit')
                off = sub(s['player'], s['boarding']); off[1] = 0
                require(norm(off) > .1 and s['reboard_blocked'] and s['boarding_reach'] == 7,
                        'actual blocked same-Torrent physical exit before walking away')
                self.clear_target = [p+4*d for p, d in zip(s['player'], unit(off))]
                self.clear_started = now; self.clear_previous = s
                self.enter('race_reboard_clear', s)
            return controls
        if self.stage == 'race_reboard_clear':
            keys = set()
            frames = s['frame']-self.clear_previous['frame']
            require(0 < frames and now-self.clear_started <= 12,
                    'ordinary same-Torrent supported reboard-clear walk within 12 seconds')
            home = s['home']
            require(home['grounded'] and home['supported'] and home['support_collider']
                    and not s['seated'] and s['control_enabled'] and not s['transition_busy'],
                    'actual supported walking throughout reboard clearance')
            step = norm(sub(s['player'], self.clear_previous['player']))
            require(step <= (home['walk_tuning']['sprint']/60*1.25+.02)*frames,
                    'continuous ordinary reboard-clear walking without placement')
            dx, reached = HulkHomePilot.home_walk_to(self, s, self.clear_target, keys, frames, home=home)
            self.clear_previous = s
            if reached:
                require(s['boarding_reach'] == 7 and s['boarding_distance'] > 7 and not s['reboard_blocked'],
                        'ordinary walk away beyond actual 7m threshold released production reboard block')
                self.receipts['reboard_clear'] = s
                self.enter('walk', s)
            if self.mouse_pending is not None:
                if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
                else: self.mouse_pending = None
            if dx: self.mouse_pending = s['walk_forward'][:]
            return keys, dx, 0, False
        if self.stage in ('walk', 'board'):
            require('reboard_clear' in self.receipts and not s['reboard_blocked'],
                    'never walk toward or board the still-blocked same Torrent')
            controls = Pilot.update(self, s, now)
            if self.stage == 'launch':
                self.enter('race_launch', s)
                self.home_braking = False
            return controls
        require(not s['paused'] and s['piloted'] and s['seated'] and s['active_ship'],
                'ordinary actual same-Torrent race pilot')
        keys = set()
        dx = dy = 0
        if self.stage == 'race_launch':
            dx, dy, reached = self.home_fly_to(s, [0, 8, -78], keys)
            if reached:
                require(s['phase'] == 'FREE_FLIGHT' and self.countdown is not None,
                        'ordinary same-Torrent free-flight departure starts real timed session')
                self.enter('race_flight', s)
        elif self.stage == 'race_flight':
            if s['race']['snapshot']['state_id'] == 'completed':
                self.paid_state = s
                self.receipts['settlement_paid'] = s
                self.enter('race_stable', s)
                keys.add('Prior')
            else:
                cursor = len(self.gates)
                require(cursor < 5, 'next actual physical timed race gate')
                # Reuse the accepted ordinary beacon navigation's braking law.
                off = sub(s['race']['points'][cursor], s['position'])
                speed, distance = norm(s['velocity']), norm(off)
                dx, dy, align = self.aim(s, [a+b for a, b in zip(s['camera'], off)])
                stopping = speed*speed/(2*s['tuning']['brake']) + speed*.18
                if distance < stopping+10: self.race_braking = True
                if speed <= .45 and distance > 10: self.race_braking = False
                if distance <= 10 or self.race_braking: keys.add('Prior')
                elif align > .72: keys.add('w')
        elif self.stage == 'race_stable':
            keys.add('Prior')
            if s['frame']-self.paid_state['frame'] >= 60:
                self.receipts['settlement_stable'] = s
                self.settlement_result = {'countdown': self.countdown, 'active': self.active,
                    'physical_gates': self.gates, 'paid': self.paid_state, 'guided_prerequisite': self.guided_result}
                self.home_previous = s
                self.home_native_previous = {'l': s['home']['native_land'], 'e': s['home']['native_interact']}
                require(not any(self.home_native_previous.values()), 'released keys before strict race home')
                self.tap_key = None; self.mouse_pending = None
                self.enter('beacon_home_clearance', s)
        else:
            require(False, 'known complete ordinary race stage')
        if self.mouse_pending is not None:
            if norm(sub(s['back'], self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = s['back'][:]
        return keys, dx, dy, False

    def finish(self, code):
        require(code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.home_result is not None and self.file_home,
                'race succeeds only after supported home and actual normal UI OS exit zero')
        self.result = self.home_result
        self.result['normal_ui_exit'] = self.receipts['exit_ui']


class PatrolRelayHomePilot(RaceHomePilot):
    """Real pause-board selection and continuous relay dwell, then strict home."""
    MODE = 'patrol-relay-home'
    HOME_MARKER = MARKER = 'NATIVE_PATROL_RELAY_HOME_OK'
    REWARD_ACTIVITY = 'cinder_relay_patrol'
    REWARD = 'return_patrol_log_to_shipyard'
    REWARD_LABEL = 'Patrol log accepted'

    def __init__(self):
        super().__init__()
        self.patrol_identity = None
        self.patrol_selected = False
        self.patrol_active = None
        self.dwell_ticks = 0
        self.dwell_start = None
        self.patrol_alignment_started = None
        self.patrol_outbound_header_samples = []
        self.patrol_outbound_header_crossing = None

    def observe_patrol_outbound_header(self, s):
        previous = self.raw_previous
        home = s['home']
        require(all(home[key] == self.home_initial[key]
                    for key in ('range_clearance_exit', 'range_clearance')),
                'unchanged original near and far outbound clearance endpoints')
        clearance = home['range_clearance']
        near_z, far_z = clearance[2]+20, clearance[2]+40
        if max(previous['position'][2], s['position'][2]) < near_z \
                or min(previous['position'][2], s['position'][2]) > far_z:
            return
        require('patrol_outbound_near' in self.receipts and 'patrol_outbound_ready' in self.receipts,
                'actual settled low near waypoint and brake/hover alignment precede outbound header crossing')
        require(s['frame']-previous['frame'] == 1
                and norm(sub(s['position'], previous['position'])) <= s['tuning']['maximum_speed']/60*1.25+.02,
                'every reverse header sample has continuous ordinary physical motion')
        for sample in (previous, s):
            require(clearance[1]-1.3 <= sample['position'][1] <= clearance[1]+1.1,
                    'actual reverse RangeHeader crossing stays within the y1.4..3.8 clearance band')
            require(sample['telemetry']['hull'] >= self.receipts['patrol_outbound_near']['telemetry']['hull'],
                    'no additional hull loss during actual reverse RangeHeader crossing')
            if not self.patrol_outbound_header_samples or self.patrol_outbound_header_samples[-1]['frame'] != sample['frame']:
                self.patrol_outbound_header_samples.append({'frame':sample['frame'],
                    'position':sample['position'], 'hull':sample['telemetry']['hull']})
        if previous['position'][2] >= near_z >= s['position'][2]:
            self.patrol_outbound_header_crossing = {'frame':s['frame'],
                'origin_z_interval':[near_z, far_z], 'samples':self.patrol_outbound_header_samples}

    @classmethod
    def require_terminal_paid(cls, s, entry):
        capture = s['patrol']['capture']
        require(entry['activity_id'] == cls.ACTIVITY and entry['generation'] == 1
                and entry['state'] == 2 and entry['reward_requested'] is True
                and entry['reward_granted'] is True
                and entry['progress']['patrol_state'] == capture
                and capture['schema_version'] == 2 and capture['branch_id'] == 'relay_sweep'
                and capture['generation'] == capture['activity_generation'] == 1
                and capture['state'] == 2 and capture['next_checkpoint_index'] == 5
                and capture['completed_checkpoint_count'] == 5
                and capture['dwell_checkpoint_index'] == -1
                and capture['dwell_elapsed_seconds'] == 0
                and capture['activity_state']['state'] == 2
                and capture['activity_state']['next_checkpoint_index'] == 5
                and capture['last_duration_seconds'] > 0,
                'actual completed schema-two relay patrol and director atomically acknowledge payment')

    def validate_observation(self, s):
        require(s.get('mode') == self.MODE and s['sequence'] > self.raw_sequence,
                'every fresh raw relay patrol observation, including coalesced samples')
        identity = tuple(s[k] for k in ('pid', 'main_id', 'player_id', 'ship_id'))
        require(all(identity), 'current process Main Player and original Torrent')
        if self.process_identity is None: self.process_identity = identity
        require(identity == self.process_identity, 'same patrol process Main and physical actors')
        patrol = s['patrol']; snapshot = patrol['snapshot']; capture = patrol['capture']
        owners = tuple(patrol[k] for k in ('owner_id', 'director_id'))
        reward_owners = tuple(s['settlement'][k] for k in ('authority_id', 'store_id'))
        require(all(owners) and all(reward_owners), 'actual Main PatrolActivity director and reward owners')
        if self.patrol_identity is None:
            self.patrol_identity, self.settlement_identity = owners, reward_owners
        require(owners == self.patrol_identity and reward_owners == self.settlement_identity,
                'original Main patrol and reward owners throughout')
        require(snapshot['attached'] == (patrol['selected_kind'] == 'patrol')
                and not snapshot['closed'] and snapshot['activity_id'] == self.ACTIVITY
                and snapshot['branch_id'] == 'relay_sweep' and capture['schema_version'] == 2
                and capture['branch_id'] == 'relay_sweep' and snapshot['dwell_seconds'] == 2
                and capture['configured_dwell_seconds'] == 2
                and patrol['route_path'] == 'res://assets/activities/cinder_reach_checkpoint_route.tres'
                and patrol['points'] == self.POINTS and patrol['radius'] == 32
                and s['physics_ticks'] == 60 and s['time_scale'] == 1,
                'actual authored relay order five 32m volumes and unchanged two-second production dwell')
        require(s['settlement']['configured'] and s['settlement']['store']['source'] == 'primary',
                'actual configured primary production reward store')
        previous = self.raw_previous
        if s['paused']:
            require((self.stage.startswith('patrol_ui_') and self.guided_result is not None)
                    or (self.stage in ('pause', 'quit_wait') and self.home_result is not None),
                    'pause only for real patrol selection or final ordinary UI exit')
        else:
            require(s['default_sampler'] and s['tuning_unchanged'] and not s['destroyed']
                    and s['phase'] not in ('FAILED', 'RECOVERING'),
                    'ordinary unchanged patrol controls without recovery')
            self.observe_home_identity(s)
            if previous is not None:
                require(s['frame'] > previous['frame'], 'advancing actual unpaused patrol physics')
            if self.stage == 'patrol_outbound_far': self.observe_patrol_outbound_header(s)
            if self.stage == 'race_reboard_clear':
                home = s['home']
                require(home['grounded'] and home['supported'] and home['support_collider']
                        and home['capsule_enabled'] and s['control_enabled'] and not s['seated'],
                        'every raw clearance-walk sample remains supported and controllable')
                require(norm(sub(s['player'], previous['player']))
                        <= (home['walk_tuning']['sprint']/60*1.25+.02)*(s['frame']-previous['frame']),
                        'continuous physical reboard clearance without placement')
        state = snapshot['state_id']
        if state == 'idle':
            require(self.patrol_active is None and not self.gates
                    and snapshot['generation'] == snapshot['activity_generation'] == 0,
                    'patrol stays genuinely fresh through Guided selection and supported reboard')
            self.require_zero(s)
        else:
            require(state in ('active', 'completed') and self.guided_result is not None
                    and self.patrol_selected and (not s['paused'] or self.home_result is not None),
                    'only ordinary selected generation-one relay patrol')
            require(patrol['selected_kind'] == 'patrol' and patrol['active_id'] == self.ACTIVITY
                    and snapshot['generation'] == snapshot['activity_generation']
                    == patrol['active_generation'] == patrol['director']['generation'] == 1
                    and snapshot['patrol_actor_instance_id'] == s['ship_id']
                    and snapshot['patrol_actor_status_id'] == 'tracked'
                    and not snapshot['failure_reason'] and not snapshot['terminal_reason'],
                    'single real relay generation without reset abort failure or replacement')
            if self.patrol_active is None:
                require(state == 'active' and s['phase'] == 'FREE_FLIGHT'
                        and 0 <= snapshot['current_time_seconds'] <= 1/60+1e-6,
                        'real initial patrol starts automatically on same-Torrent ordinary departure')
                self.patrol_active = s
                self.entry_result = self.guided_result
                self.receipts['settlement_baseline'] = s
            cursor = snapshot['next_checkpoint_index']
            require(cursor == patrol['director']['next_checkpoint_index']
                    and cursor in (len(self.gates), len(self.gates)+1) and 0 <= cursor <= 5,
                    'all actual director checkpoint transitions observed in order without skips')
            was_active = previous is not None and previous['patrol']['snapshot']['state_id'] == 'active'
            if was_active:
                require(s['frame']-previous['frame'] == 1 and not s['paused']
                        and math.isclose(snapshot['current_time_seconds']
                            -previous['patrol']['snapshot']['current_time_seconds'], 1/60, abs_tol=1e-5),
                        'every raw active physics tick retained with actual unchanged patrol clock progression')
            if len(self.gates) < 5:
                index = len(self.gates)
                sample = s['tutorial_approach']
                require(sample['caller_mode'] and sample['accepted'] and sample['sample_reason'] == 'available'
                        and sample['actor_id'] == s['ship_id'] and sample['piloting']
                        and len(sample['position']) == 3
                        and (not was_active or sample['tick'] == previous['tutorial_approach']['tick']+1),
                        'actual retained Main ship sample used by streaming and patrol this physics tick')
                occupied = norm(sub(sample['position'], patrol['points'][index])) <= 32
                if occupied:
                    if self.dwell_ticks == 0: self.dwell_start = s
                    self.dwell_ticks += 1
                else:
                    self.dwell_ticks = 0; self.dwell_start = None
                if cursor > index:
                    require(occupied and self.dwell_ticks >= 120 and was_active
                            and norm(sub(s['position'], patrol['points'][index])) <= 32
                            and s['phase'] == 'FREE_FLIGHT' and s['piloted'] and s['seated']
                            and s['active_ship'] and s['lease_free'] and not s['landed'],
                            'same departed Torrent occupies each volume for 120 continuous actual 60Hz ticks')
                    self.gates.append({'start': self.dwell_start, 'completed': s,
                                       'occupied_ticks': self.dwell_ticks})
                    self.dwell_ticks = 0; self.dwell_start = None
                    self.home_braking = False
                else:
                    require(snapshot['checkpoint_occupied'] == occupied
                            and math.isclose(snapshot['dwell_elapsed_seconds'], self.dwell_ticks/60, abs_tol=1e-5)
                            and (not occupied or snapshot['dwell_checkpoint_index'] == index),
                            'raw physical occupancy exactly accounts for every production dwell timer increment/reset')
            if state == 'completed':
                require(len(self.gates) == 5 and snapshot['state'] == 2
                        and patrol['director']['state'] == 2,
                        'five genuine continuous holds complete actual PatrolActivity and director')
                self.require_paid(s)
            else: self.require_zero(s)
        if self.paid_state is not None:
            self.require_paid(s)
            require(all(s['settlement'][k] == self.paid_state['settlement'][k]
                        for k in ('record', 'terminal', 'handoff')),
                    'same exact paid patrol ledger terminal and callback retained through home and normal UI exit')
        if not s['paused']: self.observe_tutorial_approaches(s)
        self.raw_sequence = s['sequence']
        self.raw_previous = self.last_state = s

    def patrol_ui_update(self, s, now):
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key}, 0, 0, False
            self.ui_edges.append({'sequence': s['sequence'], 'key': self.ui_key, 'pressed': False})
            self.ui_key = None; self.ui_release_until = now+.10
            return set(), 0, 0, False
        if now < self.ui_release_until or any(s['native_keys'].values()): return set(), 0, 0, False
        ui, patrol = s['ui'], s['patrol']
        if self.ui_pending is not None:
            pending = self.ui_pending; kind = pending['kind']
            if kind == 'tab': accepted = bool(ui['focus_path']) and ui['focus_path'] != pending['focus']
            elif kind == 'select': accepted = patrol['selected_kind'] == 'patrol'
            elif kind == 'branch': accepted = (patrol['snapshot']['branch_id'] == ui['patrol_branch'] == 'relay_sweep')
            elif kind == 'resume': accepted = not s['paused']
            else: accepted = s['paused'] and ui[pending['expected']]
            require(accepted or now < pending['until'], 'ordinary patrol UI input unacknowledged: '+kind+'; no retry')
            if not accepted: return set(), 0, 0, False
            self.ui_pending = None
            if kind != 'tab':
                self.receipts['patrol_ui_'+kind] = s
                if kind == 'resume':
                    self.patrol_selected = True
                    self.enter('race_reboard_release', s)
                    return set(), 0, 0, False
                self.beacon_stage({'pause':'patrol_ui_board', 'board':'patrol_ui_select',
                    'select':'patrol_ui_branch', 'branch':'patrol_ui_back', 'back':'patrol_ui_resume'}[kind], s)
        if self.stage == 'patrol_ui_pause':
            require(not s['paused'], 'normal unpaused exterior before actual Escape')
            return self.ui_press('Escape', s, now, 'pause', 'main_visible')
        require(s['paused'], 'real pause retained during patrol board selection')
        if self.stage == 'patrol_ui_back':
            require(ui['activity_visible'], 'actual ActivitySelection page before ordinary Back')
            return self.ui_press('Escape', s, now, 'back', 'main_visible')
        if self.stage == 'patrol_ui_resume':
            require(ui['main_visible'], 'actual main pause page before Resume')
            return self.ui_press('Escape', s, now, 'resume')
        page, name, kind = {'patrol_ui_board':('main_visible','ActivityBoardButton','board'),
            'patrol_ui_select':('activity_visible','PatrolActivityButton','select'),
            'patrol_ui_branch':('activity_visible','RelaySweepPatrolBranchButton','branch')}[self.stage]
        require(ui[page] and ui['focus_path'], 'actual visible patrol page and keyboard focus')
        if kind == 'branch' and not ui['relay_enabled']:
            require(ui['relay_visible'] and ui['patrol_branch'] == patrol['snapshot']['branch_id'] == 'relay_sweep'
                    and patrol['selected_kind'] == 'patrol' and patrol['snapshot']['generation'] == 0,
                    'disabled authored relay choice already selects the actual fresh default relay branch')
            self.receipts['patrol_ui_branch_disabled_default'] = s
            self.beacon_stage('patrol_ui_back', s)
            return set(), 0, 0, False
        if ui['focus_name'] == name:
            require(ui['focus_enabled'] and ui['focus_visible'], 'actual enabled visible patrol selection button')
            return self.ui_press('Return', s, now, kind, 'activity_visible' if kind == 'board' else None)
        require(ui['focus_path'] not in self.focus_seen and len(self.focus_seen) < 64,
                'patrol selection target reachable without cycling focus')
        self.focus_seen.add(ui['focus_path'])
        return self.ui_press('Tab', s, now, 'tab')

    def update(self, s, now):
        require(self.last_state is s, 'latest patrol sample independently validated')
        if self.stage.startswith('patrol_ui_'): return self.patrol_ui_update(s, now)
        if self.stage == 'race_reboard_release' and not self.patrol_selected:
            controls = Pilot.update(self, s, now)
            if self.tap_key is None and not s['native_interact']:
                require(self.guided_result is not None and s['home']['supported'] and not s['seated'],
                        'genuine Guided physical exterior exit precedes actual patrol selection')
                self.beacon_stage('patrol_ui_pause', s)
            return controls
        if self.settlement_result is not None or self.stage not in (
                'race_launch', 'patrol_outbound_near', 'patrol_outbound_align',
                'patrol_outbound_far', 'patrol_flight', 'patrol_align'):
            controls = super().update(s, now)
            if self.home_result is not None:
                self.home_result['scope'] = 'genuine Guided, actual pause-board relay selection, five continuous patrol holds, durable payment, strict home and normal UI exit'
            return controls
        self.frame = s['frame']; self.sequence = s['sequence']
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        require(not s['paused'] and s['piloted'] and s['seated'] and s['active_ship'], 'ordinary same-Torrent patrol pilot')
        keys = set(); dx = dy = 0
        if self.stage == 'race_launch':
            dx, dy, reached = self.home_fly_to(s, [0, 8, -78], keys)
            if reached:
                require(s['phase'] == 'FREE_FLIGHT' and self.patrol_active is not None,
                        'ordinary physical same-Torrent departure starts selected Main patrol')
                self.receipts['patrol_range_staging'] = s
                self.home_braking = False
                self.enter('patrol_outbound_near', s)
        elif self.stage == 'patrol_outbound_near':
            dx, dy, reached = self.home_fly_to(s, s['home']['range_clearance_exit'], keys)
            if reached:
                self.receipts['patrol_outbound_near'] = s
                self.enter('patrol_outbound_align', s)
        elif self.stage == 'patrol_outbound_align':
            target = s['home']['range_clearance']
            dx, dy, _ = self.home_fly_to(s, target, keys, ready=False)
            keys.add('h')
            direction = unit(sub(target, s['position']))
            _, _, align = self.aim(s, [s['camera'][i]+target[i]-s['position'][i] for i in range(3)])
            nose_pitch = math.degrees(math.asin(max(-1, min(1, -s['back'][1]))))
            target_pitch = math.degrees(math.asin(max(-1, min(1, direction[1]))))
            if align >= .9999 and abs(nose_pitch-target_pitch) <= .5 and s['upright'] >= .94 and norm(s['velocity']) <= .01:
                require('patrol_outbound_near' in self.receipts
                        and norm(sub(s['position'], s['home']['range_clearance_exit'])) <= .75,
                        'settled actual original low near waypoint before reverse header departure')
                self.receipts['patrol_outbound_ready'] = s
                self.home_braking = False
                self.enter('patrol_outbound_far', s)
        elif self.stage == 'patrol_outbound_far':
            dx, dy, reached = self.home_fly_to(s, s['home']['range_clearance'], keys)
            if reached:
                require(self.patrol_outbound_header_crossing is not None,
                        'actual safely sampled reverse RangeHeader crossing before original patrol holds')
                self.receipts['patrol_outbound_far'] = s
                self.home_braking = False
                self.enter('patrol_flight', s)
        elif self.stage == 'patrol_flight':
            if s['patrol']['snapshot']['state_id'] == 'completed':
                self.paid_state = s; self.receipts['settlement_paid'] = s
                self.patrol_alignment_started = now
                self.enter('patrol_align', s)
                keys.update(('Prior', 'h'))
            else:
                require(len(self.gates) < 5, 'next real patrol hold')
                dx, dy, _ = self.home_fly_to(s, s['patrol']['points'][len(self.gates)], keys)
        elif self.stage == 'patrol_align':
            require(now-self.patrol_alignment_started <= 15, 'ordinary brake/hover alignment within 15 seconds')
            keys.update(('Prior', 'h'))
            if s['frame']-self.paid_state['frame'] >= 60 and s['upright'] >= .94 and norm(s['velocity']) <= .35:
                self.receipts['settlement_stable'] = s
                self.settlement_result = {'guided_prerequisite': self.guided_result,
                    'selection': {k:v for k,v in self.receipts.items() if k.startswith('patrol_ui_')},
                    'active': self.patrol_active, 'physical_holds': self.gates, 'paid': self.paid_state,
                    'outbound_header_crossing': self.patrol_outbound_header_crossing,
                    'return_alignment': s}
                self.home_previous = s
                self.home_native_previous = {'l':s['home']['native_land'], 'e':s['home']['native_interact']}
                require(not any(self.home_native_previous.values()), 'released native keys before strict patrol home')
                self.tap_key = None; self.mouse_pending = None
                self.enter('beacon_home_clearance', s)
        if self.mouse_pending is not None:
            if norm(sub(s['back'], self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = s['back'][:]
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

    def home_walk_to(self, s, target, keys, frames, home=None):
        home = s['hulk_home'] if home is None else home
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

    def zenith_corner_required(self):
        return (self.mode == 'life-arm' and self.stage == 'walk_service'
                and self.route and self.route[self.index][0] == 'zenith_approach')

    def zenith_corner_safe(self, s):
        # Rung01 ends at x20.2; DockSlab01 starts south of z59.3.
        # Settle inside their overlap before the next southwest segment.
        return not self.zenith_corner_required() or (s['player'][0] >= 20.30 and s['player'][2] <= 59.20)

    def walk_to(self, s, target, keys, frames):
        speed = norm([s['velocity'][0], 0, s['velocity'][2]])
        arrival_radius = .30
        if self.zenith_corner_required() and not self.zenith_corner_safe(s):
            # Private steering only: the published goal and its .30m region
            # remain unchanged. This point is .223607m from that goal.
            target = [20.4, 4.2, 59.1]
            arrival_radius = .05
        dx, yaw, distance = self.yaw_to(s, target)
        vertical_error = abs(target[1]-s['player'][1])
        vertical_ok = vertical_error < .8 if self.bounded else vertical_error <= .65
        if distance <= arrival_radius and vertical_ok:
            if self.bounded:
                return 0, self.settled_frames >= 15 and self.zenith_corner_safe(s)
            if speed <= .35: return 0, True
        tuning = s['walk_tuning']
        commanded = tuning['sprint'] if distance > 3 else tuning['walk']
        stopping = speed*speed/(2*tuning['deceleration']) + max(speed, commanded)*frames/60 + .10
        if abs(yaw) < .08 and distance > arrival_radius and (speed <= .35 or distance > stopping):
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
                and math.hypot(s['velocity'][0], s['velocity'][2]) < .1 \
                and self.zenith_corner_safe(s)
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
    SLOT = 'cinder_beacon_session'
    MUTABLE = HabitatRestartFiles.MUTABLE | {'cinder_beacon_session', 'game_flow_reward_store'}

    def observe(self, s, pilot):
        if pilot.entry_result is None: return
        require(s['pid'] == pilot.process_identity[0], 'real-file observation belongs to the same game')
        label = None
        if 'baseline' not in self.snapshots: label = 'baseline'
        elif pilot.paid_state is not None and 'paid' not in self.snapshots: label = 'paid'
        elif 'stable' not in self.snapshots and (pilot.result is not None
                or getattr(pilot, 'settlement_result', None) is not None): label = 'stable'
        elif isinstance(pilot, BeaconHomePilot) and (pilot.result is not None or getattr(pilot, 'home_result', None) is not None) and 'home' not in self.snapshots: label = 'home'
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
                and payload.get(self.SLOT, {}) == settlement['terminal'],
                'independent actual file exactly matches live reward record and terminal')
        if label == 'baseline':
            pilot.require_zero(s)
        else:
            pilot.require_paid(s)
            self.require_preserved(self.snapshots['baseline']['document'], document)
            if label in ('stable', 'home'):
                paid = self.snapshots['paid']['document']['payload']
                require(payload['game_flow_reward_store'] == paid['game_flow_reward_store']
                        and payload[self.SLOT] == paid[self.SLOT],
                        'independent actual disk retains the same once-only receipt and paid terminal')
                if label == 'home':
                    stable = self.snapshots['stable']['document']['payload']
                    require(all(payload[key] == stable[key] for key in ('game_flow_reward_store', self.SLOT)),
                            'final home file retains the independently checked stable settlement')


class RaceHomeFiles(BeaconSettlementFiles):
    SLOT = 'cinder_timed_race_session'
    MUTABLE = HabitatRestartFiles.MUTABLE | {SLOT, 'game_flow_reward_store'}

    def __init__(self, profile, output):
        super().__init__(profile, output)
        self.baseline_sequence = None
        self.expected_tutorial_ids = set()

    def observe(self, s, pilot):
        if self.baseline_sequence is not None:
            self.expected_tutorial_ids.update(r['prompt_id'] for r in pilot.tutorial_approaches
                                             if r['sequence'] > self.baseline_sequence)
        super().observe(s, pilot)
        if self.baseline_sequence is None and 'baseline' in self.snapshots:
            self.baseline_sequence = s['sequence']
        pilot.file_home = 'home' in self.snapshots

    def require_preserved(self, before, after):
        key = 'tutorial_prompts_seen'
        protected_before, protected_after = self.protected(before), self.protected(after)
        if key not in protected_before and key not in protected_after and not self.expected_tutorial_ids:
            return super().require_preserved(before, after)
        def seen(payload):
            value = payload.get(key)
            require(isinstance(value, dict) and set(value) == {'schema_version', 'seen_ids'}
                    and type(value['schema_version']) in (int, float) and value['schema_version'] == 1
                    and isinstance(value['seen_ids'], list)
                    and all(isinstance(v, str) and re.fullmatch('[a-z0-9_]{1,64}', v) for v in value['seen_ids'])
                    and len(value['seen_ids']) <= 64
                    and value['seen_ids'] == sorted(set(value['seen_ids'])),
                    'exact schema-one sorted unique tutorial seen namespace')
            return value['seen_ids']
        before_ids, after_ids = seen(protected_before), seen(protected_after)
        require(after_ids == sorted(set(before_ids) | self.expected_tutorial_ids),
                'tutorial seen IDs equal preserved baseline union exact observed resident-site approaches')
        del protected_before[key]; del protected_after[key]
        require(protected_before == protected_after,
                'every unrelated actual-file sibling remains unchanged beside justified tutorial additions')
        require(after['generation'] >= before['generation'], 'actual-file generations never regress')

    def finish(self, s, pilot):
        require(pilot.file_home, 'independent actual race home file precedes UI shutdown')
        closed = self.capture('orderly-close', s['settlement']['store'])
        home = self.snapshots['home']['document']
        self.require_preserved(home, closed)
        self.require_orderly(closed, home)
        require(all(closed['payload'][k] == home['payload'][k]
                    for k in (self.SLOT, 'game_flow_reward_store')),
                'normal UI shutdown preserves the actual once-only race record and acknowledged terminal')


class PatrolRelayHomeFiles(RaceHomeFiles):
    SLOT = 'cinder_patrol_session'
    MUTABLE = HabitatRestartFiles.MUTABLE | {SLOT, 'game_flow_reward_store'}


class ZenithReturnReuseFiles(HabitatRestartFiles):
    # Normal default free flight can legitimately start/abort its timed activity
    # and show its once-only briefing. Every other durable sibling is protected.
    MUTABLE = HabitatRestartFiles.MUTABLE | {'cinder_timed_race_session', 'tutorial_prompts_seen'}

    def observe(self, s, pilot):
        label = None
        if 'baseline' not in self.snapshots and s['menu_ready']: label = 'baseline'
        elif 'wing_clear_1' in pilot.receipts and 'home-1' not in self.snapshots: label = 'home-1'
        elif len(pilot.trips) == 2 and 'home-2' not in self.snapshots: label = 'home-2'
        if label is None: return
        document = self.capture(label, s['save'])
        require(self.protected(document) == self.protected({'payload':s['save']['payload']}),
                'independent Zenith actual file matches literal live protected payload')
        for key in ('cinder_timed_race_session','tutorial_prompts_seen'):
            require(document['payload'].get(key) == s['save']['payload'].get(key),
                    'only actual observed default activity/briefing may change beside Zenith play')
        if label != 'baseline':
            self.require_preserved(self.snapshots['baseline']['document'], document)
        pilot.file_home = 'home-2' in self.snapshots

    def finish(self, s, pilot):
        require(pilot.file_home and all(label in self.snapshots for label in ('baseline','home-1','home-2')),
                'both real Zenith home files precede normal UI termination')
        home = self.snapshots['home-2']['document']
        closed = self.capture('orderly-close', s['save'])
        self.require_preserved(home, closed)
        self.require_orderly(closed, home)
        require(all(closed['payload'].get(key) == home['payload'].get(key)
                    for key in ('cinder_timed_race_session','tutorial_prompts_seen')),
                'normal UI clean close preserves final actual activity and briefing state')


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


class ZenithReturnReusePilot(ArrowReturnReusePilot):
    """Selected ordinary Zenith pilot/weapon/home/reuse member; other craft gates stay open."""
    MARKER = 'NATIVE_ZENITH_RETURN_REUSE_OK'
    IDS = tuple(k for k in ArrowReturnReusePilot.IDS if k != 'camera_id') + ('chase_camera_id', 'cockpit_camera_id')
    PHASE_LIMIT = 15  # New engineering executor bound frozen before tests, not historical handling.
    WEAPON_CAP = ArrowReturnReusePilot.WEAPON_CAP
    WEAPON_STAGES = ('weapon_aim', 'weapon_fire', 'weapon_restore')
    FOOT_STAGES = ('wing_port', 'wing_clear', 'reapproach', 'pause', 'quit_wait')

    def __init__(self):
        super().__init__()
        self.admission = LifeTowPilot('life-arm')
        self.stage = 'admission'
        self.admission_result = None
        self.now = self.stage_since = 0
        self.stage_frame = 0
        self.first_stream = self.retired_stream = None
        self.board_streams = []
        self.handling = {}
        self.control_ticks = {"boost":0, "roll":0}
        self.control_pulses = {}
        self.phase_origin = None
        self.landing_timeout = None
        self.landing_active_seen = False
        self.landing_last = {}
        self.landing_edges = [0, 0]
        self.exit_edges = [0, 0]
        self.neutral_frame = None
        self.clear_paths = [[], []]
        self.file_home = False

    def enter(self, stage, s):
        super().enter(stage, s)
        self.stage_since, self.stage_frame = self.now, s['frame']
        self.phase_origin = copy.deepcopy(s)
        self.home_braking = False
        if stage in ('boost','roll'):
            require(stage not in self.control_pulses, 'one distinct authorized Zenith '+stage+' pulse')
            require(s['up'][1] >= .94 and norm(s['ship_velocity']) <= .35,
                    'handling begins upright at controlled low speed')
            self.control_pulses[stage] = {'start_frame':s['frame'], 'start_sequence':s['sequence'],
                'baseline':{key:copy.deepcopy(s[key]) for key in ('right','up','back','ship_velocity')},
                'samples':[], 'release_request':None, 'released':None}

    def release_control_pulse(self, action, s):
        pulse = self.control_pulses[action]
        require(action in self.handling and pulse['release_request'] is None,
                'release requested once after the actual '+action+' physical outcome')
        pulse['release_request'] = {'frame':s['frame'], 'sequence':s['sequence'],
            'count':self.control_ticks[action], 'command':copy.deepcopy(s['command']),
            'native_control':copy.deepcopy(s['native_control']), 'native_thrust':s['native_thrust']}

    def receipt(self, s):
        result = super().receipt(s)
        result.update(input_stream=s['input_stream'], command=copy.deepcopy(s['command']),
                      camera_view=s['camera_view'], landing=copy.deepcopy(s['landing']))
        return result

    def require_home(self, s, contract=True):
        require(s['landed'] and s['parked_exact'] and s['lease'] and s['lease_token']
                and (not contract or s['contract']), 'actual strict exact occupied Zenith home lease')

    def require_pilot_owner(self, s):
        require(s['piloted'] and s['seated'] and s['seated_at_pilot'] and s['active_ship']
                and s['ship_camera'] and not s['capsule_enabled'] and not s['transition_busy']
                and s['source_enabled'] and s['application_focused'],
                'same actual local Zenith seat camera and default command owner')

    def require_pilot(self, s):
        self.require_pilot_owner(s)
        require(s['command']['stream_id'] == s['input_stream'],
                'actual consumed Zenith command matches its fresh pilot stream')

    def reuse_pilot_ready(self, s):
        self.require_pilot_owner(s)
        require(s['phase'] == 'START_ENGINES' and self.first_stream is not None
                and self.retired_stream is not None and s['input_stream'] > self.retired_stream > self.first_stream,
                'same default source starts a fresh fenced pilot stream after real exit/reboard')
        if s['command']['stream_id'] == s['input_stream']:
            return True
        # GameFlow seats synchronously before Hero's next physics sample. Only
        # its exact cleared neutral command may bridge that bounded admission.
        cleared = dict(schema_version=4, sequence=0, timestamp_usec=0, stream_id=0,
            throttle=0, yaw=0, pitch=0, roll=0, look_yaw_delta=0, look_pitch_delta=0,
            camera_distance_delta=0, boost=False, brake=False, hover=False, fire=False,
            barrel_roll=False, engine_start=False, engine_stop=False, landing=False,
            interact=False, camera_toggle=False, fire_pressed=False)
        require(s['command'] == cleared, 'reboard waits only for a cleared neutral consumed command, never a stale or active stream')
        return False

    def require_flight(self, s):
        self.require_pilot(s)
        require(s['phase'] == 'FREE_FLIGHT' and not s['landed'] and s['lease_free']
                and not s['landing_active'], 'physical departed Zenith free flight before control or weapon work')

    def require_foot(self, s):
        super().require_foot(s)
        require(s['engine'] == 'OFFLINE' and not any(s['command'][key] for key in ('throttle','yaw','pitch','roll','look_yaw_delta','look_pitch_delta','boost','brake','hover','fire')),
                'supported Zenith exterior walk with powered-down hull and neutral retired pilot consumer')

    def validate_weapon(self, s):
        target, shot = s['target'], s['shot']
        require(target['name'] == 'TargetDrone01' and target['target_id'] == 'DRONE-01'
                and target['base_position'] == [-13,7,-95] and target['maximum_health'] == 100
                and not target['destroyed'] and s['weapon_source'] == 1104
                and s['weapon']['range'] == 420 and s['weapon']['damage'] == 28,
                'same untouched production DRONE-01 and registered Zenith source1104 repeater')
        if 'pre_fire' not in self.weapon:
            require(target['health'] == 100 and not shot['present'], 'real unshot100HP target before unique Zenith fire')
            return
        if shot['present']:
            request = shot['request']; context = target['hit_source']
            require(shot['accepted'] and shot['resolved'] and shot['hit'] and shot['damaged']
                    and not shot['destroyed'] and shot['status'] == 'damaged'
                    and request['source_id'] == shot['source_id'] == context['source_id'] == 1104
                    and request['source_entity_id'] == shot['source_entity_id'] == context['source_entity_id'] == s['ship_id']
                    and request['weapon_id'] == context['weapon_id'] == 'zenith_interceptor_repeater'
                    and request['range'] == 420 and request['damage'] == shot['applied_damage'] == 28
                    and request['sequence'] == context['sequence']
                    == self.weapon['pre_fire']['target']['hit_source']['sequence']+1
                    and request['presentation_receipt_id'] == context['presentation_receipt_id']
                    and request['presentation_receipt_id'] >= 0
                    and shot['target_entity_id'] == s['target_instance_id']
                    and shot['damageable_id'] == s['target_adapter_id']
                    and shot['remaining_health'] == target['health'] == 72
                    and shot['damage_result']['accepted'] and shot['damage_result']['applied_damage'] == 28
                    and shot['damage_result']['health'] == 72 and shot['damage_result']['maximum_health'] == 100
                    and not shot['damage_result']['destroyed'],
                    'one exact fresh authoritative Zenith28-point hit100→72 without replay or substitute target')
            if 'hit' not in self.weapon:
                require(s['native_fire'] and s['command']['fire']
                        and s['input_stream'] == self.first_stream,
                        'new repeater hit follows actual native Fire and current consumed pilot command')
                self.weapon['hit'] = self.weapon_receipt(s)
        else:
            require(target['health'] == 100, 'target health cannot change before actual authoritative shot')
        if s['native_fire']:
            require(self.stage == 'weapon_fire' and self.flight == 0,
                    'one real Fire pulse confined to first Zenith weapon phase')

    def validate_observation(self, s):
        require(s.get('mode') == 'zenith-return-reuse' and s['actors_current'], 'literal current Zenith observer')
        previous = self.observed_previous
        if self.initial is None:
            require(s['phase'] == 'INTRO' and not s['paused'] and not s['guided_complete'],
                    'normal fresh title before accepted LIFE-ARM walk')
            self.require_home(s, False)
            self.initial = copy.deepcopy(s)
        initial = self.initial
        require(all(s[k] == initial[k] and s[k] for k in self.IDS)
                and s['capsule_geometry'] == initial['capsule_geometry'],
                'same Main world Player capsule Zenith seat source target and both real cameras')
        require(s['definition_id'] == 'zenith_b7_observed' and s['home_id'] == 'zenith_fleet_dock_berth'
                and s['default_controls'] and s['default_sampler'] and s['tuning_unchanged']
                and s['walk_tuning'] == LifeTowPilot.DEFAULT_WALK and s['ship_tuning'] == initial['ship_tuning']
                and s['ship_tuning']['cooldown'] == .24 and s['ship_tuning']['maximum_speed'] == 94
                and s['ship_tuning']['boost_speed'] == 126 and s['ship_tuning']['thrust'] == 42
                and s['ship_tuning']['brake'] == 54 and s['physics_ticks'] == 60 and s['time_scale'] == 1
                and not s['destroyed'] and s['hull'] == initial['hull'] == 68
                and not s['remote_piloted'] and not s['guided_complete'],
                'authored default Zenith controls and intact hull without Guided completion or recovery')
        require(s['endpoints'] == initial['endpoints'] and s['parked'] == initial['parked']
                and (not s['parked_exact'] or s['boarding'] == initial['boarding']),
                'unchanged live-home route endpoints')
        view = s['camera_view']
        require(view in ('CHASE', 'COCKPIT')
                and s['camera_id'] == s['chase_camera_id' if view == 'CHASE' else 'cockpit_camera_id'],
                'actual current camera matches its retained chase or cockpit node')
        if previous is not None:
            require(s['sequence'] == previous['sequence']+1 and s['frame'] == previous['frame']+1,
                    'every raw Zenith physics observation retained including coalesced samples')
            if s['piloted'] and previous['piloted'] and not s['landing_active'] and not previous['landing_active']:
                require(norm(sub(s['position'], previous['position'])) <= 126/60*1.25+.02,
                        'continuous ordinary Zenith motion without placement')
        if s['paused']:
            require(self.stage in ('pause','quit_wait') and len(self.trips) == 2,
                    'pause only follows both completed Zenith flights and supported wing-clear walks')
        if self.stage == 'admission':
            require(all(s['admission'][key] == s[key] for key in
                        ('main_id','world_id','player_id','capsule_id','shape_id','ship_id','frame','player'))
                    and s['admission']['home_berth_instance_id'] == s['berth_id']
                    and s['admission']['ship_tuning'] == s['ship_tuning'],
                    'accepted LIFE-ARM prefix belongs to these exact current Zenith actors and resources')
            self.admission.validate_observation(s['admission'])
        else:
            if s['seated'] and not s['transition_busy']:
                if self.stage == 'board': self.reuse_pilot_ready(s)
                else: self.require_pilot(s)
            if self.stage in self.FOOT_STAGES:
                self.require_foot(s); self.require_home(s)
                if previous is not None:
                    require(norm(sub(s['player'],previous['player'])) <= LifeTowPilot.DEFAULT_WALK['sprint']/60*1.25+.02,
                            'every wing-clear/reapproach observation is supported continuous walking')
        command = s['command']; native = s['native_control']
        for action, pulse in self.control_pulses.items():
            consumed = (command['boost'] or command['throttle'] != 0) if action == 'boost' else command['roll'] < 0
            consumed_neutral = (not command['boost'] and command['throttle'] == 0) if action == 'boost' else command['roll'] == 0
            native_neutral = (not native['boost'] and not s['native_thrust']) if action == 'boost' else not native['roll']
            if pulse['released'] is None:
                # Held controls are sampled synchronously by Hero. Record every
                # actual sample through native/consumer release, including phase tails.
                if consumed:
                    self.control_ticks[action] += 1

                if action == 'roll':
                    require(command['roll'] <= 0 and all(command[key] == 0 for key in
                            ('yaw','pitch','look_yaw_delta','look_pitch_delta')),
                            'deliberate Q roll has no concurrent yaw pitch or manual mouse steering')
                pulse['samples'].append({'frame':s['frame'],'sequence':s['sequence'],
                    'consumed':bool(consumed),'native_neutral':native_neutral,
                    'count':self.control_ticks[action], 'command':copy.deepcopy(command),
                    'native_control':copy.deepcopy(native),'native_thrust':s['native_thrust'],
                    'speed':norm(s['ship_velocity']),'up':s['up'][:]})
                if pulse['release_request'] is not None and native_neutral and consumed_neutral:
                    pulse['released'] = {'frame':s['frame'], 'sequence':s['sequence'],
                        'count':self.control_ticks[action], 'command':copy.deepcopy(command),
                        'native_control':copy.deepcopy(native), 'native_thrust':s['native_thrust']}
            elif (action == 'boost' and self.stage == 'boost_brake') or (action == 'roll' and self.stage == 'hover'):
                require(native_neutral and consumed_neutral, 'released '+action+' pulse cannot reactivate during settling')
        if previous is not None and s['piloted'] and not s['transition_busy']:
            if (abs(command['look_yaw_delta'])+abs(command['look_pitch_delta']) > 0
                    and norm(sub(s['back'], previous['back'])) > 1e-6):
                self.handling.setdefault('steering', self.receipt(s))
            if self.stage == 'boost' and native['boost'] and command['boost'] and command['throttle'] > 0:
                if (s['native_thrust'] and norm(s['ship_velocity']) > s['ship_tuning']['maximum_speed']
                        and norm(s['ship_velocity']) > norm(previous['ship_velocity'])+1e-6):
                    self.handling.setdefault('boost', dict(self.receipt(s), speed=norm(s['ship_velocity']),
                        cruise=s['ship_tuning']['maximum_speed'], boost_limit=s['ship_tuning']['boost_speed']))
            if self.stage == 'boost_brake' and native['brake'] and command['brake'] and norm(s['ship_velocity']) < norm(previous['ship_velocity'])-1e-6:
                self.handling.setdefault('brake', self.receipt(s))
            if self.stage == 'roll' and native['roll'] and command['roll'] < 0:
                baseline=self.control_pulses['roll']['baseline']
                cosine=max(-1,min(1,(sum(dot(s[axis],baseline[axis]) for axis in ('right','up','back'))-1)/2))
                roll_degrees=math.degrees(math.acos(cosine))
                if roll_degrees >= 30:
                    self.handling.setdefault('roll',dict(self.receipt(s),roll_degrees=roll_degrees,
                        baseline=copy.deepcopy(baseline)))
            if self.stage == 'hover' and native['hover'] and command['hover'] and s['up'][1] > previous['up'][1]+1e-6:
                self.handling.setdefault('hover', self.receipt(s))
            if view != previous['camera_view']:
                require(self.stage in ('camera_cockpit','camera_chase') and native['camera'] and command['camera_toggle'],
                        'each actual camera transition follows one consumed native V edge')
                self.handling['camera_'+view.lower()] = self.receipt(s)
        if s['native_landing'] and not (previous and previous['native_landing']):
            require(self.stage == 'land' and self.receipts.get(self.key_for('landing')) is not None,
                    'one requested distinct real Landing Assist edge')
            self.landing_edges[self.flight] += 1
            require(self.landing_edges[self.flight] == 1, 'exactly one native L per Zenith flight; no retries')
        if s['landing_active']:
            require(self.stage == 'land' and not s['landing']['last_abort_reason'], 'actual un-aborted landing owner')
            report = s['landing']
            if self.landing_timeout is None: self.landing_timeout = report['timeout_seconds']
            require(report['timeout_seconds'] == self.landing_timeout >= 24
                    and 0 <= report['elapsed'] <= report['timeout_seconds']
                    and report['stall_timeout_seconds'] == 4 and 0 <= report['stall_elapsed'] <= 4,
                    'actual captured Hero landing timeout and independent four-second stall remain binding')
            self.landing_active_seen = True
            self.landing_last[self.flight+1] = self.receipt(s)
        if self.stage != 'admission' and s['native_interact'] and not (previous and previous['native_interact']):
            if self.stage == 'exit':
                self.exit_edges[self.flight] += 1
                require(self.exit_edges[self.flight] == 1, 'one actual Zenith exit E per flight')
            else:
                require(self.stage == 'board' and self.receipts.get('board_2') is not None,
                        'fresh reuse E only after actual supported wing-clear/reapproach')
        if self.stage != 'admission' and s['phase'] == 'BOARDING':
            request = self.receipts.get('board_2', {})
            require(self.stage == 'board' and request.get('candidate') and not request.get('reboard_blocked')
                    and not request.get('station_candidate') and request.get('boarding_distance', 99) <= 7
                    and s['boarding_reserved'] and s['transition_busy']
                    and s['boarding_confirmation'].get('adapter',{}).get('view',{}).get('state') == 'boarding',
                    'real native E admits the same available Zenith canopy reservation before fresh pilot')
        if s['phase'] == 'DISEMBARKING':
            require(self.stage == 'exit' and self.receipts.get(self.key_for('offline')) is not None
                    and s['engine'] == 'OFFLINE' and self.exit_edges[self.flight] == 1, 'physical disembark only after actual neutral OFFLINE home')
        if self.stage == 'shutdown':
            self.require_home(s)
            if s['flight_demand']: self.neutral_frame = None
            elif self.neutral_frame is None: self.neutral_frame = s['frame']
        self.validate_weapon(s)
        self.observations += 1
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        self.frame = s['frame']; self.last_state = self.observed_previous = s

    def navigate(self, s, target, keys, fixed_axis=False):
        off = sub(target, s['position']); speed = norm(s['ship_velocity']); distance = norm(off)
        if fixed_axis:
            dx = dy = 0; alignment = dot(unit(off), [-v for v in s['back']])
        else:
            dx, dy, alignment = self.weapon_aim(s, off)
        stopping = speed*speed/(2*s['ship_tuning']['brake']) + speed*.18
        if distance < stopping+1.75: self.home_braking = True
        if speed <= .45 and distance > .75: self.home_braking = False
        if distance <= .75 or self.home_braking: keys.add('Prior')
        elif fixed_axis: keys.add('w' if alignment >= 0 else 's')
        elif alignment > .8: keys.add('w')
        else: keys.add('Prior')
        return dx, dy, distance <= .75 and speed <= .35

    def stage_guard(self, now):
        if self.stage in ('admission','pause','quit_wait','land'): return
        limit = 12 if self.stage == 'board' else 10 if self.stage == 'exit' else self.PHASE_LIMIT
        require(now-self.stage_since <= limit, 'frozen Zenith '+self.stage+' executor phase bound '+str(limit)+'s')
        self.check_weapon_deadline(now)

    def update(self, s, now):
        require(self.last_state is s, 'latest literal Zenith observation already validated')
        self.now = now
        if self.stage == 'admission':
            controls = self.admission.update(s['admission'], now)
            if self.admission.result is not None:
                self.admission_result = copy.deepcopy(self.admission.result)
                self.first_stream = s['input_stream']; self.board_streams.append(self.first_stream)
                self.receipts['seated_1'] = self.receipt(s)
                self.enter('depart', s)
            return controls
        self.stage_guard(now)
        if self.stage in ('pause','quit_wait'): return self.ui_update(s, now)
        keys = set(); dx = dy = 0
        if self.stage in ('depart','climb','lane','return_capture'):
            if self.stage != 'depart': self.require_flight(s)
            else: self.require_pilot(s)
            endpoint = {'depart':'clear','climb':'climb','lane':'lane'}
            target = s['capture_position'] if self.stage == 'return_capture' else s['endpoints'][endpoint[self.stage]]
            dx, dy, reached = self.navigate(s, target, keys, fixed_axis=self.stage == 'depart')
            if reached:
                self.require_flight(s)
                self.receipts[self.key_for(self.stage)] = self.receipt(s)
                if self.stage == 'depart':
                    self.excursion = norm(sub(s['position'],s['parked']))
                    require(self.excursion > 8, 'actual native-thrust lease-free Zenith departure')
                    self.enter('climb' if self.flight == 0 else 'return_capture', s)
                elif self.stage == 'climb': self.enter('boost_align', s)
                elif self.stage == 'lane':
                    self.weapon_started, self.weapon_start_frame = now, s['frame']
                    self.enter('weapon_aim', s)
                else:
                    self.enter('return_align',s)
        elif self.stage == 'return_align':
            self.require_flight(s); keys.update(('Prior','h'))
            if (s['up'][1] >= .94 and norm(s['ship_velocity']) <= .35 and s['capture']
                    and not s['native_landing'] and self.tap_key is None):
                self.receipts[self.key_for('landing')] = self.receipt(s)
                self.tap('l', now); self.landing_timeout = None; self.landing_active_seen = False
                self.enter('land', s)
        elif self.stage == 'boost_align':
            self.require_flight(s); keys.add('Prior')
            dx,dy,align = self.weapon_aim(s, sub(s['endpoints']['lane'],s['position']))
            if align > .9999 and norm(s['ship_velocity']) <= .35: self.enter('boost', s)
        elif self.stage == 'boost':
            self.require_flight(s)
            if 'boost' not in self.handling: keys.update(('w','Shift_L'))
            else:
                require('boost' in self.handling, 'positive actual boost consumer before release/brake')
                self.release_control_pulse('boost',s)
                self.enter('boost_brake', s); keys.add('Prior')
        elif self.stage == 'boost_brake':
            self.require_flight(s); keys.add('Prior')
            if norm(s['ship_velocity']) <= .35 and self.control_pulses['boost']['released'] is not None:
                require('brake' in self.handling, 'actual brake reduces physical ship speed')
                self.enter('roll', s)
        elif self.stage == 'roll':
            self.require_flight(s); keys.add('Prior')
            if 'roll' not in self.handling: keys.add('q')
            else:
                require('roll' in self.handling, 'positive actual authored roll consumer')
                self.release_control_pulse('roll',s)
                self.enter('hover', s)
        elif self.stage == 'hover':
            self.require_flight(s); keys.add('Prior')
            if self.control_pulses['roll']['released'] is not None: keys.add('h')
            if ('hover' in self.handling and s['up'][1] >= .94 and norm(s['ship_velocity']) <= .35
                    and self.control_pulses['roll']['released'] is not None):
                self.enter('camera_cockpit', s); self.tap('v', now)
        elif self.stage in ('camera_cockpit','camera_chase'):
            self.require_flight(s); keys.add('Prior')
            expected = 'COCKPIT' if self.stage == 'camera_cockpit' else self.initial['camera_view']
            if (s['camera_view'] == expected and 'camera_'+expected.lower() in self.handling
                    and self.tap_key is None and not s['native_control']['camera']
                    and now >= self.tap_cooldown and s['frame'] >= self.tap_release_frame+6):
                if self.stage == 'camera_cockpit':
                    self.enter('camera_chase', s); self.tap('v', now)
                else: self.enter('lane', s)
        elif self.stage == 'weapon_aim':
            self.require_flight(s); keys.add('Prior')
            dx,dy,align = self.weapon_aim(s, sub(s['target']['position'],s['camera']))
            if align > .99998 and norm(s['ship_velocity']) <= .35 and self.mouse_pending is None:
                require(not s['native_fire'] and s['target']['health'] == 100 and s['engine'] == 'ONLINE',
                        'stable unfired full-health real target before unique repeater pulse')
                self.weapon['pre_fire'] = self.weapon_receipt(s)
                self.tap('f', now); self.enter('weapon_fire', s); dx=dy=0
        elif self.stage == 'weapon_fire':
            keys.add('Prior')
            if 'hit' in self.weapon and self.tap_key is None and not s['native_fire']:
                self.enter('weapon_restore', s)
        elif self.stage == 'weapon_restore':
            keys.update(('Prior','h'))
            dx,dy,restored = self.restore_attitude(s, keys)
            if restored and norm(s['ship_velocity']) <= .35:
                self.weapon['restored'] = self.weapon_receipt(s)
                self.weapon['elapsed_seconds'] = now-self.weapon_started
                self.enter('return_capture', s)
        elif self.stage == 'land':
            keys.add('Prior')
            if s['landed'] and s['phase'] == 'SHUT_DOWN':
                require(self.landing_active_seen and self.landing_edges[self.flight] == 1,
                        'one acknowledged L follows observed actual landing to strict dock')
                self.require_home(s)
                require(s['landing']['elapsed'] <= self.landing_timeout and not s['landing']['last_abort_reason'],
                        'strict home arrived inside its actual preserved captured landing timeout')
                self.receipts[self.key_for('docked')] = self.receipt(s)
                self.neutral_frame = None; self.enter('shutdown', s); keys.clear()
            elif not self.landing_active_seen:
                require(s['frame']-self.stage_frame <= 120, 'single Zenith L must acknowledge within120physicsframes; no retry')
            elif not s['landing_active']:
                require(False, 'actual Zenith landing ended before strict home')
        elif self.stage == 'shutdown':
            self.require_home(s)
            if self.neutral_frame is not None and s['frame']-self.neutral_frame >= 90 and s['engine'] == 'OFFLINE':
                require(self.tap_key is None and not s['native_interact'] and not s['native_landing'],
                        'released landing key and ninety neutral own1.5s frames before real exit')
                self.receipts[self.key_for('offline')] = self.receipt(s)
                self.receipts[self.key_for('exit')] = self.receipt(s)
                self.tap('e',now); self.enter('exit',s)
        elif self.stage == 'exit':
            self.require_home(s)
            if not s['seated'] and not s['piloted'] and not s['transition_busy']:
                self.require_foot(s)
                require(norm(sub(s['player'],s['exit'])) < .8,
                        'same pilot physically leaves through live supported Zenith ExitPoint')
                self.receipts[self.key_for('exited')] = self.receipt(s)
                self.retired_stream = s['input_stream']
                self.enter('wing_port',s)
        elif self.stage in ('wing_port','wing_clear','reapproach'):
            self.require_foot(s); self.require_home(s)
            endpoint = self.stage
            dx,reached = self.walk_to(s, s['endpoints'][endpoint], keys)
            if reached:
                self.clear_paths[self.flight].append(self.receipt(s))
                if self.stage == 'wing_port': self.enter('wing_clear',s)
                elif self.stage == 'wing_clear':
                    require(s['boarding_distance'] > 7 and not s['reboard_blocked'],
                            'actual supported wing-clear walk releases production seven-metre reboard block')
                    self.receipts[self.key_for('wing_clear')] = self.receipt(s)
                    self.trips.append(dict(flight=self.flight+1, excursion_m=self.excursion,
                        neutral_frames=self.receipts[self.key_for('offline')]['frame']-self.neutral_frame))
                    if self.flight == 0: self.enter('reapproach',s)
                    else:
                        self.tap_key = None; self.enter('pause',s)
                elif s['candidate'] and not s['station_candidate'] and not s['native_interact']:
                    self.receipts['board_2'] = self.receipt(s)
                    self.tap('e',now); self.enter('board',s)
                elif s['station_candidate']:
                    # Same accepted LIFE-ARM look-away maneuver; no UI signal or reposition.
                    candidate = s['admission']['station_candidate']
                    if candidate:
                        away = [2*a-b for a,b in zip(s['player'],candidate['position'])]
                        dx,_,_ = self.admission.yaw_to(s['admission'], away)
        elif self.stage == 'board':
            if s['phase'] == 'START_ENGINES' and not s['transition_busy']:
                self.require_home(s)
                if self.reuse_pilot_ready(s):
                    self.board_streams.append(s['input_stream']); self.receipts['seated_2'] = self.receipt(s)
                    self.flight = 1; self.neutral_frame = None; self.enter('reuse_seated',s)
                else:
                    self.receipts.setdefault('reboard_pending_consumption',self.receipt(s))
        elif self.stage == 'reuse_seated':
            self.require_pilot(s); self.require_home(s)
            if s['frame']-self.stage_frame >= 90: self.enter('depart',s)
        else: require(False, 'known finite Zenith stage')
        if self.tap_key is not None:
            if now < self.tap_until or s['frame'] < self.tap_frame+6: keys.add(self.tap_key)
            else:
                self.tap_key = None; self.tap_cooldown=now+.3; self.tap_release_frame=s['frame']
        facing = s['walk_forward'] if not s['seated'] else s['camera_back']
        if self.mouse_pending is not None:
            if norm(sub(facing,self.mouse_pending)) < .00001: dx=dy=0
            else: self.mouse_pending=None
        if dx or dy: self.mouse_pending=facing[:]
        return keys,dx,dy,False

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.admission_result is not None and len(self.trips) == 2 and self.file_home
                and self.handling.get('boost',{}).get('speed',0) > 94
                and self.handling.get('roll',{}).get('roll_degrees',0) >= 30
                and set(self.control_pulses) == {'boost','roll'}
                and all(pulse['release_request'] is not None and pulse['released'] is not None
                        for pulse in self.control_pulses.values())
                and self.landing_edges == self.exit_edges == [1,1] and len(self.board_streams) == 2
                and self.board_streams[1] > self.board_streams[0]
                and all(key in self.handling for key in ('steering','boost','brake','roll','hover','camera_cockpit','camera_chase'))
                and 'hit' in self.weapon and 'restored' in self.weapon,
                'two genuine Zenith flights strict offline exits usable walks and normal HUD actualOS0')
        self.result = dict(completion_marker=self.MARKER, admission=self.admission_result,
            trips=self.trips, handling=self.handling, control_ticks=self.control_ticks, control_pulses=self.control_pulses, weapon=self.weapon, receipts=self.receipts,
            wing_clear_paths=self.clear_paths, source_streams=self.board_streams,
            landing_edges=self.landing_edges, last_active_landing=self.landing_last, normal_ui_exit=self.receipts['exit_ui'],
            same_actor_identities={k:self.initial[k] for k in self.IDS}, stages=self.stages,
            remaining=['component damage and passive repair','loss and regeneration','Torrent handback',
                       'retained Main lifecycle','asset and visual review','native hardware and human review'])
        return self.result


class GuidedExitPilot(Pilot):
    """Unchanged Guided flight, followed by ordinary pause controls and OS0."""
    IDS = ('pid', 'main_id', 'world_id', 'player_id', 'ship_id', 'source_id',
           'berth_id', 'opponent_id')

    def __init__(self):
        super().__init__()
        self.expected_pid = None
        self.initial = self.last_state = None
        self.guided_result = None
        self.receipts = {}
        self.ui_key = None
        self.ui_until = self.ui_release_until = 0
        self.quit_requested = False

    def validate_observation(self, s):
        require(s['mode'] == 'guided' and s['pid'] == self.expected_pid
                and all(s[k] > 0 for k in self.IDS), 'exact Guided process and actor identities')
        if self.initial is None:
            self.initial = copy.deepcopy(s)
        require(all(s[k] == self.initial[k] for k in self.IDS),
                'same Guided process world Player ship input home and opponent')
        if self.last_state is not None:
            require(s['sequence'] > self.last_state['sequence']
                    and s['frame'] >= self.last_state['frame'], 'ordered Guided observations')
        require(s['default_sampler'] and s['tuning_unchanged'] and not s['destroyed']
                and s['phase'] not in ('FAILED', 'RECOVERING'), 'live authored Guided sortie')
        if self.guided_result is None:
            require(not s['paused'] and s['gameplay_snapshot_fresh'], 'Guided gameplay remains unpaused')
        else:
            self.require_home(s)
            if s['paused']:
                require(not s['gameplay_snapshot_fresh'], 'paused UI snapshot never claims fresh Player motion')
        self.last_state = s

    def require_home(self, s):
        complete = self.receipts['complete']
        require(s['phase'] == 'COMPLETE' and s['guided_complete'] and not s['piloted']
                and not s['seated'] and s['control_enabled'] and s['active_ship']
                and s['exit_error'] < .25 and s['lease'] and s['parked_exact'] and s['contract']
                and s['landed'] and s['telemetry']['engine'] == 'OFFLINE'
                and s['home_lease_token'] and s['home_lease_token'] == complete['home_lease_token']
                and s['position'] == complete['position'],
                'original physical Guided exit strict home lease and automatic OFFLINE retained through UI exit')

    # This method uses only the shared UI pulse/focus fields initialized above.
    ui_update = ArrowReturnReusePilot.ui_update

    def update(self, s, now):
        require(self.last_state is s, 'latest validated Guided observation')
        if self.guided_result is not None:
            require(s['window_focused'], 'actual Guided window retains keyboard focus for UI controls')
            return self.ui_update(s, now)
        controls = super().update(s, now)
        if self.result is not None:
            self.guided_result, self.result = copy.deepcopy(self.result), None
            self.receipts['complete'] = copy.deepcopy(s)
            self.require_home(s)
            self.enter('pause', s)
            # Release the original disembarkation pulse before any UI key.
            self.tap_key = None
            self.ui_release_until = now+.10
            return set(), 0, 0, False
        return controls

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.guided_result is not None and 'exit_ui' in self.receipts,
                'full original Guided sortie and actual normal UI OS0 before success')
        self.require_home(self.last_state)
        self.result = dict(self.guided_result, normal_ui_exit=True, exit_code=exit_code,
                           receipts=self.receipts, same_actor_identities={k: self.initial[k] for k in self.IDS})
        return self.result


class TorrentReturnReusePilot(ArrowReturnReusePilot):
    """Full Guided sortie, then one ordinary same-Torrent home return and UI exit."""
    MODE = 'torrent-return-reuse'
    MARKER = 'NATIVE_TORRENT_RETURN_REUSE_OK'
    IDS = ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id',
           'ship_id', 'berth_id', 'source_id', 'seat_id', 'pid', 'opponent_id')
    FOOT_STAGES = ('reuse_release', 'reuse_clear', 'reuse_approach', 'reuse_walk', 'pause', 'quit_wait')

    def __init__(self):
        super().__init__()
        self.guided_result = None
        self.clear_target = self.walk_target = None
        self.clear_started = None
        self.neutral_frames = 0
        self.return_braking = self.launch_braking = False

    def require_home(self, s, contract=True):
        require(s['landed'] and s['parked_exact'] and s['lease'] and s['lease_token']
                and (not contract or s['contract']), 'strict current token-bound Torrent home lease')
        if self.guided_result is not None and 'departed_2' in self.receipts:
            require(s['lease_token'] != self.receipts['exited_1']['lease_token'],
                    'second home requires a fresh lease token after actual departure')
            if 'docked_2' in self.receipts:
                require(s['lease_token'] == self.receipts['docked_2']['lease_token'],
                        'same newly acquired second home lease through shutdown exit and walk')

    def require_foot(self, s):
        require(s['phase'] == 'COMPLETE' and s['guided_complete'] and not s['seated']
                and not s['piloted'] and not s['transition_busy'] and s['control_enabled']
                and s['capsule_enabled'] and s['grounded'] and s['supported']
                and s['support_collider'] and s['player_camera'] and s['engine'] == 'OFFLINE'
                and not s['flight_demand'], 'ordinary supported Torrent exit and walking')

    def validate_observation(self, s):
        require(s.get('mode') == self.MODE and s.get('actors_current'),
                'current ordinary Torrent observer actors')
        previous = self.observed_previous
        self.frame = s['frame']
        if self.initial is None:
            require(s['phase'] == 'INTRO' and not s['paused'] and not s['guided_complete']
                    and len(s['targets']) == 4 and not s['destroyed_targets'],
                    'fresh full Guided Torrent prerequisite')
            self.require_home(s, False)
            self.initial = s
        require(all(s[k] and s[k] == self.initial[k] for k in self.IDS)
                and s['capsule_geometry'] == self.initial['capsule_geometry'],
                'same Main world Player capsule Torrent seat input home and Guided opponent')
        require(s['definition_id'] == 'torrent_provisional' and s['home_id'] == 'central_berth'
                and s['default_sampler'] and s['default_controls'] and s['tuning_unchanged']
                and s['walk_tuning'] == LifeTowPilot.DEFAULT_WALK
                and s['ship_tuning'] == self.initial['ship_tuning']
                and s['physics_ticks'] == 60 and s['time_scale'] == 1
                and not s['destroyed'] and not s['remote_piloted'], 'authored live Torrent and ordinary controls')
        if previous:
            require(s['sequence'] == previous['sequence']+1 and s['frame'] == previous['frame']+1,
                    'every consecutive Torrent physics observation retained')
        self.observations += 1
        if s['paused']:
            require(self.stage in ('pause', 'quit_wait') and len(self.trips) == 2
                    and 'walked_2' in self.receipts, 'normal pause follows second supported exit walk')
        if self.stage == 'shutdown' or self.stage == 'reuse_shutdown':
            self.require_home(s)
            self.neutral_frames = self.neutral_frames+1 if not s['flight_demand'] and s['engine'] == 'OFFLINE' else 0
        if s['native_interact'] and not (previous and previous['native_interact']):
            self.native_edges.append({'frame': s['frame'], 'stage': self.stage, 'flight': self.flight+1})
        confirmation = s['boarding_confirmation'].get('adapter', {}).get('view', {}).get('state')
        require(confirmation != 'rejected', 'production Torrent boarding confirmation must not reject')
        if self.guided_result is not None:
            require(s['guided_complete'] and not s['targets'] and s['destroyed_targets'] == 4
                    and not s['opponent_active'] and not s['guided_return_authorized'],
                    'completed Guided targets opponent and return authorization stay retired during reuse')
            require(s['phase'] in ('COMPLETE', 'BOARDING', 'START_ENGINES', 'FREE_FLIGHT',
                                   'SHUT_DOWN', 'DISEMBARKING'), 'ordinary post-Guided lifecycle only')
            if self.stage in self.FOOT_STAGES:
                self.require_foot(s); self.require_home(s)
                if previous and not previous['transition_busy'] and not previous['seated']:
                    step = norm(sub(s['player'], previous['player']))
                    require(step <= LifeTowPilot.DEFAULT_WALK['sprint']/60*1.25+.02,
                            'continuous supported Torrent walking without teleport')
                    self.walked += step
            if s['phase'] == 'BOARDING':
                request = self.receipts.get('board_2')
                require(self.stage == 'board' and request is not None
                        and request['candidate'] and request['boarding_distance'] <= 7
                        and not request['station_candidate'] and not request['reboard_blocked']
                        and self.receipts['walk_clear']['frame'] < request['frame'] < s['frame']
                        and all(request[k] == s[k] for k in self.IDS)
                        and any(e['stage'] == 'board' and e['flight'] == 2 for e in self.native_edges)
                        and s['transition_busy'] and s['boarding_reserved'] and confirmation == 'boarding',
                        'fresh current candidate native E and reservation before second boarding')
                self.boarding_seen = True
            if s['phase'] in ('START_ENGINES', 'FREE_FLIGHT', 'SHUT_DOWN'):
                require(s['seated'] and s['seated_at_pilot'] and s['piloted'] and s['active_ship']
                        and s['ship_camera'] and not s['capsule_enabled'], 'same actual Torrent pilot and flight command owner')
            if self.stage == 'reuse_launch':
                self.thrust_seen |= s['native_thrust'] and s['flight_demand'] and s['engine'] == 'ONLINE'
                self.excursion = max(self.excursion, norm(sub(s['position'], s['parked'])))
                self.departed |= self.thrust_seen and s['phase'] == 'FREE_FLIGHT' and not s['landed'] and s['lease_free'] and self.excursion > 8
            if self.stage == 'reuse_land': self.landing_seen |= s['native_landing']
        if s['phase'] == 'DISEMBARKING':
            self.require_home(s)
            require(s['engine'] == 'OFFLINE' and self.neutral_frames >= 90,
                    'strict home and automatic OFFLINE after ordinary 90-frame neutral shutdown')
            if self.guided_result is None:
                require(self.stage == 'exit' and confirmation == 'disembarking'
                        and any(e['stage'] == 'exit' and e['flight'] == 1 for e in self.native_edges),
                        'native first Guided exit and actual physical disembarkation')
                self.disembarking_seen = True
            else:
                request = self.receipts.get('exit_2')
                require(self.stage == 'exit' and request is not None and request['engine'] == 'OFFLINE'
                        and request['contract'] and all(request[k] == s[k] for k in self.IDS)
                        and any(e['stage'] == 'exit' and e['flight'] == 2 for e in self.native_edges)
                        and confirmation == 'disembarking', 'distinct native E and physical second disembarkation')
                self.disembarking_seen = True
        if s['phase'] == 'SHUT_DOWN': self.require_home(s)
        self.observed_previous = self.last_state = s

    def walk_to(self, s, target, keys):
        return super().walk_to({**s, 'velocity': s['player_velocity']}, target, keys)

    def update(self, s, now):
        require(self.last_state is s, 'latest already-validated Torrent observation')
        if self.guided_result is None:
            # Retain Pilot's full Guided route while requiring a settled
            # neutral OFFLINE interval before its ordinary exit press.
            if self.stage == 'shutdown' and self.neutral_frames < 90:
                return set(), 0, 0, False
            controls = Pilot.update(self, s, now)
            if self.result is not None:
                self.require_home(s); self.require_foot(s)
                require(self.neutral_frames >= 90 and self.disembarking_seen,
                        'first home retained automatic neutral shutdown and physical exit')
                self.guided_result, self.result = self.result, None
                self.receipts['exited_1'] = self.receipt(s)
                self.trips.append({'flight': 1, 'excursion_m': self.max_excursion,
                                   'neutral_frames': self.neutral_frames})
                self.flight = 1
                self.boarding_seen = self.disembarking_seen = False
                self.enter('reuse_release', s)
            return controls
        self.frame = s['frame']
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        if self.stage in ('pause', 'quit_wait'): return self.ui_update(s, now)
        keys, dx, dy = set(), 0, 0
        speed = norm(s['ship_velocity'])
        if self.stage == 'reuse_release':
            if self.tap_key is None and not s['native_interact']:
                off = sub(s['player'], s['boarding']); off[1] = 0
                require(norm(off) > .1 and s['reboard_blocked'], 'actual blocked first Torrent exit')
                self.clear_target = [p+max(4, 8-norm(off))*d for p,d in zip(s['player'], unit(off))]
                self.clear_started = now
                self.enter('reuse_clear', s)
        elif self.stage == 'reuse_clear':
            require(now-self.clear_started <= 12, 'existing 12-second supported reboard-clear budget')
            dx, reached = self.walk_to(s, self.clear_target, keys)
            if reached:
                require(s['boarding_distance'] > 7 and not s['reboard_blocked'], 'physical clear walk releases ordinary reboard block')
                self.clear_seen = True
                self.receipts['walk_clear'] = self.receipt(s)
                self.enter('reuse_approach', s)
        elif self.stage == 'reuse_approach':
            require(not s['reboard_blocked'], 'same Torrent stays ordinarily available after clear walk')
            if s['candidate'] and not s['station_candidate'] and s['boarding_distance'] <= 7 and norm(s['player_velocity']) <= .35:
                self.request_e('board', s, now)
            else: dx, _ = self.walk_to(s, s['boarding'], keys)
        elif self.stage == 'board' and s['phase'] == 'START_ENGINES' and not s['transition_busy']:
            require(self.boarding_seen and s['boarding_confirmation'].get('adapter', {}).get('view', {}).get('state') == 'seated',
                    'actual second Torrent boarding transition completed')
            self.require_home(s)
            self.receipts['seated_2'] = self.receipt(s)
            self.departed = self.thrust_seen = self.landing_seen = False
            self.excursion = 0
            self.launch_braking = self.return_braking = False
            self.enter('reuse_launch', s)
        elif self.stage == 'reuse_launch':
            target = [0, 8, -78]
            off = sub(target, s['position']); distance = norm(off)
            dx, dy, align = self.aim(s, [p+d for p,d in zip(s['camera'], off)])
            stopping = speed*speed/(2*s['tuning']['brake'])+speed*.18
            if distance < stopping+5.75: self.launch_braking = True
            if speed <= .45 and distance > 5: self.launch_braking = False
            if distance <= 5 or self.launch_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if distance <= 5 and speed <= .45:
                require(self.departed and s['phase'] == 'FREE_FLIGHT', 'actual second native-thrust lease-free Torrent departure exceeds 8m')
                self.receipts['departed_2'] = self.receipt(s)
                self.enter('reuse_return_align', s)
        elif self.stage == 'reuse_return_align':
            keys.update(('Prior', 'h'))
            off = sub([0, 2, -18], s['position'])
            dx, dy, align = self.aim(s, [p+d for p,d in zip(s['camera'], off)])
            if align > .98 and s['upright'] > .94 and speed <= .8: self.enter('reuse_return', s)
        elif self.stage == 'reuse_return':
            off = sub([0, 2, -18], s['position']); distance = norm(off)
            dx, dy, align = self.aim(s, [p+d for p,d in zip(s['camera'], off)])
            stopping = speed*speed/(2*s['tuning']['brake'])+speed*.18
            if distance < stopping+1.75: self.return_braking = True
            if speed <= .45 and distance > 1: self.return_braking = False
            if distance <= 1 or self.return_braking: keys.add('Prior')
            elif align > .72: keys.add('w')
            if distance <= 1 and speed <= .45: self.enter('reuse_align_berth', s)
        elif self.stage == 'reuse_align_berth':
            keys.update(('Prior', 'h'))
            off = sub(s['parked'], s['position'])
            dx, dy, align = self.aim(s, [p+d for p,d in zip(s['camera'], off)])
            if align > .995 and s['upright'] > .94 and speed <= .35:
                require(s['capture'], 'registered second Torrent home capture')
                self.tap('l', now)
                if self.tap_key == 'l': self.enter('reuse_land', s)
        elif self.stage == 'reuse_land':
            keys.add('Prior')
            if s['phase'] == 'SHUT_DOWN' and s['landed']:
                require(self.departed and self.landing_seen, 'second departure and native L before second home')
                self.require_home(s)
                self.receipts['docked_2'] = self.receipt(s)
                self.neutral_frames = 0
                keys.clear(); self.enter('reuse_shutdown', s)
            elif not s['landing_active'] and s['capture']: self.tap('l', now)
        elif self.stage == 'reuse_shutdown' and s['engine'] == 'OFFLINE' and self.neutral_frames >= 90:
            self.receipts['offline_2'] = self.receipt(s)
            self.request_e('exit', s, now)
        elif self.stage == 'exit' and s['phase'] == 'COMPLETE' and not s['transition_busy']:
            self.require_foot(s); self.require_home(s)
            require(self.disembarking_seen and norm(sub(s['player'], s['exit'])) < .65,
                    'actual separate native E second supported physical Torrent exit')
            self.receipts['exited_2'] = self.receipt(s)
            self.trips.append({'flight': 2, 'excursion_m': self.excursion, 'neutral_frames': self.neutral_frames})
            off = sub(s['player'], s['boarding']); off[1] = 0
            self.walk_target = [p+d for p,d in zip(s['player'], unit(off))]
            self.enter('reuse_walk', s)
        elif self.stage == 'reuse_walk':
            dx, reached = self.walk_to(s, self.walk_target, keys)
            if reached and norm(sub(s['player'], self.receipts['exited_2']['player'])) >= .5 \
                    and self.frame-self.receipts['exited_2']['frame'] >= 20:
                self.receipts['walked_2'] = self.receipt(s)
                self.tap_key = None
                self.enter('pause', s)
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame+6: keys.add(self.tap_key)
            else:
                self.tap_key = None; self.tap_cooldown = now+.3; self.tap_release_frame = self.frame
        # Preserve the accepted walking mouse acknowledgement fence. Flight
        # uses Pilot's existing bounded mouse law without this on-foot fence.
        if self.stage in self.FOOT_STAGES:
            if self.mouse_pending is not None:
                if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
                else: self.mouse_pending = None
            if dx: self.mouse_pending = s['walk_forward'][:]
        return keys, dx, dy, False

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.guided_result is not None and len(self.trips) == 2 and self.clear_seen
                and all(k in self.receipts for k in ('exited_1', 'walk_clear', 'board_2', 'seated_2',
                    'departed_2', 'docked_2', 'offline_2', 'exited_2', 'walked_2', 'exit_ui'))
                and all(t['excursion_m'] > 8 and t['neutral_frames'] >= 90 for t in self.trips),
                'full Guided prefix two strict returns usable second exit and actual normal UI OS0 before success')
        self.result = {'completion_marker': self.MARKER, 'guided_prerequisite': self.guided_result,
                       'trips': self.trips, 'receipts': self.receipts, 'walked_m': self.walked,
                       'native_interact_edges': self.native_edges, 'physics_observations': self.observations,
                       'normal_ui_exit': True, 'scope': 'partial CRAFT-ACCEPT-TORRENT return and reuse capability',
                       'weapons_damage_recovery_crosscraft_main_acceptance': 'NOT_RUN'}
        return self.result


class TorrentDamagedReturnPilot(TorrentReturnReusePilot):
    """One ordinary incoming contact, persistent airborne damage and real berth repair."""
    MODE = 'torrent-damaged-return'
    MARKER = 'NATIVE_TORRENT_DAMAGED_RETURN_OK'
    COMPONENTS = ('forward_hull', 'port_wing', 'starboard_wing', 'core_systems', 'engine_bay')
    CHANNELS = {'port_wing': 'fire', 'starboard_wing': 'fire',
                'core_systems': 'targeting', 'engine_bay': 'mobility'}

    def __init__(self):
        super().__init__()
        self.damage_initial = self.damage_previous = self.incoming = None
        self.airborne_frames = self.airborne_run = 0
        self.airborne_proof = None
        self.repair_start = self.repaired = self.repair_baseline = None

    def states(self, d):
        rows = d['components']
        require(len(rows) == 5 and {r['id'] for r in rows} == set(self.COMPONENTS),
                'complete five-component scalar snapshot')
        require(all(math.isfinite(r['integrity']) and 0 <= r['integrity'] <= 1 for r in rows),
                'finite bounded component integrities')
        return {r['id']: r for r in rows}

    def same_model(self, d):
        require(all(d[k] > 0 and d[k] == self.damage_initial[k]
                    for k in ('model_id', 'generation', 'authority_id', 'damageable_id')),
                'same live component model generation authority and damageable without reset')
        require(d['opponent_tuning'] == self.damage_initial['opponent_tuning']
                and d['repair_rate'] == self.damage_initial['repair_rate'] == .62,
                'unchanged defender tuning and authored passive repair rate')

    def require_channels(self, d, damaged=None):
        modifiers = d['modifiers']
        expected = self.CHANNELS.get(damaged)
        for channel in ('mobility', 'fire', 'targeting'):
            require(not modifiers[channel+'_disabled'] and modifiers[channel+'_multiplier'] > 0,
                    'live mobility fire and targeting remain usable')
            if damaged is not None:
                require(math.isclose(modifiers[channel+'_multiplier'], .62 if channel == expected else 1,
                                     abs_tol=.0001), 'actual attributed impaired component declared consequence')

    def require_incoming(self, hit, s, d):
        h = hit['snapshot']; self.same_model(h)
        context, request = hit['context'], hit['request']
        require(all(hit[k] for k in ('present', 'accepted', 'resolved', 'hit', 'damaged'))
                    and not hit['destroyed'] and hit['request_matches']
                    and hit['source_entity_id'] == request['source_entity_id'] == s['opponent_id']
                    and hit['source_id'] == request['source_id'] == context['source_id'] == 2101
                    and request['weapon_id'] == context['weapon_id'] == 'defence_pulse_cannon'
                    and context['source_entity_id'] == s['opponent_id']
                    and request['sequence'] == context['sequence']
                    and hit['target_entity_id'] == context['target_id'] == s['ship_id']
                    and hit['damageable_id'] == d['damageable_id'] and hit['collider_id'] > 0
                    and hit['contact_finite'] and context['contact_finite']
                    and hit['position'] == context['position']
                    and hit['applied_damage'] == request['damage'] == 11 and hit['remaining_health'] == h['hull']
                    and hit['frame'] <= s['frame']
                    and hit['phase'] == 'INTERCEPTOR_ENGAGEMENT' and hit['opponent_active']
                    and hit['opponent_health'] > 0 and not h['landed'] and not h['landing_active'],
                    'genuine current defender source2101 finite-contact damageable incoming receipt')

    def validate_damage(self, s):
        d = s['damage']
        rows = self.states(d)
        previous = self.damage_previous
        if self.damage_initial is None:
            require(d['hull'] == d['maximum_hull'] == 100 and all(
                r['integrity'] == 1 and r['state_id'] == 'nominal' for r in rows.values())
                and not d['incoming'] and d['incoming_count'] == d['repair_count'] == 0 and d['incoming_damage'] == 0,
                'pristine authored Torrent starts before real incoming damage')
            self.damage_initial = copy.deepcopy(d)
        self.same_model(d)
        if previous:
            require(d['repair_count'] >= previous['repair_count'] and d['incoming_count'] >= previous['incoming_count']
                    and d['incoming_damage'] >= previous['incoming_damage']
                    and d['revision'] >= previous['revision'], 'retained damage repair receipts and ledger never regress')
        self.require_channels(d)
        require(d['maximum_hull'] == 100 and d['hull'] > 0 and not d['incoming_violation']
                and d['incoming_damage'] == d['incoming_count']*11
                and d['hull'] == 100-d['incoming_damage'], 'only actual cumulative live defender damage without healing')
        if not self.incoming and d['incoming']:
            hit = d['incoming']; h = hit['snapshot']; self.same_model(h)
            hr = self.states(h); context = hit['context']; request = hit['request']
            self.require_incoming(hit, s, d)
            require(h['hull'] == 89 and hit['cumulative_damage'] == 11 and hit['opponent_health'] == 85
                    and not hit['native_fire'] and not hit['command_fire'], 'exact clean first incoming contact')
            damaged = [k for k in self.COMPONENTS if hr[k]['integrity'] < 1]
            require(len(damaged) == 1 and math.isclose(hr[damaged[0]]['integrity'], .56, abs_tol=.0001)
                    and hr[damaged[0]]['state_id'] == 'impaired'
                    and all(hr[k]['state_id'] == 'nominal' for k in self.COMPONENTS if k != damaged[0]),
                    'first real eleven-point hit attributes exactly one impaired component')
            self.require_channels(h, damaged[0])
            self.incoming = copy.deepcopy(hit)
            self.receipts['incoming_damage'] = {**copy.deepcopy(hit), 'component': damaged[0]}
        if not self.incoming:
            require(d['hull'] == 100 and all(r['integrity'] == 1 for r in rows.values())
                    and d['repair_count'] == 0, 'no unattributed damage or repair before incoming receipt')
        else:
            self.require_incoming(d['incoming_last'], s, d)
            require(d['incoming_last']['cumulative_damage'] == d['incoming_damage']
                    and d['incoming_last']['remaining_health'] == d['hull'],
                    'retained last genuine hit and cumulative hull loss')
            if not d['landed']:
                require(d['repair_count'] == 0 if self.repair_start is None else
                        d['repair_count'] == previous['repair_count'], 'no passive repair while airborne')
                if previous:
                    prior = self.states(previous)
                    require(all(rows[k]['integrity'] <= prior[k]['integrity']+.0001 for k in self.COMPONENTS),
                            'no airborne component integrity increase')
                if self.repair_start is None and s['frame'] > self.incoming['frame']:
                    self.airborne_run += 1
            eligible = d['landed'] and not d['landing_active']
            if eligible and self.repair_start is None:
                require(self.airborne_run >= 90, 'ninety consecutive damaged airborne frames before first home')
                self.airborne_frames = self.airborne_run
                self.airborne_proof = {'frames': self.airborne_run, 'last_airborne_frame': s['frame']-1}
                self.repair_baseline = copy.deepcopy(previous)
                self.require_home(s)
                self.repair_start = min(s['frame'], d['repair_first'].get('frame', s['frame']))
            if d['landed']:
                self.airborne_run = 0
            require(not d['repair_violation'], 'every passive repair commit is strictly landed and token bound')
            if d['repair_count']:
                require(self.repair_start is not None, 'real passive repair follows eligible strict home')
                first, last = d['repair_first'], d['repair_last']
                for event in (first, last):
                    self.same_model(event['snapshot'])
                    require(event['origin'] == 'passive_berth' and event['generation'] == d['generation']
                            and event['strict_home'] and event['snapshot']['hull'] == d['hull'],
                            'actual same-ledger passive berth commit without hull healing')
                require(last['revision'] >= first['revision'] > self.incoming['snapshot']['revision'],
                        'passive commits advance the actual damaged ledger')
                first_rows, last_rows = self.states(first['snapshot']), self.states(last['snapshot'])
                baseline_rows = self.states(self.repair_baseline)
                require(any(r['integrity'] < 1 for r in baseline_rows.values())
                        and all(math.isclose(first_rows[k]['integrity'], min(1., baseline_rows[k]['integrity']+.62/60), abs_tol=.0001)
                                for k in self.COMPONENTS)
                        and all(math.isclose(last_rows[k]['integrity'], rows[k]['integrity'], abs_tol=.0001)
                                for k in self.COMPONENTS)
                        and last['snapshot']['revision'] == d['revision'],
                        'real passive pulses explain current restored component integrities')
            nominal = all(r['integrity'] == 1 and r['state_id'] == 'nominal' for r in rows.values())
            effects_clear = all(d['effects'][k] == 0 for k in ('localized', 'repair_cues', 'pending', 'impacts'))
            if self.repair_start is not None and self.repaired is None:
                require(s['frame']-self.repair_start < 180,
                        'existing component integration repair and presentation bound under180 physics frames')
                if nominal and effects_clear:
                    self.require_home(s)
                    require(d['repair_count'] > 0 and all(d['modifiers'][k+'_multiplier'] == 1
                            for k in ('mobility', 'fire', 'targeting')), 'real passive repair restores all nominal channels')
                    self.repaired = copy.deepcopy(d)
                    self.receipts['passive_repaired'] = {'frame': s['frame'], 'eligible_frame': self.repair_start,
                        'airborne_frames': self.airborne_frames, 'airborne_run': self.airborne_proof,
                        'pre_repair': self.repair_baseline, 'snapshot': self.repaired}
            if self.repaired is not None:
                require(nominal and effects_clear, 'repaired component state and effects persist through usable continuation')
        self.damage_previous = copy.deepcopy(d)

    def validate_observation(self, s):
        super().validate_observation(s)
        self.validate_damage(s)

    def update(self, s, now):
        if self.guided_result is None and self.stage == 'interceptor' and self.incoming is None:
            require(s['phase'] == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                    and s['opponent_health'] == 85 and s['seated'] and s['piloted']
                    and s['active_ship'] and s['ship_camera'] and not s['landing_active'],
                    'ordinary live interceptor wait with player fire released')
            dx, dy, _ = self.aim(s, s['opponent'], .2)
            return {'Prior'}, dx, dy, False
        if self.guided_result is None and self.stage == 'shutdown' and self.repaired is None:
            return set(), 0, 0, False
        return super().update(s, now)

    def finish(self, exit_code):
        require(self.incoming is not None and self.repaired is not None and self.airborne_frames >= 90,
                'actual incoming impairment airborne persistence and passive repair before completion')
        result = super().finish(exit_code)
        result.update(scope='partial CRAFT-ACCEPT-TORRENT one incoming component damage and passive repair capability',
                      all_component_stages_destruction_crosscraft_main_acceptance='NOT_RUN')
        return result


class TorrentArrowHandoffPilot(TorrentDamagedReturnPilot):
    """Accepted damaged return/reuse, then physical Arrow handoff and Torrent reclaim."""
    MODE = 'torrent-arrow-handoff'
    MARKER = 'NATIVE_TORRENT_ARROW_HANDOFF_OK'
    TORRENT, ARROW = 'torrent_provisional', 'arrow_provisional'
    HULL_IDS = ('ship_id', 'source_id', 'seat_id', 'area_id', 'berth_id')
    WALK_STAGES = ('handoff_clear', 'handoff_to_arrow', 'handoff_to_torrent', 'handoff_final_walk')

    def __init__(self):
        super().__init__()
        self.handoff_initial = self.handoff_previous = None
        self.handoff_started = False
        self.handoff_receipts, self.handoff_edges, self.retired = {}, [], {}
        self.handoff_route, self.handoff_visited = [], []
        self.handoff_goal_since = self.handoff_clear_since = None
        self.handoff_neutral = 0
        self.handoff_clear_target = self.handoff_final_target = None

    def handoff_receipt(self, s):
        return {'frame': s['frame'], 'sequence': s['sequence'], 'phase': s['phase'],
                'player': s['player'][:], 'seated': s['seated'], 'transition_busy': s['transition_busy'],
                'handoff': copy.deepcopy(s['handoff'])}

    def validate_handoff_actors(self, s, active=False):
        h = s['handoff']
        require(h['actors_current'] and set(h['fleet']) == {self.TORRENT, self.ARROW},
                'two current physical handoff actors')
        if self.handoff_initial is None: self.handoff_initial = copy.deepcopy(h)
        require(h['active_ship_id'] in {r['ship_id'] for r in h['fleet'].values()}
                and all(r['active'] == (r['ship_id'] == h['active_ship_id']) for r in h['fleet'].values()),
                'current active craft identity agrees with both physical actor rows')
        for key in (self.TORRENT, self.ARROW):
            row, initial = h['fleet'][key], self.handoff_initial['fleet'][key]
            require(row['actors_current'] and all(row[k] > 0 and row[k] == initial[k] for k in self.HULL_IDS)
                    and row['definition_id'] == key and row['home_id'] == initial['home_id']
                    and row['default_sampler'] and row['tuning_unchanged'] and row['tuning'] == initial['tuning']
                    and not row['destroyed'] and not row['remote_piloted'],
                    'same physical hull seat source berth and authored tuning through handoff')
            if key == self.ARROW or active:
                require(row['parked_exact'] and row['landed'] and not row['landing_active'] and row['lease']
                        and row['lease_token'] and row['engine'] == 'OFFLINE' and not row['flight_demand']
                        and norm(row['velocity']) < .0001,
                        'both handoff hulls remain secured parked landed offline without flight demand')
            if active and 'prerequisite' in self.handoff_receipts:
                require(row['lease_token'] == self.handoff_receipts['prerequisite']['handoff']['fleet'][key]['lease_token'],
                        'stationary handoff preserves each current occupied berth lease')
            if key == self.ARROW:
                require(row['hull'] == initial['hull'], 'Arrow handoff preserves its original intact hull')
        return h

    def require_handoff_foot(self, s):
        require(s['phase'] == 'COMPLETE' and not s['seated'] and not s['transition_busy']
                and s['control_enabled'] and s['capsule_enabled'] and s['player_camera']
                and s['grounded'] and s['supported'] and s['support_collider']
                and not s['handoff']['piloting'], 'supported ordinary walking between physical craft')
        require(all(not r[k] for r in s['handoff']['fleet'].values()
                    for k in ('piloted', 'seated', 'camera', 'reserved', 'player_reservation')),
                'on-foot handoff releases both old pilot seats cameras and reservations')

    def remember_retired(self, key, s, after_stream=None):
        row = s['handoff']['fleet'][key]
        require(not row['piloted'] and not row['seated'] and not row['camera']
                and not row['reserved'] and row['pending'] == 0 and row['command_neutral'],
                'retired craft is unpiloted neutral and has no undelivered ownership claims')
        if after_stream is not None:
            require(row['stream'] > after_stream, 'physical exit retires the prior producer stream epoch')
        self.retired[key] = {k: row[k] for k in ('stream', 'next_sequence', 'delivery_generation')}

    def require_handoff_exit_home(self, key, row):
        if key == self.ARROW:
            require(row['physical_strict'] and row['occupant_id'] == row['ship_id']
                    and row['reservation_owner_id'] == row['ship_id'] and row['reserved_ship_id'] == key
                    and row['lease_token'] and row['main_lease_token'] == row['lease_token']
                    and row['main_berth_id'] == row['home_id'],
                    'Arrow exit uses actual strict physical dock and exact Main-bound occupied berth lease')
        else:
            require(row['contract'], 'Torrent reclaim retains its actual prior strict landing contract')

    def require_exit_consumer(self, key, label, s):
        request = self.handoff_receipts.get(label+'_press')
        require(request is not None, 'physical exit requires a fresh current native E request')
        row, h = s['handoff']['fleet'][key], s['handoff']
        edge = row['interact']
        require(edge and edge['native'] and edge['valid'] and edge['current']
                and edge['ship_id'] == row['ship_id'] and edge['source_id'] == row['source_id']
                and edge['stream'] == row['stream'] == request['handoff']['fleet'][key]['stream']
                and request['frame'] < edge['frame'] <= s['frame']
                and h['consumed_ship_id'] == row['ship_id'] and h['consumed_stream'] == edge['stream']
                and h['consumed_sequence'] >= edge['sequence']
                and h['active_ship_id'] == row['ship_id'] and row['active']
                and any(e['stage'] == self.stage and e['frame'] > request['frame'] for e in self.handoff_edges),
                'native E reaches the current craft producer stream and actual transition consumer')
        if label+'_transition' not in self.handoff_receipts:
            self.handoff_receipts[label+'_transition'] = self.handoff_receipt(s)

    def validate_handoff(self, s):
        h = self.validate_handoff_actors(s, True)
        previous = self.handoff_previous
        require(self.guided_result is not None and len(self.trips) == 2 and 'walked_2' in self.receipts
                and self.repaired is not None and s['damage']['hull'] == self.repaired['hull']
                and s['guided_complete'] and not s['targets'] and s['destroyed_targets'] == 4
                and not s['opponent_active'] and not s['guided_return_authorized'],
                'full accepted damaged two-home prerequisite retained during physical handoff')
        require(s['mode'] == self.MODE and s['actors_current']
                and all(s[k] == self.initial[k] and s[k] for k in self.IDS)
                and s['capsule_geometry'] == self.initial['capsule_geometry']
                and s['default_controls'] and s['default_sampler'] and s['tuning_unchanged']
                and s['walk_tuning'] == LifeTowPilot.DEFAULT_WALK and s['ship_tuning'] == self.initial['ship_tuning']
                and s['physics_ticks'] == 60 and s['time_scale'] == 1,
                'same Main Player capsule Torrent and authored input throughout physical handoff')
        require(s['sequence'] == self.observed_previous['sequence']+1
                and s['frame'] == self.observed_previous['frame']+1,
                'all consecutive handoff physics observations retained')
        require(s['phase'] in ('COMPLETE', 'BOARDING', 'START_ENGINES', 'DISEMBARKING'),
                'physical handoff has no launch or other craft flight phase')
        if s['paused']:
            require(self.stage in ('pause', 'quit_wait') and 'torrent_walked' in self.handoff_receipts,
                    'normal UI quit follows completed Arrow exit and usable Torrent reclaim')
        if s['native_interact'] and not self.observed_previous['native_interact']:
            self.handoff_edges.append({'frame': s['frame'], 'stage': self.stage})
        confirmation = s['boarding_confirmation'].get('adapter', {}).get('view', {}).get('state')
        require(confirmation != 'rejected', 'normal handoff boarding or exit must not reject')
        for key, retired in self.retired.items():
            row = h['fleet'][key]
            require(not row['piloted'] and not row['seated'] and not row['camera']
                    and not row['reserved'] and row['pending'] == 0 and row['command_neutral'],
                    'inactive old craft stays neutral without stale seat camera reservation or delivery')
            if not s['paused'] and previous is not None and not previous['paused']:
                require(all(row[k] == retired[k] for k in retired),
                        'unpaused retired producer stream and cursor remain unconsumed')
            elif s['paused']:
                self.retired[key] = {k: row[k] for k in retired}
        if self.stage in self.WALK_STAGES or self.stage in ('handoff_release', 'handoff_arrow_ready', 'handoff_torrent_ready', 'pause', 'quit_wait'):
            self.require_handoff_foot(s)
            if previous is not None and not previous['transition_busy'] and not previous['seated']:
                step = norm(sub(s['player'], previous['player']))
                require(step <= LifeTowPilot.DEFAULT_WALK['sprint']/60*1.25+.02,
                        'continuous physical handoff walking without teleport')
                self.walked += step
        if s['phase'] == 'BOARDING':
            key, label = (self.ARROW, 'arrow_board') if self.stage == 'handoff_arrow_board' else (self.TORRENT, 'torrent_board')
            request = self.handoff_receipts.get(label+'_press')
            row = h['fleet'][key]
            require(self.stage == 'handoff_'+label and request is not None
                    and request['frame'] < s['frame'] and request['handoff']['fleet'][key]['candidate']
                    and request['handoff']['fleet'][key]['boarding_distance'] <= 7
                    and not request['handoff']['fleet'][key]['reboard_blocked']
                    and any(e['stage'] == self.stage and e['frame'] > request['frame'] for e in self.handoff_edges)
                    and row['active'] and row['reserved'] and row['player_reservation']
                    and s['transition_busy'] and confirmation == 'boarding',
                    'fresh current physical candidate native E and correct reserved actor before boarding')
        if s['seated'] and not s['transition_busy']:
            key = self.ARROW if self.stage.startswith('handoff_arrow') else self.TORRENT
            row, other = h['fleet'][key], h['fleet'][self.TORRENT if key == self.ARROW else self.ARROW]
            require(row['active'] and row['piloted'] and row['seated'] and row['camera']
                    and row['reserved'] and row['player_reservation'] and h['piloting']
                    and not other['piloted'] and not other['seated'] and not other['camera']
                    and not s['capsule_enabled'] and not s['player_camera'],
                    'one correct current physical seat camera and input consumer')
        if self.stage in ('handoff_arrow_neutral', 'handoff_torrent_neutral'):
            key = self.ARROW if self.stage == 'handoff_arrow_neutral' else self.TORRENT
            row = h['fleet'][key]
            require(row['command_valid'] and row['command_neutral'] and row['command_stream'] == row['stream']
                    and row['source_enabled'] and row['next_sequence'] > row['command_sequence'],
                    'current seated craft consumes its own fresh ordinary neutral commands')
            self.handoff_neutral += 1
        if s['phase'] == 'DISEMBARKING':
            key, label = (self.ARROW, 'arrow_exit') if self.stage == 'handoff_arrow_exit' else (self.TORRENT, 'torrent_exit')
            require(self.stage == 'handoff_'+label and self.handoff_neutral >= 90
                    and confirmation == 'disembarking',
                    'separate physical current-craft exit follows ninety neutral offline frames and secured home')
            self.require_handoff_exit_home(key, h['fleet'][key])
            if label+'_transition' not in self.handoff_receipts: self.require_exit_consumer(key, label, s)
        self.frame = s['frame']; self.observations += 1
        self.observed_previous = self.last_state = s
        self.handoff_previous = s
        self.validate_damage(s)

    def validate_observation(self, s):
        if self.handoff_started: return self.validate_handoff(s)
        self.validate_handoff_actors(s)
        return super().validate_observation(s)

    def begin_handoff_walk(self, stage, goals, s):
        self.handoff_route = [list(goal) for goal in goals]
        self.handoff_goal_since = None; self.mouse_pending = None
        self.enter(stage, s)

    def request_handoff_e(self, label, key, s, now):
        row = s['handoff']['fleet'][key]
        if self.tap_key is not None or s['native_interact']: return
        if label.endswith('board'):
            require(row['candidate'] and row['boarding_distance'] <= 7 and not row['reboard_blocked']
                    and not s['station_candidate'], 'fresh current physical boarding candidate before native E')
        self.tap('e', now)
        if self.tap_key == 'e':
            if label.endswith('board'): self.retired.pop(key, None)
            self.handoff_receipts[label+'_press'] = self.handoff_receipt(s)
            self.enter('handoff_'+label, s)

    def update(self, s, now):
        if not self.handoff_started:
            controls = super().update(s, now)
            if self.stage == 'pause' and 'walked_2' in self.receipts:
                self.handoff_started = True; self.handoff_previous = s
                self.handoff_receipts['prerequisite'] = self.handoff_receipt(s)
                self.remember_retired(self.TORRENT, s)
                self.remember_retired(self.ARROW, s)
                self.enter('handoff_release', s)
            return controls
        require(self.last_state is s, 'latest validated physical handoff observation')
        if self.stage in ('pause', 'quit_wait'): return self.ui_update(s, now)
        keys, dx, dy = set(), 0, 0
        fleet = s['handoff']['fleet']
        if self.stage == 'handoff_release' and self.tap_key is None and not s['native_interact']:
            off = sub(s['player'], fleet[self.TORRENT]['boarding']); off[1] = 0
            require(norm(off) > .1, 'physical Torrent exterior exit before departure walk')
            self.handoff_clear_target = [p+max(4, 8-norm(off))*d for p,d in zip(s['player'], unit(off))]
            self.handoff_clear_since = now
            self.begin_handoff_walk('handoff_clear', [self.handoff_clear_target], s)
        elif self.stage in self.WALK_STAGES:
            require(self.handoff_route, 'physical handoff walking has a concrete current goal')
            if self.handoff_goal_since is None: self.handoff_goal_since = now
            require(now-self.handoff_goal_since <= 15, 'ordinary physical handoff walking goal15 seconds')
            if self.stage == 'handoff_clear':
                require(now-self.handoff_clear_since <= 12, 'existing12-second physical reboard-clear walk')
            final_boarding_leg = self.stage in ('handoff_to_arrow', 'handoff_to_torrent') and len(self.handoff_route) == 1
            boarding_key = self.ARROW if self.stage == 'handoff_to_arrow' else self.TORRENT
            boarding = fleet[boarding_key]
            current_boarding_candidate = (final_boarding_leg and boarding['candidate']
                and boarding['boarding_distance'] <= 7 and not boarding['reboard_blocked'] and not s['station_candidate'])
            if current_boarding_candidate:
                # Boarding markers can be above the floor and inside the hull.
                # Release walking at the real interaction boundary, then settle.
                reached = norm(s['player_velocity']) <= .35
            else:
                dx, reached = self.walk_to(s, self.handoff_route[0], keys)
                if final_boarding_leg: reached = False
            if reached and self.stage == 'handoff_final_walk':
                reached = (norm(sub(s['player'], self.handoff_receipts['torrent_exited']['player'])) >= .5
                           and s['frame']-self.handoff_receipts['torrent_exited']['frame'] >= 20)
            if reached:
                self.handoff_visited.append({'stage': self.stage, 'frame': s['frame'], 'goal': self.handoff_route.pop(0)})
                self.handoff_goal_since = None
                if not self.handoff_route:
                    if self.stage == 'handoff_clear':
                        require(fleet[self.TORRENT]['boarding_distance'] > 7 and not fleet[self.TORRENT]['reboard_blocked'],
                                'actual outward walk clears Torrent reboard block')
                        self.handoff_clear_target = s['player'][:]
                        self.handoff_receipts['torrent_clear'] = self.handoff_receipt(s)
                        self.begin_handoff_walk('handoff_to_arrow', [[-8.5, 0, s['player'][2]], [-8.5, 0, 13.5],
                            [-35, 0, 13.5], [-35, 0, 22], [fleet[self.ARROW]['boarding'][0], 0, 22],
                            fleet[self.ARROW]['boarding']], s)
                    elif self.stage == 'handoff_to_arrow': self.enter('handoff_arrow_ready', s)
                    elif self.stage == 'handoff_to_torrent': self.enter('handoff_torrent_ready', s)
                    else:
                        require(norm(sub(s['player'], self.handoff_receipts['torrent_exited']['player'])) >= .5
                                and s['frame']-self.handoff_receipts['torrent_exited']['frame'] >= 20,
                                'supported usable walk after physical Torrent reclaim exit')
                        self.handoff_receipts['torrent_walked'] = self.handoff_receipt(s)
                        self.enter('pause', s)
        elif self.stage in ('handoff_arrow_ready', 'handoff_torrent_ready'):
            key, label = (self.ARROW, 'arrow') if self.stage == 'handoff_arrow_ready' else (self.TORRENT, 'torrent')
            self.request_handoff_e(label+'_board', key, s, now)
        elif self.stage in ('handoff_arrow_board', 'handoff_torrent_board'):
            key, label = (self.ARROW, 'arrow') if self.stage == 'handoff_arrow_board' else (self.TORRENT, 'torrent')
            row = fleet[key]
            if s['phase'] == 'START_ENGINES' and not s['transition_busy'] and row['command_stream'] == row['stream']:
                before = self.handoff_receipts[label+'_board_press']['handoff']['fleet'][key]
                require(row['stream'] > before['stream'] and row['command_valid'] and row['source_enabled']
                        and row['next_sequence'] > row['command_sequence'] and row['command_neutral'],
                        'physical boarding establishes fresh current producer epoch and neutral consumer')
                self.handoff_receipts[label+'_seated'] = self.handoff_receipt(s)
                self.handoff_neutral = 0; self.enter('handoff_'+label+'_neutral', s)
        elif self.stage in ('handoff_arrow_neutral', 'handoff_torrent_neutral') and self.handoff_neutral >= 90:
            key, label = (self.ARROW, 'arrow') if self.stage == 'handoff_arrow_neutral' else (self.TORRENT, 'torrent')
            self.handoff_receipts[label+'_offline90'] = {**self.handoff_receipt(s), 'neutral_frames': self.handoff_neutral}
            self.request_handoff_e(label+'_exit', key, s, now)
        elif self.stage in ('handoff_arrow_exit', 'handoff_torrent_exit') and s['phase'] == 'COMPLETE' and not s['transition_busy']:
            key, label = (self.ARROW, 'arrow') if self.stage == 'handoff_arrow_exit' else (self.TORRENT, 'torrent')
            self.require_handoff_foot(s)
            self.require_handoff_exit_home(key, fleet[key])
            require(label+'_exit_transition' in self.handoff_receipts
                    and norm(sub(s['player'], fleet[key]['exit'])) < .65,
                    'actual current-craft exit completes at its supported physical anchor')
            self.handoff_receipts[label+'_exited'] = self.handoff_receipt(s)
            self.remember_retired(key, s, self.handoff_receipts[label+'_seated']['handoff']['fleet'][key]['stream'])
            if key == self.ARROW:
                self.begin_handoff_walk('handoff_to_torrent', [[fleet[self.ARROW]['boarding'][0], 0, 22],
                    [-35, 0, 22], [-35, 0, 13.5], [-8.5, 0, 13.5],
                    [-8.5, 0, self.handoff_clear_target[2]], self.handoff_clear_target, fleet[self.TORRENT]['boarding']], s)
            else:
                off = sub(s['player'], fleet[self.TORRENT]['boarding']); off[1] = 0
                self.handoff_final_target = [p+d for p,d in zip(s['player'], unit(off))]
                self.begin_handoff_walk('handoff_final_walk', [self.handoff_final_target], s)
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame+6: keys.add(self.tap_key)
            else: self.tap_key = None; self.tap_cooldown = now+.3; self.tap_release_frame = self.frame
        if self.mouse_pending is not None:
            if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = None
        if dx: self.mouse_pending = s['walk_forward'][:]
        return keys, dx, dy, False

    def finish(self, exit_code):
        required = ('prerequisite', 'torrent_clear', 'arrow_board_press', 'arrow_seated', 'arrow_offline90',
                    'arrow_exit_press', 'arrow_exit_transition', 'arrow_exited', 'torrent_board_press',
                    'torrent_seated', 'torrent_offline90', 'torrent_exit_press', 'torrent_exit_transition',
                    'torrent_exited', 'torrent_walked')
        require(self.handoff_started and all(k in self.handoff_receipts for k in required)
                and all(self.handoff_receipts[a]['frame'] < self.handoff_receipts[b]['frame']
                        for a,b in zip(required, required[1:]) if not b.endswith('exit_press')),
                'ordered real Arrow handoff exit and Torrent reclaim exit walk before normal UI completion')
        result = super().finish(exit_code)
        result.update(scope='partial CRAFT-ACCEPT-TORRENT physical Arrow handoff and Torrent reclaim capability',
            handoff_receipts=self.handoff_receipts, handoff_waypoints=self.handoff_visited,
            handoff_native_edges=self.handoff_edges, arrow_flight_weapon_acceptance='NOT_RUN',
            all_component_stages_destruction_main_acceptance='NOT_RUN')
        return result


class ZenithTorrentHandbackPilot(Pilot):
    """Frozen LIFE-ARM admission, real Guided Torrent, same Zenith reclaim."""
    MODE = 'zenith-torrent-handback'
    MARKER = 'NATIVE_ZENITH_TORRENT_HANDBACK_OK'
    ZENITH, TORRENT = 'zenith_b7_observed', 'torrent_provisional'
    IDS = ('main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id', 'ship_id',
           'berth_id', 'source_id', 'seat_id', 'chase_camera_id', 'cockpit_camera_id', 'pid')
    HULL_IDS = TorrentArrowHandoffPilot.HULL_IDS + ('chase_camera_id', 'cockpit_camera_id')
    REVERSE_ARM = ([22,4.2,68.3], [13,4.2,68.3], [6,4.2,68.3], [-3.5,4.2,68.3],
                   [-3.5,4.2,64.2], [-3.5,4.2,61.5], [-5.7,4.2,61.2], [-5.7,0,51],
                   [0,0,51], [0,0,46.3], [0,0,39], [0,0,15.5], [-8.5,0,15.5], [-8.5,0,13.5])
    WALK_STAGES = ('wing_port', 'wing_clear', 'to_torrent', 'torrent_clear', 'connector', 'outward_arm')
    handoff_receipt = TorrentArrowHandoffPilot.handoff_receipt
    remember_retired = TorrentArrowHandoffPilot.remember_retired
    require_exit_consumer = TorrentArrowHandoffPilot.require_exit_consumer
    request_handoff_e = TorrentArrowHandoffPilot.request_handoff_e
    ui_update = ArrowReturnReusePilot.ui_update

    def __init__(self):
        super().__init__()
        self.stage = 'admission'
        self.admission = LifeTowPilot('life-arm')
        self.walker = LifeTowPilot('life-arm')
        self.admission_result = self.guided_result = None
        self.guided = Pilot()
        self.initial = self.last_state = self.observed_previous = None
        self.handoff_initial = None
        self.handoff_receipts, self.handoff_edges, self.retired = {}, [], {}
        self.receipts = self.handoff_receipts
        self.visited, self.route = [], []
        self.walked = self.observations = self.admission_neutral = self.final_neutral = self.torrent_neutral = 0
        self.first_stream = self.retired_zenith_stream = None
        self.now = self.stage_since = 0
        self.goal_since = self.board_since = self.clear_since = None
        self.control_previous = self.mouse_pending = None
        self.landing_timeout = None
        self.landing_seen = False
        self.landing_receipts = []
        self.ui_key = None
        self.ui_until = self.ui_release_until = 0
        self.quit_requested = False
        self.expected_pid = None

    def enter(self, stage, s):
        super().enter(stage, s)
        self.stage_since = self.now

    @staticmethod
    def secured(row, strict=False, offline=True):
        require(row['landed'] and row['parked_exact'] and row['lease'] and row['lease_token']
                and (not offline or row['engine'] == 'OFFLINE') and not row['flight_demand']
                and not row['landing_active'] and norm(row['velocity']) < .0001,
                'stationary craft retains actual occupied home and automatic OFFLINE')
        if strict:
            require(row['physical_strict'] and row['occupant_id'] == row['ship_id']
                    and row['reservation_owner_id'] == row['ship_id']
                    and row['reserved_ship_id'] == row['definition_id']
                    and row['main_lease_token'] == row['lease_token']
                    and row['main_berth_id'] == row['home_id'],
                    'exact physical home and Main-bound occupied lease')

    @staticmethod
    def neutral_owner(row):
        return (row['piloted'] and row['seated'] and row['camera'] and row['active']
                and row['reserved'] and row['player_reservation'] and row['source_enabled']
                and row['command_valid'] and row['command_neutral'] and row['pending'] == 0
                and row['command_stream'] == row['stream']
                and row['next_sequence'] > row['command_sequence'])

    def require_foot(self, s):
        self.walker.require_walking(s['admission'])
        require(s['player_camera'] and not s['handoff']['piloting']
                and all(not row[k] for row in s['handoff']['fleet'].values()
                        for k in ('piloted','seated','camera','reserved','player_reservation')),
                'supported ordinary foot controls release both ship seats cameras and claims')

    def validate_actors(self, s):
        require(s.get('mode') == self.MODE and s['actors_current'] and s['handoff']['actors_current']
                and s['torrent']['actors_current'], 'literal current Zenith and Torrent observer actors')
        if self.expected_pid is not None:
            require(s['pid'] == self.expected_pid, 'observer belongs to exact owned exported process')
        h = s['handoff']
        require(set(h['fleet']) == {self.ZENITH, self.TORRENT}, 'exact two registered handback craft')
        if self.initial is None:
            require(s['phase'] == 'INTRO' and not s['paused'] and not s['guided_complete']
                    and len(s['torrent']['targets']) == 4 and not s['torrent']['destroyed_targets'],
                    'normal fresh title before unchanged LIFE-ARM and pending actual Guided')
            self.initial = copy.deepcopy(s)
            self.handoff_initial = copy.deepcopy(h)
        initial = self.initial
        require(all(s[k] == initial[k] and s[k] for k in self.IDS)
                and s['capsule_geometry'] == initial['capsule_geometry']
                and s['endpoints'] == initial['endpoints'] and s['parked'] == initial['parked'],
                'same Main Player capsule original Zenith both cameras and live-home endpoints')
        require(s['default_controls'] and s['default_sampler'] and s['tuning_unchanged']
                and s['walk_tuning'] == LifeTowPilot.DEFAULT_WALK
                and s['ship_tuning'] == initial['ship_tuning']
                and s['physics_ticks'] == 60 and s['time_scale'] == 1
                and s['definition_id'] == self.ZENITH and s['home_id'] == 'zenith_fleet_dock_berth',
                'unchanged authored control maps samplers physics and Zenith resources')
        require(h['active_ship_id'] in {r['ship_id'] for r in h['fleet'].values()}
                and all(r['active'] == (r['ship_id'] == h['active_ship_id']) for r in h['fleet'].values()),
                'active craft identity agrees with both physical rows')
        for key, combat_source in ((self.ZENITH,1104), (self.TORRENT,1101)):
            row, baseline = h['fleet'][key], self.handoff_initial['fleet'][key]
            require(row['actors_current'] and all(row[k] and row[k] == baseline[k] for k in self.HULL_IDS)
                    and row['definition_id'] == key and row['home_id'] == baseline['home_id']
                    and row['combat_source'] == combat_source and row['default_sampler']
                    and row['tuning_unchanged'] and row['tuning'] == baseline['tuning']
                    and not row['remote_piloted'] and not row['destroyed'],
                    'same registered physical hull seat area berth source cameras and authored tuning')
        zenith = h['fleet'][self.ZENITH]
        self.secured(zenith, True)
        require(zenith['hull'] == self.handoff_initial['fleet'][self.ZENITH]['hull'] == 68,
                'original Zenith remains intact at home throughout; no flight or combat replay')
        t = s['torrent']
        require(all(t[k] == initial['torrent'][k] and t[k] for k in TorrentReturnReusePilot.IDS)
                and all(t[k] == s[k] for k in ('main_id','world_id','player_id','capsule_id','shape_id','frame','player','phase',
                    'seated','transition_busy','control_enabled','capsule_enabled','player_camera','native_interact'))
                and all(s['admission'][k] == s[k] for k in ('main_id','world_id','player_id','capsule_id','shape_id','ship_id','frame','player'))
                and t['default_controls'] and t['default_sampler'] and t['tuning_unchanged']
                and t['walk_tuning'] == LifeTowPilot.DEFAULT_WALK
                and t['ship_tuning'] == initial['torrent']['ship_tuning']
                and t['definition_id'] == self.TORRENT and t['home_id'] == 'central_berth',
                'detached Guided and admission snapshots refer to the same current actors and physics tick')
        require(s['admission']['home_berth_instance_id'] == s['berth_id']
                and s['admission']['ship_tuning'] == s['ship_tuning']
                and zenith['ship_id'] == s['ship_id'] and zenith['source_id'] == s['source_id']
                and h['fleet'][self.TORRENT]['ship_id'] == t['ship_id']
                and h['fleet'][self.TORRENT]['source_id'] == t['source_id'],
                'authoritative pair and detached per-craft identity bindings agree')
        view = s['camera_view']
        require(view in ('CHASE','COCKPIT')
                and s['camera_id'] == s['chase_camera_id' if view == 'CHASE' else 'cockpit_camera_id'],
                'current Zenith camera is one of its retained original cameras')
        return h

    def validate_lifecycle(self, s, previous):
        h = s['handoff']
        if s['native_interact'] and not (previous and previous['native_interact']):
            self.handoff_edges.append({'frame':s['frame'], 'stage':self.stage})
        state = s['boarding_confirmation'].get('adapter',{}).get('view',{}).get('state')
        require(state != 'rejected', 'ordinary physical boarding and exit never reject')
        if self.stage == 'admission': return
        torrent = h['fleet'][self.TORRENT]
        if (self.stage in ('to_torrent','torrent_ready','handoff_torrent_board')
                and s['phase'] == 'APPROACH_SHIP' and torrent['candidate']
                and torrent['boarding_distance'] <= 7 and not torrent['reboard_blocked']
                and not s['station_candidate'] and not s['transition_busy'] and not s['seated']):
            self.require_foot(s)
            self.handoff_receipts.setdefault('torrent_approach',self.handoff_receipt(s))
        if s['phase'] == 'BOARDING':
            key, label = ((self.TORRENT,'torrent_board') if self.stage == 'handoff_torrent_board'
                          else (self.ZENITH,'zenith_board'))
            request = self.handoff_receipts.get(label+'_press')
            row = h['fleet'][key]
            require(self.stage == 'handoff_'+label and request is not None
                    and request['frame'] < s['frame'] and request['handoff']['fleet'][key]['candidate']
                    and request['handoff']['fleet'][key]['boarding_distance'] <= 7
                    and not request['handoff']['fleet'][key]['reboard_blocked']
                    and any(e['stage'] == self.stage and request['frame'] < e['frame'] <= s['frame'] for e in self.handoff_edges)
                    and row['active'] and row['reserved'] and row['player_reservation']
                    and s['transition_busy'] and state == 'boarding',
                    'actual candidate native E and correct reserved physical hull precede boarding')
            self.handoff_receipts.setdefault(label+'_boarding', self.handoff_receipt(s))
        for key,label in ((self.TORRENT,'torrent_board'),(self.ZENITH,'zenith_board')):
            if self.stage != 'handoff_'+label or s['phase'] != 'START_ENGINES' or s['transition_busy']: continue
            row = h['fleet'][key]
            request = self.handoff_receipts[label+'_press']
            require(label+'_boarding' in self.handoff_receipts and row['stream'] > request['handoff']['fleet'][key]['stream']
                    and row['active'] and row['piloted'] and row['seated'] and row['camera']
                    and row['reserved'] and row['player_reservation'] and not s['capsule_enabled'] and not s['player_camera'],
                    'fresh physical board owns the original seat camera and producer epoch')
            require(row['command_neutral'] and row['command_stream'] in (0,row['stream']),
                    'boarding bridges only an exact cleared neutral consumer, never an old or active stream')
            if self.neutral_owner(row):
                self.handoff_receipts.setdefault(label.removesuffix('_board')+'_seated', self.handoff_receipt(s))
        if s['phase'] == 'DISEMBARKING':
            key,label = ((self.ZENITH,'zenith_exit') if self.stage == 'handoff_zenith_exit'
                         else (self.TORRENT,'torrent_exit'))
            require(self.stage == 'handoff_'+label and state == 'disembarking',
                    'separate ordinary current-craft exit transition')
            self.secured(h['fleet'][key], True)
            if key == self.TORRENT:
                require(h['fleet'][key]['contract'] and self.torrent_neutral >= 90 and self.landing_seen,
                        'Torrent exit follows real Guided landing and ninety consecutive neutral OFFLINE ticks')
            else:
                require(self.admission_result is not None and self.admission_neutral >= 90,
                        'initial Zenith exit uses the existing admission ninety neutral ticks once')
            if label+'_transition' not in self.handoff_receipts:
                self.require_exit_consumer(key,label,s)
        if self.stage.startswith('handoff_') and not s['seated'] and not s['transition_busy'] and s['phase'] in ('APPROACH_SHIP','COMPLETE'):
            self.require_foot(s)
        for key, retired in self.retired.items():
            row = h['fleet'][key]
            require(not row['piloted'] and not row['seated'] and not row['camera'] and not row['reserved']
                    and not row['player_reservation'] and row['pending'] == 0 and row['command_neutral'],
                    'retired hull remains neutral without stale seat camera reservation or delivery')
            if not s['paused'] and previous and not previous['paused']:
                require(all(row[k] == retired[k] for k in retired), 'retired producer stream and cursor remain unconsumed')
            elif s['paused']:
                self.retired[key] = {k:row[k] for k in retired}
        if s['seated'] and not s['transition_busy']:
            occupied = [key for key,row in h['fleet'].items() if row['seated']]
            expected = self.TORRENT if self.stage in ('handoff_torrent_board','guided','handoff_torrent_exit') else self.ZENITH
            require(occupied == [expected] and h['piloting'] and not s['capsule_enabled'] and not s['player_camera']
                    and all(h['fleet'][expected][k] for k in ('piloted','active','camera','reserved','player_reservation'))
                    and (s['paused'] or (h['fleet'][expected]['source_enabled']
                        and (s['torrent'] if expected == self.TORRENT else s)['application_focused']))
                    and all(not row[k] for key,row in h['fleet'].items() if key != expected for k in ('piloted','seated','camera','reserved','player_reservation')),
                    'only the current occupied craft owns pilot seat camera and input claims')

    def validate_observation(self, s):
        h = self.validate_actors(s)
        previous = self.observed_previous
        if previous:
            require(s['sequence'] == previous['sequence']+1 and s['frame'] == previous['frame']+1,
                    'every raw handback physics observation retained before latest controls')
        self.validate_lifecycle(s, previous)
        if self.stage == 'admission':
            self.admission.validate_observation(s['admission'])
            if self.admission.stage == 'seated_observe':
                require(self.neutral_owner(h['fleet'][self.ZENITH]), 'admission ninety seated ticks consume current neutral Zenith stream')
                self.admission_neutral += 1
        if self.stage not in ('guided','handoff_torrent_exit'):
            require(s['phase'] in ('INTRO','APPROACH_SHIP','BOARDING','START_ENGINES','DISEMBARKING','COMPLETE'),
                    'handback exterior and Zenith admission have no unauthorized flight phase')
        t = s['torrent']
        if self.guided_result is not None:
            require(t['guided_complete'] and not t['targets'] and t['destroyed_targets'] == 4
                    and not t['opponent_active'] and not t['guided_return_authorized'],
                    'actual Guided completion remains retired through same-Zenith reclaim')
            self.secured(h['fleet'][self.TORRENT],True)
            require(h['fleet'][self.TORRENT]['contract'], 'Torrent preserves its actual strict Guided home landing contract')
        elif self.stage not in ('guided','handoff_torrent_exit'):
            require(not t['guided_complete'] and len(t['targets']) == 4 and not t['destroyed_targets'],
                    'mandatory Guided remains pending and all four drones intact until real Torrent flight')
            self.secured(h['fleet'][self.TORRENT],True)
        if self.stage in ('guided','handoff_torrent_exit'):
            require(t['phase'] != 'FAILED' and not t['destroyed'], 'actual live Guided Torrent suffix')
            if not self.guided.phases or self.guided.phases[-1] != t['phase']: self.guided.phases.append(t['phase'])
            self.guided.shot |= t['shot_accepted']; self.guided.fired |= t['command_fire']
            self.guided.max_excursion = max(self.guided.max_excursion,norm(sub(t['position'],t['parked'])))
            self.guided.departed |= t['lease_free'] and not t['landed'] and self.guided.max_excursion > .01
            if t['landing_active']:
                report = t['landing']
                if self.landing_timeout is None: self.landing_timeout = report['timeout_seconds']
                require(self.guided.stage == 'land' and not report['last_abort_reason']
                        and report['timeout_seconds'] == self.landing_timeout >= 24
                        and 0 <= report['elapsed'] <= self.landing_timeout
                        and report['stall_timeout_seconds'] == 4 and 0 <= report['stall_elapsed'] <= 4,
                        'real Hero landing timeout and independent four-second stall remain binding')
                self.landing_seen = True
                self.landing_receipts.append({'frame':s['frame'], **copy.deepcopy(report)})
            require(not t['landing']['last_abort_reason'], 'first actual Torrent landing never aborts or retries')
            if self.guided.stage == 'shutdown':
                self.secured(h['fleet'][self.TORRENT],True,offline=False)
                require(t['contract'] and self.landing_seen and self.guided.departed,
                        'actual Guided departure and Hero landing establish strict exact home')
                row=h['fleet'][self.TORRENT]
                self.torrent_neutral = self.torrent_neutral+1 if self.neutral_owner(row) and row['engine']=='OFFLINE' else 0
        if self.stage in self.WALK_STAGES or self.stage in ('torrent_release','torrent_ready','zenith_ready'):
            if not s['paused']:
                self.require_foot(s)
                if previous and not previous['transition_busy'] and not previous['seated']:
                    self.walker.observed_previous = previous['admission']
                    motion = self.walker.require_motion_epoch(s['admission'])
                    if motion['step_up']: self.walker.require_step_event(s['admission'],motion)
                    else:
                        require(norm(sub(s['player'],previous['player'])) <= LifeTowPilot.DEFAULT_WALK['sprint']/60*1.25+.02,
                                'continuous physically supported handback walking without placement')
                    require(motion['start'] == previous['player'], 'completed walking tick starts at prior current actor position')
                    self.walked += norm(sub(s['player'],previous['player']))
            if self.stage in ('outward_arm','wing_clear') and self.route:
                name,target=self.route[0]
                # The reverse departure crosses the same deck/rung corner.
                # Reuse LIFE-ARM's private steering and fifteen settled samples;
                # retain the published live wing-clear endpoint in our route.
                guarded_name='zenith_approach' if self.stage=='wing_clear' else name
                self.walker.route=[(guarded_name,target)]; self.walker.index=0; self.walker.stage='walk_service'
                settled=(math.hypot(target[0]-s['player'][0],target[2]-s['player'][2])<=.30
                         and abs(target[1]-s['player'][1])<.8 and math.hypot(s['velocity'][0],s['velocity'][2])<.1
                         and self.walker.zenith_corner_safe(s))
                self.walker.settled_frames=self.walker.settled_frames+1 if settled else 0
        if self.stage in ('handoff_zenith_board','final_neutral') and 'zenith_seated' in self.handoff_receipts:
            row=h['fleet'][self.ZENITH]
            require(self.retired_zenith_stream is not None and row['stream'] > self.retired_zenith_stream > self.first_stream
                    and self.neutral_owner(row) and row['engine']=='OFFLINE',
                    'same original Zenith consumes a fresh current fenced neutral pilot stream')
            self.final_neutral += 1
        if s['paused']:
            require(self.stage in ('pause','quit_wait') and self.final_neutral>=90 and self.guided_result is not None,
                    'normal HUD pause only follows actual Guided and ninety fresh same-Zenith ticks')
        self.frame=s['frame']; self.observations+=1
        if not self.phases or self.phases[-1]!=s['phase']: self.phases.append(s['phase'])
        self.last_state=self.observed_previous=s

    def begin_walk(self, stage, goals, s):
        self.route=[(name,list(target)) for name,target in goals]
        self.goal_since=None; self.mouse_pending=None; self.walker.settled_frames=0
        self.enter(stage,s)

    def update(self, s, now):
        require(self.last_state is s, 'latest already-validated complete handback batch')
        self.now=now
        if self.stage=='admission':
            controls=self.admission.update(s['admission'],now)
            if self.admission.result is not None:
                require(self.admission_neutral>=90,'unchanged LIFE-ARM admission already proves ninety neutral seated ticks')
                self.admission_result=copy.deepcopy(self.admission.result)
                self.first_stream=s['input_stream']
                self.handoff_receipts['zenith_offline90']=self.handoff_receipt(s)
                self.tap_key=self.admission.tap_key; self.tap_until=self.admission.tap_until
                self.tap_frame=self.admission.tap_frame; self.tap_cooldown=self.admission.tap_cooldown
                self.tap_release_frame=self.admission.tap_release_frame
                self.enter('initial_release',s)
            return controls
        if self.stage in ('pause','quit_wait'): return self.ui_update(s,now)
        keys=set(); dx=dy=0
        fleet=s['handoff']['fleet']
        if self.stage=='initial_release':
            self.request_handoff_e('zenith_exit',self.ZENITH,s,now)
        elif self.stage in ('handoff_zenith_exit','handoff_torrent_exit'):
            key,label=((self.ZENITH,'zenith_exit') if self.stage=='handoff_zenith_exit' else (self.TORRENT,'torrent_exit'))
            if key==self.ZENITH: require(now-self.stage_since<=10,'initial ordinary docked Zenith exit10 seconds')
            if not s['seated'] and not s['transition_busy'] and s['phase'] in ('APPROACH_SHIP','COMPLETE'):
                self.require_foot(s)
                require(label+'_transition' in self.handoff_receipts and norm(sub(s['player'],fleet[key]['exit']))<.8,
                        'physical exit completes through the current craft supported exterior anchor')
                self.handoff_receipts[label.removesuffix('_exit')+'_exited']=self.handoff_receipt(s)
                before=self.handoff_receipts[label+'_press']['handoff']['fleet'][key]['stream']
                self.remember_retired(key,s,before)
                if key==self.ZENITH:
                    self.retired_zenith_stream=fleet[key]['stream']
                    self.begin_walk('wing_port',[('wing_port',s['endpoints']['wing_port'])],s)
                else:
                    self.guided.update(s['torrent'],now)
                    require(self.guided.result is not None,'unchanged original Pilot accepts actual whole Guided suffix')
                    self.guided_result=copy.deepcopy(self.guided.result)
                    self.enter('torrent_release',s)
        elif self.stage in self.WALK_STAGES:
            require(self.route,'frozen walking stage has a concrete goal')
            if self.goal_since is None: self.goal_since=now
            require(now-self.goal_since<=15,'ordinary walking fifteen-second per-goal deadline')
            if self.stage=='torrent_clear': require(now-self.clear_since<=12,'existing Torrent radial-clear twelve-second deadline')
            name,target=self.route[0]
            final_candidate=self.stage=='to_torrent' and len(self.route)==1
            row=fleet[self.TORRENT]
            if final_candidate and row['candidate'] and row['boarding_distance']<=7 and not row['reboard_blocked'] and not s['station_candidate']:
                reached=norm(s['velocity'])<=.35
            elif self.stage in ('outward_arm','wing_clear'):
                frames=s['frame']-self.control_previous['frame'] if self.control_previous else 1
                dx,reached=self.walker.walk_to(s,target,keys,frames)
            else:
                dx,reached=ArrowReturnReusePilot.walk_to(self,s,target,keys)
                # Use the authored walking gait for this stair-base descent.
                if self.stage=='to_torrent' and name=='reverse_8': keys.discard('Shift_L')
                if final_candidate: reached=False
            if reached:
                self.visited.append({'stage':self.stage,'goal':name,'target':target[:],**self.handoff_receipt(s)})
                self.route.pop(0); self.goal_since=None; self.walker.settled_frames=0
                if not self.route:
                    if self.stage=='wing_port': self.begin_walk('wing_clear',[('wing_clear',s['endpoints']['wing_clear'])],s)
                    elif self.stage=='wing_clear':
                        require(fleet[self.ZENITH]['boarding_distance']>7 and not fleet[self.ZENITH]['reboard_blocked'],
                                'live wing-clear point physically clears Zenith reboard block')
                        self.handoff_receipts['zenith_clear']=self.handoff_receipt(s)
                        goals=[('reverse_'+str(i),p) for i,p in enumerate(self.REVERSE_ARM)]
                        # Cross the accepted Freight lane south of the fixed
                        # central cargo crates, then retain both old goals.
                        goals[12:12]=[('cargo_south',[0,0,13.5]),('cargo_port',[-8.5,0,13.5])]
                        goals += [('torrent_exit_z',[-8.5,0,fleet[self.TORRENT]['exit'][2]]),('torrent_candidate',fleet[self.TORRENT]['boarding'])]
                        self.begin_walk('to_torrent',goals,s)
                    elif self.stage=='to_torrent': self.board_since=now; self.enter('torrent_ready',s)
                    elif self.stage=='torrent_clear':
                        require(row['boarding_distance']>7 and not row['reboard_blocked'],'actual Torrent radial walk clears seven-metre reboard block')
                        self.handoff_receipts['torrent_clear']=self.handoff_receipt(s)
                        self.begin_walk('connector',[
                            ('0',[-8.5,0,self.clear_target[2]]),('1',[-8.5,0,13.5]),
                            ('2',[-8.5,0,15.5]),('cargo_south',[-8.5,0,13.5]),
                            ('cargo_east',[0,0,13.5]),('3',[0,0,15.5])],s)
                    elif self.stage=='connector': self.begin_walk('outward_arm',LifeTowPilot.ARM_GOALS,s)
                    elif self.stage=='outward_arm': self.board_since=now; self.enter('zenith_ready',s)
        elif self.stage in ('torrent_ready','zenith_ready'):
            require(now-self.board_since<=12,'ordinary physical boarding twelve-second deadline')
            key,label=((self.TORRENT,'torrent') if self.stage=='torrent_ready' else (self.ZENITH,'zenith'))
            if s['station_candidate']:
                candidate=s['admission']['station_candidate']
                require(candidate,'actual prompt position for unchanged LIFE-ARM look-away maneuver')
                away=[2*a-b for a,b in zip(s['player'],candidate['position'])]
                dx,_,_=self.admission.yaw_to(s['admission'],away)
            elif fleet[key]['candidate'] and fleet[key]['boarding_distance']<=7 and not fleet[key]['reboard_blocked'] and norm(s['velocity'])<=.35:
                self.request_handoff_e(label+'_board',key,s,now)
        elif self.stage in ('handoff_torrent_board','handoff_zenith_board'):
            require(now-self.board_since<=12,'physical candidate through pilot ownership twelve-second deadline')
            label='torrent' if self.stage=='handoff_torrent_board' else 'zenith'
            if label+'_seated' in self.handoff_receipts:
                if label=='torrent':
                    self.guided.stage='board'; self.guided.max_walk=self.admission.walked+self.walked
                    prefix=[self.handoff_receipts[key] for key in ('torrent_approach','torrent_board_boarding')]
                    require(prefix[0]['frame'] < prefix[1]['frame']
                            and [receipt['phase'] for receipt in prefix] == ['APPROACH_SHIP','BOARDING'],
                            'original Guided prefix derives only from actual validated Torrent approach and boarding')
                    self.guided.phases=[receipt['phase'] for receipt in prefix]
                    self.enter('guided',s)
                else: self.enter('final_neutral',s)
        elif self.stage=='guided':
            if self.guided.stage=='shutdown':
                if self.torrent_neutral>=90:
                    self.handoff_receipts['torrent_offline90']={**self.handoff_receipt(s),'neutral_frames':self.torrent_neutral}
                    self.request_handoff_e('torrent_exit',self.TORRENT,s,now)
                    if self.stage=='handoff_torrent_exit': self.guided.stage='exit'
            else:
                return self.guided.update(s['torrent'],now)
        elif self.stage=='torrent_release' and self.tap_key is None and not s['native_interact']:
            off=sub(s['player'],fleet[self.TORRENT]['boarding']); off[1]=0
            require(norm(off)>.1,'actual Torrent exterior before unchanged radial-clear target')
            self.clear_target=[p+max(4,8-norm(off))*d for p,d in zip(s['player'],unit(off))]
            self.clear_since=now
            self.begin_walk('torrent_clear',[('radial_clear',self.clear_target)],s)
        elif self.stage=='final_neutral' and self.final_neutral>=90:
            self.handoff_receipts['zenith_reclaimed90']={**self.handoff_receipt(s),'neutral_frames':self.final_neutral}
            self.enter('pause',s)
        if self.tap_key is not None:
            if now<self.tap_until or self.frame<self.tap_frame+6: keys.add(self.tap_key)
            else: self.tap_key=None; self.tap_cooldown=now+.3; self.tap_release_frame=self.frame
        if self.mouse_pending is not None:
            if norm(sub(s['walk_forward'],self.mouse_pending))<.00001: dx=0
            else: self.mouse_pending=None
        if dx: self.mouse_pending=s['walk_forward'][:]
        self.control_previous=s
        return keys,dx,dy,False

    def finish(self, exit_code):
        required=('zenith_offline90','zenith_exit_press','zenith_exit_transition','zenith_exited','zenith_clear',
                  'torrent_approach','torrent_board_press','torrent_board_boarding','torrent_seated','torrent_offline90',
                  'torrent_exit_press','torrent_exit_transition','torrent_exited','torrent_clear',
                  'zenith_board_press','zenith_board_boarding','zenith_seated','zenith_reclaimed90','exit_ui')
        require(exit_code==0 and self.quit_requested and self.stage=='quit_wait' and self.admission_result is not None
                and self.guided_result is not None and self.final_neutral>=90 and self.landing_seen
                and all(k in self.handoff_receipts for k in required),
                'actual Guided and fresh same-Zenith handback precede normal HUD Quit and actual OS0')
        require(all(self.handoff_receipts[a]['frame']<self.handoff_receipts[b]['frame']
                    for a,b in zip(required,required[1:]) if b not in ('exit_ui','torrent_board_press','torrent_exit_press')), 'ordered physical handback receipts')
        self.result=dict(completion_marker=self.MARKER,admission=self.admission_result,guided=self.guided_result,
                         handoff_receipts=self.handoff_receipts,native_edges=self.handoff_edges,visited=self.visited,
                         same_actor_identities={k:self.initial[k] for k in self.IDS},
                         first_zenith_stream=self.first_stream,retired_zenith_stream=self.retired_zenith_stream,
                         final_zenith_stream=self.last_state['handoff']['fleet'][self.ZENITH]['stream'],
                         landing_timeout=self.landing_timeout,landing_receipts=self.landing_receipts,
                         torrent_clear_target=self.clear_target,walked_m=self.walked,
                         admission_neutral_frames=self.admission_neutral,torrent_neutral_frames=self.torrent_neutral,
                         fresh_zenith_neutral_frames=self.final_neutral,stages=self.stages,phases=self.phases,
                         normal_ui_exit=self.receipts['exit_ui'],native_hardware='NOT_RUN',human_review='NOT_RUN')
        return self.result


class BreachFireControl:
    """A consumed ordinary press/release is input evidence, never a hit."""
    def __init__(self):
        self.phase, self.scope, self.cursor = 'release', None, None
        self.receipts = []

    def release(self):
        self.phase, self.scope, self.cursor = 'release', None, None
        return False

    def step(self, s, ready):
        board, target = s['breach']['board'], s['target']
        director = board['director']
        valid = (not s['paused'] and not s['destroyed'] and not s['transition_busy']
                 and s['phase'] == 'FREE_FLIGHT' and all(s[k] for k in
                    ('actors_current', 'piloted', 'seated', 'seated_at_pilot', 'active_ship',
                     'default_sampler', 'source_enabled', 'application_focused', 'mouse_captured'))
                 and director['scenario'] == 'heavy_breach' and director['state'] == 'running'
                 and director['outcome'] == 'pending' and director['elapsed'] < director['bounds']['scenario_time_limit']
                 and target['active'] and target['health'] > 0 and target['source_id'] == 2102
                 and s['weapon_source'] == 1102 and s['command_stream'] == s['input_stream'])
        if not valid: return self.release()
        scope = tuple(s[k] for k in ('pid', 'main_id', 'player_id', 'ship_id', 'source_id', 'input_stream'))
        scope += (director['scenario_generation'], target['id'], target['generation'], target['source_id'])
        cursor = (s['sequence'], s['frame'], s['command_sequence'])
        if scope != self.scope:
            self.release(); self.scope, self.cursor = scope, cursor
            return False
        fresh = all(a > b for a, b in zip(cursor, self.cursor))
        if self.phase == 'release':
            if fresh and not s['native_fire'] and not s['command_fire']:
                self.phase = 'ready'
                self.receipts.append(dict(action='released', scope=scope, cursor=cursor))
            return False
        if self.phase == 'press':
            if fresh and s['native_fire'] and s['command_fire']:
                self.phase, self.cursor = 'release', cursor
                self.receipts.append(dict(action='consumed', scope=scope, cursor=cursor))
                return False
            return True
        if not ready: return False
        if s['native_fire'] or s['command_fire']:
            self.phase, self.cursor = 'release', cursor
            return False
        self.phase, self.cursor = 'press', cursor
        self.receipts.append(dict(action='requested', scope=scope, cursor=cursor))
        return True


class HeavyBreachPilot(Pilot):
    """The actual posted Heavy contract, one real clear/payment and physical return."""
    MARKER = 'NATIVE_HEAVY_BREACH_OK'
    ACTIVITY, REWARD = 'shipyard_heavy_breach', 'return_heavy_breach_credit'
    WEAPON = 'arrow_precision_recon_emitter'
    IDS = ('pid', 'main_id', 'world_id', 'player_id', 'capsule_id', 'shape_id',
           'ship_id', 'berth_id', 'seat_id', 'source_id')
    DEFAULT_WALK = LifeTowPilot.DEFAULT_WALK
    finite_vector = staticmethod(LifeTowPilot.finite_vector)
    require_walking = LifeTowPilot.require_walking
    require_motion_epoch = LifeTowPilot.require_motion_epoch
    require_step_event = LifeTowPilot.require_step_event
    require_home = ArrowReturnReusePilot.require_home
    ui_update = ArrowReturnReusePilot.ui_update
    restore_attitude = ArrowReturnReusePilot.restore_attitude
    weapon_aim = ArrowReturnReusePilot.weapon_aim
    yaw_to = HabitatLoopPilot.yaw_to
    walk_to = HabitatLoopPilot.walk_to

    def __init__(self):
        super().__init__()
        self.initial = self.observed_previous = self.last_state = None
        self.receipts, self.visited, self.shots, self.native_edges = {}, [], [], []
        self.route, self.walked = [], 0.
        self.motion_lag = None; self.consumed_step_frames = set()
        self.mouse_pending = None; self.last_input_frame = 0
        self.last_sequence = self.shot_sequence = -1
        self.shot_receipts = set()
        self.armed = self.departure = self.launched = self.charge = self.kill = self.paid = None
        self.next_posting = None; self.landing_seen = False; self.neutral_start = None
        self.fire_control = BreachFireControl()
        self.ui_key = None; self.ui_until = self.ui_release_until = 0
        self.quit_requested = False

    @staticmethod
    def receipt(s):
        keys = ('sequence', 'frame', 'pid', 'main_id', 'player_id', 'ship_id', 'source_id',
                'input_stream', 'command_sequence', 'phase', 'player', 'position', 'breach',
                'target', 'native_interact', 'native_fire', 'command_fire', 'shot', 'fire_gate')
        return copy.deepcopy({k: s[k] for k in keys if k in s})

    @classmethod
    def require_paid(cls, s):
        record = s['settlement']['record']; receipt = record.get('last_receipt', {})
        require(record.get('receipt_serial') == record.get('total_receipts') == 1
                and record.get('reward_counts') == {cls.REWARD: 1}
                and receipt.get('receipt_id') == 1 and receipt.get('activity_id') == cls.ACTIVITY
                and receipt.get('reward_id') == cls.REWARD and receipt.get('granted') is True
                and receipt.get('replay_allowed') is False,
                'one actual non-replayable Heavy Breach credit, no unrelated award')
        handoff = s['breach']['board']['reward_handoff']
        require(handoff['highest_reward_generation'] == receipt['activity_generation']
                and handoff['pending_reward_generation'] == 0
                and receipt['activity_generation'] == s['breach']['board']['director']['scenario_generation'],
                'same current board acknowledges the exact paid generation')
        return receipt

    def observe_shot(self, s):
        shot = s['shot']
        if not shot['present']: return
        request = shot['request']; sequence = request['sequence']
        if sequence == self.shot_sequence: return
        require(sequence > self.shot_sequence and self.departure is not None
                and request['source_id'] == shot['source_id'] == 1102
                and request['source_entity_id'] == shot['source_entity_id'] == s['ship_id']
                and request['weapon_id'] == self.WEAPON and request['range'] == 480 and request['damage'] == 24
                and request['presentation_receipt_id'] not in self.shot_receipts
                and self.finite_vector(request['origin']) and self.finite_vector(request['direction'])
                and abs(norm(request['direction'])-1) < .000001 and shot['accepted'] and shot['resolved'],
                'fresh real Arrow resolver shot with original weapon/source and finite unit ray')
        self.shot_sequence = sequence; self.shot_receipts.add(request['presentation_receipt_id'])
        self.shots.append(self.receipt(s))
        if shot['status'] == 'miss':
            require(shot['impact'] == [math.inf]*3 and shot['collider'] == dict(id=0, path='')
                    and shot['target_entity_id'] == 0 and shot['applied_damage'] == 0
                    and not shot['damaged'] and not shot['destroyed'], 'authentic no-contact miss, no invented hit')
        else:
            require(self.finite_vector(shot['impact']) and shot['collider']['id'] > 0
                    and shot['collider']['path'], 'actual finite contact and real collider')
        if shot['target_entity_id'] != s['target']['id'] or not shot['damaged']: return
        damage = shot['damage_result']
        require(damage.get('accepted') and shot['damageable_id'] > 0 and 0 < shot['applied_damage'] <= 24
                and damage.get('health') == shot['remaining_health'] == s['target']['health'],
                'actual sole damage ledger confirms real player-weapon picket damage')
        if shot['destroyed']:
            require(self.charge is not None and self.launched is not None and self.kill is None
                    and damage.get('destroyed') and shot['remaining_health'] == 0
                    and s['target']['destroyed'], 'real charged picket terminal zero-health kill')
            self.kill = self.receipt(s)

    def validate_observation(self, s):
        require(s.get('mode') == 'heavy-breach'
                and (self.last_sequence < 0 or s['sequence'] == self.last_sequence+1),
                'every Heavy observation retained in sequence')
        self.last_sequence = s['sequence']; self.last_state = s
        if s['paused']:
            require(self.stage in ('pause', 'quit_wait') and self.next_posting is not None,
                    'pause only after full physical Heavy journey')
            return
        require(s['actors_current'], 'current Main/Player/Arrow/board/director/objective/picket')
        b, d, t = s['breach'], s['breach']['board']['director'], s['target']
        if self.initial is None:
            require(s['phase'] == 'INTRO' and not s['guided_complete'] and not b['board']['sortie_armed']
                    and b['board']['offered_scenario'] == 'heavy_breach', 'fresh normal title and original Heavy posting')
            self.require_home(s, False)
            require(s['settlement']['record'].get('total_receipts', 0) == 0, 'fresh actual unpaid ledger')
            self.initial = copy.deepcopy(s)
        require(all(s[k] == self.initial[k] and s[k] for k in self.IDS)
                and all(b[k] == self.initial['breach'][k] for k in ('board_id', 'director_id', 'objective_id', 'objective_position'))
                and t['id'] == self.initial['target']['id'] and t['shape_id'] == self.initial['target']['shape_id'],
                'original process/Player/Arrow/input/berth/board/picket and live authored objective retained')
        require(s['default_sampler'] and s['default_controls'] and s['tuning_unchanged']
                and s['ship_tuning'] == self.initial['ship_tuning'] and s['walk_tuning'] == self.DEFAULT_WALK
                and s['physics_ticks'] == 60 and s['time_scale'] == 1
                and s['weapon_source'] == 1102 and s['weapon']['range'] == 480 and s['weapon']['damage'] == 24,
                'original Arrow/default controls, combat profile and production pacing')
        require(not s['destroyed'] and s['hull'] > 0 and not s['remote_piloted']
                and not s['guided_complete'] and s['phase'] not in ('FAILED', 'RECOVERING'),
                'live original local player/craft, no recovery or skipped Guided credit')
        previous = self.observed_previous
        if previous:
            require(s['frame'] == previous['frame']+1, 'consecutive actual physics frames')
            if s['native_interact'] != previous['native_interact']:
                self.native_edges.append(dict(frame=s['frame'], pressed=s['native_interact'], stage=self.stage))
            if self.stage.startswith('walk_'):
                self.require_walking(s)
                motion = self.require_motion_epoch(s)
                require(motion['start'] == previous['player'], 'continuous original Player motion')
                if motion['step_up']: self.require_step_event(s, motion)
                else: require(norm(sub(s['player'], previous['player'])) <= 9.2/60+.10, 'ordinary bounded walking')
                self.walked += norm(sub(s['player'], previous['player']))
        if self.armed is None and b['board']['sortie_armed']:
            press = self.receipts.get('arm_press')
            require(press is not None and s['frame'] > press['frame'] and s['native_interact']
                    and b['board']['armed_actor_instance_id'] == s['player_id']
                    and b['last_result'].get('accepted') and b['candidate'] and b['distance'] <= 2.8,
                    'actual physical E arms this posted Heavy for the original walking Player')
            self.armed = self.receipt(s)
        if self.departure is None and b['board']['active_director_generation'] > 0:
            require(self.armed is not None and not s['landed'] and s['lease_free']
                    and s['active_ship'] and s['piloted'] and s['seated_at_pilot'] and s['command_thrust'] > 0
                    and d['scenario'] == 'heavy_breach' and not b['board']['sortie_armed'],
                    'real occupied Arrow takeoff consumes the physical Heavy arm')
            self.departure = self.receipt(s)
        if self.departure is not None:
            require(d['scenario'] == 'heavy_breach'
                    and d['scenario_generation'] == self.departure['breach']['board']['director']['scenario_generation']
                    and d['outcome'] in ('pending', 'cleared'), 'one real Heavy generation; first failed/withdrawn/expired outcome stops')
            if d['launched'] and self.launched is None:
                require(t['active'] and t['source_id'] == 2102 and t['health'] > 0
                        and b['receipt']['accepted'] and b['receipt']['picket_instance_id'] == t['id']
                        and b['receipt']['protected_objective_instance_id'] == b['objective_id'],
                        'director launches actual charged-picket/protected-objective relationship')
                self.launched = self.receipt(s)
            if t['charge'] and self.charge is None:
                require(self.launched is not None and t['active']
                        and t['charge_target_id'] == b['objective_id']
                        and t['charge_dispatch_generation'] == d['scenario_generation'],
                        'real current lance charge targets the authored protected objective')
                self.charge = self.receipt(s)
        self.observe_shot(s)
        if d['outcome'] == 'cleared' and self.departure is not None:
            require(self.kill is not None and t['health'] == 0 and b['board']['offered_scenario'] == 'torpedo_run',
                    'real player-weapon picket kill alone clears Heavy and rotates normal posting')
            self.require_paid(s)
            if self.paid is None: self.paid = self.receipt(s); self.paid['settlement'] = copy.deepcopy(s['settlement'])
        if self.paid is not None:
            self.require_paid(s)
            require(s['settlement']['record'] == self.paid['settlement']['record'], 'same once-only payment retained through home')
        if self.stage == 'shutdown':
            self.require_home(s)
            if s['engine'] == 'OFFLINE' and not s['flight_demand']:
                if self.neutral_start is None: self.neutral_start = s['frame']
            else: self.neutral_start = None
        self.observed_previous = copy.deepcopy(s)

    def begin_walk(self, stage, points, s):
        self.route = [p[:] for p in points]; self.enter(stage, s)

    def press(self, key, stage, label, s, now):
        if self.tap_key is None and not s['native_interact']:
            self.tap(key, now)
            if self.tap_key == key:
                self.receipts[label] = self.receipt(s); self.enter(stage, s)

    def update(self, s, now):
        require(self.last_state is s, 'latest validated Heavy sample alone drives ordinary OS input')
        self.frame = s['frame']
        if self.stage in ('pause', 'quit_wait'):
            self.fire_control.release(); return self.ui_update(s, now)
        keys, dx, dy, fire = set(), 0, 0, False
        frames = max(1, self.frame-self.last_input_frame); self.last_input_frame = self.frame
        speed = norm(s['ship_velocity']); b = s['breach']; d = b['board']['director']
        if self.stage == 'boot' and s['menu_ready']:
            self.press('e', 'begin_shift', 'begin_shift_press', s, now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP' and s['supported']:
            self.begin_walk('walk_board', [[-8.5, .18, 6], [8, .18, 6], [8, .18, -24]], s)
        elif self.stage.startswith('walk_'):
            self.require_walking(s)
            if self.route:
                dx, arrived = self.walk_to(s, self.route[0], keys, frames)
                if arrived: self.visited.append(dict(stage=self.stage, frame=s['frame'], point=self.route.pop(0)))
            elif self.stage in ('walk_board', 'walk_next'):
                dx, yaw, _ = self.yaw_to(s, b['position'])
                ready = b['candidate'] and b['distance'] <= 2.55 and b['facing'] >= .05 and abs(yaw) < .08
                if ready and self.stage == 'walk_board':
                    require(b['board']['offered_scenario'] == 'heavy_breach' and b['available'].get('available'), 'ordinary initial Heavy available')
                    self.press('e', 'arm_wait', 'arm_press', s, now)
                elif ready:
                    require(self.paid is not None and b['board']['offered_scenario'] == 'torpedo_run'
                            and not b['board']['sortie_armed'] and b['available'].get('available')
                            and 'TORPEDO RUN' in b['prompt'], 'physical board offers usable normal next Torpedo posting')
                    self.next_posting = self.receipt(s); self.receipts['next_posting'] = self.next_posting
                    self.tap_key = None; self.enter('pause', s)
            elif s['candidate'] and not s['station_candidate'] and s['boarding_distance'] <= 7 and not s['reboard_blocked']:
                self.press('e', 'board_wait', 'board_press', s, now)
            else: dx, _ = self.walk_to(s, s['boarding'], keys, frames)
        elif self.stage == 'arm_wait':
            if self.armed is not None:
                self.begin_walk('walk_ship', [[8, .18, 6], [-8.5, .18, 6], [-8.5, .18, 13.5],
                    [-35, .18, 13.5], [-35, .18, 22], [s['boarding'][0], .18, 22]], s)
            else: require(self.frame <= self.receipts['arm_press']['frame']+90, 'one physical arm press, no retry')
        elif self.stage == 'board_wait':
            if s['piloted'] and s['seated_at_pilot'] and not s['transition_busy']:
                self.require_home(s, False); self.receipts['boarded'] = self.receipt(s); self.enter('depart', s)
            else: require(self.frame <= self.receipts['board_press']['frame']+300, 'one real Arrow boarding, no retry')
        elif self.stage == 'depart':
            if self.departure is None or norm(sub(s['position'], s['parked'])) < 16: keys.add('w')
            else:
                keys.add('Prior')
                if speed <= .35: self.enter('fight', s)
        elif self.stage == 'fight':
            keys.add('Prior')
            if self.paid is not None:
                self.fire_control.release(); self.mouse_pending = None; self.enter('restore', s)
            elif self.launched is not None and s['target']['active']:
                dx, dy, align = self.weapon_aim(s, sub(s['target']['aim'], s['camera']))
                gate = s['fire_gate']
                require(gate['frame'] == s['frame'] and gate['ship_id'] == s['ship_id']
                        and gate['target_id'] == s['target']['id'], 'current actual camera/next-muzzle fire forecast')
                ready = self.charge is not None and gate['clear'] and gate['weapon'].get('ready')
                fire = self.fire_control.step(s, ready)
        elif self.stage == 'restore':
            keys.add('Prior'); dx, dy, restored = self.restore_attitude(s, keys)
            if restored and speed <= .35 and self.mouse_pending is None:
                require(s['capture'], 'actual Arrow home capture after genuine fight, no direct landing')
                dx = dy = 0; keys.discard('q'); keys.discard('r')
                self.press('l', 'land', 'landing_press', s, now)
        elif self.stage == 'land':
            keys.add('Prior'); self.landing_seen |= s['landing_active']
            if s['phase'] == 'SHUT_DOWN' and s['landed']:
                require(self.landing_seen, 'sole normal L performed actual home landing')
                self.require_home(s); self.receipts['docked'] = self.receipt(s); keys.clear(); self.enter('shutdown', s)
            else:
                require(self.landing_seen or self.frame <= self.receipts['landing_press']['frame']+120, 'sole ordinary landing accepted, no retry')
        elif self.stage == 'shutdown' and self.neutral_start is not None and self.frame-self.neutral_start >= 89:
            self.require_home(s); self.press('e', 'exit', 'exit_press', s, now)
        elif self.stage == 'exit':
            self.require_home(s)
            if not s['seated'] and not s['piloted'] and not s['transition_busy'] and s['supported']:
                self.require_walking(s)
                require(norm(sub(s['player'], s['exit'])) < .65, 'actual normal supported Arrow exit anchor')
                self.receipts['home_exit'] = self.receipt(s)
                self.begin_walk('walk_next', [[s['player'][0], .18, 22], [-35, .18, 22], [-35, .18, 13.5],
                    [-8.5, .18, 13.5], [-8.5, .18, 6], [8, .18, 6], [8, .18, -24]], s)
            else: require(self.frame <= self.receipts['exit_press']['frame']+600, 'one physical supported exit, no retry')
        if self.stage != 'fight': self.fire_control.release()
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame+6: keys.add(self.tap_key)
            else:
                self.tap_key = None; self.tap_cooldown = now+.3; self.tap_release_frame = self.frame
        facing = s['camera_back'] if s['seated'] else s['walk_forward']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = dy = 0
            else: self.mouse_pending = None
        if dx or dy: self.mouse_pending = facing[:]
        return keys, dx, dy, fire

    def report(self):
        return dict(stage=self.stage, stages=self.stages, receipts=self.receipts, visited=self.visited,
                    walked_m=self.walked, shots=self.shots, fire_consumption=self.fire_control.receipts,
                    charge=self.charge, kill=self.kill, paid=self.paid, last_state=self.last_state)

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.kill is not None and self.paid is not None and self.next_posting is not None
                and 'home_exit' in self.receipts, 'complete real Heavy sortie, home, next posting and normal UI OS exit0')
        self.result = dict(self.report(), completion_marker=self.MARKER, normal_ui_exit=True)


class HeavyBreachFiles(HabitatRestartFiles):
    MUTABLE = HabitatRestartFiles.MUTABLE | {'heavy_breach_session', 'game_flow_reward_store'}

    def observe(self, s, pilot):
        if s['paused']: return
        label = 'paid' if pilot.paid is not None else 'baseline'
        if label in self.snapshots: return
        document = self.capture(label, s['settlement']['store']); payload = document['payload']
        if label == 'baseline':
            require(payload.get('game_flow_reward_store', {}).get('total_receipts', 0) == 0, 'independent actual empty reward document')
        else:
            receipt = pilot.require_paid(s)
            completion = payload['heavy_breach_session']['session']['completion']
            require(payload['game_flow_reward_store'] == s['settlement']['record']
                    and completion['activity_id'] == pilot.ACTIVITY and completion['scenario'] == 'heavy_breach'
                    and completion['outcome'] == 'cleared' and completion['reward_granted'] is True
                    and completion['generation'] == receipt['activity_generation'],
                    'actual primary document contains exact once-only Heavy reward and acknowledged clear')

    def finish(self):
        require('paid' in self.snapshots, 'actual committed Heavy payment read before shutdown')
        final = self.capture('orderly-close'); paid = self.snapshots['paid']['document']
        self.require_orderly(final, paid)
        require(all(final['payload'][k] == paid['payload'][k] for k in ('game_flow_reward_store', 'heavy_breach_session')),
                'actual clean UI shutdown preserves same once-only receipt/terminal after next posting')


class RetainedHeavyFiles(HabitatRestartFiles):
    """Seed either declared real save, then read only the game's own primary."""
    FIXTURES = frozenset({
        (8655, '25f9ccfe03b22018eae2cffcb52841ed5fbcff3f4a51a6c020e6c7495701aa73'),
        (9296, 'af2fada0a687b3a2dad6ee5c4550d4e6cd92120f2df94f6681f053e5b23ed409'),
    })
    RELATIVE_SAVE = Path('data/godot/app_userdata/Mudds Shipyards/mudds_user_data.json')

    def __init__(self, profile, output, fixture):
        super().__init__(profile, output)
        fixture = Path(fixture)
        require(fixture.is_file() and not fixture.is_symlink(), 'retained input is a regular raw save fixture')
        with fixture.open('rb') as stream:
            raw = stream.read(max(size for size, _ in self.FIXTURES) + 1)
        digest = hashlib.sha256(raw).hexdigest()
        require((len(raw), digest) in self.FIXTURES,
                'exact accepted earned Heavy orderly-close fixture bytes')
        self.expected = json.loads(raw)
        self.path = self.profile / self.RELATIVE_SAVE
        self.path.parent.mkdir(parents=True, mode=0o700, exist_ok=False)
        with self.path.open('xb') as stream:
            stream.write(raw)
        self.path.chmod(0o644)
        self.fixture = {'path': str(fixture.resolve()), 'bytes': len(raw), 'sha256': digest}
        require(self.capture('retained-input') == self.expected, 'fresh private profile contains only the exact retained input')

    def require_retained(self, document):
        self.require_preserved(self.expected, document)
        require(document['payload']['solo_safe_recovery'] == self.expected['payload']['solo_safe_recovery'],
                'actual on-foot Arrow safe-home preference retained')

    def require_loaded(self, document, sample):
        self.require_retained(document)
        payload, previous = document['payload'], self.expected['payload']
        crash, safe = payload['crash_recovery'], payload['safe_start_recovery']
        require(document['generation'] > self.expected['generation']
                and sample['settlement']['store']['generation'] > self.expected['generation'],
                'production reader advanced the actual retained primary generation')
        require(crash['state'] == 'running' and crash['unclean_start_count'] == 0
                and crash['session_id'] == previous['crash_recovery']['session_id'] + 1
                and crash['startup_generation'] == previous['crash_recovery']['startup_generation'] + 1,
                'retained clean save starts healthy next session and startup')
        require(safe['startup_generation'] == previous['safe_start_recovery']['startup_generation'] + 1
                and safe['state'] in ('starting', 'stable') and safe['consecutive_failure_count'] == 0
                and not safe['safe_settings_recommended'], 'retained clean save has no safe-start recovery recommendation')
        events = payload['session_diagnostics']['events']
        require(not any(e['event_code'] == 'crash_detected' for e in events)
                and any(e['event_code'] == 'session_started' and e['session_id'] == crash['session_id']
                        and e['fields'].get('recovered') is False for e in events),
                'actual current session starts without crash recovery')
        require(payload['game_flow_reward_store'] == sample['settlement']['record'],
                'actual retained primary and live decoded reward authority agree')

    def observe(self, sample, pilot):
        if sample['paused']: return
        if sample['menu_ready'] and 'loaded-title' not in self.snapshots:
            document = self.capture('loaded-title', sample['settlement']['store'])
            self.require_loaded(document, sample)
            pilot.file_context_accepted = True
        if pilot.next_posting is not None and 'next-posting' not in self.snapshots:
            document = self.capture('next-posting', sample['settlement']['store'])
            self.require_loaded(document, sample)

    def finish(self):
        require('loaded-title' in self.snapshots and 'next-posting' in self.snapshots,
                'actual primary observed at normal title and physical next posting')
        final = self.capture('orderly-close')
        self.require_orderly(final, self.snapshots['loaded-title']['document'])
        self.require_retained(final)


class RetainedHeavyPilot(HeavyBreachPilot):
    """Ordinary title/load/walk/quit using a previously earned Heavy save."""
    MARKER = 'NATIVE_RETAINED_HEAVY_OK'
    WAYPOINTS = ((-8.5, .18, 6), (8, .18, 6), (8, .18, -24))

    def __init__(self, expected, expected_pid):
        super().__init__()
        self.expected = copy.deepcopy(expected)
        self.expected_pid = expected_pid
        self.file_context_accepted = False

    def require_loaded_board(self, s):
        board = s['breach']['board']; handoff = board['reward_handoff']; director = board['director']
        generation = self.expected['payload']['game_flow_reward_store']['last_receipt']['activity_generation']
        require(board['offered_scenario'] == 'torpedo_run' and not board['sortie_armed']
                and board['active_director_generation'] == 0 and director['state'] == 'idle'
                and director['scenario_generation'] == 0
                and handoff['highest_reward_generation'] == generation == 1
                and handoff['pending_reward_generation'] == 0,
                'loaded paid Heavy acknowledgement offers Torpedo while fresh director stays idle and unarmed')

    def validate_observation(self, s):
        require(s.get('mode') == 'heavy-breach' and s['pid'] == self.expected_pid
                and (self.last_sequence < 0 or s['sequence'] == self.last_sequence + 1),
                'every retained Heavy observation belongs to this exact process in sequence')
        self.last_sequence = s['sequence']; self.last_state = s
        if s['paused']:
            require(self.initial is not None and s['main_id'] == self.initial['main_id']
                    and self.stage in ('pause', 'quit_wait') and self.next_posting is not None,
                    'retained load pauses only after physical next-posting continuation')
            return
        require(s['actors_current'], 'retained load current production actors')
        if self.initial is None:
            require(s['phase'] == 'INTRO' and norm(sub(s['player'], s['spawn'])) < .75,
                    'retained clean save starts at normal title and authored spawn')
            self.initial = copy.deepcopy(s)
        require(all(s[k] == self.initial[k] and s[k] for k in self.IDS)
                and all(s['breach'][k] == self.initial['breach'][k]
                        for k in ('board_id', 'director_id', 'objective_id', 'objective_position')),
                'same current Player Arrow board director and objective during retained continuation')
        require(s['phase'] in ('INTRO', 'APPROACH_SHIP') and not s['seated'] and not s['piloted']
                and not s['remote_piloted'] and not s['station_seated'] and not s['game_station_seated']
                and not s['sleeping'] and not s['transition_busy'] and not s['destroyed']
                and not s['guided_complete'] and not s['native_fire'] and not s['command_fire'],
                'retained continuation stays awake on foot without activity combat or pilot admission')
        require(s['default_sampler'] and s['default_controls'] and s['tuning_unchanged']
                and s['ship_tuning'] == self.initial['ship_tuning'] and s['walk_tuning'] == self.DEFAULT_WALK
                and s['physics_ticks'] == 60 and s['time_scale'] == 1,
                'retained continuation uses original walking controls tuning and pacing')
        expected_ledger = self.expected['payload']['game_flow_reward_store']
        require(s['settlement']['record'] == expected_ledger,
                'live decoded retained Heavy ledger remains exactly one original non-replayable receipt')
        self.require_loaded_board(s)
        previous = self.observed_previous
        if previous:
            require(s['frame'] == previous['frame'] + 1, 'consecutive retained continuation physics frames')
            if s['native_interact'] != previous['native_interact']:
                self.native_edges.append(dict(frame=s['frame'], pressed=s['native_interact'], stage=self.stage))
            if self.stage == 'walk_next':
                self.require_walking(s)
                motion = self.require_motion_epoch(s)
                require(motion['start'] == previous['player'], 'continuous retained Player motion')
                if motion['step_up']: self.require_step_event(s, motion)
                else: require(norm(sub(s['player'], previous['player'])) <= 9.2/60 + .10,
                              'ordinary bounded retained walking')
                self.walked += norm(sub(s['player'], previous['player']))
        self.observed_previous = copy.deepcopy(s)

    def update(self, s, now):
        require(self.last_state is s, 'latest validated retained observation alone drives OS input')
        self.frame = s['frame']
        if self.stage in ('pause', 'quit_wait'): return self.ui_update(s, now)
        keys, dx = set(), 0
        frames = max(1, self.frame - self.last_input_frame); self.last_input_frame = self.frame
        if self.stage == 'boot' and s['menu_ready'] and self.file_context_accepted:
            self.press('e', 'begin_shift', 'begin_shift_press', s, now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP' and s['supported']:
            require(norm(sub(s['player'], s['spawn'])) < .75,
                    'ordinary Begin Shift admits the authored fresh spawn after clean quit')
            require(any(edge['pressed'] for edge in self.native_edges), 'ordinary Begin Shift E was observed')
            self.receipts['awake'] = self.receipt(s)
            self.begin_walk('walk_next', [list(point) for point in self.WAYPOINTS], s)
        elif self.stage == 'walk_next':
            self.require_walking(s)
            if self.route:
                dx, arrived = self.walk_to(s, self.route[0], keys, frames)
                if arrived:
                    self.visited.append(dict(stage=self.stage, frame=s['frame'], point=self.route.pop(0)))
            else:
                breach = s['breach']
                dx, yaw, _ = self.yaw_to(s, breach['position'])
                if breach['candidate'] and breach['distance'] <= 2.55 and breach['facing'] >= .05 and abs(yaw) < .08:
                    require(breach['available'].get('available') and 'TORPEDO RUN' in breach['prompt'],
                            'physical retained board offers usable next Torpedo posting without arming')
                    require(self.walked > 10 and len(self.visited) == len(self.WAYPOINTS),
                            'all retained continuation waypoints reached by actual physical walking')
                    self.next_posting = self.receipt(s); self.receipts['next_posting'] = self.next_posting
                    self.tap_key = None; self.enter('pause', s)
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame + 6: keys.add(self.tap_key)
            else:
                self.tap_key = None; self.tap_cooldown = now + .3; self.tap_release_frame = self.frame
        facing = s['walk_forward']
        if self.mouse_pending is not None:
            if norm(sub(facing, self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = None
        if dx: self.mouse_pending = facing[:]
        return keys, dx, 0, False

    def report(self):
        return dict(stage=self.stage, stages=self.stages, receipts=self.receipts, visited=self.visited,
                    walked_m=self.walked, native_edges=self.native_edges, last_state=self.last_state)

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.file_context_accepted and self.next_posting is not None
                and 'awake' in self.receipts and 'exit_ui' in self.receipts,
                'retained Heavy load physical continuation and normal UI actual OS exit0')
        self.result = dict(self.report(), completion_marker=self.MARKER, normal_ui_exit=True)


class CorruptRetainedHeavyFiles(RetainedHeavyFiles):
    """One corrupt-primary recovery, then the unchanged retained Heavy walk."""
    FIXTURES = frozenset({(9296, 'af2fada0a687b3a2dad6ee5c4550d4e6cd92120f2df94f6681f053e5b23ed409')})
    CORRUPT = b'{corrupt'
    CORRUPT_SHA256 = '98e8e66d98f45504a80923203572020d15c102340a21a5201c92c598a7e34b69'
    MARKER = 'NATIVE_CORRUPT_RETAINED_HEAVY_OK'

    def __init__(self, profile, output, fixture):
        super().__init__(profile, output, fixture)
        require(self.expected['payload']['crash_recovery']['session_id'] == 2,
                'corrupt recovery admits only the pinned actual run b4 session two fixture')
        self.raw = self.path.read_bytes()
        self.backup = Path(str(self.path)+'.bak')
        self.recovery = Path(str(self.path)+'.recovery')
        with self.backup.open('xb') as stream: stream.write(self.raw)
        self.backup.chmod(0o600)
        self.path.write_bytes(self.CORRUPT); self.path.chmod(0o600)
        require(len(self.CORRUPT) == 8 and hashlib.sha256(self.CORRUPT).hexdigest() == self.CORRUPT_SHA256,
                'literal eight-byte corrupt primary identity')
        self.output.joinpath('corrupt-primary.bin').write_bytes(self.CORRUPT)
        self.output.joinpath('valid-backup.json').write_bytes(self.raw)
        self.leg = 0

    def require_quarantine(self):
        require(self.recovery.is_file() and not self.recovery.is_symlink()
                and self.recovery.read_bytes() == self.CORRUPT,
                'exact bad primary bytes retained in actual recovery sibling through final exit')

    def require_live(self, sample):
        recovery = sample['recovery']
        require(recovery['store']['path'] == str(self.path)
                and recovery['settings'] == self.expected['payload']['runtime_settings']['values'],
                'actual production store and runtime settings retain the exact accepted values')
        if not sample['paused']:
            require(sample['settlement']['record'] == self.expected['payload']['game_flow_reward_store'],
                    'actual live Heavy ledger retains exactly the original credit')

    def observe(self, sample, pilot):
        self.require_live(sample)
        if self.leg:
            self.require_quarantine()
            super().observe(sample, pilot)
            for label in ('loaded-title', 'next-posting'):
                if label in self.snapshots:
                    require(self.snapshots[label]['document']['generation'] > self.snapshots['repair-committed']['document']['generation'],
                            'distinct cold process commits its healthy startup after the actual repair successor')
            return
        recovery = sample['recovery']; store = recovery['store']
        if store['source'] == 'backup':
            require(self.path.read_bytes() == self.CORRUPT and self.backup.read_bytes() == self.raw
                    and store['generation'] == self.expected['generation'],
                    'backup Boot preserves actual corrupt primary and exact valid backup without ordinary writes')
            self.require_quarantine()
            # Later read-only users of the shared store clear its transient
            # receipt. Startup's detached load result retains the authority.
            loaded = recovery['load'].get('store_status', {})
            quarantine = loaded.get('recovery_receipt', {})
            require(loaded.get('accepted') is True and loaded.get('source') == 'backup'
                    and loaded.get('reason') == 'primary_invalid_backup_loaded'
                    and loaded.get('generation') == self.expected['generation']
                    and quarantine.get('available') is True
                    and quarantine.get('path') == 'user://mudds_user_data.json.recovery'
                    and quarantine.get('bytes') == len(self.CORRUPT),
                    'retained authentic startup backup-load receipt names the exact game-relative recovery sibling')
            if sample.get('menu_ready') and 'backup-title' not in self.snapshots:
                require(recovery['load'].get('store_reason') == 'primary_invalid_backup_loaded',
                        'actual startup loader selected the valid backup')
                self.snapshots['backup-title'] = copy.deepcopy(recovery)
                pilot.file_context_accepted = True
            return
        require(store['source'] == 'primary' and pilot.confirm_requested
                and 'repair_confirm_ui' in pilot.receipts and 'backup-title' in self.snapshots,
                'only actual focused GUI confirmation may promote the primary')
        self.require_quarantine()
        if 'repair-committed' not in self.snapshots:
            document = self.capture('repair-committed', store)
            expected_generation = self.expected['generation'] + 1
            report = recovery['repair']; status = report['last_status']
            require(status.get('accepted') is True and status.get('reason') == 'repair_committed'
                    and report['confirmation_consumed'] is True and report['prepared'] is False
                    and report['observed_generation'] == self.expected['generation']
                    and store['generation'] == document['generation'] == expected_generation
                    and document['commit']['id'] == f'runtime-settings-repair-{expected_generation:010d}'
                    and document['commit']['parent_id'] == self.expected['commit']['id']
                    and document['commit']['parent_generation'] == self.expected['generation']
                    and document['payload'] == self.expected['payload']
                    and self.backup.read_bytes() == self.raw,
                    'one actual GUI repair successor commit precedes all other writes and preserves entire payload and valid backup')
            require(recovery['ui']['settings_visible'] and recovery['ui']['status_visible']
                    and recovery['ui']['status_text'] == CorruptRetainedRepairPilot.STATUS,
                    'actual Settings reports successful repair and required new OS process')
            pilot.repair_accepted = True

    def finish_leg(self, leg, pilot):
        self.require_quarantine()
        if not leg:
            require(pilot.repair_accepted, 'first process completed genuine Settings repair before normal quit')
            document = self.capture('repair-orderly-close')
            require(document == self.snapshots['repair-committed']['document']
                    and document['payload'] == self.expected['payload']
                    and self.backup.read_bytes() == self.raw,
                    'failed first-start coordinators never manufacture a healthy initial session or mutate repaired payload')
        else:
            super().finish()

    @staticmethod
    def require_two_legs(legs, elapsed):
        require(len(legs) == 2 and legs[0]['pid'] != legs[1]['pid']
                and all(item['exit_code'] == 0 and item['reaped'] and item.get('normal_ui_exit') for item in legs)
                and elapsed < CAP,
                'two distinct normally quit reaped OS0 processes inside the unchanged whole-route cap')


class CorruptRetainedRepairPilot(RetainedHeavyPilot):
    """Normal Begin Shift, focused Settings confirmation, and pause-menu quit."""
    MARKER = 'NATIVE_CORRUPT_RETAINED_REPAIR_OK'
    STATUS = 'SETTINGS BACKUP REPAIRED\nQUIT AND REOPEN THE GAME TO FINISH RECOVERY'

    def __init__(self, expected, expected_pid):
        super().__init__(expected, expected_pid)
        self.confirm_requested = self.repair_accepted = False
        self.ui_edges = []

    def enter(self, stage, s):
        if not s['paused']:
            return super().enter(stage, s)
        # Paused observations carry UI identity and sequence, without querying
        # gameplay position/phase or advancing a physics owner for bookkeeping.
        self.stage = stage
        ui = s['recovery']['ui']
        event = dict(stage=stage, frame=s['frame'], sequence=s['sequence'], main_id=s['main_id'],
                     focus_path=ui['focus_path'], focus_name=ui['focus_name'])
        self.stages.append(event)
        print(json.dumps(event), flush=True)

    def require_loaded_board(self, s):
        board = s['breach']['board']; handoff = board['reward_handoff']; director = board['director']
        require(board['offered_scenario'] == 'heavy_breach' and not board['sortie_armed']
                and board['active_director_generation'] == 0 and director['state'] == 'idle'
                and director['scenario_generation'] == 0
                and handoff['highest_reward_generation'] == 0 and handoff['pending_reward_generation'] == 0
                and s['breach']['prompt'] == 'SAVE RECOVERY REQUIRED',
                'backup-loaded first board refuses terminal adoption and remains default idle unarmed Heavy until a new process')

    def validate_observation(self, s):
        if not s['paused']:
            super().validate_observation(s)
        else:
            require(s.get('mode') == 'heavy-breach' and s['pid'] == self.expected_pid
                    and s['sequence'] == self.last_sequence + 1 and self.initial is not None
                    and s['main_id'] == self.initial['main_id']
                    and self.stage in ('repair_pause', 'settings_open', 'repair_confirm', 'repair_wait', 'repair_back', 'pause', 'quit_wait'),
                    'every paused repair observation belongs to the same exact Main and first OS process')
            self.last_sequence = s['sequence']; self.last_state = s
        recovery = s['recovery']
        begin = recovery['safe_start']['begin_status']
        session = recovery['session']['last_status']
        require(begin.get('accepted') is False and begin.get('reason') == 'store_recovery_required'
                and session.get('accepted') is False and session.get('reason') == 'begin_failed'
                and session.get('coordinator_status', {}).get('reason') == 'store_recovery_required',
                'both actual first startup coordinators refuse backup writes until a new OS process')
        require(recovery['settings'] == self.expected['payload']['runtime_settings']['values'],
                'repair process uses exact decoded runtime settings throughout')

    def update(self, s, now):
        require(self.last_state is s, 'latest validated real observation alone drives repair keyboard')
        self.frame = s['frame']
        if self.stage in ('pause', 'quit_wait'):
            return self.ui_update(s, now)
        if self.stage == 'boot':
            if s['menu_ready'] and self.file_context_accepted:
                self.press('e', 'begin_shift', 'begin_shift_press', s, now)
        if self.stage == 'begin_shift':
            if s['phase'] == 'APPROACH_SHIP' and s['supported']:
                require(any(edge['pressed'] for edge in self.native_edges), 'actual normal Begin Shift E before Settings')
                self.receipts['awake'] = self.receipt(s)
                self.tap_key = None; self.enter('repair_pause', s)
            else:
                if self.tap_key is not None:
                    if now < self.tap_until or self.frame < self.tap_frame + 6:
                        return {self.tap_key}, 0, 0, False
                    self.tap_key = None
                return set(), 0, 0, False
        if self.stage == 'boot': return set(), 0, 0, False
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key}, 0, 0, False
            self.ui_edges.append(dict(sequence=s['sequence'], key=self.ui_key, pressed=False))
            self.ui_key = None; self.ui_release_until = now + .10
            return set(), 0, 0, False
        if now < self.ui_release_until or (s['paused'] and any(s['native_keys'].values())):
            return set(), 0, 0, False
        ui = s['recovery']['ui']; key = None
        if self.stage == 'repair_pause':
            if not s['paused']: key = 'Escape'
            else:
                require(ui['main_visible'] and ui['focus_path'], 'actual keyboard-focused main pause page')
                if ui['focus_is_settings_open']:
                    require(ui['open_visible'] and ui['open_enabled'] and ui['focus_visible'] and ui['focus_enabled']
                            and ui['focus_name'] == 'SettingsOpenButton' and ui['focus_path'] == ui['open_path']
                            and ui['open_text'] == 'SETTINGS', 'actual enabled focused SettingsOpenButton')
                    self.receipts['settings_open_ui'] = copy.deepcopy(s)
                    self.enter('settings_open', s); key = 'Return'
                else: key = 'Tab'
        elif self.stage in ('settings_open', 'repair_confirm'):
            require(s['paused'] and ui['settings_visible'] and ui['focus_path'], 'real Settings page retains keyboard focus')
            if ui['focus_is_repair_confirm']:
                require(ui['confirm_visible'] and ui['confirm_enabled'] and ui['focus_visible'] and ui['focus_enabled']
                        and ui['confirmation_available'] and ui['focus_name'] == 'SettingsRepairConfirmButton'
                        and ui['focus_path'] == ui['confirm_path'] and ui['confirm_text'] == 'CONFIRM BACKUP REPAIR',
                        'actual opaque enabled focused SettingsRepairConfirmButton')
                require(not self.confirm_requested, 'exactly one GUI repair confirmation')
                self.confirm_requested = True; self.receipts['repair_confirm_ui'] = copy.deepcopy(s)
                self.enter('repair_wait', s); key = 'Return'
            else:
                self.enter('repair_confirm', s); key = 'Tab'
        elif self.stage == 'repair_wait' and self.repair_accepted:
            require(ui['settings_visible'] and ui['status_visible'] and ui['status_text'] == self.STATUS,
                    'player-visible repair success requires quit and reopen')
            self.receipts['repair_status_ui'] = copy.deepcopy(s)
            self.enter('repair_back', s); key = 'Escape'
        elif self.stage == 'repair_back' and ui['main_visible']:
            self.enter('pause', s)
        if key:
            self.ui_key, self.ui_until = key, now + .08
            self.ui_edges.append(dict(sequence=s['sequence'], key=key, pressed=True, focus=ui['focus_path']))
            return {key}, 0, 0, False
        return set(), 0, 0, False

    def report(self):
        return dict(super().report(), repair_accepted=self.repair_accepted, ui_edges=self.ui_edges)

    def finish(self, exit_code):
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.file_context_accepted and self.confirm_requested and self.repair_accepted
                and all(k in self.receipts for k in ('awake', 'settings_open_ui', 'repair_confirm_ui', 'repair_status_ui', 'exit_ui')),
                'actual Settings repair and restart message precede first normal HUD quit and OS0')
        self.result = dict(self.report(), completion_marker=self.MARKER, normal_ui_exit=True)


class UnsupportedSaveFiles(RetainedHeavyFiles):
    """Prelaunch fixture ownership and independent reads; never repair a live file."""
    FIXTURES = CorruptRetainedHeavyFiles.FIXTURES
    MARKER = 'NATIVE_UNSUPPORTED_SAVE_OK'
    SENTINEL = b'UNRELATED FILE MUST SURVIVE\n'
    WARNINGS = (
        b'WARNING: Startup could not read stored settings: store_load_failed',
        b'WARNING: Atomic runtime settings load retained authored defaults: store_load_failed / newer_schema',
    )
    SUFFIX = {'primary': '', 'temporary': '.tmp', 'backup': '.bak'}

    def __init__(self, profile, output, fixture, placement):
        require(placement in self.SUFFIX, 'one declared canonical future-artifact placement')
        super().__init__(profile, output, fixture)
        self.placement = placement
        self.leg = 0
        self.reset_defaults = None
        raw = self.path.read_bytes()
        backup = Path(str(self.path)+'.bak')
        with backup.open('xb') as stream: stream.write(raw)
        if placement == 'temporary':
            with Path(str(self.path)+'.tmp').open('xb') as stream: stream.write(raw)
        # Opaque future bytes are deliberately never copied into logs/reports.
        future = {'schema_version': 2, 'opaque_future_payload': {
            'private_marker': 'unsupported-private-'+secrets.token_hex(16),
            'shape': [None, True, {'future': 9}]}}
        Path(str(self.path)+self.SUFFIX[placement]).write_bytes(json.dumps(future, separators=(',', ':')).encode())
        for artifact in self.path.parent.iterdir(): artifact.chmod(0o600)
        sentinel = self.path.parent/'unrelated.txt'
        with sentinel.open('xb') as stream: stream.write(self.SENTINEL)
        sentinel.chmod(0o640)
        self.directory_identity = self.identity(self.path.parent)
        self.baseline = self.read_files()
        self.snapshots = {}
        self.capture_preserved('prelaunch')

    def read_files(self):
        require(not self.path.parent.is_symlink() and self.path.parent.resolve() == self.profile.resolve()/self.RELATIVE_SAVE.parent,
                'exact owned save directory without path redirection')
        names = {self.path.name, self.path.name+'.bak', 'unrelated.txt'}
        if self.placement == 'temporary': names.add(self.path.name+'.tmp')
        require({p.name for p in self.path.parent.iterdir()} == names, 'exact canonical artifact names and sentinel; no extra recovery siblings')
        result = {}
        for name in sorted(names):
            path = self.path.parent/name
            require(path.is_file() and not path.is_symlink(), 'owned artifacts remain ordinary files')
            before = path.stat()
            raw = path.read_bytes()
            after = path.stat()
            require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_mode)
                    == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_mode),
                    'independent artifact read has stable identity and contents')
            result[name] = (before.st_dev, before.st_ino, before.st_mode & 0o777, raw)
        return result

    def capture_preserved(self, label=None):
        require(self.identity(self.path.parent) == self.directory_identity, 'same exact owned save directory')
        current = self.read_files()
        require(current == self.baseline, 'unsupported authority preserves exact names bytes modes and file identities')
        if label is not None:
            require(label not in self.snapshots, 'milestone independently read once')
            self.snapshots[label] = {name: dict(device=item[0], inode=item[1], mode=oct(item[2]),
                bytes=len(item[3]), sha256=hashlib.sha256(item[3]).hexdigest()) for name, item in current.items()}

    def observe(self, s, pilot):
        self.capture_preserved()
        require(s['recovery']['store']['path'] == str(self.path), 'production store names exact owned path')
        label = f'leg-{self.leg+1}-title'
        if not s['paused'] and s['menu_ready'] and label not in self.snapshots:
            self.capture_preserved(label)
            pilot.file_context_accepted = True

    def require_warnings(self, lines):
        actual = diagnostic_lines(lines)
        require(len(actual) == len(self.WARNINGS) and all(actual.count(warning) == 1 for warning in self.WARNINGS),
                'exact two expected future-load production warnings occur once each per OS process; no other diagnostics')

    def finish_leg(self, leg, pilot):
        require(pilot.result is not None and pilot.quit_requested, 'ordinary UI exit precedes independent shutdown read')
        self.capture_preserved(f'leg-{leg+1}-orderly-close')

    def make_pilot(self, pid, cold):
        return UnsupportedSavePilot(self, pid, cold=cold)

    require_two_legs = staticmethod(CorruptRetainedHeavyFiles.require_two_legs)


class UnsupportedSavePilot(CorruptRetainedRepairPilot):
    """Ordinary OS keyboard Save, Reset confirmation and cold Begin Shift."""
    MARKER = UnsupportedSaveFiles.MARKER
    SAVE_STATUS = 'UNSAVED  //  STORE_LOAD_FAILED'
    RESET_STATUS = 'DEFAULTS ACTIVE  //  SAVE FAILED'

    def __init__(self, files, expected_pid, cold=False):
        super().__init__(files.expected, expected_pid)
        self.files, self.cold = files, cold
        self.save_refused = self.reset_refused = False
        self.attempt_baseline = None
        self.begin_attempts = None
        self.boot_settings = None

    def validate_observation(self, s):
        require(s.get('mode') == 'heavy-breach' and s['pid'] == self.expected_pid
                and (self.last_sequence < 0 or s['sequence'] == self.last_sequence+1),
                'every unsupported-save observation belongs to this exact process in sequence')
        self.last_sequence = s['sequence']; self.last_state = s
        if s['paused']:
            require(self.initial is not None and s['main_id'] == self.initial['main_id']
                    and self.stage in ('repair_pause', 'settings_open', 'save_wait', 'reset_open', 'reset_confirm', 'reset_wait', 'repair_back', 'pause', 'quit_wait'),
                    'same Main remains paused only during ordinary Settings and quit navigation')
        else:
            require(s['actors_current'], 'unsupported load leaves current production actors usable')
            if self.initial is None:
                require(s['phase'] == 'INTRO' and norm(sub(s['player'], s['spawn'])) < .75,
                        'unsupported load boots normal title and authored spawn')
                self.boot_settings = copy.deepcopy(s['recovery']['settings'])
                if self.cold:
                    require(self.files.reset_defaults is not None and self.boot_settings == self.files.reset_defaults,
                            'cold refused load uses the same actual authored defaults as first-process Reset')
                self.initial = copy.deepcopy(s)
            require(all(s[k] == self.initial[k] and s[k] for k in self.IDS)
                    and s['phase'] in ('INTRO', 'APPROACH_SHIP') and not any(s[k] for k in
                        ('seated','piloted','remote_piloted','station_seated','game_station_seated','sleeping','transition_busy','destroyed','native_fire','command_fire')),
                    'same original actors stay awake on foot without injected gameplay')
            require(s['default_sampler'] and s['default_controls'] and s['tuning_unchanged']
                    and s['physics_ticks'] == 60 and s['time_scale'] == 1 and s['walk_tuning'] == self.DEFAULT_WALK,
                    'authored default controls and pacing remain unchanged')
            ledger = s['settlement']['record']
            require(ledger.get('total_receipts', 0) == ledger.get('receipt_serial', 0) == 0
                    and not ledger.get('reward_counts') and not ledger.get('last_receipt'),
                    'refused outer envelope cannot adopt retained Heavy credits')
            if self.observed_previous and self.stage == 'walk_next':
                self.require_walking(s)
                require(s['frame']==self.observed_previous['frame']+1, 'every cold walking physics sample retained')
                motion=self.require_motion_epoch(s)
                require(motion['start']==self.observed_previous['player'], 'continuous actual cold Player motion')
                if motion['step_up']: self.require_step_event(s,motion)
                else: require(norm(sub(s['player'],self.observed_previous['player']))<=9.2/60+.10,
                              'ordinary bounded cold walking speed')
                self.walked+=norm(sub(s['player'],self.observed_previous['player']))
            if self.observed_previous and s['native_interact'] != self.observed_previous['native_interact']:
                self.native_edges.append(dict(frame=s['frame'], pressed=s['native_interact'], stage=self.stage))
            self.observed_previous = copy.deepcopy(s)
        self.validate_authority(s)

    def validate_authority(self, s):
        r = s['recovery']; store = r['store']; loaded = r['load']; nested = loaded['store_status']
        require(store['source'] == 'none' and store['generation'] == 0 and store['snapshot'] == {}
                and loaded['accepted'] is False and loaded['reason'] == 'store_load_failed'
                and loaded['store_reason'] == 'newer_schema' and nested['accepted'] is False
                and nested['reason'] == 'newer_schema' and nested['source'] == 'none'
                and nested['generation'] == 0 and nested['payload'] == {},
                'exact future outer envelope refuses load with none source generation zero empty snapshot')
        safe = r['safe_start']
        require(safe['restore_status']['reason'] == 'store_load_unavailable'
                and safe['restore_status']['accepted'] is False
                and safe['begin_status']['reason'] == 'not_attempted' and safe['begin_status']['accepted'] is False,
                'unsupported load never fabricates a healthy safe-start session')
        require(r['repair']['last_status']['reason'] == 'unsupported_newer_schema'
                and not r['ui']['confirmation_available'], 'unsupported authority never offers backup repair')
        p = r['persistence']
        require(self.settings_commits_unchanged(p),
                'no unsupported write becomes a successful settings commit')

    def settings_commits_unchanged(self, persistence):
        return (persistence['save_success_count'] == 0 and persistence['commit_serial'] == 0
                and not persistence['last_commit_id'])

    def refusal_status(self, status):
        return (status['accepted'] is False and status['reason'] == 'store_load_failed'
                and status['store_reason'] == 'newer_schema' and status['store_status']['payload'] == {})

    @staticmethod
    def focused(ui, action, name, text):
        return (ui['focus_is_settings_open' if action == 'open' else 'focus_is_'+action] and ui[action+'_visible'] and ui[action+'_enabled']
                and ui['focus_visible'] and ui['focus_enabled'] and ui['focus_name'] == name
                and ui['focus_path'] == ui[action+'_path'] and ui[action+'_text'] == text)

    def refused(self, s, operation):
        p = s['recovery']['persistence']; status = p['last_save_status']; ui = s['recovery']['ui']
        if p['save_attempt_count'] == self.attempt_baseline['save_attempt_count']: return False
        require(p['save_attempt_count'] == self.attempt_baseline['save_attempt_count']+1
                and p['accepted_transaction_count'] == self.attempt_baseline['accepted_transaction_count']+1
                and self.refusal_status(status)
                and ui['settings_visible'] and ui['status_visible']
                and ui['status_text'] == (self.SAVE_STATUS if operation == 'save' else self.RESET_STATUS),
                'one actual GUI transaction visibly refuses unsupported settings write')
        self.files.capture_preserved('after-'+operation)
        self.receipts[operation+'_status_ui'] = copy.deepcopy(s)
        return True

    def update(self, s, now):
        require(self.last_state is s, 'latest validated observation alone drives ordinary OS input')
        self.frame = s['frame']
        if self.stage in ('pause','quit_wait'): return self.ui_update(s, now)
        if self.stage == 'boot':
            if s['menu_ready'] and self.file_context_accepted:
                self.begin_attempts = copy.deepcopy(s['recovery']['persistence'])
                self.press('e','begin_shift','begin_shift_press',s,now)
            else: return set(),0,0,False
        if self.stage == 'begin_shift':
            if s['phase'] == 'APPROACH_SHIP' and s['supported']:
                require(any(e['pressed'] for e in self.native_edges) and s['control_enabled']
                        and norm(sub(s['player'],s['spawn'])) < .75,
                        'real observed ordinary Begin Shift enables awake authored-spawn controls')
                self.receipts['awake'] = self.receipt(s); self.tap_key = None
                if self.cold:
                    self.begin_walk('walk_next', [list(point) for point in self.WAYPOINTS], s)
                    self.walk_started=now; self.last_input_frame=self.frame
                else: self.enter('repair_pause',s)
            else:
                if self.tap_key is not None and (now < self.tap_until or self.frame < self.tap_frame+6):
                    return {self.tap_key},0,0,False
                self.tap_key = None
                return set(),0,0,False
        if self.stage == 'walk_next':
            self.require_walking(s)
            require(now-self.walk_started <= 45, 'cold physical continuation forty-five-second deadline')
            keys=set()
            frames=max(1,self.frame-self.last_input_frame); self.last_input_frame=self.frame
            if self.route:
                dx,arrived=self.walk_to(s,self.route[0],keys,frames)
                if arrived:
                    self.visited.append(dict(frame=s['frame'],point=self.route.pop(0)))
                if self.mouse_pending is not None:
                    if norm(sub(s['walk_forward'],self.mouse_pending)) < .00001: dx=0
                    else: self.mouse_pending=None
                if dx: self.mouse_pending=s['walk_forward'][:]
                return keys,dx,0,False
            require(self.walked>10 and len(self.visited)==len(self.WAYPOINTS),
                    'cold ordinary walking reaches all three existing retained continuation waypoints')
            self.files.capture_preserved('cold-walk-complete'); self.enter('pause',s)
            return self.ui_update(s,now)
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key},0,0,False
            self.ui_edges.append(dict(sequence=s['sequence'],key=self.ui_key,pressed=False))
            self.ui_key = None; self.ui_release_until = now+.10
            return set(),0,0,False
        if now < self.ui_release_until or (s['paused'] and any(s['native_keys'].values())):
            return set(),0,0,False
        ui = s['recovery']['ui']; key = None
        if self.stage == 'repair_pause':
            if not s['paused']: key='Escape'
            elif ui['focus_is_settings_open']:
                require(self.focused(ui,'open','SettingsOpenButton','SETTINGS'), 'focused enabled normal Settings button')
                self.receipts['settings_open_ui']=copy.deepcopy(s); self.enter('settings_open',s); key='Return'
            else:
                require(ui['main_visible'] and ui['focus_path'], 'normal main pause keyboard focus')
                key='Tab'
        elif self.stage == 'settings_open':
            require(s['paused'] and ui['settings_visible'] and ui['focus_path'], 'real focused Settings page')
            if ui['focus_is_save']:
                require(self.focused(ui,'save','SettingsSaveButton','APPLY + SAVE'), 'focused ordinary Save action')
                self.files.capture_preserved('before-save'); self.attempt_baseline=copy.deepcopy(s['recovery']['persistence'])
                self.receipts['save_ui']=copy.deepcopy(s); self.enter('save_wait',s); key='Return'
            else: key='Tab'
        elif self.stage == 'save_wait':
            if self.refused(s,'save'):
                self.save_refused=True; self.enter('reset_open',s)
        elif self.stage == 'reset_open':
            if ui['focus_is_reset']:
                require(self.focused(ui,'reset','SettingsResetButton','RESET DEFAULTS') and ui['settings_dirty'],
                        'failed Save makes ordinary Reset require confirmation')
                self.files.capture_preserved('before-reset-open'); self.receipts['reset_ui']=copy.deepcopy(s)
                self.enter('reset_confirm',s); key='Return'
            else: key='Tab'
        elif self.stage == 'reset_confirm':
            require(ui['reset_confirmation_visible'], 'actual unsaved-settings Reset confirmation shown')
            require(self.focused(ui,'reset_confirm','ConfirmSettingsResetButton','CONFIRM RESET'),
                    'focused enabled ordinary Reset confirmation')
            self.files.capture_preserved('before-reset-confirm'); self.attempt_baseline=copy.deepcopy(s['recovery']['persistence'])
            self.receipts['reset_confirm_ui']=copy.deepcopy(s); self.enter('reset_wait',s); key='Return'
        elif self.stage == 'reset_wait':
            if self.refused(s,'reset'):
                require(not ui['reset_confirmation_visible'], 'real Reset confirmation retires after attempted reset')
                require(s['recovery']['settings'] == self.boot_settings,
                        'actual Reset reapplies the initial authored runtime defaults while its write is refused')
                self.files.reset_defaults = copy.deepcopy(s['recovery']['settings'])
                self.reset_refused=True; self.enter('repair_back',s); key='Escape'
        elif self.stage == 'repair_back' and ui['main_visible']:
            require(not ui['settings_visible'], 'ordinary back closes Settings before normal HUD quit')
            self.receipts['settings_closed_ui']=copy.deepcopy(s); self.enter('pause',s)
        if key:
            self.ui_key,self.ui_until=key,now+.08
            self.ui_edges.append(dict(sequence=s['sequence'],key=key,pressed=True,focus=ui['focus_path']))
            return {key},0,0,False
        return set(),0,0,False

    def finish(self, exit_code):
        persistence = self.last_state['recovery']['persistence']
        attempts = 0 if self.cold else 2
        require(self.begin_attempts is not None
                and persistence['save_attempt_count']-self.begin_attempts['save_attempt_count'] == attempts
                and persistence['accepted_transaction_count']-self.begin_attempts['accepted_transaction_count'] == attempts
                and self.settings_commits_unchanged(persistence),
                'exactly one Save and one confirmed Reset in first process, zero writes in cold process')
        require(exit_code == 0 and self.quit_requested and self.stage == 'quit_wait'
                and self.file_context_accepted and 'awake' in self.receipts and 'exit_ui' in self.receipts
                and ((self.cold and len(self.visited)==len(self.WAYPOINTS) and self.walked>10) or (self.save_refused and self.reset_refused and 'settings_closed_ui' in self.receipts)),
                'unsupported load permits normal Begin Shift and HUD OS0 in both distinct processes')
        self.result=dict(self.report(),completion_marker=self.MARKER,normal_ui_exit=True,cold=self.cold,
                         save_refused=self.save_refused,reset_refused=self.reset_refused)


class UnsupportedSettingsFiles(UnsupportedSaveFiles):
    """A future settings section inside a supported, normally committing store."""
    MARKER = 'NATIVE_UNSUPPORTED_SETTINGS_OK'
    WARNINGS = (
        b'WARNING: Startup could not read stored settings: settings_payload_newer',
        b'WARNING: Atomic runtime settings load retained authored defaults: settings_payload_newer / ok',
    )
    MUTABLE = frozenset({'crash_recovery', 'session_diagnostics'})
    PAYLOAD = {
        'runtime_settings': {'schema_version': 12, 'values': {}},
        'tutorial_prompts_seen': {'schema_version': 1, 'seen_ids': ['cinder_reach_checkpoint_route']},
        'solo_safe_recovery': {'location': 'mudds_home_berth', 'mode': 'on_foot',
                               'craft_id': 'arrow_provisional', 'berth_id': 'arrow_recon_berth'},
        'unrelated_future_test': {'label': 'KEEP'},
    }

    def __init__(self, profile, output, fixture, placement):
        require(placement == 'primary', 'nested settings qualify primary placement only')
        HabitatRestartFiles.__init__(self, profile, output)
        fixture = Path(fixture)
        require(fixture.is_file() and not fixture.is_symlink(), 'nested fixture is an ordinary source-produced file')
        raw = fixture.read_bytes()
        document = json.loads(raw)
        self.require_envelope(document)
        require(document['generation'] == 1 and document['payload'] == self.PAYLOAD
                and document['commit']['id'] == 'nested-settings-fixture'
                and document['commit']['parent_generation'] == 0 and document['commit']['parent_id'] == '',
                'exact source-produced supported generation-one nested fixture')
        self.expected = copy.deepcopy(document)
        self.fixture = dict(path=str(fixture.resolve()), bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        self.path = self.profile / self.RELATIVE_SAVE
        self.path.parent.mkdir(parents=True, mode=0o700, exist_ok=False)
        with self.path.open('xb') as stream: stream.write(raw)
        self.path.chmod(0o600)
        sentinel = self.path.parent/'unrelated.txt'
        with sentinel.open('xb') as stream: stream.write(self.SENTINEL)
        sentinel.chmod(0o640)
        self.sentinel_identity = self.identity(sentinel)
        self.directory_identity = self.identity(self.path.parent)
        self.placement, self.leg, self.reset_defaults = placement, 0, None
        self.snapshots = {}
        self.capture_preserved('prelaunch')

    @staticmethod
    def require_envelope(document):
        require(isinstance(document, dict) and set(document) == {'schema_version','generation','commit','payload'}
                and document['schema_version'] == 1 and type(document['generation']) in (int, float)
                and document['generation'] == int(document['generation']) and document['generation'] > 0
                and isinstance(document['payload'], dict), 'supported committed outer-one envelope')
        commit = document['commit']
        require(isinstance(commit, dict) and set(commit) == {'id','parent_generation','parent_id','payload_sha256'}
                and isinstance(commit['id'], str) and commit['id']
                and type(commit['parent_generation']) in (int,float)
                and commit['parent_generation'] == document['generation']-1
                and isinstance(commit['parent_id'],str)
                and isinstance(commit['payload_sha256'],str)
                and re.fullmatch('[0-9a-f]{64}',commit['payload_sha256']), 'actual store commit identity and checksum field')

    def require_payload(self, payload):
        require(isinstance(payload,dict) and set(self.PAYLOAD) <= set(payload)
                and set(payload) <= set(self.PAYLOAD) | self.MUTABLE
                and all(payload[key] == value for key,value in self.PAYLOAD.items()),
                'complete future settings and unrelated namespaces remain exact; only declared lifecycle keys may change')
        if 'crash_recovery' in payload:
            crash = payload['crash_recovery']
            require(set(crash) == {'schema_version','state','session_id','startup_generation','unclean_start_count',
                                   'last_physics_tick','last_elapsed_physics_seconds'}
                    and crash['schema_version'] == 1 and crash['state'] in ('running','clean')
                    and crash['session_id'] == crash['startup_generation']
                    and crash['session_id'] in range(1,self.leg+2) and crash['unclean_start_count'] == 0,
                    'only the two actual clean-start session lifecycles update crash markers')
        if 'session_diagnostics' in payload:
            record = payload['session_diagnostics']
            require(set(record) == {'schema_version','capacity','next_sequence','dropped_event_count','events'}
                    and record['schema_version'] == 1 and isinstance(record['events'],list)
                    and not any(event['event_code'] in ('crash_detected','recovery_started','recovery_completed')
                                for event in record['events']), 'normal session diagnostics never invent recovery')

    def require_session(self, payload, closed=False):
        self.require_payload(payload)
        crash = payload['crash_recovery']; events = payload['session_diagnostics']['events']
        require(crash['session_id'] == crash['startup_generation'] == self.leg+1
                and crash['state'] == ('clean' if closed else 'running'), 'actual current process lifecycle marker')
        require(any(event['session_id'] == self.leg+1 and event['event_code'] == 'session_started'
                    and event['fields'].get('recovered') is False for event in events),
                'actual current process owns an unrecovered startup receipt')
        if closed:
            require(any(event['session_id'] == self.leg+1 and event['event_code'] == 'session_ended'
                        for event in events), 'actual normal Quit owns its durable session-ended receipt')

    def capture_preserved(self, label=None):
        require(self.identity(self.profile) == self.profile_identity
                and self.identity(self.path.parent) == self.directory_identity, 'same original nested profile and save directory')
        sentinel = self.path.parent/'unrelated.txt'
        require(not sentinel.is_symlink() and self.identity(sentinel) == self.sentinel_identity
                and sentinel.read_bytes() == self.SENTINEL and sentinel.stat().st_mode & 0o777 == 0o640,
                'independent unrelated sentinel bytes mode and identity remain exact')
        names = {entry.name for entry in self.path.parent.iterdir()}
        durable = {self.path.name, self.path.name+'.bak', *(self.path.name+'.bak.'+str(i) for i in range(1,4))}
        require(names <= durable | {'unrelated.txt','diagnostics'} and self.path.name in names,
                'settled nested milestones allow only ordinary store history and declared diagnostics sink')
        documents, files = {}, {}
        for name in sorted(names & durable):
            artifact = self.path.parent/name
            require(artifact.is_file() and not artifact.is_symlink() and artifact.stat().st_mode & 0o777 == 0o600,
                    'ordinary durable store artifact retains private mode')
            before = artifact.stat(); raw = artifact.read_bytes(); after = artifact.stat()
            require((before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns) ==
                    (after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns), 'settled independent document read remains stable')
            document = json.loads(raw); self.require_envelope(document); self.require_payload(document['payload'])
            documents[name] = document
            files[name] = dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),mode=oct(0o600),generation=document['generation'])
        primary = documents[self.path.name]
        expected_names = [self.path.name, self.path.name+'.bak',
                          *(self.path.name+'.bak.'+str(i) for i in range(1,4))]
        expected_names = expected_names[:min(int(primary['generation']),len(expected_names))]
        require(set(documents) == set(expected_names), 'ordinary rotation retains exactly the bounded preceding generations')
        for index,name in enumerate(expected_names):
            document = documents[name]
            require(document['generation'] == primary['generation']-index,
                    'durable history uses the exact preceding generation in each canonical name')
            if index:
                successor = documents[expected_names[index-1]]
                require(successor['commit']['parent_id'] == document['commit']['id'], 'durable generations retain actual parent identity')
        diagnostic = self.path.parent/'diagnostics'
        if diagnostic.exists():
            require(diagnostic.is_dir() and not diagnostic.is_symlink(), 'declared ordinary diagnostics directory')
            require({item.name for item in diagnostic.iterdir()} <= {'crash-log.json','crash-log.previous.json'},
                    'settled diagnostics contain only fixed current and previous logs')
            for item in diagnostic.iterdir():
                require(item.is_file() and not item.is_symlink(), 'diagnostic log is an ordinary file')
                raw = item.read_bytes(); json.loads(raw)
                files['diagnostics/'+item.name] = dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        if label is not None:
            require(label not in self.snapshots, 'nested milestone captured exactly once')
            self.snapshots[label] = dict(files=files, document=primary)
        return primary

    def observe(self, sample, pilot):
        store = sample['recovery']['store']
        require(store['path'] == str(self.path) and store['source'] == 'primary', 'exact supported primary remains production authority')
        self.require_payload(store['snapshot'])
        # The cached production snapshot is safe during atomic publication;
        # disk topology is inspected only at the named settled milestones.
        label = f'leg-{self.leg+1}-title'
        if not sample['paused'] and sample['menu_ready'] and label not in self.snapshots:
            document = self.capture_preserved(label)
            self.require_session(document['payload'])
            pilot.file_context_accepted = True

    def finish_leg(self, leg, pilot):
        require(pilot.result is not None and pilot.quit_requested, 'actual normal UI exit precedes nested shutdown read')
        document = self.capture_preserved(f'leg-{leg+1}-orderly-close')
        self.require_session(document['payload'],closed=True)

    def make_pilot(self, pid, cold):
        return UnsupportedSettingsPilot(self,pid,cold=cold)


class UnsupportedSettingsPilot(UnsupportedSavePilot):
    MARKER = UnsupportedSettingsFiles.MARKER
    SAVE_STATUS = 'UNSAVED  //  SETTINGS_PAYLOAD_NEWER'

    def __init__(self, files, expected_pid, cold=False):
        super().__init__(files,expected_pid,cold)
        self.boot_commit_serial = None

    def settings_commits_unchanged(self, persistence):
        return (persistence['save_success_count'] == 0 and not persistence['last_commit_id']
                and persistence['commit_serial'] == self.boot_commit_serial)

    def refusal_status(self, status):
        return (status['accepted'] is False and status['reason'] == 'settings_payload_newer'
                and status['payload_reason'] == 'newer_schema' and status['store_reason'] == 'ok'
                and status['store_status']['accepted'] is True and status['store_status']['source'] == 'primary'
                and status['store_status']['reason'] == 'ok'
                and status['store_status']['payload']['runtime_settings'] == self.files.PAYLOAD['runtime_settings'])

    def validate_authority(self, sample):
        recovery = sample['recovery']; loaded = recovery['load']; store = recovery['store']
        require(self.refusal_status(loaded) and loaded['applied'] is False and loaded['migrated_legacy'] is False,
                'typed schema twelve refuses settings while supported primary loads normally')
        require(store['source'] == 'primary' and store['generation'] >= loaded['generation'] > 0,
                'normal bookkeeping advances the supported primary without replacing settings authority')
        self.files.require_payload(store['snapshot'])
        safe = recovery['safe_start']
        require(safe['restore_status']['accepted'] is True and safe['restore_status']['reason'] == 'empty'
                and safe['begin_status']['accepted'] is False and safe['begin_status']['reason'] == 'settings_authority_blocked'
                and safe['startup_generation'] == 0,
                'future settings block safe-start publication without fabricating a healthy startup')
        require(recovery['repair']['last_status']['reason'] == 'unsupported_newer_schema'
                and not recovery['ui']['confirmation_available'], 'future settings offer no destructive repair')
        persistence = recovery['persistence']
        if self.boot_commit_serial is None: self.boot_commit_serial = persistence['commit_serial']
        require(self.settings_commits_unchanged(persistence), 'refused settings requests never become successful commits')


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



class BomberRearmPilot(SandboxPilot):
    """Ordinary parked payload spending and same-hull physical seat re-entry."""
    MARKER = 'NATIVE_BOMBER_REARM_OK'
    CRAFT = 'cinder_long_range_bomber'
    WAYPOINTS = LifeTowPilot.ARM_GOALS[:6]
    TRIGGERS = {'aft_stair_top': CRAFT}

    def __init__(self):
        super().__init__()
        self.expected_pid = None
        self.policy_identity = None
        self.policy_frame = -1
        self.policy_previous = None
        self.initial_generation = self.reboard_generation = None
        self.shots = 0
        self.fire_pending = None
        self.receipts = {}
        self.native_edges = []
        self.native_previous = {'fire': False, 'e': False}
        self.last_policy_state = None

    def retain(self, name, s):
        self.receipts[name] = json.loads(json.dumps(s))

    def validate_observation(self, s):
        b = s['bomber_rearm']
        self.last_policy_state = s
        require(s['frame'] > self.policy_frame and b['pid'] == self.expected_pid
                and not b['paused'], 'fresh unpaused Bomber sample from exact process')
        self.policy_frame = s['frame']
        identity = tuple(b[k] for k in ('pid', 'main_id', 'player_id', 'ship_id', 'seat_id',
                                       'authority_id', 'component_id', 'component_generation',
                                       'berth_id', 'berth_instance_id', 'berth_parent_id'))
        require(all(identity) and b['definition_id'] == self.CRAFT
                and b['player_id'] == s['player_id'], 'actual original Bomber pilot hull seat and owners')
        if self.policy_identity is None:
            self.policy_identity = identity
            require(not b['piloted'] and b['parked_exact'] and b['lease'], 'fresh parked unpiloted Bomber')
        require(identity == self.policy_identity, 'same Bomber hull authority component life and berth throughout')
        require(not b['destroyed'] and s['phase'] not in ('FAILED', 'RECOVERING')
                and b['default_sampler'] and b['tuning_unchanged']
                and b['parked_exact'] and b['landed'] and b['lease']
                and norm(b['velocity']) <= .01, 'parked ordinary Bomber without recovery replacement or tuning change')
        require(not b['regeneration_pending'], 'no Bomber regeneration')
        for action, pressed in (('fire', b['native_fire']), ('e', b['native_interact'])):
            if pressed != self.native_previous[action]:
                if pressed:
                    require(self.fire_pending is not None if action == 'fire' else self.stage in (
                        'begin_shift', 'craft_board', 'payload_exit_wait', 'payload_reboard_wait', 'payload_final_exit_wait'),
                        'only the one outstanding ordinary input edge may arrive')
                self.native_edges.append({'frame': s['frame'], 'action': action, 'pressed': pressed})
                self.native_previous[action] = pressed
        if b['piloted']:
            require(b['active_ship'] and s['seated'] and b['seated_at_pilot']
                    and b['source_enabled'] and b['application_focused'], 'actual enabled focused Bomber pilot')
        a, loop = b['authority'], b['loop']
        if a['active']:
            require(b['piloted'] and loop['active'] and loop['ship_id'] == self.CRAFT
                    and a['generation'] == loop['generation'], 'same live pilot payload generation')
            if self.initial_generation is None:
                require(self.stage == 'craft_board' and a['ammunition_remaining'] == 4
                        and not a['release_records'] and loop['request_sequence'] == 0,
                        'first actual seat starts with exactly four payloads')
                self.initial_generation = a['generation']
                self.retain('initial_seated', s)
            if a['generation'] != self.initial_generation:
                if self.reboard_generation is None:
                    require(self.stage == 'payload_reboard_wait' and 'detached_foot' in self.receipts
                            and 'walked_clear' in self.receipts and a['generation'] > self.initial_generation
                            and a['ammunition_remaining'] == 4 and a['cooldown_remaining'] == 0
                            and not a['release_records'] and loop['request_sequence'] == 0,
                            'physical same-hull retake alone starts newer generation with exactly four')
                    self.reboard_generation = a['generation']
                    self.shots = 0
                    self.retain('refilled_seated', s)
                require(a['generation'] == self.reboard_generation, 'no hidden interim payload generation')
            else:
                require(self.reboard_generation is None, 'old payload generation cannot return after reboarding')
            count = len(a['release_records'])
            require(count == loop['request_sequence'] == 4 - a['ammunition_remaining'],
                    'every spent round has exactly one real ordered release record')
            allowed = {self.shots}
            if self.fire_pending and self.fire_pending['kind'] == 'release': allowed.add(self.shots + 1)
            require(count in allowed, 'holding or an unsolicited edge never spends another payload')
            for index, record in enumerate(a['release_records'], 1):
                require(record['generation'] == a['generation'] and record['release_sequence'] == index
                        and record['request_sequence'] == index and record['ammunition_remaining'] == 4-index
                        and record['actor_id'] == 'player_pilot', 'actual ordered same-generation pilot releases')
        elif self.initial_generation is not None:
            require(self.stage in ('payload_exit_wait', 'payload_clear', 'payload_return',
                                   'payload_reboard_wait', 'payload_final_exit_wait', 'complete')
                    and a['ammunition_remaining'] == 0 and not a['release_records']
                    and a['detach_reason'] == 'pilot_disembarked'
                    and not loop['active'] and not loop['projectiles'] and loop['request_sequence'] == 0,
                    'only ordinary physical disembark detaches and clears the old payload loop')
        previous = self.policy_previous
        normal = not s['seated'] and s['control_enabled'] and not s['transition_busy']
        if normal and previous and previous['normal']:
            require(norm(sub(s['player'], previous['player'])) <= 9.2*(s['frame']-previous['frame'])/60+1.5,
                    'continuous ordinary Bomber access walking without teleport')
        self.policy_previous = {'normal': normal, 'player': s['player'][:], 'frame': s['frame']}

    def press_e(self, stage, s, now):
        require(self.tap_key is None and not s['bomber_rearm']['native_interact'],
                'released E before one ordinary lifecycle press')
        self.tap('e', now)
        require(self.tap_key == 'e', 'ordinary lifecycle pulse ready without retry')
        self.enter(stage, s)

    def fire(self, s, now, kind):
        b = s['bomber_rearm']
        require(not b['native_fire'] and not b['command_fire'] and b['authority']['cooldown_remaining'] == 0,
                'distinct released ordinary FIRE edge after actual cooldown')
        self.fire_pending = {'kind': kind, 'frame': s['frame'], 'until': now+.15}
        return set(), 0, 0, True

    def finish_fire(self, s, now):
        pending, b = self.fire_pending, s['bomber_rearm']
        if now < pending['until'] or s['frame'] < pending['frame']+6:
            return set(), 0, 0, True
        if b['native_fire'] or b['command_fire']:
            return set(), 0, 0, False
        a, loop = b['authority'], b['loop']
        if pending['kind'] == 'release':
            require(len(a['release_records']) == self.shots+1 and loop['last_result']['accepted'],
                    'single FIRE edge acknowledged by one real release; no retry')
            require(loop['last_result'].get('presentation', {}).get('accepted') is True,
                    'every actual Bomber release including reboard must admit its payload presentation')
            self.shots += 1
            label = ('reboard_release' if self.reboard_generation is not None else 'release_'+str(self.shots))
            self.retain(label, s)
        else:
            require(a['ammunition_remaining'] == 0 and len(a['release_records']) == 4
                    and not loop['last_result']['accepted']
                    and loop['last_result']['reason'] == 'ammunition_exhausted',
                    'fifth post-cooldown FIRE actually refuses exhausted ammunition')
            self.retain('exhausted', s)
            self.enter('payload_idle_exit', s)
        self.fire_pending = None
        return set(), 0, 0, False

    def _update_route(self, s, now):
        if self.stage in ('boot', 'begin_shift', 'walk_station', 'craft_approach'):
            return super()._update_route(s, now)
        self.frame = s['frame']
        b, keys, dx = s['bomber_rearm'], set(), 0
        if self.fire_pending: return self.finish_fire(s, now)
        if self.stage in ('craft_board', 'payload_reboard_wait'):
            ready = self.initial_generation if self.stage == 'craft_board' else self.reboard_generation
            if ready is not None and not s['transition_busy']:
                self.shots = 0
                self.enter('payload_spend' if self.stage == 'craft_board' else 'payload_reboard_fire', s)
        elif self.stage == 'payload_spend':
            if b['authority']['cooldown_remaining'] == 0:
                return self.fire(s, now, 'release' if self.shots < 4 else 'exhausted')
        elif self.stage == 'payload_reboard_fire':
            if self.shots == 0: return self.fire(s, now, 'release')
            require(self.shots == 1 and b['authority']['ammunition_remaining'] == 3,
                    'first fresh reboard release spends exactly one of restored four')
            self.enter('payload_final_idle', s)
        elif self.stage in ('payload_idle_exit', 'payload_final_idle'):
            if b['engine'] == 'OFFLINE' and not b['native_interact'] and self.tap_key is None:
                self.press_e('payload_exit_wait' if self.stage == 'payload_idle_exit'
                             else 'payload_final_exit_wait', s, now)
        elif self.stage in ('payload_exit_wait', 'payload_final_exit_wait'):
            if not s['seated'] and not b['piloted'] and s['control_enabled'] and not s['transition_busy']:
                require(b['grounded'] and b['supported'] and b['support_collider'], 'physical supported exterior exit')
                require(not b['authority']['active'] and not b['loop']['active'], 'ordinary exit detached authority')
                if self.stage == 'payload_exit_wait':
                    self.retain('detached_foot', s)
                    self.pending_walk = list(reversed(self.approach_path[:-1]))
                    self.walk_origin = s['player'][:]
                    self.enter('payload_clear', s)
                else:
                    self.retain('final_foot', s)
                    require(len([e for e in self.native_edges if e['action'] == 'fire' and e['pressed']]) == 6,
                            'four spent one exhausted and one fresh physical FIRE edges')
                    require(len([e for e in self.native_edges if e['action'] == 'e' and e['pressed']]) == 5
                            and not b['native_interact'] and not b['native_fire'],
                            'one Begin Shift board exit reboard and final exit edge, all released')
                    self.enter('complete', s)
                    self.result = {'completion_marker': self.MARKER,
                                   'scope': 'parked same-hull Bomber physical seat re-entry refills four only',
                                   'same_identity': self.policy_identity,
                                   'initial_generation': self.initial_generation, 'reboard_generation': self.reboard_generation,
                                   'receipts': self.receipts, 'native_edges': self.native_edges,
                                   'stages': self.stages, 'full_flight_combat_recovery': 'NOT_RUN'}
        elif self.stage in ('payload_clear', 'payload_return'):
            require(not s['seated'] and s['control_enabled'] and not s['transition_busy'], 'ordinary on-foot reboard walk')
            craft = s['sandbox']['fleet'][self.CRAFT]
            if self.stage == 'payload_return' and craft['candidate'] and self.walk_arrival_ready():
                if s['sandbox']['station_candidate']: dx = self.clear_station_prompt(s)
                else: self.press_e('payload_reboard_wait', s, now)
            else:
                dx, reached = self.walk_pending(s, keys)
                if reached:
                    self.pending_walk.pop(0)
                    if not self.pending_walk:
                        if self.stage == 'payload_clear':
                            require(not b['reboard_blocked'] and b['boarding_distance'] > b['boarding_reach'],
                                    'actual outward walk clears production reboard suppression')
                            self.retain('walked_clear', s)
                            self.pending_walk = self.approach_path[:]
                            self.walk_origin = s['player'][:]
                            self.enter('payload_return', s)
                        else:
                            require(craft['candidate'], 'physical return reaches actual Bomber candidate; no retry')
        self.pulse(keys, now)
        return keys, dx, 0, False


class CinderSupplyPilot(BeaconEntryPilot):
    """First funded supply journey; every control is an ordinary OS event."""
    MODE = 'cinder-supply'
    MARKER = 'NATIVE_CINDER_SUPPLY_OK'
    ACTIVITY = 'cinder_platform_supply_run'
    REWARD = 'return_fabrication_kits_to_shipyard'
    DEFAULT_WALK = LifeTowPilot.DEFAULT_WALK
    finite_vector = staticmethod(LifeTowPilot.finite_vector)
    require_motion_epoch = LifeTowPilot.require_motion_epoch
    require_step_event = LifeTowPilot.require_step_event

    def __init__(self):
        super().__init__()
        self.initial = self.previous = self.last_state = None
        self.visited, self.native_edges = [], []
        self.walk_index = 0
        self.walked = self.home_walked = 0
        self.goal_since = self.stage_since = None
        self.route = []
        self.paid_state = self.paid_slot = self.paid_record = None
        self.file_pretransfer = self.file_paid = self.file_repeat = self.file_home = False
        self.quit_requested = False
        self.clearance_index = 0
        self.flight_target = None
        self.stop_since = None
        self.cargo_identity = None
        self.phase_seen = []
        self.motion_lag = None
        self.observed_previous = None
        self.consumed_step_frames = set()

    def enter(self, stage, s):
        super().enter(stage, s)
        self.stage_since = time.monotonic()
        self.stages[-1].update(wall_time=self.stage_since, player=s['player'])
        self.goal_since = None
        self.stop_since = None
        self.mouse_pending = None

    def initial_walk_route(self, s):
        return [target[:] if target is not None else ([-42, .38, s['boarding'][2]] if name == 'freight_boarding_z' else s['boarding'][:]) for name, target in LifeTowPilot.GANTRY_GOALS]

    def reboard_walk_route(self, s):
        route = s['cargo']['route']
        return [route[1], route[2], route[1], route[0], s['boarding'][:]]

    def home_walk_route(self, s):
        return [[p+1.5*f for p, f in zip(s['player'], s['walk_forward'])]]

    def require_stock(self, s, source, destination):
        manifests = s['cargo']['inventory']['manifests']
        quantities = {m['owner_entity_id']: sum(e['quantity'] for e in m['entries']
                      if e['item_id'] == 'cinder_supply_crates') for m in manifests}
        require(quantities.get('jovian_provisional') == source
                and sum(v for k, v in quantities.items() if k != 'jovian_provisional') == destination,
                'actual supply manifest source/destination quantities '+str((source, destination)))

    def require_paid(self, s):
        slot, record = s['paid_slot'], s['reward_record']
        delivery = slot['delivery']
        require(delivery['contract_id'] == self.ACTIVITY and delivery['quantity'] == 1
                and delivery['generation'] == 1 and delivery['ordered_phases'] == ['load_crate', 'clear_gate', 'dock_platform']
                and delivery['deadline_seconds'] == 120 and 0 <= delivery['elapsed_seconds'] < 120
                and delivery['transfer_proof']['source_quantity_after'] == 1
                and delivery['transfer_proof']['destination_quantity_after'] == 1
                and delivery['reward_receipt'] == {'activity_id': 'cinder_kit_cargo_run', 'reward_id': self.REWARD,
                                                  'granted': True, 'replay_allowed': False},
                'actual durable one-crate terminal receipt is paid within the original120 seconds')
        require(record['total_receipts'] == 1 and record['receipt_serial'] == 1
                and record['reward_counts'] == {self.REWARD: 1}
                and record['last_receipt']['activity_id'] == 'cinder_kit_cargo_run'
                and record['last_receipt']['activity_generation'] == 1
                and record['last_receipt']['granted'] and not record['last_receipt']['replay_allowed'],
                'one actual supply payment and no Jovian kit-job credit')
        if self.paid_slot is not None:
            require(slot == self.paid_slot and record == self.paid_record, 'same paid receipt and one credit retained')

    def validate_observation(self, s):
        require(s['mode'] == self.MODE and s['sequence'] > self.sequence, 'fresh supply observer sequence')
        self.sequence = s['sequence']
        ids = tuple(s[k] for k in ('pid', 'main_id', 'player_id', 'ship_id', 'source_id', 'capsule_id', 'shape_id'))
        require(all(ids), 'actual original Main Player capsule Jovian and source')
        if self.initial is None:
            self.initial = s
            self.process_identity = ids
        require(ids == self.process_identity and s['tuning_unchanged'] and s['default_sampler']
                and s['home']['id'] == self.initial['home']['id'],
                'same original actors and unchanged production default input source/tuning')
        require(not s['destroyed'] and s['hull'] == self.initial['hull'] and s['phase'] != 'FAILED', 'live undamaged supply sortie')
        require(s['kit_state']['state'] == 0 and s['kit_state']['generation'] == 0,
                'Jovian fabrication-kit activity remains unselected and idle')
        if s['seated'] and not s['transition_busy']:
            require(s['seated_at_pilot'] and s['piloted'] and s['active_ship'] and s['ship_camera'] and s['source_enabled'],
                    'actual original local Jovian pilot owns current camera and default controls')
        if self.previous is not None and not s['paused'] and not self.previous['paused']:
            dt = (s['frame']-self.previous['frame'])/60
            normal = lambda a: a['control_enabled'] and not a['seated'] and not a['transition_busy']
            if dt > 0 and normal(s) and normal(self.previous):
                step = norm(sub(s['player'], self.previous['player']))
                self.observed_previous = self.previous
                motion = self.require_motion_epoch(s)
                if step > 9.2*dt*1.25+.02:
                    self.require_step_event(s, motion)
                self.walked += step
                if self.stage == 'home_walk': self.home_walked += step
        if s['native_interact'] and not (self.previous and self.previous['native_interact']):
            self.native_edges.append({'frame': s['frame'], 'stage': self.stage})
        c = s['cargo']
        if c['available'] and c['activity']:
            a = c['activity']
            require(a['state'] not in (3, 4), 'supply activity never fails or expires')
            if a['state'] == 1:
                require(a['generation'] == 1 and a['deadline_seconds'] == 120 and a['elapsed_seconds'] < 120,
                        'same first funded active supply clock remains within120 seconds')
                if not self.phase_seen or self.phase_seen[-1] != a['next_phase_index']:
                    self.phase_seen.append(a['next_phase_index'])
            if self.cargo_identity is not None and self.paid_state is None:
                require(tuple(c[k] for k in ('cluster_id', 'generation', 'access_id', 'attachment', 'berth_id', 'terminal_id', 'binding_id', 'activity_id')) == self.cargo_identity,
                        'exact current Cinder attachment, berth, terminal and supply owner through payment')
        if self.paid_state is not None: self.require_paid(s)
        self.previous = self.last_state = s

    def require_walking(self, s):
        # Preserve the step validator's control/identity prerequisites while
        # allowing bounded Cinder stair airtime through this route's rule.
        require(not s['seated'] and not s['station_seated'] and not s['game_station_seated']
                and not s['sleeping'] and not s['transition_busy'] and s['control_enabled']
                and s['mouse_captured'] and s['capsule_enabled'] and not s['piloted'],
                'ordinary awake walking controls without ship ownership')
        self.foot(s)

    def foot(self, s):
        # Cinder permits ordinary brief stair airtime inside its finite live
        # walking region. Station/home retain their actual floor requirement.
        c = s.get('cargo', {})
        cinder_walk = (self.stage in ('terminal_walk', 'reverse_walk', 'reboard_walk')
                       and c.get('available') and c.get('actor_authorized')
                       and c.get('lease') and c.get('contract') and c.get('walk_within_region'))
        require(((s['grounded'] and s['supported'] and s['support_collider']) or cinder_walk)
                and s['control_enabled']
                and not s['seated'] and not s['transition_busy'], 'same original controlled walking Player in current physical route')

    def walk_to(self, s, target, keys, now):
        self.foot(s)
        if self.goal_since is None: self.goal_since = now
        require(now-self.goal_since <= 15, 'ordinary supply walking waypoint15 seconds')
        off = sub(target, s['player']); off[1] = 0
        distance, speed = norm(off), math.hypot(s['velocity'][0], s['velocity'][2])
        if self.stage == 'reboard_walk' and distance <= 3:
            # Near the hatch connector, steer with ordinary backing/strafe
            # instead of repeatedly turning past a nearby waypoint.
            dx = 0
            reached = distance <= .30 and abs(target[1]-s['player'][1]) <= .65 and speed <= .35
            tuning = s['walk_tuning']
            stopping = speed*speed/(2*tuning['deceleration']) + max(speed, tuning['walk'])/20 + .10
            if not reached and distance > .30 and (speed <= .35 or distance > stopping):
                direction = unit(off)
                for axis, positive, negative in ((s['walk_forward'], 'w', 's'), (s['walk_right'], 'd', 'a')):
                    projection = dot(direction, axis)
                    if abs(projection) >= math.sin(math.pi/8):
                        keys.add(positive if projection > 0 else negative)
        else:
            dx, reached = ArrowReturnReusePilot.walk_to(self, s, target, keys)
        reached = reached and s['grounded']
        if reached:
            self.visited.append({'stage': self.stage, 'index': self.walk_index, 'target': target, 'frame': s['frame'], 'player': s['player'], 'support': s['support_collider'], 'grounded': s['grounded'], 'cinder_region': s.get('cargo', {}).get('walk_within_region', False)})
            self.goal_since = None
        return dx, reached

    def look(self, s, target):
        off = sub(target, s['interaction_origin']); off[1] = 0
        d = unit(off)
        yaw = math.atan2(dot(d, s['walk_right']), dot(d, s['walk_forward']))
        return round(max(-360, min(360, yaw/s['walk_tuning']['mouse'])))

    def request(self, key, stage, s, now):
        if self.tap_key is None and now >= self.tap_cooldown and self.frame >= self.tap_release_frame+6:
            self.tap(key, now)
            if self.tap_key == key:
                self.receipts[stage] = s
                self.enter(stage, s)

    @staticmethod
    def station_clearance_targets(s, reverse=False):
        # Freight's full body envelope must clear before turning back toward
        # Cinder. The measured high diagonal clears the current station with
        # an all-attitude hull envelope; use the live capture in both directions.
        capture = s['home']['capture_position']
        offsets = ([0, 0, 0], [0, 0, 26.7], [0, 66.37, 66.7],
                   [84, 66.37, -308.3])
        points = [[p+d for p, d in zip(capture, offset)] for offset in offsets]
        return list(reversed(points)) if reverse else points

    def clearance_flight(self, s, keys, reverse=False):
        targets = self.station_clearance_targets(s, reverse)
        dx, dy, settled = self.flight(s, targets[self.clearance_index], keys)
        if settled:
            self.receipts[('home' if reverse else 'outbound')+'_clearance_'+str(self.clearance_index)] = s
            self.clearance_index += 1
            if self.clearance_index == len(targets):
                self.enter('home_flight' if reverse else 'outbound', s)
        return dx, dy

    def flight(self, s, target, keys):
        off = sub(target, s['position']); distance = norm(off); speed = norm(s['ship_velocity'])
        # World-up projected into the local roll plane. Near vertical forward,
        # that projection vanishes and roll has no stable level reference.
        roll_sin, roll_cos = s['right'][1], s['up'][1]
        if math.hypot(roll_sin, roll_cos) > .15:
            roll_error = math.atan2(roll_sin, roll_cos)
            if roll_error > math.radians(5): keys.add('r')
            elif roll_error < -math.radians(5): keys.add('q')

        stopping = speed*speed/(2*max(s['tuning']['brake'], 1e-6)) + speed*.15 + 2
        # aim() measures from the chase camera; this waypoint belongs to the
        # ship root, so preserve the root's desired vector at that camera.
        aim_target = [camera+delta for camera, delta in zip(s['camera'], off)]
        dx, dy, alignment = self.aim(s, aim_target, .3)
        if distance <= max(2, stopping):
            keys.add('Prior')
        elif alignment > .97:
            keys.add('w')
        else:
            keys.add('Prior')
        return dx, dy, distance <= 2 and speed <= .5

    def supply_ui(self, s, now):
        if self.ui_key is not None:
            if now < self.ui_until: return {self.ui_key}, 0, 0, False
            self.ui_key = None; self.ui_release_until = now+.10
            return set(), 0, 0, False
        if now < self.ui_release_until or any(s['native_keys'].values()): return set(), 0, 0, False
        pending = self.ui_pending
        if pending is not None:
            kind = pending['kind']; ui = s['ui']; a = s['cargo']['activity']
            if kind == 'tab': accepted = bool(ui['focus_path']) and ui['focus_path'] != pending['focus']
            elif kind == 'select': accepted = s['selected_activity'] == self.ACTIVITY
            elif kind == 'start': accepted = a['state'] == 1 and a['generation'] == 1 and a['next_phase_index'] == 0
            elif kind == 'resume': accepted = not s['paused']
            else: accepted = s['paused'] and ui[pending['expected']]
            require(accepted or now < pending['until'], 'single ordinary supply UI press acknowledged: '+kind)
            if not accepted: return set(), 0, 0, False
            self.ui_pending = None
            if kind != 'tab':
                next_stage = {'pause': 'supply_board', 'board': 'supply_nearby', 'nearby': 'supply_select', 'select': 'supply_start',
                              'start': 'supply_back_activity', 'back_activity': 'supply_back_main', 'back_main': 'supply_resume', 'resume': 'load_phase'}[kind]
                self.enter(next_stage, s); self.focus_seen.clear()
                if kind == 'start': self.receipts['supply_started'] = s
                if kind == 'resume': return set(), 0, 0, False
        if self.stage == 'supply_pause': return self.ui_press('Escape', s, now, 'pause', 'main_visible')
        require(s['paused'], 'supply menu remains actually paused until Resume')
        if self.stage in ('supply_back_activity', 'supply_back_main', 'supply_resume'):
            kind, expected = {'supply_back_activity': ('back_activity', 'activity_visible'), 'supply_back_main': ('back_main', 'main_visible'), 'supply_resume': ('resume', None)}[self.stage]
            return self.ui_press('Escape', s, now, kind, expected)
        page, name, kind = {'supply_board': ('main_visible', 'ActivityBoardButton', 'board'), 'supply_nearby': ('activity_visible', 'NearbyActivityOpenButton', 'nearby'),
                            'supply_select': ('nearby_visible', None, 'select'), 'supply_start': ('nearby_visible', None, 'start')}[self.stage]
        ui = s['ui']; require(ui[page] and ui['focus_path'], 'actual supply page keyboard focus')
        target = ui['focus_name'] == name if name else ui['focus_activity'] == self.ACTIVITY and ui['focus_text'] == kind.upper()
        if target:
            require(ui['focus_visible'] and ui['focus_enabled'], 'visible enabled actual supply action')
            return self.ui_press('Return', s, now, kind, {'board': 'activity_visible', 'nearby': 'nearby_visible'}.get(kind))
        require(ui['focus_path'] not in self.focus_seen and len(self.focus_seen) < 64, 'supply focus reaches target without cycle')
        self.focus_seen.add(ui['focus_path'])
        return self.ui_press('Tab', s, now, 'tab')

    def update(self, s, now):
        require(self.last_state is s, 'every actual supply observation validated before controls')
        self.frame = s['frame']
        if not self.phases or self.phases[-1] != s['phase']: self.phases.append(s['phase'])
        if self.stage.startswith('supply_'): return self.supply_ui(s, now)
        if self.stage in ('pause', 'quit_wait'): return ArrowReturnReusePilot.ui_update(self, s, now)
        keys, dx, dy = set(), 0, 0
        c = s['cargo']; speed = norm(s['ship_velocity'])
        if self.stage == 'boot' and s['menu_ready']:
            self.request('e', 'begin_shift', s, now)
        elif self.stage == 'begin_shift' and s['phase'] == 'APPROACH_SHIP' and s['grounded'] and s['supported']:
            self.route = self.initial_walk_route(s)
            self.enter('walk', s)
        elif self.stage == 'walk':
            dx, reached = self.walk_to(s, self.route[self.walk_index], keys, now)
            if reached:
                self.walk_index += 1
                if self.walk_index == len(self.route): self.enter('board_aim', s)
        elif self.stage in ('board_aim', 'reboard_aim'):
            self.foot(s)
            dx = self.look(s, s['boarding'])
            if s['candidate'] and not s['station_candidate'] and not s['reboard_blocked'] and s['boarding_distance'] <= 7:
                self.request('e', 'board' if self.stage == 'board_aim' else 'reboard', s, now)
        elif self.stage in ('board', 'reboard'):
            require(now-self.stage_since <= 12, 'ordinary animated Jovian boarding12 seconds')
            if s['seated_at_pilot'] and s['active_ship'] and not s['transition_busy']:
                self.enter('launch' if self.stage == 'board' else 'home_depart', s)
        elif self.stage == 'launch':
            keys.add('w')
            if not s['landed'] and s['home']['lease_free'] and norm(sub(s['position'], self.initial['parked'])) >= 8:
                self.receipts['departed_home'] = s
                self.clearance_index = 0
                self.enter('outbound_clearance', s)
        elif self.stage == 'outbound_clearance':
            dx, dy = self.clearance_flight(s, keys)
        elif self.stage == 'outbound':
            # Current common-world capture guidance replaces the authored anchor
            # as soon as the production distance policy commits Cinder.
            target = c['capture_position'] if c['available'] else s['outbound_target']
            dx, dy, _ = self.flight(s, target, keys)
            if c['available'] and c['capture']:
                self.request('l', 'cargo_land', s, now)
        elif self.stage in ('cargo_land', 'cargo_redock'):
            require(now-self.stage_since <= 120, 'physical Cinder landing120 seconds')
            if (s['landed'] and s['phase'] == 'SHUT_DOWN' and c['lease'] and c['contract']
                    and norm(sub(s['position'], c['dock'])) <= .05 and speed <= .05):
                self.require_stock(s, 2, 0)
                require(c['source_entity_id'] == s['ship_id'], 'actual occupied Jovian registers source')
                if self.stage == 'cargo_land':
                    self.cargo_identity = tuple(c[k] for k in ('cluster_id', 'generation', 'access_id', 'attachment', 'berth_id', 'terminal_id', 'binding_id', 'activity_id'))
                    self.receipts['occupied_source'] = s
                    self.enter('cargo_arrival_shutdown', s)
                else: self.enter('cargo_shutdown', s)
        elif self.stage == 'cargo_arrival_shutdown':
            # Pausing before the authored neutral idle interval freezes auto
            # shutdown; starting thrust while still ONLINE retains the dock latch.
            require(s['landed'] and c['lease'] and c['contract'] and speed <= .05,
                    'first Cinder dock remains secured during neutral auto shutdown')
            if s['engine'] == 'OFFLINE': self.enter('supply_pause', s)
        elif self.stage == 'load_phase':
            if c['activity']['next_phase_index'] == 1:
                require(c['lease'], 'load_crate consumed from real occupied berth')
                self.receipts['load_crate'] = s
                self.enter('clear_gate', s)
        elif self.stage == 'clear_gate':
            # The dock yaw points the nose toward the guidance target beyond
            # the existing capture edge; use actual forward/reverse throttle.
            signed = dot(sub(c['clear_target'], s['position']), [-v for v in s['back']])
            keys.add('w' if signed >= 0 else 's')
            if c['activity']['next_phase_index'] == 2:
                require(c['lease_free'] and not c['inside_capture'], 'clear_gate consumes physical lease release and outside-capture root')
                self.receipts['clear_gate'] = s
                self.enter('gate_brake', s)
        elif self.stage == 'gate_brake':
            keys.add('Prior')
            if c['capture']:
                self.request('l', 'cargo_redock', s, now)
            elif speed <= .5:
                self.enter('gate_return', s)
        elif self.stage == 'gate_return':
            dx, dy, _ = self.flight(s, c['capture_position'], keys)
            if c['capture']: self.request('l', 'cargo_redock', s, now)
        elif self.stage == 'cargo_shutdown':
            require(c['activity']['next_phase_index'] == 3 and c['lease'] and c['contract'], 'dock_platform consumes exact real re-occupancy')
            if s['engine'] == 'OFFLINE': self.request('e', 'cargo_exit', s, now)
        elif self.stage == 'cargo_exit':
            require(now-self.stage_since <= 10, 'physical Cinder authored exit10 seconds')
            if not s['seated'] and s['control_enabled'] and not s['transition_busy']:
                self.foot(s); require(c['actor_authorized'], 'real GameFlow disembark authorized exact Player')
                self.route = c['route']; self.walk_index = 0
                self.receipts['cargo_exterior'] = s
                self.enter('terminal_walk', s)
        elif self.stage == 'terminal_walk':
            dx, reached = self.walk_to(s, self.route[self.walk_index], keys, now)
            if reached:
                self.walk_index += 1
                if self.walk_index == len(self.route): self.enter('terminal_aim', s)
        elif self.stage == 'terminal_aim':
            dx = self.look(s, c['terminal'])
            if self.file_pretransfer and c['terminal_candidate']: self.request('e', 'terminal_transfer', s, now)
        elif self.stage == 'terminal_transfer':
            require(now-self.stage_since <= 8, 'physical terminal transfer and durable payment8 seconds')
            if c['activity']['state'] == 2 and s['paid_slot'].get('delivery', {}).get('reward_receipt', {}).get('granted'):
                self.require_stock(s, 1, 1); self.require_paid(s)
                require(c['last_request']['accepted'] and c['last_request']['reason'] == 'cargo_terminal_delivery_committed', 'real terminal E commits exact delivery')
                self.paid_state = s; self.paid_slot = s['paid_slot']; self.paid_record = s['reward_record']
                self.enter('repeat_aim', s)
        elif self.stage == 'repeat_aim':
            if self.file_paid and c['terminal_candidate'] and not s['native_interact']:
                self.request('e', 'terminal_repeat', s, now)
        elif self.stage == 'terminal_repeat':
            require(now-self.stage_since <= 8, 'ordinary duplicate terminal request8 seconds')
            if not s['native_interact'] and not c['last_request']['accepted']:
                self.require_stock(s, 1, 1)
                self.receipts['repeat_terminal'] = s
                self.enter('reverse_walk', s); self.route = list(reversed(c['route'])); self.walk_index = 0
        elif self.stage == 'reverse_walk':
            dx, reached = self.walk_to(s, self.route[self.walk_index], keys, now)
            if reached:
                self.walk_index += 1
                if self.walk_index == len(self.route):
                    # Retrace the physical connector far enough to clear the
                    # production seven-metre reboard guard, then return to hatch.
                    self.route = self.reboard_walk_route(s); self.walk_index = 0
                    self.enter('reboard_walk', s)
        elif self.stage == 'reboard_walk':
            dx, reached = self.walk_to(s, self.route[self.walk_index], keys, now)
            if reached:
                self.walk_index += 1
                if self.walk_index == len(self.route): self.enter('reboard_aim', s)
        elif self.stage == 'home_depart':
            require(self.file_repeat, 'duplicate actual-file receipt conservation proved before departure')
            keys.add('w')
            if not s['landed'] and c['lease_free']:
                self.receipts['departed_cinder'] = s
                self.clearance_index = 0
                self.enter('home_clearance', s)
        elif self.stage == 'home_clearance':
            dx, dy = self.clearance_flight(s, keys, reverse=True)
        elif self.stage == 'home_flight':
            dx, dy, _ = self.flight(s, s['home']['capture_position'], keys)
            if s['home']['capture']: self.request('l', 'home_land', s, now)
        elif self.stage == 'home_land':
            require(now-self.stage_since <= 120, 'normal home landing120 seconds')
            if (s['landed'] and s['phase'] == 'SHUT_DOWN' and s['home']['lease'] and s['home']['contract']
                    and norm(sub(s['position'], s['home']['dock'])) <= .05 and speed <= .05):
                self.receipts['home_docked'] = s; self.enter('home_shutdown', s)
        elif self.stage == 'home_shutdown':
            if s['engine'] == 'OFFLINE': self.request('e', 'home_exit', s, now)
        elif self.stage == 'home_exit':
            require(now-self.stage_since <= 10, 'home authored physical exit10 seconds')
            if not s['seated'] and s['control_enabled'] and not s['transition_busy']:
                self.foot(s); self.receipts['home_exterior'] = s
                self.route = self.home_walk_route(s)
                self.enter('home_walk', s)
        elif self.stage == 'home_walk':
            dx, reached = self.walk_to(s, self.route[0], keys, now)
            require(s['home']['lease'] and s['home']['contract'], 'physical home berth remains occupied during usable exit')
            if reached and self.home_walked >= 1 and self.file_home:
                self.receipts['home_usable'] = s; self.enter('pause', s)
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame+6: keys.add(self.tap_key)
            else:
                self.tap_key = None; self.tap_cooldown = now+.3; self.tap_release_frame = self.frame
        if dx and not s['seated']:
            if self.mouse_pending is not None and norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = s['walk_forward'][:]
        return keys, dx, dy, False

    def finish(self, code):
        require(code == 0 and self.quit_requested and self.stage == 'quit_wait' and self.file_home,
                'full supply journey finishes only after real normal UI exit and actual OS0')
        self.result = {'completion_marker': self.MARKER, 'stages': self.stages, 'visited': self.visited,
                       'receipts': self.receipts, 'native_interact_edges': self.native_edges,
                       'walked_m': self.walked, 'home_walked_m': self.home_walked,
                       'phase_indices': self.phase_seen, 'paid_slot': self.paid_slot, 'reward_record': self.paid_record}
        require(self.phase_seen == [0, 1, 2, 3], 'all three real supply phases observed in order')


class CinderHaulerSupplyPilot(CinderSupplyPilot):
    """Same funded supply contract, flown by the production Dock04 Hauler."""
    MODE = 'hauler-supply'
    MARKER = 'NATIVE_HAULER_SUPPLY_OK'
    SHIP = 'cinder_cargo_hauler'
    MANIFEST = 'cinder_hauler_source_manifest'
    INITIAL_GOALS = tuple(point for _, point in LifeTowPilot.ARM_GOALS[:12]) + (
        [25.4, 4.2, 68.3], [25.4, 4.2, 70.6], [23, 4.18, 72.8],
        [22.2, 4.18, 75.2], [22.2, 4.18, 90], [8.8, 4.18, 90])
    CARGO_LOCAL_POINTS = (
        [-21, 2.9, 0], [-21, 2.9, 10], [-24.3, 2.9, 13.75],
        [-24.3, 3.8, 17.8], [-14.15, 3.8, 18], [-4, 3.8, 18],
        [-2.4, 3.8, 16.7], [-1.6, 4.05, 16.166667],
        [-.8, 4.30, 15.633333], [0, 4.65, 15.1])

    def __init__(self):
        super().__init__()
        self.home_alignment_started = None

    def flight(self, s, target, keys):
        if self.stage == 'home_flight':
            now = time.monotonic()
            if self.home_alignment_started is not None:
                require(now-self.home_alignment_started <= 15,
                        'ordinary Hauler home brake/hover alignment within 15 seconds')
            if norm(sub(target, s['position'])) <= 2 and norm(s['ship_velocity']) <= .5:
                if self.home_alignment_started is None:
                    self.home_alignment_started = now
                # The vertical clearance descent leaves the nose down. Hold
                # normal brake/hover to upright without aiming back down at the
                # nearby capture root. The caller still requires live capture.
                keys.update({'Prior', 'h'})
                return 0, 0, True
        return super().flight(s, target, keys)

    def initial_walk_route(self, s):
        # Stop on the supported apron and aim at the actual boarding marker.
        return [point[:] for point in self.INITIAL_GOALS]

    def home_walk_route(self, s):
        # Retrace the supported apron point already reached before boarding.
        return [self.INITIAL_GOALS[-1][:]]

    def reboard_walk_route(self, s):
        # The ten-point outbound/reverse walk already clears the reboard guard.
        return [s['boarding'][:]]

    @staticmethod
    def station_clearance_targets(s, reverse=False):
        capture = s['home']['capture_position']
        points = [capture[:], [capture[0], capture[1]+60, capture[2]]]
        return list(reversed(points)) if reverse else points

    def require_stock(self, s, source, destination):
        manifests = s['cargo']['inventory']['manifests']
        owners = {m['owner_entity_id']: m for m in manifests}
        require(len(owners) == len(manifests) and self.SHIP in owners
                and owners[self.SHIP]['manifest_id'] == self.MANIFEST,
                'actual Hauler owns its exact shared-stock source manifest')
        quantity = lambda m: sum(e['quantity'] for e in m['entries'] if e['item_id'] == 'cinder_supply_crates')
        target = s['cargo']['destination_handle']
        require(set(owners) == {self.SHIP, target['entity_id']}
                and owners[target['entity_id']]['manifest_id'] == target['manifest_id']
                and quantity(owners[self.SHIP]) == source
                and quantity(owners[target['entity_id']]) == destination
                and 'jovian_provisional' not in owners,
                'Hauler alone carries shared mission stock; no Jovian source custody')

    def validate_observation(self, s):
        require(s['ship_definition_id'] == self.SHIP and s['production_hauler']
                and s['home']['id'] == 'dock_04_cargo',
                'actual original production Dock04 Hauler, never another craft')
        c = s['cargo']
        if c['available']:
            require(len(c['route_local']) == len(self.CARGO_LOCAL_POINTS)
                    and all(norm(sub(actual, expected)) <= .00001
                            for actual, expected in zip(c['route_local'], self.CARGO_LOCAL_POINTS)),
                    'exact supported ten-point Hauler terminal path')
            if c['lease']:
                require(norm(sub(c['dock_local'], [-29, 4.25, 0])) <= .00001
                        and c['dock_yaw_pi'], 'actual occupied Hauler contact and authored PI yaw')
        super().validate_observation(s)


class CinderSupplyFiles(HabitatRestartFiles):
    MUTABLE = HabitatRestartFiles.MUTABLE | {'cinder_cargo_delivery', 'game_flow_reward_store'}

    def observe(self, s, pilot):
        if s['save']['source'] != 'primary': return
        label = None
        if 'baseline' not in self.snapshots: label = 'baseline'
        elif pilot.stage == 'terminal_aim' and pilot.paid_state is None and 'pretransfer' not in self.snapshots: label = 'pretransfer'
        elif pilot.paid_state is not None and 'paid' not in self.snapshots: label = 'paid'
        elif 'repeat_terminal' in pilot.receipts and 'repeat' not in self.snapshots: label = 'repeat'
        elif 'home_docked' in pilot.receipts and 'home' not in self.snapshots: label = 'home'
        if label is None: return
        document = self.capture(label, s['save'])
        payload = document['payload']
        if label in ('baseline', 'pretransfer'):
            require('cinder_cargo_delivery' not in payload and payload.get('game_flow_reward_store', {}).get('total_receipts', 0) == 0,
                    'actual default primary starts without a prior supply completion or payment')
            if label == 'pretransfer':
                # Ordinary selection/tutorials can create records after the
                # initial title snapshot. Preserve every preexisting value,
                # then protect the complete actual document across payment.
                before = self.snapshots['baseline']['document']
                require(all(k in payload and payload[k] == v for k, v in self.protected(before).items()),
                        'unrelated actual-file payload retained before transfer')
                require(document['generation'] >= before['generation'], 'actual-file generations never regress')
                pilot.file_pretransfer = True
        else:
            require(pilot.file_pretransfer and 'pretransfer' in self.snapshots,
                    'actual pre-transfer primary captured before terminal input')
            pilot.require_paid(s)
            self.require_preserved(self.snapshots['pretransfer']['document'], document)
            require(payload['cinder_cargo_delivery'] == s['paid_slot'] and payload['game_flow_reward_store'] == s['reward_record'],
                    'independent actual primary file matches paid supply terminal and one reward')
            if label == 'paid': pilot.file_paid = True
            if label in ('repeat', 'home'):
                paid = self.snapshots['paid']['document']['payload']
                require(payload['cinder_cargo_delivery'] == paid['cinder_cargo_delivery']
                        and payload['game_flow_reward_store'] == paid['game_flow_reward_store'],
                        'actual default disk conserves paid supply slot and exact once-only ledger')
                if label == 'repeat': pilot.file_repeat = True
                else: pilot.file_home = True

class CrewRecoveryFiles(HabitatRestartFiles):
    CONTEXT = {'location': 'mudds_home_berth', 'mode': 'crew',
               'craft_id': 'jovian_provisional', 'berth_id': 'jovian_freight_berth'}

    def observe(self, s, pilot):
        if s['paused']: return
        if 'title' not in self.snapshots:
            self.capture('title', s['save'])
        if pilot.stage == 'crew_aim' and 'before-chair' not in self.snapshots:
            self.capture('before-chair', s['save'])
        if pilot.stage == 'crew_commit' and not pilot.file_context_accepted:
            if s['save']['context'] != self.CONTEXT: return
            pilot.require_crew(s)
            committed = self.capture('crew-committed', s['save'])
            before = self.snapshots['before-chair']['document']
            require(committed['payload']['solo_safe_recovery'] == self.CONTEXT
                    and s['save']['retry_seconds'] == 0
                    and committed['generation'] >= s['save']['context_generation'] > before['generation'],
                    'actual accepted primary crew commit after real chair admission')
            self.require_preserved(before, committed)
            predecessor_raw = Path(str(self.path)+'.bak').read_bytes()
            predecessor = json.loads(predecessor_raw)
            require(predecessor['generation'] == committed['commit']['parent_generation']
                    and predecessor['commit']['id'] == committed['commit']['parent_id'],
                    'actual committed document has its real predecessor')
            self.require_preserved(predecessor, committed)
            self.output.joinpath('crew-predecessor.json').write_bytes(predecessor_raw)
            pilot.file_context_accepted = True
        if pilot.cold and 'cold-title' not in self.snapshots and s['recovery']['available']:
            cold = self.capture('cold-title', s['save'])
            self.require_interrupted_cold(cold, self.snapshots['crew-committed']['document'])
            pilot.file_context_accepted = True
        if pilot.cold and pilot.awake and 'cold-awake' not in self.snapshots:
            awake = self.capture('cold-awake', s['save'])
            self.require_preserved(self.snapshots['crew-committed']['document'], awake)

    @classmethod
    def require_interrupted_cold(cls, cold, cut):
        payload, previous = cold['payload'], cut['payload']
        crash, safe = payload['crash_recovery'], payload['safe_start_recovery']
        require(payload['solo_safe_recovery'] == cls.CONTEXT
                and crash['state'] == 'running' and crash['unclean_start_count'] == 1
                and crash['session_id'] == previous['crash_recovery']['session_id']+1
                and crash['startup_generation'] == previous['crash_recovery']['startup_generation']+1
                and safe['startup_generation'] == previous['safe_start_recovery']['startup_generation']+1,
                'distinct crash recovery session retains exact crew preference')
        prior_safe = previous['safe_start_recovery']
        failures = prior_safe['consecutive_failure_count'] + (1 if prior_safe['state'] == 'starting' else 0)
        require(safe['state'] in ('starting', 'stable')
                and safe['consecutive_failure_count'] == (0 if safe['state'] == 'stable' else failures)
                and safe['safe_settings_recommended'] is False,
                'source-defined startup marker advances; stable startup resets prior failure count')
        events = payload['session_diagnostics']['events']
        require(sum(e['event_code'] == 'crash_detected' for e in events) == 1,
                'one actual crash diagnostic across owned interruption')
        require(cls.protected(cold) == cls.protected(cut), 'cold boot preserves all unrelated actual payload')

    def kill(self, process, desktop, leg_result, log_path):
        require('crew-committed' in self.snapshots and process.poll() is None,
                'only a live committed crew game may be interrupted')
        desktop.keys([]); desktop.mouse(0, 0, False)
        interrupted = self.path.read_bytes()
        require(hashlib.sha256(interrupted).hexdigest() == self.snapshots['crew-committed']['sha256'],
                'same independently captured committed bytes immediately before kill')
        process.kill()
        code = process.wait(timeout=15)
        leg_result.update(exit_code=code, reaped=process.poll() is not None, signal='SIGKILL')
        require(code == -9 and leg_result['reaped'], 'owned SIGKILL actually reaped as minus nine')
        require(self.path.read_bytes() == interrupted, 'kill cannot run orderly saves or mutate committed bytes')
        drain_game_output(process, log_path)

    @staticmethod
    def require_two_legs(legs, elapsed):
        require(len(legs) == 2 and legs[0]['pid'] != legs[1]['pid']
                and legs[0]['exit_code'] == -9 and legs[0]['reaped']
                and legs[0].get('signal') == 'SIGKILL'
                and legs[1]['exit_code'] == 0 and legs[1]['reaped'] and legs[1].get('normal_ui_exit')
                and 0 <= elapsed < CAP, 'owned killed/reaped first leg, distinct normal OS0 restart within original whole cap')


class CrewRecoveryPilot(LifeTowPilot):
    MARKER = 'NATIVE_CREW_RECOVERY_OK'
    begin_quit = HabitatRestartPilot.begin_quit
    ui_update = HabitatRestartPilot.ui_update

    def __init__(self, cold=False, expected_pid=None):
        super().__init__('life-gantry')
        self.MARKER = 'NATIVE_CREW_RECOVERY_OK'
        self.cold = cold
        self.expected_pid = expected_pid
        self.file_context_accepted = False
        self.awake = False
        self.cut_ready = False
        self.quit_requested = False
        self.ui_key = None
        self.ui_until = self.ui_release_until = 0
        self.ui_last_focus = None
        self.ui_edges = []
        self.sequence = 0
        self.aim_settled = 0
        self.last_input_frame = 0
        self.resume_pressed = False

    def validate_observation(self, s):
        require(s.get('mode') == 'crew-recovery' and s['pid'] == self.expected_pid
                and s['sequence'] == self.sequence+1, 'exact crew process and consecutive observer stream')
        self.sequence = s['sequence']
        self.last_state = s
        if s['paused']:
            require(self.initial is not None and s['main_id'] == self.initial['main_id']
                    and self.stage in ('restart_pause', 'restart_exit_wait'), 'only terminal normal pause UI')
            return
        if self.stage == 'helm_seating': self.require_helm_assignment(s)
        require(s['actors_current'] and s['ship_definition_id'] == 'jovian_provisional'
                and s['home_berth_id'] == 'jovian_freight_berth' and not s['destroyed']
                and not s['remote_piloted'], 'current supported live solo Jovian and authored home')
        fields = ('main_id', 'world_id', 'player_id', 'ship_id', 'capsule_id', 'shape_id', 'home_berth_instance_id')
        if self.initial is None:
            require(s['phase'] == 'INTRO' and norm(sub(s['player'], s['spawn'])) < .75,
                    'normal fresh Boot at authored hub before ordinary Begin Shift')
            self.initial = copy.deepcopy(s)
        require(all(s[k] != 0 and s[k] == self.initial[k] for k in fields)
                and s['default_sampler'] and s['default_controls'] and s['tuning_unchanged']
                and s['walk_tuning'] == self.DEFAULT_WALK and s['ship_tuning'] == self.initial['ship_tuning']
                and s['physics_ticks'] == 60 and s['time_scale'] == 1,
                'unchanged actual actors, default input/tuning and physical timing throughout each leg')
        previous = self.observed_previous
        if previous:
            require(s['frame'] == previous['frame']+1, 'consecutive actual crew gameplay frames')
            if s['native_interact'] != previous['native_interact']:
                self.native_edges.append(dict(frame=s['frame'], pressed=s['native_interact'], stage=self.stage))
            if self.stage in ('crew_walk', 'crew_aim', 'helm_walk', 'helm_aim'):
                self.require_walking(s)
                motion = self.require_motion_epoch(s)
                require(motion['start'] == previous['player'], 'continuous physical crew walking without placement')
                if motion['step_up']: self.require_step_event(s, motion)
                else: require(norm(sub(s['player'], previous['player'])) <= 9.2/60+.10,
                              'bounded normal crew walking motion')
                self.walked += norm(sub(s['player'], previous['player']))
        self.observed_previous = copy.deepcopy(s)

    @staticmethod
    def require_crew(s):
        crew = s['crew']
        require(crew['seated'] and crew['current'] and crew['role'] == 'engineer'
                and crew['seat_id'] == 'passenger_port_01' and crew['generation'] > 0
                and crew['authority_id'] and crew['tagged'] and crew['seated_at_anchor']
                and s['seated'] and s['station_seated'] and s['game_station_seated']
                and s['control_enabled'] and not s['transition_busy'] and not s['sleeping']
                and not s['piloted'] and s['cabin']['registered'] and s['cabin']['contained'],
                'actual settled current engineer role seat authority and registered occupant')

    @staticmethod
    def require_awake_home(s):
        c, crew = s['cabin'], s['crew']
        require(s['phase'] == 'IN_FLIGHT_CABIN' and s['hud_mode'] == 'aboard'
                and s['parked_exact'] and s['home_lease'] and not s['seated'] and not s['sleeping']
                and not s['piloted'] and not s['transition_busy'] and s['control_enabled']
                and s['grounded'] and s['supported'] and s['capsule_enabled']
                and not crew['seated'] and not crew['current'] and not crew['tagged']
                and crew['authority_id'] == 0 and not crew['assignment']
                and all(c[k] for k in ('frame_id', 'registered', 'contained', 'hatch_reserved', 'owner_current')),
                'fresh awake unseated supported home cabin and hatch without old claims')

    @staticmethod
    def require_helm_candidate(s):
        require(s['candidate'] and not s['station_candidate'],
                'ordinary helm Interact requires the actual ship candidate without a competing station')

    @staticmethod
    def require_helm_assignment(s):
        require(not s['crew']['assignment'],
                'helm Interact must not acquire any crew assignment, including an unfinished transition')

    @staticmethod
    def require_throttle(s):
        require(s['piloted'] and s['seated_at_pilot'] and s['active_ship'] and not s['transition_busy']
                and not s['crew']['seated'] and not s['crew']['current']
                and s['engine_online'] and s['command_throttle'] > 0 and s['flight_demand'] and s['native_forward'],
                'real current Jovian helm responds with ONLINE positive command and flight demand')

    def goal(self, s):
        name, target = self.route[self.index]
        if target is None:
            target = [-42, .38, s['access'][2]] if name == 'ramp_align' else s[name]
        return name, target

    def walk_goal(self, s, keys, frames):
        name, target = self.goal(s)
        precise = name in ('engineer_entry', 'helm_entry')
        if not precise:
            dx, reached = self.walk_to(s, target, keys, frames)
        else:
            dx, yaw, distance = self.yaw_to(s, target)
            speed = math.hypot(s['velocity'][0], s['velocity'][2])
            reached = distance <= .12 and abs(target[1]-s['player'][1]) < .8 and self.settled_frames >= 4
            stop = speed*speed/(2*s['walk_tuning']['deceleration'])+max(speed, 5.8)*frames/60+.02
            if abs(yaw) < .08 and distance > .12 and (speed <= .15 or distance > stop): keys.add('w')
        if reached:
            self.visited.append(dict(name=name, target=target, frame=s['frame'], position=s['player']))
            self.index += 1
            self.settled_frames = 0
        return dx

    def update(self, s, now):
        require(self.last_state is s, 'only latest validated crew sample drives OS input')
        if self.stage in ('restart_pause', 'restart_exit_wait'):
            return self.ui_update(s, now)
        self.frame = s['frame']
        frames = max(1, self.frame-self.last_input_frame)
        self.last_input_frame = self.frame
        keys, dx, dy = set(), 0, 0
        if self.stage == 'boot':
            if self.cold:
                recovery = s['recovery']
                if self.file_context_accepted and recovery['resume_visible'] and recovery['resume_enabled']:
                    if self.ui_key is None and now >= self.ui_release_until:
                        self.ui_key = 'Return' if recovery['focus_resume'] else 'Tab'
                        self.ui_until = now+.08
                        if self.ui_key == 'Return': self.resume_pressed = True
                if self.resume_pressed and not recovery['available'] and self.ui_key is None:
                    self.enter('begin_shift', s)
            elif s['menu_ready']:
                self.tap('e', now); self.enter('begin_shift', s)
        elif self.stage == 'begin_shift':
            if self.cold and s['menu_ready'] and self.tap_key is None and not s['native_interact']:
                self.tap('e', now)
            if self.cold and s['phase'] == 'IN_FLIGHT_CABIN':
                self.require_awake_home(s)
                self.receipts['awake'] = copy.deepcopy(s)
                self.awake = True
                self.begin_walk('helm_walk', [('aisle_forward', None), ('helm_entry', None)], s)
            elif not self.cold and s['phase'] == 'APPROACH_SHIP' and s['grounded']:
                route = list(self.GANTRY_GOALS[:11])+[(name, None) for name in
                        ('ramp_align', 'access', 'deck', 'aisle_aft', 'aisle_forward', 'engineer_entry')]
                self.begin_walk('crew_walk', route, s)
        elif self.stage in ('crew_walk', 'helm_walk'):
            self.require_walking(s)
            name, target = self.goal(s)
            flat = sub(target, s['player']); flat[1] = 0
            radius = .12 if name in ('engineer_entry', 'helm_entry') else .30
            if norm(flat) <= radius and math.hypot(s['velocity'][0], s['velocity'][2]) <= .35:
                self.settled_frames += frames
            else: self.settled_frames = 0
            dx = self.walk_goal(s, keys, frames)
            if self.index == len(self.route):
                self.enter('crew_aim' if self.stage == 'crew_walk' else 'helm_aim', s)
        elif self.stage in ('crew_aim', 'helm_aim'):
            engineer = self.stage == 'crew_aim'
            target = s['crew']['aim'] if engineer else s['helm_aim']
            dx, yaw, _distance = self.yaw_to(s, target)
            direction = unit(sub(target, s['camera_origin']))
            pitch = math.asin(max(-1, min(1, direction[1])))-math.asin(max(-1, min(1, s['camera_forward'][1])))
            dy = round(max(-180, min(180, -pitch/s['walk_tuning']['mouse'])))
            if abs(yaw) < .08 and abs(pitch) < .08 and not s['native_interact'] and (s['crew']['candidate'] if engineer else (s['candidate'] and not s['station_candidate'])):
                if not engineer: self.require_helm_candidate(s)
                self.tap('e', now)
                if self.tap_key == 'e': self.enter('crew_seating' if engineer else 'helm_seating', s)
        elif self.stage == 'crew_seating':
            if s['crew']['seated'] and not s['transition_busy']:
                self.require_crew(s)
                require(any(e['pressed'] and e['stage'] == 'crew_seating' for e in self.native_edges),
                        'actual OS engineer Interact observed before committed admission')
                self.receipts['crew'] = copy.deepcopy(s)
                self.enter('crew_commit', s)
        elif self.stage == 'crew_commit':
            self.require_crew(s)
            if self.file_context_accepted:
                self.tap_key = None
                self.cut_ready = True
        elif self.stage == 'helm_seating':
            if s['phase'] == 'START_ENGINES' and s['seated_at_pilot'] and not s['transition_busy']:
                require(any(e['pressed'] and e['stage'] == 'helm_seating' for e in self.native_edges),
                        'actual fresh OS Interact acquired the real Jovian helm')
                self.enter('helm_throttle', s)
        elif self.stage == 'helm_throttle':
            keys.add('w')
            if s['engine_online'] and s['command_throttle'] > 0 and s['flight_demand']:
                self.require_throttle(s)
                self.receipts['throttle'] = copy.deepcopy(s)
                keys.clear()
                self.begin_quit(s)
        if self.ui_key is not None:
            if now < self.ui_until: keys.add(self.ui_key)
            else:
                self.ui_key = None
                self.ui_release_until = now+.10
        if self.tap_key is not None:
            if now < self.tap_until or self.frame < self.tap_frame+6: keys.add(self.tap_key)
            else:
                self.tap_key = None; self.tap_cooldown = now+.3; self.tap_release_frame = self.frame
        if self.mouse_pending is not None:
            if norm(sub(s['walk_forward'], self.mouse_pending)) < .00001: dx = 0
            else: self.mouse_pending = None
        if dx: self.mouse_pending = s['walk_forward'][:]
        return keys, dx, dy, False

    def report(self):
        return dict(stage=self.stage, stages=self.stages, receipts=self.receipts, visited=self.visited,
                    walked_m=self.walked, native_edges=self.native_edges, ui_edges=self.ui_edges,
                    last_state=self.last_state, awake=self.awake, cut_ready=self.cut_ready)


def capture_guided_shutdown(profile, output):
    """Retain the real post-exit file before private-profile cleanup; no writes to it."""
    candidates = list((profile/'data').rglob('mudds_user_data.json'))
    if len(candidates) != 1:
        return {'captured': False, 'reason': 'expected one actual private-profile primary',
                'primary_count': len(candidates)}
    files = HabitatRestartFiles(profile, output)
    document = files.capture('guided-post-exit-user-data',
                             {'path': str(candidates[0].resolve()), 'source': 'primary', 'generation': 0})
    snapshot = files.snapshots['guided-post-exit-user-data']
    payload = document['payload']
    return dict(snapshot, captured=True, artifact='guided-post-exit-user-data.json',
                crash_recovery_state=payload.get('crash_recovery', {}).get('state'),
                safe_start_recovery_state=payload.get('safe_start_recovery', {}).get('state'))


def game_leg_arguments(base_arguments, route, output, leg):
    """Keep desktop engine logs outside the unsupported save directory."""
    arguments = list(base_arguments)
    if route != 'unsupported-save': return arguments
    output = Path(output)
    require(leg in (0, 1) and output.is_absolute() and output.is_dir()
            and not output.is_symlink() and output.resolve() == output,
            'future-save engine log uses the exact owned absolute output directory')
    require(not any(argument == '--log-file' or argument.startswith('--log-file=') for argument in arguments),
            'fresh per-leg engine arguments cannot accumulate log-file flags')
    log_path = output / f'godot-leg-{leg+1}.log'
    require(not log_path.exists() and not log_path.is_symlink(), 'fresh owned per-leg engine log path')
    arguments.extend(('--log-file', str(log_path)))
    return arguments


def run(binary, output, route="guided", qualify_beacon_outbound=False, retained_data=None, future_artifact=None, future_format=None):
    require(route in ("zenith-torrent-handback", "zenith-return-reuse", "patrol-relay-home", "race-home", "heavy-breach", "retained-heavy", "corrupt-retained-heavy", "unsupported-save", "bomber-rearm", "cinder-supply", "hauler-supply", "arrow-return-reuse", "torrent-return-reuse", "torrent-damaged-return", "torrent-arrow-handoff", "guided", "courier-intercept", "courier-escape", "courier-withdraw-phase", "courier-withdraw-distance", "beacon-entry", "beacon-settlement", "beacon-home", "sandbox-walk", "sandbox", "hulk-arrival", "hulk-breaker", "hulk-home", "habitat-loop", "habitat-restart", "crew-recovery", "life-tow", "life-gantry", "life-arm", "life-patrol"), "known ordinary-input route")
    require(not qualify_beacon_outbound or route == 'beacon-home',
            'outbound timing qualification requires the full beacon-home route')
    require((route in ('retained-heavy', 'corrupt-retained-heavy', 'unsupported-save')) == (retained_data is not None),
            'retained-data input is required only for retained-heavy, corrupt-retained-heavy or unsupported-save')
    require((route == 'unsupported-save') == (future_artifact is not None)
            and (future_artifact is None or future_artifact in UnsupportedSaveFiles.SUFFIX),
            'future-artifact is required only for unsupported-save and names one canonical placement')
    require(future_format is None or (route == 'unsupported-save' and future_format in ('outer','settings')),
            'future-format is valid only for the explicit unsupported-save route')
    require(future_format != 'settings' or future_artifact == 'primary', 'nested settings qualify primary placement only')
    unsupported_class = UnsupportedSettingsFiles if future_format == 'settings' else UnsupportedSaveFiles
    output.mkdir(parents=True, exist_ok=False)
    game = xvfb = desktop = pilot = None
    temporary_profile = None
    restart_files = None
    settlement_files = None
    breach_files = None
    retained_files = None
    corrupt_files = None
    unsupported_files = None
    route_warnings = unsupported_class.WARNINGS if route == 'unsupported-save' else ()
    zenith_files = None
    outbound_timing = None
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
            if route == 'unsupported-save':
                unsupported_files = unsupported_class(profile, output, retained_data, future_artifact)
                result['retained_input'] = unsupported_files.fixture
                result['future_artifact'] = future_artifact
                result['future_format'] = future_format or 'outer'
                result['expected_warnings_per_process'] = [warning.decode() for warning in route_warnings]
            if route == 'corrupt-retained-heavy':
                corrupt_files = CorruptRetainedHeavyFiles(profile, output, retained_data)
                result['retained_input'] = corrupt_files.fixture
                result['corrupt_primary'] = dict(bytes=len(corrupt_files.CORRUPT), sha256=corrupt_files.CORRUPT_SHA256)
            if route == 'retained-heavy':
                retained_files = RetainedHeavyFiles(profile, output, retained_data)
                result['retained_input'] = retained_files.fixture
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
                        '--native-sortie-observer' if route == 'guided' else '--native-sortie-observer='+('sandbox' if route == 'bomber-rearm' else 'heavy-breach' if route in ('retained-heavy', 'corrupt-retained-heavy', 'unsupported-save') else route)]
                result.update(arguments=args, display=env['DISPLAY'], xvfb_pid=xvfb.pid,
                              binary_sha256=hashlib.file_digest(binary.open('rb'),'sha256').hexdigest())
                breach_files = HeavyBreachFiles(profile, output) if route == 'heavy-breach' else None
                zenith_files = ZenithReturnReuseFiles(profile, output) if route == 'zenith-return-reuse' else None
                settlement_files = (PatrolRelayHomeFiles(profile, output) if route == 'patrol-relay-home' else
                                    RaceHomeFiles(profile, output) if route == 'race-home' else
                                    CinderSupplyFiles(profile, output) if route in ('cinder-supply', 'hauler-supply') else
                                    BeaconSettlementFiles(profile, output) if route in ('beacon-settlement', 'beacon-home') else None)
                restart_files = (CrewRecoveryFiles(profile, output) if route == 'crew-recovery' else
                                 HabitatRestartFiles(profile, output) if route == 'habitat-restart' else None)
                result['game_legs'] = []
                for leg in range(2 if restart_files or corrupt_files or unsupported_files else 1):
                    if unsupported_files:
                        unsupported_files.leg = leg
                        unsupported_files.capture_preserved(f'leg-{leg+1}-before-launch')
                    leg_log_offset = (output/'game.log').stat().st_size if (output/'game.log').exists() else 0
                    if corrupt_files: corrupt_files.leg = leg
                    # Same base args/env/profile/display/helper; this route redirects
                    # each engine log into its own retained output file.
                    # The single timer above remains armed across both games.
                    desktop.keys([]); desktop.mouse(0, 0, False)
                    leg_arguments = game_leg_arguments(args, route, output, leg)
                    game = subprocess.Popen(leg_arguments,cwd=binary.parent,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,bufsize=0)
                    leg_result = {'pid': game.pid, 'leg': leg + 1, 'exit_code': None, 'reaped': False,
                                  'arguments': leg_arguments}
                    if unsupported_files: leg_result['godot_log_path'] = leg_arguments[-1]
                    result['game_legs'].append(leg_result)
                    if leg == 0: result['game_pid'] = game.pid
                    else:
                        result['restart_game_pid'] = game.pid
                        require(game.pid != result['game_pid'], 'restart launches a distinct OS game process')
                    deadline = time.monotonic()+15
                    window = None
                    while time.monotonic()<deadline:
                        if game.poll() is not None:
                            code = record_terminal_game_exit(game, leg_result, output/'game.log')
                            raise RuntimeError(f'exported game exited before X window: {code}')
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
                    pilot = (unsupported_files.make_pilot(game.pid, cold=bool(leg)) if unsupported_files else (
                             (RetainedHeavyPilot(corrupt_files.expected, game.pid) if leg else
                              CorruptRetainedRepairPilot(corrupt_files.expected, game.pid)) if corrupt_files else
                             RetainedHeavyPilot(retained_files.expected, game.pid) if retained_files else
                             CrewRecoveryPilot(cold=bool(leg), expected_pid=game.pid) if isinstance(restart_files, CrewRecoveryFiles) else
                             HabitatRestartPilot(cold=bool(leg)) if restart_files else {
                        "zenith-torrent-handback": ZenithTorrentHandbackPilot, "zenith-return-reuse": ZenithReturnReusePilot, "patrol-relay-home": PatrolRelayHomePilot, "race-home": RaceHomePilot, "heavy-breach": HeavyBreachPilot, "bomber-rearm": BomberRearmPilot, "cinder-supply": CinderSupplyPilot, "hauler-supply": CinderHaulerSupplyPilot, "arrow-return-reuse": ArrowReturnReusePilot, "torrent-return-reuse": TorrentReturnReusePilot, "torrent-damaged-return": TorrentDamagedReturnPilot, "torrent-arrow-handoff": TorrentArrowHandoffPilot, "guided": GuidedExitPilot, "courier-intercept": CourierPilot, "courier-escape": CourierEscapePilot, "courier-withdraw-phase": CourierWithdrawPhasePilot, "courier-withdraw-distance": CourierWithdrawDistancePilot, "beacon-entry": BeaconEntryPilot, "beacon-settlement": BeaconSettlementPilot, "beacon-home": BeaconHomePilot, "sandbox-walk": SandboxWalkPilot, "sandbox": SandboxPilot,
                        "hulk-arrival": HulkArrivalPilot, "hulk-breaker": HulkBreakerPilot,
                        "hulk-home": HulkHomePilot, "habitat-loop": HabitatLoopPilot, "life-tow": LifeTowPilot, "life-gantry": lambda: LifeTowPilot("life-gantry"), "life-arm": lambda: LifeTowPilot("life-arm"), "life-patrol": lambda: LifeTowPilot("life-patrol")}[route]()))
                    if isinstance(pilot, BeaconHomePilot): pilot.file_snapshots = settlement_files.snapshots
                    if qualify_beacon_outbound: outbound_timing = BeaconOutboundTiming(game.pid)
                    if isinstance(pilot, (BomberRearmPilot, GuidedExitPilot, ZenithTorrentHandbackPilot)): pilot.expected_pid = game.pid
                    with selectors.DefaultSelector() as selector:
                        selector.register(game.stdout,selectors.EVENT_READ)
                        pending = b''
                        with (output/'game.log').open('ab') as log:
                            while pilot.result is None:
                                if game.poll() is not None:
                                    code = record_terminal_game_exit(game, leg_result, output/'game.log')
                                    if isinstance(pilot, (ZenithTorrentHandbackPilot, GuidedExitPilot, ArrowReturnReusePilot, CinderSupplyPilot, HeavyBreachPilot, RaceHomePilot)):
                                        require(pilot.quit_requested, f'native process exits only after normal UI request (actual exit {code})')
                                        tail = (output/'game.log').read_bytes().splitlines()
                                        for observation in observations_from_lines(tail, route_warnings):
                                            if (corrupt_files or unsupported_files) and observation['pid'] != game.pid: continue
                                            if observation['sequence'] > pilot.last_state['sequence']:
                                                pilot.validate_observation(observation)
                                                if breach_files: breach_files.observe(observation, pilot)
                                                if retained_files: retained_files.observe(observation, pilot)
                                                if corrupt_files: corrupt_files.observe(observation, pilot)
                                                if unsupported_files: unsupported_files.observe(observation, pilot)
                                        pilot.finish(game.wait())
                                        if isinstance(pilot, RaceHomePilot): settlement_files.finish(pilot.last_state, pilot)
                                        if zenith_files: zenith_files.finish(pilot.last_state, pilot)
                                        if breach_files: breach_files.finish()
                                        if retained_files: retained_files.finish()
                                        if corrupt_files: corrupt_files.finish_leg(leg, pilot)
                                        if unsupported_files: unsupported_files.finish_leg(leg, pilot)
                                        leg_result.update(exit_code=0, reaped=True, normal_ui_exit=True)
                                        if isinstance(pilot, (GuidedExitPilot, ZenithTorrentHandbackPilot)):
                                            leg_result['exit_ui'] = pilot.receipts['exit_ui']
                                            result['post_exit_user_data'] = capture_guided_shutdown(profile, output)
                                            if isinstance(pilot, ZenithTorrentHandbackPilot):
                                                closed = result['post_exit_user_data']
                                                require(closed.get('captured') and closed.get('crash_recovery_state') == 'clean'
                                                        and closed.get('safe_start_recovery_state') == 'clean_shutdown',
                                                        'independently read actual post-OS0 primary requires both durable clean markers')
                                        break
                                    if not restart_files: raise RuntimeError(f'game exited during {pilot.stage}: {game.returncode}')
                                    require(pilot.quit_requested and pilot.stage == 'restart_exit_wait',
                                            'game exits only after actual EXIT TO DESKTOP activation')
                                    require(game.wait() == 0, 'normal UI shutdown exits zero and reaps game')
                                    leg_result.update(exit_code=0, reaped=True, normal_ui_exit=True)
                                    break
                                if xvfb.poll() is not None: raise RuntimeError('owned Xvfb exited during sortie')
                                if time.monotonic()-start >= CAP: raise TimeoutError('300-second sortie cap')
                                if outbound_timing: outbound_timing.check_deadline(time.monotonic())
                                if isinstance(pilot, ArrowReturnReusePilot):
                                    pilot.check_weapon_deadline(time.monotonic())
                                for key,_ in selector.select(.1):
                                    chunk = os.read(key.fd,262144)
                                    if not chunk: continue
                                    log.write(chunk); log.flush()
                                    pending += chunk
                                    lines = pending.split(b'\n'); pending=lines.pop()
                                    observations = observations_from_lines(lines, route_warnings)
                                    if observations:
                                        if outbound_timing:
                                            received_at = time.monotonic()
                                            for observation in observations:
                                                outbound_timing.observe(observation, received_at)
                                        if isinstance(pilot, (ZenithTorrentHandbackPilot, GuidedExitPilot, BomberRearmPilot, LifeTowPilot, ArrowReturnReusePilot, CinderSupplyPilot, HeavyBreachPilot, RaceHomePilot)):
                                            for observation in observations:
                                                pilot.validate_observation(observation)
                                                if breach_files: breach_files.observe(observation, pilot)
                                                if retained_files: retained_files.observe(observation, pilot)
                                                if corrupt_files: corrupt_files.observe(observation, pilot)
                                                if unsupported_files: unsupported_files.observe(observation, pilot)
                                        state = observations[-1]
                                        if restart_files:
                                            require(state['pid'] == game.pid, 'observer belongs to exact running game PID')
                                            if not isinstance(restart_files, CrewRecoveryFiles) and leg and 'cold-title' not in restart_files.snapshots and state.get('menu_ready'):
                                                cold_title = restart_files.capture('cold-title', state['save'])
                                                closed = restart_files.snapshots['first-orderly-close']['document']
                                                restart_files.require_cold(cold_title, closed)
                                                restart_files.require_preserved(closed, cold_title)
                                        if isinstance(restart_files, CrewRecoveryFiles): restart_files.observe(state, pilot)
                                        keys,dx,dy,fire=pilot.update(state,time.monotonic())
                                        if settlement_files: settlement_files.observe(state, pilot)
                                        if zenith_files: zenith_files.observe(state, pilot)
                                        if restart_files and not isinstance(restart_files, CrewRecoveryFiles):
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
                                        if outbound_timing:
                                            outbound_timing.send_input(desktop, pilot.stage, state, keys, dx, dy, fire)
                                        else:
                                            desktop.keys(keys); desktop.mouse(dx,dy,fire)
                                        if isinstance(restart_files, CrewRecoveryFiles) and pilot.cut_ready:
                                            restart_files.kill(game, desktop, leg_result, output/'game.log')
                                            leg_result['sortie'] = pilot.report()
                                            pilot.result = {'owned_cut_complete': True}
                                            break
                    if unsupported_files:
                        desktop.keys([]); desktop.mouse(0, 0, False)
                        drain_game_output(game, output/'game.log'); game.stdout.close()
                        with (output/'game.log').open('rb') as stream:
                            stream.seek(leg_log_offset)
                            unsupported_files.require_warnings(stream.read().splitlines())
                        unsupported_files.capture_preserved(f'leg-{leg+1}-final-drain')
                        leg_result.update(sortie=pilot.result, expected_warning_count=2, unexpected_diagnostic_count=0)
                        game = None
                    elif corrupt_files:
                        desktop.keys([]); desktop.mouse(0, 0, False)
                        drain_game_output(game, output/'game.log'); game.stdout.close()
                        require(not diagnostic_lines((output/'game.log').read_bytes().splitlines()),
                                'zero game diagnostics across both normal corrupt recovery processes')
                        leg_result['sortie'] = pilot.result
                        game = None
                    elif isinstance(restart_files, CrewRecoveryFiles):
                        desktop.keys([]); desktop.mouse(0, 0, False)
                        game.stdout.close()
                        require(not diagnostic_lines((output/'game.log').read_bytes().splitlines()),
                                'zero diagnostics across both actual crew processes')
                        if leg:
                            require(pilot.quit_requested and pilot.awake and 'throttle' in pilot.receipts,
                                    'normal UI OS0 follows actual awake cabin and real throttle response')
                            closed = restart_files.capture('second-orderly-close')
                            restart_files.require_orderly(closed, restart_files.snapshots['cold-title']['document'])
                            restart_files.require_preserved(restart_files.snapshots['crew-committed']['document'], closed)
                            leg_result['sortie'] = pilot.report()
                        game = None
                    elif restart_files:
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
                        if outbound_timing:
                            require(outbound_timing.report()['qualified'],
                                    'full Beacon home completion also requires qualified outbound timing')
                        result.update(success=True,sortie=pilot.result)
                if breach_files: result['actual_file_snapshots'] = breach_files.snapshots
                if retained_files: result['actual_file_snapshots'] = retained_files.snapshots
                if unsupported_files:
                    unsupported_files.require_two_legs(result['game_legs'], time.monotonic()-start)
                    result['actual_file_snapshots'] = unsupported_files.snapshots
                    result.update(success=True, sortie=dict(completion_marker=unsupported_files.MARKER,
                        legs=[item['sortie'] for item in result['game_legs']], distinct_processes=True,
                        same_binary=str(binary), same_profile=str(profile),
                        same_input_helper_pid=desktop.process.pid, same_xvfb_pid=xvfb.pid))
                if corrupt_files:
                    corrupt_files.require_two_legs(result['game_legs'], time.monotonic()-start)
                    result['actual_file_snapshots'] = corrupt_files.snapshots
                    result.update(success=True, sortie=dict(completion_marker=corrupt_files.MARKER,
                        legs=[item['sortie'] for item in result['game_legs']], distinct_processes=True,
                        same_binary=str(binary), same_profile=str(profile),
                        same_input_helper_pid=desktop.process.pid, same_xvfb_pid=xvfb.pid))
                if restart_files:
                    result['actual_file_snapshots'] = restart_files.snapshots
                    if isinstance(restart_files, CrewRecoveryFiles):
                        restart_files.require_two_legs(result['game_legs'], time.monotonic()-start)
                    result['sortie'] = {'completion_marker': CrewRecoveryPilot.MARKER if isinstance(restart_files, CrewRecoveryFiles) else HabitatRestartPilot.MARKER,
                                        'legs': [item['sortie'] for item in result['game_legs']],
                                        'distinct_processes': True, 'same_profile': str(profile),
                                        'same_input_helper_pid': desktop.process.pid,
                                        'same_xvfb_pid': xvfb.pid}
                    result['success'] = True
    except Exception as error:
        if unsupported_files is not None: result['actual_file_snapshots'] = unsupported_files.snapshots
        if breach_files is not None: result['actual_file_snapshots'] = breach_files.snapshots
        if retained_files is not None: result['actual_file_snapshots'] = retained_files.snapshots
        if corrupt_files is not None: result['actual_file_snapshots'] = corrupt_files.snapshots
        if zenith_files is not None:
            result['actual_file_snapshots'] = zenith_files.snapshots
        if settlement_files is not None:
            result['actual_file_snapshots'] = settlement_files.snapshots
        if restart_files is not None:
            result['actual_file_snapshots'] = restart_files.snapshots
        if pilot is not None:
            result['partial_sortie'] = {'stage': pilot.stage, 'stages': pilot.stages, 'phases': pilot.phases}
            if isinstance(pilot, ZenithTorrentHandbackPilot):
                result['partial_sortie'].update(last_state=pilot.last_state, receipts=pilot.handoff_receipts,
                    guided_stage=pilot.guided.stage, guided_result=pilot.guided_result,
                    guided_stages=pilot.guided.stages, guided_phases=pilot.guided.phases,
                    visited=pilot.visited, remaining_goals=pilot.route,
                    native_edges=pilot.handoff_edges, retired=pilot.retired,
                    initial_identities={key:pilot.initial[key] for key in pilot.IDS} if pilot.initial else None,
                    first_zenith_stream=pilot.first_stream, retired_zenith_stream=pilot.retired_zenith_stream,
                    admission_neutral_frames=pilot.admission_neutral, torrent_neutral_frames=pilot.torrent_neutral,
                    final_neutral_frames=pilot.final_neutral, goal_since=pilot.goal_since,
                    board_since=pilot.board_since, clear_since=pilot.clear_since,
                    zenith_corner_required=pilot.walker.zenith_corner_required(),
                    zenith_corner_safe=pilot.walker.zenith_corner_safe(pilot.last_state) if pilot.last_state else None)
            if isinstance(pilot, GuidedExitPilot):
                result['partial_sortie'].update(last_state=pilot.last_state, receipts=pilot.receipts,
                                               guided_prerequisite=pilot.guided_result)
            if isinstance(pilot, ArrowReturnReusePilot):
                result['partial_sortie'].update(last_state=pilot.last_state, receipts=pilot.receipts, trips=pilot.trips, weapon=pilot.weapon)
            if isinstance(pilot, CourierPilot):
                result['partial_sortie'].update(courier=pilot.last_courier, courier_clear=pilot.courier_clear)
            if isinstance(pilot, CourierEscapePilot):
                result['partial_sortie'].update(courier_escape=pilot.courier_escape, dispatched_ids=sorted(pilot.dispatched_ids),
                                               waiting_flight=pilot.waiting_flight_report(),
                                               defender_wounds=pilot.defender_wounds, defender_misses=pilot.defender_misses)
            if isinstance(pilot, CourierWithdrawPhasePilot):
                result['partial_sortie'].update(courier_dispatch=pilot.dispatch, defender_kill=pilot.defender_kill,
                                               courier_withdrawal=pilot.courier_withdrawal,
                                               maximum_withdraw_radius_m=pilot.maximum_wait_radius)
            if isinstance(pilot, CourierWithdrawDistancePilot):
                result['partial_sortie'].update(courier_dispatch=pilot.dispatch, courier_withdrawal=pilot.courier_withdrawal,
                    withdraw_waypoint=pilot.withdraw_waypoint, escape_heading=pilot.escape_heading, defender_kill=pilot.defender_kill)
            if isinstance(pilot, HeavyBreachPilot): result['partial_sortie'] = pilot.report()
            if isinstance(pilot, HabitatRestartPilot):
                result['partial_restart'] = pilot.report()
            if isinstance(pilot, (HabitatLoopPilot, LifeTowPilot)):
                result['partial_sortie'].update(last_state=pilot.last_state, visited=pilot.visited,
                                               receipts=pilot.receipts, native_interact_edges=pilot.native_edges,
                                               walked_m=pilot.walked)
            if isinstance(pilot, CinderSupplyPilot):
                result['partial_sortie'].update(last_state=pilot.last_state, visited=pilot.visited, receipts=pilot.receipts, native_edges=pilot.native_edges)
            if isinstance(pilot, BeaconEntryPilot):
                result['partial_sortie'].update(last_state=pilot.last_state, receipts=pilot.receipts,
                                               ui_edges=pilot.ui_edges, sequence=pilot.sequence)
            if isinstance(pilot, BeaconHomePilot):
                result['partial_sortie'].update(settlement=pilot.settlement_result,
                                               native_home_edges=pilot.home_edges, home_presses=pilot.home_pressed,
                                               home_landing_active_seen=pilot.home_landing_seen,
                                               home_header_samples=pilot.home_header_samples,
                                               home_header_crossing=pilot.home_header_crossing,
                                               home_walked_m=pilot.home_walked)
            if isinstance(pilot, HulkArrivalPilot):
                result['partial_sortie']['last_state'] = pilot.last_state
            if isinstance(pilot, SandboxPilot):
                result['partial_sortie'].update(visited=pilot.visited, craft_sorties=pilot.completed,
                                               last_state=pilot.last_state, deliberate_crash=pilot.crash_receipt)
            if isinstance(pilot, BomberRearmPilot):
                result['partial_sortie'].update(last_policy_state=pilot.last_policy_state,
                                               receipts=pilot.receipts, native_edges=pilot.native_edges)
        result['error'] = f'{type(error).__name__}: {error}'
    finally:
        if outbound_timing is not None:
            result['beacon_outbound_timing'] = outbound_timing.report()
        if zenith_files is not None:
            result['actual_file_snapshots'] = zenith_files.snapshots
        if settlement_files is not None:
            result['actual_file_snapshots'] = settlement_files.snapshots
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
        if route == 'unsupported-save':
            expected = [line for line in diagnostics if line in route_warnings]
            diagnostics = [line for line in diagnostics if line not in route_warnings]
            result['expected_warning_count'] = len(expected)
            result['expected_warning_counts'] = {line.decode(): expected.count(line) for line in route_warnings}
            result['unexpected_diagnostic_count'] = len(diagnostics)
            if len(result.get('game_legs', [])) != 2 or any(expected.count(line) != 2 for line in route_warnings):
                result['success'] = False
                result.setdefault('error', 'future-load warnings must occur exactly once each in both OS processes')
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
    parser.add_argument('--retained-data', type=Path,
                        help='raw fixture: accepted Heavy save for retained/outer routes, source-produced fixture for unsupported-save settings')
    parser.add_argument('--future-artifact', choices=('primary','temporary','backup'),
                        help='required only for unsupported-save; run exactly one canonical future-envelope placement')
    parser.add_argument('--future-format', choices=('outer','settings'),
                        help='unsupported-save format, default outer; settings requires primary and the source-produced fixture')
    parser.add_argument('--qualify-beacon-outbound', action='store_true',
                        help='qualify the fixed 60.0s outbound monotonic maximum within the unchanged full beacon-home route')
    parser.add_argument('--route', choices=('zenith-torrent-handback', 'zenith-return-reuse', 'patrol-relay-home', 'race-home', 'heavy-breach', 'retained-heavy', 'corrupt-retained-heavy', 'unsupported-save', 'bomber-rearm', 'cinder-supply', 'hauler-supply', 'arrow-return-reuse', 'torrent-return-reuse', 'torrent-damaged-return', 'torrent-arrow-handoff', 'guided', 'courier-intercept', 'courier-escape', 'courier-withdraw-phase', 'courier-withdraw-distance', 'beacon-entry', 'beacon-settlement', 'beacon-home', 'sandbox-walk', 'sandbox', 'hulk-arrival', 'hulk-breaker', 'hulk-home', 'habitat-loop', 'habitat-restart', 'crew-recovery', 'life-tow', 'life-gantry', 'life-arm', 'life-patrol'), default='guided',
                        help='zenith-torrent-handback walks unchanged LIFE-ARM, exits docked Zenith, completes actual Guided in Torrent, and physically reclaims the same Zenith for90 fresh neutral ticks and normal HUD OS0; zenith-return-reuse covers selected Zenith LIFE-ARM admission, pilot controls/cameras, actual28-point repeater hit, two strict home/OFFLINE/wing-clear exits and normal UI OS0; patrol-relay-home completes genuine Guided, actual pause-board relay selection, five continuous two-second holds, exact durable payment, strict home and normal UI exit; race-home completes the genuine Guided prerequisite then same-Torrent timed race, exact durable reward, strict home and normal UI exit; heavy-breach completes real posted Heavy/picket kill/payment/home/next posting/UI exit; courier-withdraw-distance flies beyond all actual contacts for real seven-second grace withdrawal before original defender and home; courier-withdraw-phase kills the original defender after actual first courier dispatch and verifies phase withdrawal/standdown through home; courier-escape lets the actual first live runner escape and verifies standdown through home; courier-intercept destroys the actual first courier before escape then returns home; beacon-home retains payment through genuine Guided combat, home docking and usable exterior walking; hauler-supply flies the actual Dock04 Hauler through the funded Cinder terminal/home journey; cinder-supply flies the full funded Jovian/Cinder terminal/home journey; beacon-settlement continues the accepted entry through four physical beacons and durable reward; beacon-entry departs normally and physically reaches/starts the first Beacon through actual pause controls; life-patrol walks Habitat through the real door beside patrol drones and boards Torrent; life-arm walks Aft stairs past the live service arm and boards Zenith; life-gantry walks Freight past the live gantry and boards Jovian; life-tow walks Central beside live tow service and boards Torrent; hulk-home carries the earned HULK cell back to a supported home exit; hulk-breaker continues HULK arrival through its breaker; hulk-arrival flies the normal Guided prelude then docks/exits at HULK; sandbox runs fleet/crash/reuse; sandbox-walk covers station traversal')
    args=parser.parse_args()
    if args.qualify_beacon_outbound and args.route != 'beacon-home':
        parser.error('--qualify-beacon-outbound requires --route beacon-home')
    if (args.route in ('retained-heavy', 'corrupt-retained-heavy', 'unsupported-save')) != (args.retained_data is not None):
        parser.error('--retained-data is required only for --route retained-heavy, corrupt-retained-heavy or unsupported-save')
    if (args.route == 'unsupported-save') != (args.future_artifact is not None):
        parser.error('--future-artifact is required only for --route unsupported-save')
    if args.future_format is not None and args.route != 'unsupported-save':
        parser.error('--future-format is valid only for --route unsupported-save')
    if args.future_format == 'settings' and args.future_artifact != 'primary':
        parser.error('--future-format settings requires --future-artifact primary')
    try: binary=validate_binary(args.binary)
    except ValueError as error: parser.error(str(error))
    result=run(binary,args.output.absolute(),args.route,qualify_beacon_outbound=args.qualify_beacon_outbound,retained_data=args.retained_data,future_artifact=args.future_artifact,future_format=args.future_format)
    print(json.dumps(result,indent=2))
    return 0 if result['success'] and result.get('inputs_released') and result['game_reaped'] and result['xvfb_reaped'] and result['input_helper_reaped'] else 1


if __name__=='__main__': raise SystemExit(main())
