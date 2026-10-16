#!/usr/bin/env python3
"""Fly the embedded Linux game with OS XTest keys/mouse on an owned Xvfb.

Usage: run_native_sortie.py GAME.x86_64 --output NEW_RESULT_DIRECTORY
No source/pack overrides. 300 seconds is the fixed whole-process sortie cap.
This establishes Linux/Xvfb OS-input behavior, not native GPU or human acceptance.
"""
import argparse
import ctypes as C
import hashlib
import json
import math
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


def sub(a, b): return [x-y for x, y in zip(a, b)]
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def norm(a): return math.sqrt(dot(a, a))
def unit(a): return [x/max(norm(a), 1e-9) for x in a]


def validate_binary(path):
    path = Path(path).absolute()
    if path.is_symlink() or not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError("game must be a regular executable Linux ELF")
    with path.open('rb') as stream:
        header = stream.read(20)
    if header[:4] != b'\x7fELF' or header[4:6] != b'\x02\x01' or header[18:20] != b'\x3e\x00':
        raise ValueError("only native Linux x86_64 ELF is supported; PE/Wine is forbidden")
    return path


class Desktop:
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
        self.tap_key = None
        self.tap_cooldown = 0
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
        if now >= self.tap_cooldown:
            self.tap_key = key
            self.tap_until = now + .08
            self.tap_cooldown = now + .6

    def aim(self, s, target, gain=.55):
        desired = unit(sub(target, s['camera']))
        local = [dot(desired, s[a]) for a in ('right', 'up', 'back')]
        # Ordinary mouse controls map pixels directly to local craft attitude.
        yaw = math.atan2(local[0], -local[2])
        pitch = math.atan2(local[1], math.hypot(local[0], local[2]))
        sensitivity = s['tuning']['mouse']
        clamp = lambda v: round(max(-35, min(35, v)))
        return clamp(yaw*gain/sensitivity), clamp(-pitch*gain/sensitivity), -local[2]

    def update(self, s, now):
        phase = s['phase']
        if not self.phases or self.phases[-1] != phase:
            self.phases.append(phase)
        ids = (s['player_id'], s['ship_id'])
        if self.identities is None:
            self.identities = ids
            assert s['lease'], 'initial occupied central berth lease'
        assert self.identities == ids, 'same actor identities throughout'
        assert s['default_sampler'] and s['tuning_unchanged'], 'authored controls and tuning'
        assert phase != 'FAILED' and not s['destroyed'], 'live sortie'
        self.shot |= s['shot_accepted']
        self.fired |= s['command_fire']
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
                assert self.max_walk > 8, 'physical walk from spawn'
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
            assert s['piloted'] and s['seated'] and s['active_ship']
            self.enter('launch', s)
        elif self.stage == 'launch':
            target = [0, 8, -78]
            off = sub(target, s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            dist = norm(off)
            stopping = speed*speed/(2*s['tuning']['brake'])
            if dist < stopping+5.75: keys.add('End')
            elif align > .72: keys.add('w')
            if dist <= 5 and phase == 'TARGET_PRACTICE':
                assert self.departed and s['position'][2] < -66
                self.enter('range', s)
        elif self.stage == 'range':
            keys.add('End')
            if speed > .8:
                pass
            elif s['targets']:
                target = sorted(s['targets'], key=lambda t:t['name'])[0]
                dx, dy, align = self.aim(s, target['position'])
                fire = align >= .997
            else:
                assert s['destroyed_targets'] == 4 and phase == 'INTERCEPTOR_ENGAGEMENT' and s['opponent_active']
                self.enter('interceptor', s)
        elif self.stage == 'interceptor':
            keys.add('End')
            dx, dy, align = self.aim(s, s['opponent'], .8)
            fire = align >= .997
            if not s['opponent_active'] and phase == 'RETURN_TO_YARD':
                assert self.shot and self.fired and s['telemetry']['hull'] > 0
                self.enter('return', s)
        elif self.stage == 'return':
            waypoint = [0, 2, -18]
            off = sub(waypoint, s['position'])
            distance = norm(off)
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            stopping = speed*speed/(2*s['tuning']['brake'])
            if distance < stopping+1.75: self.return_braking = True
            if speed <= .45 and distance > 1: self.return_braking = False
            if distance <= 1 or self.return_braking: keys.add('End')
            elif align > .72: keys.add('w')
            if distance <= 1 and speed <= .45:
                self.enter('align_berth', s)
        elif self.stage == 'align_berth':
            keys.add('End')
            off = sub(s['parked'], s['position'])
            dx, dy, align = self.aim(s, [s['camera'][i]+off[i] for i in range(3)])
            if align > .995 and s['upright'] > .94 and speed <= .35:
                assert s['capture'], 'registered broad landing capture'
                self.landing_distance = norm(off)
                self.enter('land', s)
                self.tap('l', now)
        elif self.stage == 'land':
            if phase == 'SHUT_DOWN':
                assert s['contract'] and s['parked_exact'] and s['lease'], 'exact secured home berth'
                self.enter('shutdown', s)
        elif self.stage == 'shutdown' and s['telemetry']['engine'] == 'OFFLINE':
            self.enter('exit', s)
            self.tap('e', now)
        elif self.stage == 'exit' and phase == 'COMPLETE':
            assert not s['piloted'] and not s['seated'] and s['control_enabled']
            assert s['guided_complete'] and s['active_ship'] and s['exit_error'] < .25
            assert norm(sub(s['player'], s['spawn'])) > 8
            assert s['lease'] and s['parked_exact'] and s['contract']
            expected = ['APPROACH_SHIP','START_ENGINES','LAUNCH','TARGET_PRACTICE','INTERCEPTOR_ENGAGEMENT','RETURN_TO_YARD','SHUT_DOWN','COMPLETE']
            assert all(p in self.phases for p in expected), 'all genuine gameplay phases'
            self.enter('complete', s)
            self.result = {'phases': self.phases, 'stages': self.stages, 'walked_m': self.max_walk,
                           'excursion_m': self.max_excursion, 'landing_approach_m': self.landing_distance,
                           'exit_error_m': s['exit_error'], 'same_player_id': ids[0], 'same_ship_id': ids[1],
                           'authored_tuning': s['tuning'], 'default_sampler': True, 'shot_accepted': self.shot}
        if now < self.tap_until: keys.add(self.tap_key)
        return keys, dx, dy, fire


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    elif process:
        process.wait()


def run(binary, output):
    output.mkdir(parents=True, exist_ok=False)
    game = xvfb = desktop = None
    temporary_profile = None
    result = {'success': False, 'cap_seconds': CAP, 'binary': str(binary), 'native_gpu': 'NOT_RUN',
              'human_review': 'NOT_RUN', 'input_route': 'OS XTest → X11 → Godot Input → default sampler'}
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
                   'MUDDS_PRIVATE_PROBE_INPUT':'native-sortie-x11'}
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
                # Xlib reads XAUTHORITY itself; never open the inherited desktop.
                previous_auth = os.environ.get('XAUTHORITY')
                os.environ['XAUTHORITY'] = str(auth)
                try: desktop = Desktop(env['DISPLAY'])
                finally:
                    if previous_auth is None: os.environ.pop('XAUTHORITY',None)
                    else: os.environ['XAUTHORITY'] = previous_auth
                args = [str(binary),'--audio-driver','Dummy','--display-driver','x11',
                        '--rendering-driver','dummy','--disable-render-loop','--native-sortie-observer']
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
                        if re.search(r'=\s*'+str(game.pid)+r'\s*$',prop): window=int(candidate,16); break
                    if window: break
                    time.sleep(.05)
                if not window: raise RuntimeError('no X11 window owned by exact game PID')
                result['window'] = hex(window)
                desktop.x.XSetInputFocus(desktop.d,window,1,0)
                desktop.x.XFlush(desktop.d)
                pilot = Pilot()
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
                            if any(b'SCRIPT ERROR:' in line or line.startswith(b'NATIVE_SORTIE_REJECTED:') for line in lines):
                                raise RuntimeError('native game diagnostic failed; see game.log')
                            observations = [json.loads(line[len(PREFIX):]) for line in lines if line.startswith(PREFIX)]
                            if observations:
                                keys,dx,dy,fire=pilot.update(observations[-1],time.monotonic())
                                desktop.keys(keys); desktop.mouse(dx,dy,fire)
                    result.update(success=True,sortie=pilot.result)
    except Exception as error:
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
        for name, process in [('game',game),('xvfb',xvfb)]:
            try: stop(process)
            except Exception as error: cleanup_errors.append(name+': '+str(error))
            result[name+'_reaped'] = process is None or process.poll() is not None
        if temporary_profile:
            try: temporary_profile.cleanup()
            except Exception as error: cleanup_errors.append('profile: '+str(error))
        if cleanup_errors:
            result['cleanup_errors'] = cleanup_errors
            result['success'] = False
        result['elapsed_seconds'] = round(time.monotonic()-start,3)
        for sig,handler in old_signals.items(): signal.signal(sig,handler)
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary')
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    try: binary=validate_binary(args.binary)
    except ValueError as error: parser.error(str(error))
    result=run(binary,args.output.absolute())
    print(json.dumps(result,indent=2))
    return 0 if result['success'] and result.get('inputs_released') and result['game_reaped'] and result['xvfb_reaped'] else 1


if __name__=='__main__': raise SystemExit(main())
