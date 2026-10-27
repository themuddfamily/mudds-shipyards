#!/usr/bin/env python3
"""Exercise INSTALL-LINUX-UNINSTALL on a pinned package in a fresh private root.

Runs the shipped manager, strict installed startup and the existing full ordinary
Guided driver. Leaves result.json, raw logs and preserved fixtures for review.
This checkpoint capability does not qualify a final candidate or native GPU.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import time

import install_linux_desktop as manager

HERE = Path(__file__).resolve().parent
SAVE_SHA = '25f9ccfe03b22018eae2cffcb52841ed5fbcff3f4a51a6c020e6c7495701aa73'
SAVE_BYTES = 8655
PHASES = ['APPROACH_SHIP', 'START_ENGINES', 'LAUNCH', 'TARGET_PRACTICE',
          'INTERCEPTOR_ENGAGEMENT', 'RETURN_TO_YARD', 'SHUT_DOWN', 'COMPLETE']
DIAGNOSTIC = re.compile(rb'SCRIPT ERROR:|(?:^|\n)ERROR:|WARNING:|ObjectDB instances leaked|resources still in use')


class Refusal(RuntimeError):
    pass


class Abort(BaseException):
    def __init__(self, signum):
        self.signum = signum


def require(condition, message):
    if not condition:
        raise Refusal(message)


def absolute_path(value):
    path = Path(value)
    require(path.is_absolute() and path == Path(os.path.abspath(path)), 'paths must be absolute and normalized')
    manager.safe_path(path)
    return path


def identity(path):
    require(not path.is_symlink() and path.is_file(), f'expected regular file: {path}')
    info = path.stat()
    return dict(bytes=info.st_size, sha256=manager.digest(path), mode=stat.S_IMODE(info.st_mode))


def sha(value):
    require(isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value), 'invalid SHA256 pin')
    return value


def no_links(root):
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(directory) / name
            require(not path.is_symlink(), f'symlink in private namespace: {path}')
            require(path.is_dir() or path.is_file(), f'special file in private namespace: {path}')


def preflight(args):
    root = absolute_path(args.root)
    require(not root.exists(), 'run root must be absent; existing roots are never reused or removed')
    require(root.parent.is_dir(), 'run root parent must already exist')
    paths = {key: absolute_path(getattr(args, key)) for key in ('archive', 'export_result', 'retained_save')}
    require(len(set(paths.values())) == 3, 'three independent input files required')
    for path in paths.values():
        require(not path.is_relative_to(root), 'inputs must be outside run root')
    inputs = {key: identity(path) for key, path in paths.items()}
    require(inputs['archive']['sha256'] == sha(args.archive_sha256), 'archive SHA256 differs from pin')
    require(sha(args.retained_save_sha256) == SAVE_SHA
            and inputs['retained_save']['sha256'] == SAVE_SHA
            and inputs['retained_save']['bytes'] == SAVE_BYTES, 'actual earned Heavy save bytes/pin required')
    record = json.loads(paths['export_result'].read_text())
    require(record.get('schema_version') == 1 and record.get('platform') == 'linux'
            and record.get('architecture') == 'x86_64' and record.get('preset') == 'Linux', 'wrong Linux export result')
    commit = record.get('source_commit', '')
    require(re.fullmatch('[0-9a-f]{40}', commit), 'export source commit required')
    package_root = 'MuddsShipyards-' + commit[:7]
    executable = package_root + '.x86_64'
    require(record.get('tarball_root') == package_root, 'source/tag/package root mismatch')
    for key, expected_name in (('tarball', package_root + '-linux-x86_64.tar.gz'), ('binary', executable)):
        item = record[key]
        require(Path(item['path']).name == expected_name and type(item['bytes']) is int
                and item['bytes'] > 0, f'export {key} identity missing')
        sha(item['sha256'])
    require(paths['archive'].name == Path(record['tarball']['path']).name
            and inputs['archive']['bytes'] == record['tarball']['bytes']
            and inputs['archive']['sha256'] == record['tarball']['sha256'], 'archive/export identity mismatch')
    template = record['release_template']
    require(type(template['bytes']) is int and template['bytes'] > 0
            and sha(template['sha256']) == sha(template['expected_sha256']), 'release template pin mismatch')
    payload = {}
    with manager.checked_archive(paths['archive']) as (archive, actual_root, actual_executable):
        require((actual_root, actual_executable) == (package_root, executable), 'archive source/tag mismatch')
        require(f'{package_root}/{manager.BUNDLED_INSTALLER}' in archive.getnames(), 'shipped manager is required')
        for name in (executable, manager.ICON, manager.BUNDLED_INSTALLER):
            member = archive.getmember(f'{package_root}/{name}')
            with archive.extractfile(member) as stream:
                digest = hashlib.sha256()
                while block := stream.read(1024 * 1024):
                    digest.update(block)
            payload[name] = dict(bytes=member.size, sha256=digest.hexdigest())
            if name == executable:
                require(template['bytes'] < member.size, 'ELF must contain the release template and embedded payload')
                require(payload[name] == {k: record['binary'][k] for k in ('bytes', 'sha256')}, 'archive ELF/export mismatch')
    # Detect changes during the trust pass before creating the run root.
    require(all(identity(paths[k]) == value for k, value in inputs.items()), 'input changed during preflight')
    return root, paths, inputs, record, payload


def write_file(path, content, mode):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.open('xb') as stream:
        stream.write(content)
        os.fchmod(stream.fileno(), mode)


def desktop_bytes(runtime, executable):
    # Independently compare the entire published launcher, not the manager's own validator.
    def argument(value):
        value = value.replace('%', '%%')
        for character in ('\\', '"', '`', '$'):
            value = value.replace(character, '\\' + character)
        return '"' + value.replace('\\', '\\\\') + '"'
    def string(value):
        return str(value).replace('\\', '\\\\')
    return ("[Desktop Entry]\nType=Application\nName=Mudd's Shipyards\n"
            'Comment=Build, fly and crew your ships\n'
            f'Exec=/usr/bin/env -- {argument(str(runtime / executable))}\n'
            f'Path={string(runtime)}\nIcon={string(runtime / manager.ICON)}\n'
            'Terminal=false\nCategories=Game;Simulation;\n').encode()


def journals_absent(prefix):
    require(all(not (prefix / name).exists() for name in (manager.UPDATE, manager.UNINSTALL)), 'transaction journal remains')


def installed(prefix, apps, executable, payload):
    manifest = prefix / manager.MANIFEST
    require(identity(manifest)['mode'] == 0o644, 'manifest mode differs')
    state = json.loads(manifest.read_text())
    require(set(state) == {'owner', 'generation', 'executable', 'applications_dir', 'files'}
            and state['owner'] == 'mudds-shipyards-linux-desktop'
            and re.fullmatch(r'\.mudds-shipyards-runtime-[0-9a-f]{32}', state['generation'])
            and state['executable'] == executable and state['applications_dir'] == str(apps)
            and state['files'] == {name: payload[name]['sha256'] for name in (executable, manager.ICON)}, 'exact manifest contract differs')
    runtime = prefix / state['generation']
    require(runtime.is_dir() and stat.S_IMODE(runtime.stat().st_mode) == 0o755, 'runtime directory mode differs')
    for name, mode in ((executable, 0o755), (manager.ICON, 0o644)):
        require(identity(runtime / name) == dict(payload[name], mode=mode), 'installed payload bytes/mode differ')
    entry = apps / manager.DESKTOP
    require(identity(entry)['mode'] == 0o644 and entry.read_bytes() == desktop_bytes(runtime, executable), 'complete desktop launcher differs')
    journals_absent(prefix)
    return state


def removed(prefix, apps, state):
    for path in [prefix / manager.MANIFEST, apps / manager.DESKTOP,
                 *(prefix / state['generation'] / name for name in state['files'])]:
        require(not path.exists(), f'managed file remains after uninstall: {path}')
    journals_absent(prefix)


def preserved(fixtures):
    for path, expected in fixtures.items():
        require(identity(path) == expected, f'protected bytes/mode changed: {path}')


def snapshot(roots):
    result = {}
    for root in roots:
        for path in (root, *sorted(root.rglob('*'))):
            require(not path.is_symlink(), 'symlink in managed namespace')
            result[str(path)] = (dict(directory=True, mode=stat.S_IMODE(path.stat().st_mode))
                                 if path.is_dir() else identity(path))
    return result


def run_child(command, cap, env, log, steps, *, child_umask=0o077):
    # Existing subreaper owns detached peers as well as the direct child. Never
    # replace it with a timeout of just the game's original process group.
    supervised = [sys.executable, str(HERE / 'suite_process.py'), '--timeout', str(cap), '--', *command]
    started = time.monotonic()
    step = dict(command=command, cap_seconds=cap, log=str(log))
    steps.append(step)
    with log.open('xb') as output:
        process = subprocess.Popen(supervised, env=env, stdin=subprocess.DEVNULL,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True, umask=child_umask)
        try:
            code = process.wait(timeout=cap + 10)
        except BaseException:
            handlers = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGINT, signal.SIGTERM)}
            try:
                process.send_signal(signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
            finally:
                for sig, handler in handlers.items(): signal.signal(sig, handler)
            raise
    step.update(exit_code=code, elapsed_seconds=round(time.monotonic() - started, 3))
    if code in (130, 143):
        raise Abort(code - 128)
    require(code == 0, f'child failed (exit {code}): {log}')


def startup_result(directory, binary, expected_sha):
    base = directory / (binary.name + '.startup-check')
    record = json.loads(base.with_suffix(base.suffix + '.json').read_text())
    raw = base.with_suffix(base.suffix + '.log').read_bytes()
    require(record.get('status') == 'PASS' and record.get('check') == 'linux_startup_menu_ready'
            and record.get('exit_code') == 0 and record.get('sentinel_count') == 1
            and record.get('binary_sha256') == expected_sha and record.get('input') == str(binary)
            and record.get('launch_mode') == 'headless' and record.get('wall_ms', 300001) <= 300000
            and record.get('reasons') == [] and raw.splitlines().count(b'STARTUP_MENU_READY_OK') == 1
            and b'STARTUP_MENU_READY_FAILED' not in raw and not DIAGNOSTIC.search(raw), 'strict startup result/log contract failed')
    return record


def guided_result(directory, binary, expected_sha):
    record = json.loads((directory / 'result.json').read_text())
    raw = (directory / 'game.log').read_bytes()
    require(record.get('success') is True and record.get('route') == 'guided'
            and record.get('cap_seconds') == 300 and record.get('elapsed_seconds', 301) <= 300
            and record.get('binary') == str(binary) and record.get('binary_sha256') == expected_sha
            and record.get('diagnostic_count') == 0 and not DIAGNOSTIC.search(raw)
            and all(record.get(key) is True for key in ('inputs_released', 'game_reaped', 'xvfb_reaped', 'input_helper_reaped'))
            and not record.get('cleanup_errors'), 'Guided identity/cap/diagnostic/cleanup contract failed')
    require(record.get('arguments') == [str(binary), '--audio-driver', 'Dummy', '--display-driver', 'x11',
                                       '--rendering-driver', 'dummy', '--disable-render-loop', '--native-sortie-observer'], 'Guided ordinary input arguments differ')
    sortie = record.get('sortie', {})
    require(sortie.get('normal_ui_exit') is True and sortie.get('exit_code') == 0
            and sortie.get('default_sampler') is True and sortie.get('walked_m', 0) > 8
            and all(phase in sortie.get('phases', []) for phase in PHASES)
            and sortie.get('receipts', {}).get('exit_ui'), 'full ordinary Guided/HUD OS0 result missing')
    legs = record.get('game_legs', [])
    require(len(legs) == 1 and legs[0].get('exit_code') == 0 and legs[0].get('normal_ui_exit') is True
            and legs[0].get('reaped') is True, 'actual Guided OS0 leg missing')
    closed = record.get('post_exit_user_data', {})
    require(closed.get('captured') is True and closed.get('crash_recovery_state') == 'clean'
            and closed.get('safe_start_recovery_state') == 'clean_shutdown', 'durable clean markers missing')
    artifact = directory / 'guided-post-exit-user-data.json'
    actual = identity(artifact)
    require(actual['sha256'] == closed.get('sha256'), 'captured primary bytes differ')
    document = json.loads(artifact.read_text())
    require(document == closed.get('document') and document['payload']['crash_recovery']['state'] == 'clean'
            and document['payload']['safe_start_recovery']['state'] == 'clean_shutdown', 'actual primary lacks durable clean markers')
    return record


def execute(args):
    consumer_started = time.monotonic()
    root, paths, inputs, export, payload = preflight(args)
    tooling = {path: identity(path) for path in (Path(__file__).resolve(), HERE / 'install_linux_desktop.py',
               HERE / 'suite_process.py', HERE / 'run_linux_startup_check.sh', HERE / 'run_native_sortie.py')}
    root.mkdir(mode=0o700)
    result = dict(success=False, scope='INSTALL-LINUX-UNINSTALL checkpoint capability',
                  final_candidate='NOT_RUN', native_gpu='NOT_RUN', human_review='NOT_RUN',
                  source_commit=export['source_commit'], export_result=export, inputs=inputs,
                  runner_sha256=manager.digest(Path(__file__).resolve()),
                  tooling={str(path): value for path, value in tooling.items()}, steps=[])
    old_umask = os.umask(0o077)
    old_signals = {sig: signal.signal(sig, lambda signum, frame: (_ for _ in ()).throw(Abort(signum)))
                   for sig in (signal.SIGINT, signal.SIGTERM)}
    code = 1
    try:
        prefix, apps, profile = root / 'installed game', root / 'applications', root / 'profile'
        prefix.mkdir(mode=0o700)
        apps.mkdir(mode=0o700)
        env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'HOME': os.environ.get('HOME', '/tmp'),
               'GODOT_SILENCE_ROOT_WARNING': '1'}
        profile.mkdir(mode=0o700)
        for key, name in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'),
                          ('XDG_STATE_HOME', 'state'), ('XDG_RUNTIME_DIR', 'runtime'), ('XDG_DATA_DIRS', 'data-dirs'),
                          ('XDG_CONFIG_DIRS', 'config-dirs'), ('TMPDIR', 'tmp')]:
            (profile / name).mkdir(mode=0o700)
            env[key] = str(profile / name)
        package = root / 'package'
        package.mkdir(mode=0o700)
        # checked_archive has already audited every path/type/gzip/payload header.
        with manager.checked_archive(paths['archive']) as (archive, name, executable):
            destination = package / name
            destination.mkdir(mode=0o700)
            for member in archive.getmembers():
                if member.isfile():
                    with archive.extractfile(member) as source:
                        write_file(destination / Path(member.name).name, source.read(), member.mode & 0o777)
        shipped = destination / manager.BUNDLED_INSTALLER
        require({k: identity(shipped)[k] for k in ('bytes', 'sha256')} == payload[manager.BUNDLED_INSTALLER], 'extracted manager differs')
        result['shipped_manager'] = identity(shipped)
        fixtures = {}
        installer_started = consumer_started
        game_time = 0.0

        def invariants():
            no_links(root)
            require(all(identity(paths[k]) == value for k, value in inputs.items()), 'read-only input changed')
            preserved(fixtures)
            require(all(identity(path) == value for path, value in tooling.items()), 'consumer/helper source changed')
            require(time.monotonic() - installer_started - game_time < 120, 'installer consumer exceeded120s excluding games')

        def cli(operation, label):
            invariants()
            remaining = 120 - (time.monotonic() - installer_started - game_time)
            command = [sys.executable, str(shipped), operation]
            if operation == 'install': command += ['--archive', str(paths['archive'])]
            command += ['--install-dir', str(prefix), '--applications-dir', str(apps)]
            run_child(command, min(10, remaining), env, root / f'{label}.log', result['steps'], child_umask=0o022)
            invariants()

        def fixture(path, content, mode):
            write_file(path, content, mode)
            fixtures[path] = identity(path)

        cli('install', 'first-install')
        first = installed(prefix, apps, executable, payload)
        fixture(prefix / 'personal-notes.txt', b'root notes\n', 0o640)
        fixture(prefix / first['generation'] / 'personal-notes.txt', b'runtime notes\n', 0o600)
        fixture(apps / 'other-game.desktop', b'other game\n', 0o600)
        fixture(Path(env['XDG_DATA_HOME']) / 'godot/app_userdata/Mudds Shipyards/mudds_user_data.json', paths['retained_save'].read_bytes(), 0o644)
        cli('uninstall', 'first-uninstall')
        removed(prefix, apps, first)
        before_repeat = snapshot((prefix, apps, profile))
        cli('uninstall', 'repeat-uninstall')
        removed(prefix, apps, first)
        require(snapshot((prefix, apps, profile)) == before_repeat, 'repeat uninstall mutated namespace')
        cli('install', 'reinstall')
        second = installed(prefix, apps, executable, payload)
        require(second['generation'] != first['generation'], 'reinstall reused old generation')
        fixture(prefix / second['generation'] / 'personal-notes.txt', b'reinstalled runtime notes\n', 0o600)
        binary = prefix / second['generation'] / executable
        before_games = snapshot((prefix, apps))
        results = root / 'startup-results'
        results.mkdir(mode=0o700)
        startup_env = dict(env, STARTUP_CHECK_RESULT_DIR=str(results), STARTUP_CHECK_TIMEOUT_SECONDS='300')
        started = time.monotonic()
        run_child(['bash', str(HERE / 'run_linux_startup_check.sh'), str(binary)], 310, startup_env,
                  root / 'startup.log', result['steps'])
        result['startup'] = startup_result(results, binary, payload[executable]['sha256'])
        run_child([sys.executable, str(HERE / 'run_native_sortie.py'), str(binary), '--route', 'guided',
                   '--output', str(root / 'guided-results')], 330, env, root / 'guided.log', result['steps'])
        result['guided'] = guided_result(root / 'guided-results', binary, payload[executable]['sha256'])
        game_time += time.monotonic() - started
        invariants()
        require(snapshot((prefix, apps)) == before_games, 'gameplay changed installed namespace')
        installed(prefix, apps, executable, payload)
        cli('uninstall', 'final-uninstall')
        removed(prefix, apps, second)
        removed(prefix, apps, first)
        invariants()
        expected_prefix = {prefix / 'personal-notes.txt', prefix / first['generation'], prefix / second['generation'],
                           prefix / first['generation'] / 'personal-notes.txt', prefix / second['generation'] / 'personal-notes.txt'}
        require(set(prefix.rglob('*')) == expected_prefix and set(apps.iterdir()) == {apps / 'other-game.desktop'}, 'uninstall removed or retained unexpected paths')
        result.update(success=True, first_generation=first['generation'], reinstalled_generation=second['generation'],
                      protected_files={str(path): value for path, value in fixtures.items()},
                      installer_elapsed_seconds=round(time.monotonic() - installer_started - game_time, 3),
                      cleanup='final shipped uninstall complete; private root retained for review')
        code = 0
    except Abort as error:
        code = 128 + error.signum
        result['error'] = f'aborted by signal{error.signum}; owned children supervised; root retained'
    except Exception as error:
        result['error'] = f'{type(error).__name__}: {error}'
    finally:
        for sig, handler in old_signals.items(): signal.signal(sig, handler)
        os.umask(old_umask)
        with (root / 'result.json').open('x') as output:
            json.dump(result, output, indent=2)
            output.write('\n')
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('archive', 'archive-sha256', 'export-result', 'retained-save', 'retained-save-sha256', 'root'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    try:
        return execute(args)
    except (Refusal, manager.InstallError, OSError, ValueError, KeyError, TypeError) as error:
        print(f'linux-install-lifecycle: REFUSED: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
