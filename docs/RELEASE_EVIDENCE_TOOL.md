# Release candidate evidence tool

`tools/release/release_candidate.py` is a bounded Phase 9 gate for a Windows
candidate that has already been exported, inventoried, matrix-tested, and
package-probed. It publishes nothing and does not claim that an embedded
certificate is cryptographically valid.

The tool emits two files beside the executable only after every input passes:

- `<artifact-stem>.release.json`, validated against
  `tools/release/release_candidate.schema.json`;
- `SHA256SUMS`, containing the executable and candidate-record SHA-256 values in
  filename order.

The JSON is deterministic for identical inputs. It has no generation-clock
field; the matrix and probe run identities retain their own recorded UTC bounds.

## Inputs and invocation

First create the package inventory from the exact candidate:

```sh
python3 tools/release/package_inventory.py \
  builds/windows/MuddsShipyards-<source-sha7>.exe \
  -o builds/windows/MuddsShipyards-<source-sha7>.inventory.json
```

Then run the evidence gate from a clean worktree whose `HEAD` is the full source
revision named by the artifact's seven-character suffix:

```sh
python3 tools/release/release_candidate.py \
  --repository /path/to/clean/source-worktree \
  --artifact /path/to/MuddsShipyards-<source-sha7>.exe \
  --godot /path/to/the/validated/godot \
  --matrix-manifest /path/to/full-matrix/run-manifest.txt \
  --probe-manifest /path/to/package-probes/run-manifest.txt \
  --inventory /path/to/MuddsShipyards-<source-sha7>.inventory.json
```

Python's `jsonschema` package and the selected Godot executable are required.
Use `--check-only` to print a validated record without writing either output.

## Fail-closed contract

The gate refuses to emit release evidence when any of these conditions holds:

- the source worktree is dirty, its revision is malformed, or the artifact's
  filename suffix is not that worktree's exact seven-character short revision;
- the selected Godot executable differs from the matrix/probe executable, or
  its exact version disagrees with the PCK engine version;
- the matrix is not full-scope `PASS`, has a failing canonical row, has changed
  source, or its recorded source manifest cannot be reproduced byte-for-byte
  from the clean candidate worktree;
- package probes are missing/failing, target different executable bytes, or
  have missing or hash-mismatched logs;
- the inventory targets different bytes, is unsorted, contains unsafe or
  forbidden paths, has bad payload hashes/bounds/overlaps, or disagrees with
  the embedded PCK trailer or path-manifest digest;
- PE32+ headers, fixed file/product versions, resource bounds, or certificate
  table bounds are malformed;
- the output schema is unavailable or the candidate record violates it.

An absent PE Certificate Table is recorded as `unsigned`. A bounded non-empty
table is recorded only as `embedded_certificate_present_unverified`, with
`cryptographic_signature_verified=false` and
`external_catalog_assessed=false`. This tool does not authenticate a signer.

## ae4ffba audit result

The implementation-time read-only audit did not issue a candidate record for
`MuddsShipyards-ae4ffba.exe`. The latest associated full matrix run
(`20260816T200543Z`) recorded source-scope SHA-256
`c7dcf50a2c4a11dec1a5169e2d48bf049f9d921a649df7fded9dfd2918d43428`
over 720 files. A clean `ae4ffba` worktree reproduces 713 files and SHA-256
`e4e0485853d7f8c1b02aa2a02709068f16f096c778c3d58989c49f5feb2714c6`.
The artifact and its passing probes remain useful diagnostic evidence, but they
cannot satisfy the source-binding release gate. A new clean-source export,
full matrix, package probes, and inventory are required for a PASS record.

## Native Windows checkpoint startup

Run the actual exported EXE or checkpoint ZIP with native Windows PowerShell:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/release/run_windows_startup_check.ps1 `
  -Artifact C:\Candidates\MuddsShipyards-<source-sha7>-checkpoint.zip `
  -ExpectedExeSha256 <64-character-exe-sha256> `
  -ResultDirectory C:\Checks\<fresh-run-directory>
```

The result directory must be new and outside real APPDATA, LOCALAPPDATA and
Downloads. A ZIP must contain exactly `<build>.exe` and `<build>-notes.txt` as
regular top-level members; duplicates, traversal, links and unexpected files
fail before extraction. The executable is copied into a private native Windows
TEMP directory and must match the supplied SHA-256 before it can run.

The child uses `CreateNoWindow`, `--headless --audio-driver Dummy --startup-check`,
private APPDATA/LOCALAPPDATA/TEMP/TMP, all seven XDG paths and TMPDIR. HOME and
USERPROFILE stay inherited. Stdout/stderr drain asynchronously. Passing requires
actual exit 0, exactly one readiness record in both stdout and Godot's log, and
no engine/script/warning/leak diagnostics. The default 300-second deadline can be
shortened with `-TimeoutSeconds`; it cannot be increased.

Abort independently from another terminal:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/release/run_windows_startup_check.ps1 `
  -Abort -ResultDirectory C:\Checks\<fresh-run-directory>
```

Abort verifies the canonical generated native TEMP child, the per-run ownership
marker and result-directory binding, then the live PID, start time and executable
before writing a request. Invalid or stale records cause no request writes. The
runner assigns the process to a named kill-on-close Windows Job while it is
suspended, then resumes it; descendants cannot escape that Job. The independent abort command opens only that bound Job; abort and deadlines
stop the whole Job, and output draining has a separate ten-second bound. Both success and failure retain `result.json`,
`owned-process.json` and available stdout/stderr/Godot logs; the private profile
and copied payload are removed only after no owned actors remain. Sources and
parent environment are checked unchanged. No installer or input automation runs.
This checks native Windows headless title-menu readiness; native GPU, gameplay,
audible audio and human review remain `NOT_RUN`.

The small native failure suite compiles a harmless managed fixture and checks
nonzero exit, duplicate readiness, script diagnostics, timeout, independent
abort, a descendant retaining stdout/stderr pipes, malformed abort records that
must cause no writes, and unsafe ZIP members:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/release/test_windows_startup_check.ps1 `
  -TestDirectory C:\Checks\<fresh-fixture-directory>
```

`.github/workflows/windows-startup.yml` runs this fixture suite on a native
Windows runner with Windows PowerShell when its source/helper/test files change,
and supports manual dispatch. It uses a fresh `RUNNER_TEMP` directory outside
APPDATA, LOCALAPPDATA and Downloads, with bounded execution and seven-day
retention of available JSON results and logs even on failure. These harmless
managed fixtures do not run Godot or an exported game and do not establish game
startup, native GPU, gameplay or full-release acceptance.

## Native Windows OS interruption and safe-home recovery

Use the compiled convoy probe in a pinned Windows EXE. Each invocation creates a
fresh private profile, waits for its durable typed arm boundary, terminates that
exact native Windows Job with `TerminateJobObject`, and starts a distinct resume
process against the same private profile. No external script override is used.

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/release/run_windows_interruption_check.ps1 `
  -Artifact builds/windows/MuddsShipyards-<commit>.exe `
  -ExpectedExeSha256 <64-character-EXE-SHA256> `
  -RecoveryContext pilot `
  -ResultDirectory <fresh-explicit-result-directory>
```

Run `pilot`, `cabin`, `rest`, and `crew` independently with fresh result directories.
Both legs are headless with Dummy audio, with a maximum/default deadline of 300
seconds per leg. HOME and USERPROFILE stay inherited; APPDATA, LOCALAPPDATA,
TEMP, TMP, TMPDIR and all seven XDG variables point into a GUID namespace under
native Windows TEMP. The command refuses existing results, reparse paths and
real application-data/Downloads result destinations, checks the source and tested
copy against the required pin, snapshots real game data read-only before/after,
and removes only the verified owned namespace once its processes are reaped.

The command requires unique typed markers in stdout and the game log, actual
resume exit zero, a byte-identical document across termination, unchanged durable
convoy boundary, one crash event, receipts advancing from one to two, clean final
crash markers and usable safe-home pilot or awake cabin flags. Logs, process
identities, interrupted/recovered documents and real-data snapshots remain in the
result directory. The unchanged startup Job helper bounds descendants and stream
draining. Abort from another terminal using:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/release/run_windows_interruption_check.ps1 `
  -Abort -ResultDirectory <running-result-directory>
```

Abort validates the private owner marker and live PID/start-time/EXE binding before
opening only the recorded leg's named Job. Closing the harness Job handle also
terminates owned descendants. The recovered compiled probe reacquires its real
safe-home context before using the disclosed escort-motion fixture to finish a
convoy; cabin/rest/crew contexts walk and retake the pilot before a distinct new
convoy. This is native OS interruption/recovery qualification for that fixture.
Native GPU, human ordinary-input acceptance, original airborne pose restoration,
remote crew and full-release gates remain open.

Focused managed protocol failures and second-leg abort can be checked separately:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File tools/release/test_windows_interruption_check.ps1 `
  -TestDirectory <fresh-explicit-test-directory>
```

Current validation on 2026-10-14: the pinned `c8d8b59` Windows checkpoint passed
all four actual native headless interruption/recovery contexts, with Job
termination code 1, distinct restart exit zero, one crash event, receipts 1 to 2,
clean final markers, zero diagnostics/owned actors, removed private profiles and
unchanged protected real game data. Seven managed protocol/abort/path failure
cases passed. [Raw results and closure](../roadmap-validation/native-windows-recovery-command/summary.json)
retain the exact package and command hashes. The four contexts ran concurrently;
these timings do not qualify hardware performance. The current game's full CI
and main runtime integration remain unqualified alongside the gates above.
