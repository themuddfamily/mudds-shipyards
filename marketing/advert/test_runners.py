#!/usr/bin/env python3
"""Exercise capture orchestration with fake processes; never render or play audio."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="advert runners ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "project"
        self.advert = self.repo / "marketing" / "advert"
        shutil.copytree(SOURCE, self.advert, ignore=shutil.ignore_patterns("out", "__pycache__"))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}", MOCK_LOG=str(self.log))
        self.fake("timeout", 'if [[ "${MOCK_TIMEOUT:-}" == 1 ]]; then exit 124; fi\nshift 2\nexec "$@"')
        self.fake("xvfb-run", 'shift 3\nexec "$@"')
        self.fake("godot", '''python3 - "$@" <<'INNER'
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['MOCK_LOG'], 'a') as f:
    f.write(json.dumps(args) + '\\n')
if os.environ.get('MOCK_EXIT'):
    sys.exit(int(os.environ['MOCK_EXIT']))
if os.environ.get('MOCK_ERROR'):
    print('SCRIPT ERROR: mock parser failure')
if '--write-movie' in args:
    path = pathlib.Path(args[args.index('--write-movie') + 1])
    path.with_name('f00000000.png').touch()
    print('ADVERT_START_FRAME 24')
    if not os.environ.get('MOCK_INCOMPLETE'):
        print('ADVERT_DONE 63.0')
else:
    path = pathlib.Path(os.environ['ADVERT_STILLS_DIR']) / '00_mock_50.png'
    path.touch()
    print('ADVERT_STILL ' + str(path))
    if not os.environ.get('MOCK_INCOMPLETE'):
        print('ADVERT_STILLS_DONE 1')
INNER''')
        self.fake("ffmpeg", 'touch "${@: -1}"')

    def fake(self, name, body):
        p = self.bin / name
        p.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body + '\n')
        p.chmod(0o755)

    def run_capture(self, script, **extra):
        env = dict(self.env, **extra)
        return subprocess.run([str(self.advert / script), 'relative output'], cwd=self.root,
                              env=env, capture_output=True, text=True)

    def test_relative_movie_output_and_override_cleanup(self):
        result = self.run_capture('render_advert.sh')
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        output = self.root / 'relative output'
        self.assertTrue((output / 'mudds_shipyards_advert.mp4').exists())
        args = json.loads(self.log.read_text().splitlines()[0])
        self.assertEqual(args[args.index('--write-movie') + 1], str(output / 'frames/f.png'))
        self.assertEqual(args[args.index('--audio-driver') + 1], 'Dummy')
        self.assertEqual(args[args.index('--display-driver') + 1], 'x11')
        self.assertFalse((self.repo / 'override.cfg').exists())

    def test_relative_stills_output(self):
        result = self.run_capture('render_stills_gpu.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'relative output/00_mock_50.png').exists())

    def test_both_runners_reject_process_errors_timeouts_and_incomplete_capture(self):
        for script in ['render_advert.sh', 'render_stills_gpu.sh']:
            for settings, expected in [({'MOCK_EXIT': '7'}, 7), ({'MOCK_TIMEOUT': '1'}, 124),
                                       ({'MOCK_ERROR': '1'}, 1), ({'MOCK_INCOMPLETE': '1'}, 1)]:
                with self.subTest(script=script, settings=settings):
                    result = self.run_capture(script, **settings)
                    self.assertEqual(result.returncode, expected, result.stderr + result.stdout)
                    self.assertFalse((self.repo / 'override.cfg').exists())

    def test_existing_override_is_preserved(self):
        override = self.repo / 'override.cfg'
        override.write_text('existing')
        result = self.run_capture('render_advert.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(override.read_text(), 'existing')


if __name__ == '__main__':
    unittest.main()
