# Package build record — build label `gateE-20260815-ef5450c`

Gate E asks for a package exported from one exact clean commit under a unique build
label, with the source commit, matrix record, Godot version, EXE size/hash, PE version,
embedded PCK inventory, signing state, smoke result, and hardware recorded. This file
records what was captured for that build and, just as importantly, what was **not**.

**This build does not satisfy Gate E.** Gate E also requires a representative-hardware
performance benchmark (1920×1080 High, 60 s warm-up, ten-minute representative route,
p95 ≤16.7 ms, p99 ≤33.3 ms, no post-warm-up frame >100 ms, peak working set ≤4 GiB) and
an uninterrupted no-shortcut human playtest. Neither was produced. See
"What this evidence does not establish".

## Source

| Field | Value |
| --- | --- |
| Source commit | `ef5450cabcaa713d0dfd79b526b67a6444267554` |
| Commit subject | `List all 81 test suites in README` |
| Commit date | 2026-08-15 16:12:03 +0100 |
| Working tree | clean before and after export (`git status --porcelain` empty) |
| Build label | `gateE-20260815-ef5450c` (carried in the artifact filename only — see "Build label caveat") |

## Toolchain

| Field | Value |
| --- | --- |
| Godot (host/exporter) | `4.7.1.stable.official.a13da4feb` |
| Export templates | `~/.local/share/godot/export_templates/4.7.1.stable`, `version.txt` = `4.7.1.stable` |
| Template consumed | `windows_release_x86_64.exe` (109,212,160 bytes) |
| Preset | `Windows Desktop` (`export_presets.cfg` `[preset.0]`), `binary_format/embed_pck=true`, `codesign/enable=false`, `script_export_mode=2`, `exclude_filter="tests/**,artifacts/**,tools/**"` |

### Editor/import gate

A fresh worktree has no `.godot/`, so `class_name` registrations do not exist and every
suite that subclasses a global class fails to parse. The documented gate
(`README.md`) was run first:

```
godot --headless --editor --path <project root> --quit
```

Exit `0`; 141 global classes registered; zero `ERROR:`/`SCRIPT ERROR`/`FATAL` lines.
This is a prerequisite for both the matrix and the export — not an optional step.

## Matrix record

Two full 81-suite matrix runs were taken. Both used
`tools/release/run_test_matrix.sh` with `--audio-driver Dummy`.

| Run ID | Result | Notes |
| --- | --- | --- |
| `gateE-pkg-20260815` | **FAIL** (79 PASS / 2 FAIL) | ran while a sibling agent saturated the host; both failures are load-induced timing flakes, see below |
| `gateE-pkg-20260815-rerun` | **PASS** (81/81) | authoritative record for this package |

Authoritative record — `artifacts/test-matrix/gateE-pkg-20260815-rerun/`
(`artifacts/` is gitignored; the hashes below are the durable anchor):

| Field | Value |
| --- | --- |
| `run-manifest.txt` SHA-256 | `844a9759092e51e3ae7e93a4270359d36774b374b4631b0790e911c63c5662b6` |
| `results.tsv` SHA-256 | `965e3ada1113d60699d2fe90cd678e5e8c1c14774c5d100447607d72c088bd07` |
| `result-file-hashes.csv` SHA-256 | `01e1892c5276ff868cac09b66f3705190c732cc9ee3a559c5949b4e9f82ec014` |
| Source manifest SHA-256 (before == after) | `0ac6a9828bc079a90c1e869b23ac329c043448c644e328b55c298bd69adcf889` over 471 files |
| Window (UTC) | 2026-08-15T16:19:52Z → 2026-08-15T16:24:46Z |
| Suites / assertions | 81 / 7,313 anchored `PASS:` |
| Sentinels | 79 `_OK` + 2 `_PASS`, exactly one terminal sentinel per suite |
| Diagnostics | 0 |

### Timing-flaky suites (finding, not fixed here)

Two suites fail intermittently under host CPU contention. Neither is a defect in the
shipped code; both are wall-clock races in the harness.

- `tests/station_interaction_flow_test.gd` — the assertion *"door interaction reaches a
  traversable physical opening"* (line 83) waits `await create_timer(0.15).timeout` for a
  door with `motion_duration = 0.08`. That is a 1.9× wall-clock margin. Observed **3 fails
  in 8 source runs and 1 fail in 6 packaged-probe runs**; every failure landed on a run
  whose duration was ≥5.0 s versus 2.6–4.3 s for passing runs. It fails on **both** sides,
  so it is not a source/package divergence.
- `tests/regeneration_reentry_safety_test.gd` — the assertion *"expired deadline stays
  unchanged and pending while the whole Main subtree is detached"* (line 396) failed once
  in the loaded matrix and passed 2/2 in isolation.

The host was shared with sibling agents running Godot suites in other worktrees
(load average peaked near 9). Suites that gate on real elapsed time rather than on a
stepped frame count will keep producing false Gate-blocking failures until the margins are
widened or the waits are made frame-deterministic. Fixing them was out of scope for this
task.

## Export

```
godot --headless \
  --path /root/keths-shipyard/.claude/worktrees/agent-a83d575471380d472 \
  --export-release "Windows Desktop" \
  /root/keths-shipyard/.claude/worktrees/agent-a83d575471380d472/builds/windows/MuddsShipyards-gateE-20260815-ef5450c.exe
```

Exit `0`. 102 pack steps, no `ERROR:`/`SCRIPT ERROR`/`FATAL` lines. The preset's own
`export_path` (`builds/windows/MuddsShipyards.exe`) was deliberately overridden on the
command line so the labelled artifact does not overwrite the unlabelled one.
`builds/` is gitignored; **no EXE or PCK bytes are committed.**

Despite `debug/export_console_wrapper=1` in the preset, the release export produced only
the single GUI executable — no `.console.exe` companion. Stdout from the native Windows
run is therefore only visible when the process can attach to an existing console.

## Artifact

| Field | Value |
| --- | --- |
| Path | `builds/windows/MuddsShipyards-gateE-20260815-ef5450c.exe` (gitignored) |
| Size | 153,713,144 bytes |
| SHA-256 | `2325f175e336c70bda247ccba3d4617867fad19c962772d09928e7f9fb929583` |
| Modified | 2026-08-15 17:15:11.403061792 +0100 |
| `file(1)` | PE32+ executable (GUI) x86-64 (stripped to external PDB), for MS Windows, 12 sections |

### PE header (parsed, not guessed)

Parsed directly from the on-disk bytes: `e_lfanew` → COFF header → optional header →
data directories → section table.

| Field | Value |
| --- | --- |
| Optional header magic | `0x20b` (PE32+) |
| Machine | `0x8664` (AMD64 / x86-64) |
| Subsystem | `2` (`IMAGE_SUBSYSTEM_WINDOWS_GUI`) |
| Sections | 12 — `.text .data .rdata .pdata .xdata .bss .edata .idata .tls .rsrc .reloc pck` |

### PE version resource (`VS_VERSION_INFO`, RT_VERSION)

Read from the `.rsrc` directory: `VS_FIXEDFILEINFO` signature `0xFEEF04BD` verified,
then the `StringFileInfo` block walked.

| Field | Value |
| --- | --- |
| `VS_FIXEDFILEINFO` FileVersion | `0.12.0.0` |
| `VS_FIXEDFILEINFO` ProductVersion | `0.12.0.0` |
| Lang/codepage | `040904b0` (US English, Unicode) |
| `FileVersion` | `0.12.0.0` |
| `ProductVersion` | `0.12.0.0` |
| `ProductName` | `Mudds Shipyards` |
| `FileDescription` | `Modern standalone Keth Shipyards fan remake prototype` |

### Signing state

**Unsigned.** The Certificate (Security) data directory — index 4 of the optional
header's data directories — is zero offset / zero size, so there is no embedded
Authenticode certificate. This matches `codesign/enable=false` in the preset.
External catalog signing was not assessed and cannot be assessed from the file alone.

### Build label caveat

The PE version metadata still reads `0.12.0.0`, identical to the previously recorded
v0.12 artifact (SHA-256 `014b6e44…`, 153,657,032 bytes) — but this is a **different
binary** (SHA-256 `2325f175…`, 153,713,144 bytes). The unique build label
`gateE-20260815-ef5450c` exists only in the filename and in this record; nothing inside
the executable distinguishes the two. Roadmap release discipline says "never replace two
different binaries under the same finalized/source-current label", and the version fields
in `export_presets.cfg` were deliberately not modified by this task. Bumping
`application/file_version` / `application/product_version` (or adding a build-label
string resource) is the open action needed to make the artifact self-identifying.

## Embedded PCK inventory

The PCK is embedded (`binary_format/embed_pck=true`); there is no separate `.pck`.
Located via the `GDPC` trailer at end-of-file, then parsed from the pack header.

Note: this is **pack format 4**, which moved the file directory from immediately after
the header to a `directory_offset` near the end of the pack. A format-2/3-shaped parser
reads `file_count = 0` here and silently reports an empty pack — worth knowing for any
future tooling.

| Field | Value |
| --- | --- |
| Start offset in EXE | 109,228,032 |
| Declared pack size | 44,485,100 bytes |
| Pack format version | 4 |
| Engine version in pack | 4.7.1 |
| Pack flags | `2` (`REL_FILEBASE` — entry offsets relative to `file_base`) |
| `file_base` | 112 |
| `directory_offset` | 44,452,656 |
| Entry count | 313 (313 unique paths, no duplicates) |
| Sum of entry sizes | 44,450,058 bytes within a 44,452,544-byte data region |
| Directory end | 44,485,096, i.e. 4 bytes of trailing alignment before the declared end |
| Sorted-path manifest SHA-256 | `dc0800edfdf7a553d98e8b398d493461ef7e9eaa7dd1f309debb9466fde34684` |

Scope checks:

- **Zero** `tests/`, `artifacts/`, or `tools/` paths — `exclude_filter` held.
- **Zero** raw `.gd`, `.tscn`, or `.tres` files. Scripts ship as `.gdc` binary tokens
  (`script_export_mode=2`) reached through `.remap` pointers.
- The recent station fixes are present: `scripts/world/station_route_registry.gdc`,
  `scripts/world/station_module_contract.gdc`, `scripts/world/shipyard_world.gdc`.

By extension (313 entries): 82 `.remap`, 67 `.import`, 48 `.gdc`, 33 `.scn`, 28 `.mesh`,
28 `.ctex`, 10 `.json`, 7 `.sample`, 5 `.res`, 2 `.png`, 1 `.cfg`, 1 `.binary`, 1 `.bin`.

By top-level directory: 103 `.godot/` (67 `imported/`, 34 `exported/`,
`global_script_class_cache.cfg`, `uid_cache.bin`), 88 `scripts/`, 79 `assets/`,
37 `scenes/`, 4 `docs/research/` (the runtime-loaded ledger and evidence JSON),
`project.binary`, and `default_bus_layout.tres.remap`.

## Package probes

```
PACKAGE_PATH=<the labelled exe> \
PACKAGE_PROBE_RUN_ID=gateE-20260815-ef5450c \
tools/release/run_package_probes.sh
```

Overall status **PASS** (4/4), zero diagnostics:

| Probe | Status | Exit | Sentinel | `PASS:` | Duration |
| --- | --- | --- | --- | --- | --- |
| `tests/station_surface_playability_test.gd` | PASS | 0 | `STATION_SURFACE_PLAYABILITY_TEST_OK` | 31 | 7,036 ms |
| `tests/station_interaction_flow_test.gd` | PASS | 0 | `STATION_INTERACTION_FLOW_TEST_OK` | 7 | 2,763 ms |
| `tests/station_triplanar_material_test.gd` | PASS | 0 | `STATION_TRIPLANAR_MATERIAL_TEST_OK` | 15 | 2,479 ms |
| `tests/central_berth_hero_test.gd` | PASS | 0 | `CENTRAL_BERTH_HERO_TEST_OK` | 56 | 2,482 ms |

### What the probes actually exercise

The probe runner invokes the **Linux** Godot 4.7.1 binary as
`godot --headless --main-pack <the .exe> --path <project root> --audio-driver Dummy
--script res://tests/<probe>.gd`. It does **not** execute the Windows executable.

Because `exclude_filter` keeps `tests/**` out of the pack (confirmed: zero `tests/` entries
among the 313), the probe driver scripts are **not** in the pack and are loaded from the
on-disk working tree, while the game code and resources they exercise come from the pack
(shipped as `.gdc`/`.scn` behind `.remap` entries, which take priority over the on-disk
`.gd`/`.tscn`). So the probes are on-disk test drivers exercising packed game content
under a Linux engine — real package-content parity evidence, but not Windows-binary
evidence.

## Smoke results

### Linux, embedded main pack

```
godot --headless --main-pack <the labelled exe> --audio-driver Dummy --quit-after 300
```

Exit `0`; 300 frames in 4.519 s real (2.764 s user); output contained only the engine
banner and the generic root-user warning. No renderer is initialised in this
configuration, so no GPU-side behaviour is covered.

### Native Windows — obtained, contrary to expectation

The Linux environment is WSL2 with `binfmt_misc` `WSLInterop` enabled, so the exported
executable was run on the **actual Windows host**. This is genuine native-Windows
startup evidence, which prior package records in this repo did not have.

Host: `Microsoft Windows [Version 10.0.26200.9168]`. The artifact was copied to
`C:\Windows\Temp` and its SHA-256 re-verified as `2325f175…` (byte-identical) before
running; the copy was deleted afterwards.

```
/init /mnt/c/Windows/Temp/keth-gateE/MuddsShipyards-gateE-20260815-ef5450c.exe --headless --quit-after 300
```

Result, reproduced across three runs (300, 300 and 900 frames), exit `0` every time:

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org
Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070 Ti

WARNING: 7 RIDs of type "Texture" were leaked.
   at: finalize (servers/rendering/rendering_device.cpp:8900)
```

Two things follow.

1. The executable launches natively, enumerates a real GPU, and brings up the **Vulkan
   Forward+** renderer — the first evidence in this project that the shipped Windows
   binary reaches a real rendering device at all.
2. **Finding: exactly 7 `Texture` RIDs leak at engine finalize.** The count is identical
   at 300 and 900 frames, so it is a fixed shutdown-time leak rather than per-frame
   growth. No Linux run can surface this: the headless Linux configuration never creates
   a rendering device, which is why the matrix and the package probes are all
   diagnostically clean. This is exactly the class of defect the package-parity rule
   exists to catch, and it is unowned as of this record.

The run was deliberately kept to `--headless` with a bounded `--quit-after`, so no game
window was opened on the host desktop and no interactive session was performed.

## Hardware

| Field | Value |
| --- | --- |
| CPU | Intel Core i9-14900 — 16 cores / 32 threads |
| RAM | 94 GiB usable, 24 GiB swap |
| OS (build/test env) | Ubuntu 24.04.4 LTS on WSL2, kernel `6.18.33.2-microsoft-standard-WSL2` |
| GPU (WSL2 side) | none — no `/dev/dri`, `lspci` unavailable; Godot ran with no rendering device |
| Windows host | Windows 11 build `10.0.26200.9168` |
| GPU (Windows host) | NVIDIA GeForce RTX 5070 Ti, Vulkan 1.4.341, Forward+ |
| Audio device | not captured — every Linux run used `--audio-driver Dummy`, and the native Windows runs were headless |

## Fields not captured, and why

| Gate E field | Status |
| --- | --- |
| Performance benchmark (p95/p99/frame spikes/working set) | **Not produced.** Requires a windowed 1920×1080 High session with a 60 s warm-up and a ten-minute representative route on representative hardware. Not attempted: it needs an interactive GUI session on the host desktop and a frame-time instrument neither the matrix nor the probe runner provides. |
| Uninterrupted human playtest | **Not produced.** Requires a human. |
| GPU driver version | **Not captured.** The Vulkan banner reports API version 1.4.341 and the adapter name, not the NVIDIA driver package version. |
| Audio device / audible mix | **Not captured.** Dummy audio driver throughout; headless native runs. |
| External catalog signing | **Not assessable** from the file. The embedded state is definitively unsigned (zero Security Directory). |
| Installer / clean-install / upgrade / rollback | Out of scope for this build. |

## What this evidence does and does not establish

Establishes:

- The Windows x86-64 artifact exports cleanly (exit `0`) from clean commit `ef5450c` with
  a green 81/81, 7,313-assertion, zero-diagnostic matrix behind it.
- Its PE identity, section layout, version resource and unsigned state are as configured.
- Its embedded format-4 PCK is fully accounted for at 313 entries, with correct scope
  exclusions and no raw source, and includes the recent station route/module fixes.
- The packed content passes all four external probes under the Linux engine.
- The binary starts natively on Windows 11, reaches Vulkan Forward+ on a real GPU, and
  exits cleanly from a bounded headless run — while leaking 7 texture RIDs at shutdown.

Does **not** establish:

- **Gate E is not satisfied.** No performance benchmark and no human playtest exist.
- No interactive native-Windows play, input, camera, HUD or audio behaviour was
  exercised; `--headless --quit-after` proves startup and clean shutdown, nothing about
  playability.
- No audibility evidence of any kind.
- No claim about signing beyond "no embedded Authenticode certificate".
- The probe results are evidence about **pack contents under the Linux engine**, not
  about the Windows executable's own behaviour.

## Reproducing the inspection

Nothing in `artifacts/` or `builds/` is committed. To regenerate:

1. `godot --headless --editor --path . --quit`
2. `tools/release/run_test_matrix.sh`
3. `godot --headless --path . --export-release "Windows Desktop" builds/windows/<labelled>.exe`
4. `PACKAGE_PATH=builds/windows/<labelled>.exe tools/release/run_package_probes.sh`

The PE and PCK figures above were produced by parsing the file directly (PE headers,
`RT_VERSION` resource, data directory 4, and the `GDPC` trailer plus format-4 directory);
no value in this record is inferred from `file(1)` output alone.
