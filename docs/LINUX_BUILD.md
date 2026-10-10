# Linux x86_64 build

Linux x86_64 is a supported desktop export target alongside Windows. This page
covers how a Linux candidate is exported, packaged and startup-checked, and
what has been validated so far.

## Latest published checkpoint: `b3de8e299` — 2026-10-10

The [executable](../builds/linux/MuddsShipyards-b3de8e2.x86_64),
[archive](../builds/linux/MuddsShipyards-b3de8e2-linux-x86_64.tar.gz) and
[notes](../builds/linux/MuddsShipyards-b3de8e2-linux-notes.txt) include the
Cinder Loadmaster manifest chair, readable Aft Operations signage and boarding
cards showing role, rated speed and maximum hull.

Fresh clean-source export and direct/extracted-archive startup exit 0, with
reaped actors, one parsed mouse-free menu-ready result per startup and zero
diagnostics. This Linux embedded package passes HUD205, live GameFlow16 and
four standard probes223. All 1,492 PCK4 entries, five safe archive members,
11,759 tracked source files and 577 cache files pass guards. Publication uses
exclusive writes and verifies file hashes and archive parity. Executable mode
is 0755; archive and notes are 0644.

Executable SHA256:
`af2cf2d7373c98df20211dd703b2a05d483c522369d51c2060702f111ba27ad4`.
Archive SHA256:
`9869f2d783a936d69d7440c901d61cc704ebb92713dd47153b4e727c25a3743f`.

These checks use Linux/WSL headless execution and Dummy audio. Native GPU,
physical devices, human review, complete regression and this archive's desktop
helper execution remain NOT_RUN. Windows package and installer qualification
are separate; this publication does not close a roadmap phase or completion task.

Known current-source issue: the subsequent controlled twelve-cycle soak on
`b3de8e299` exits 1 with seven failure diagnostics (60/67 executed checks;
intended 80-check coverage is incomplete). Cinder cargo boarding fails in cycles
3 and 12, and interceptor launch fails in cycle 4, with downstream return,
activity and re-entry coverage failures. The separate four-cycle lifecycle
passes 204 checks. Causes remain unproven; these findings are retained while
interaction/admission and craft handoff are investigated. The original published
notes retain their build-time acceptance scope.

## Earlier published checkpoint: `999fee71e` — 2026-10-10

The matching [executable](../builds/linux/MuddsShipyards-999fee7.x86_64),
[archive](../builds/linux/MuddsShipyards-999fee7-linux-x86_64.tar.gz) and
[notes](../builds/linux/MuddsShipyards-999fee7-linux-notes.txt) include six
matte pale linen Habitat bunk pillows and remove the existing linen clearcoat.
Geometry, collision, lights and material allocation are unchanged.
The executable is 142,003,008 bytes, mode 0755, SHA256
`f92595802e3eefba6eea984bdcb4cb18afeddae234e30c45b00152b17fd74fc1`.
The archive is 93,185,634 bytes, SHA256
`f514121c56c6bc47537b73a0a554c8f03773a1562086e2583b54858befd0b1ac`.

Fresh export and direct/extracted-archive startup finish with actual exits 0
and reaped actors. Each startup emits exactly one parsed menu-ready record,
mouse-free loading and zero diagnostics/warnings. The exact Linux PCK passes
Habitat415 and the four standard probes89/40/25/69, each with exit 0, one
success marker and zero diagnostics. All 1,492 embedded PCK4 entries, five safe
archive members, executable/helper/desktop/icon bytes and modes, 11,756 tracked
source files and 577 recursive cache files are verified. Source/cache and all
package/extracted bytes remain stable through qualification. Independent review,
exclusive publication, root readback and independent final readback pass.

This build's desktop launch and install-helper execution, native GPU/device/audio,
human review, peer/endurance, full regression and final release remain open.
Matching Windows startup and package checks have separate qualification. The
latest installer remains `dcd63d72b`; its acceptance does not qualify this source.

## Earlier published checkpoint: `dcd63d72b` — 2026-10-10

The matching [executable](../builds/linux/MuddsShipyards-dcd63d7.x86_64),
[archive](../builds/linux/MuddsShipyards-dcd63d7-linux-x86_64.tar.gz) and
[notes](../builds/linux/MuddsShipyards-dcd63d7-linux-notes.txt) include supported
Halyard crew berths and Ember runtime improvements. Executable mode is 0755;
SHA256 is `c2fb1a78adef26435a7512dfe5d9331d071f1fce9b31e4a04cc8ae985781873e`.
Archive SHA256 is
`7567ca27fa82327f7832173fee63f223bb3abdb06bb7b370c2213c699e57771a`.

Direct and extracted-archive startup exit 0 with one parsed menu-ready record,
mouse-free loading and zero diagnostics. Four existing probes against this
ELF's embedded PCK pass 89/40/25/69 assertions with actual exits 0, zero
diagnostics and original limits. The archive has one directory and four files;
its executable matches the standalone binary. Source, cache and artifact
readbacks are unchanged. Windows package gameplay checks have separate scope.

The shipped desktop helper passes install, reinstall, `--uninstall` and repeated
uninstall in a private XDG directory, with an extraction path containing spaces.
All four actions exit 0 and reap; resolved executable/icon paths and modes match
the archive, repeated installation is byte-identical, and the seeded Godot save
remains unchanged. Root independently verifies the archive/member hashes and
owned temporary-tree cleanup. No GUI or desktop launcher was run.

Native graphical Linux/GPU, physical controls, audio/human review, peer/endurance,
complete current-source regression and final release remain open. These checks
qualify a checkpoint; the 34 completion tasks remain open.

## Earlier published checkpoint: `9ef48fdc2`

The [binary](../builds/linux/MuddsShipyards-9ef48fd.x86_64),
[checkpoint archive](../builds/linux/MuddsShipyards-9ef48fd-linux-checkpoint.tar.gz)
and [notes](../builds/linux/MuddsShipyards-9ef48fd-linux-notes.txt) include ordinary
Jovian engineer controls and durable mining recovery. The standalone binary has
execute mode 0755; its SHA256 is
`842a9c00d7854f0f7e64a2b18cc41c6a7d40095a7ace54595f61d6617a49d896`.
The checkpoint archive SHA256 is
`10cfc0326390427c49b82339536144e0273bf42dbbac551965493541225a4dac`.

Fifteen embedded-package suites pass 655 assertions plus the reward-adapter check.
Direct embedded-game pilot, cabin, rest, Halyard-passenger, mining-pilot and
beacon-pilot kill/restart checks pass, with one acknowledgement/payment and crash,
unchanged durable boundaries and removed private profiles. Binary and fresh
unpacked archive startup each exit 0 with exactly one parsed menu-ready record,
mouse free and no diagnostics. Root and independent review verify all 113
retained hashes, source/import parity, archive contents and process cleanup.

The six-member checkpoint archive preserves the original export bundle and adds
immutable initial notes. Published export metadata describes the original
five-member export archive and its build-time startup status; completed checks
are recorded separately in the notes. Linux/WSL headless and private X11 input
checks leave clean desktop/GPU, physical-controller/audio/human, Linux installation,
full/endurance/signing and final-release acceptance open. This source excludes
the newer station-defence recovery delivery `189124deb`.

## What ships

`tools/release/export_linux_candidate.sh` writes three files directly into
`builds/linux/` (which is git-ignored and excluded from the export):

| File | Contents |
| --- | --- |
| `MuddsShipyards-<short>.x86_64` | Self-contained ELF binary. The PCK is embedded (`binary_format/embed_pck=true`), so this one file is the game. |
| `MuddsShipyards-<short>-linux-x86_64.tar.gz` | Top-level folder `MuddsShipyards-<short>/` holding the binary, `mudds-shipyards.desktop`, `mudds-shipyards.png` (the Keth icon) and `install-desktop-entry.sh`. The archive is built reproducibly: sorted names, owner and group 0, mtime set to the commit time, gzip `-n`. |
| `MuddsShipyards-<short>.x86_64.export-result.json` | `schema_version` 1: source commit, Godot version, and path, size and SHA-256 for the binary and the tarball. Also `signing: "unsigned"` and `startup_check: "NOT_RUN"`. |

`<short>` is the first seven characters of the exact clean `HEAD` commit. Keep
that filename: the pause-menu footer reads the revision from it
(`GameHUD.BUILD_FILENAME_PATTERN` accepts both `.exe` and `.x86_64`). If you
rename the binary, the footer honestly says `UNSTAMPED BUILD`.

### For players

```sh
tar -xzf MuddsShipyards-<short>-linux-x86_64.tar.gz
cd MuddsShipyards-<short>
./MuddsShipyards-<short>.x86_64          # run directly
./install-desktop-entry.sh               # optional: add to the applications menu
./install-desktop-entry.sh --uninstall   # remove the menu entry again
```

The installer only writes
`${XDG_DATA_HOME:-~/.local/share}/applications/mudds-shipyards.desktop`. It
points `Exec`, `Path` and `Icon` at absolute paths inside the unpacked folder,
so if you move the folder, run it again. It refuses folder paths that contain
characters other than letters, digits, spaces and `/._+,@-`. It never touches
saves or settings. The shipped `.desktop` file can
also be launched in place: it uses `%k` to find the binary next to itself.
Some desktops ask you to mark it as trusted first.

User data lives in the standard Godot location, which follows `XDG_DATA_HOME`:
`${XDG_DATA_HOME:-~/.local/share}/godot/app_userdata/Mudds Shipyards/`. That
folder holds `settings.cfg`, saves, `diagnostics/` (session log and support
exports) and screenshots. It is the Linux counterpart of
`%APPDATA%\Godot\app_userdata\Mudds Shipyards\` on Windows.

## Exporting a candidate (main thread / release engineer)

Prerequisites: Godot 4.7.1 on `PATH` (or `GODOT_BIN`), and the Linux templates
`linux_release.x86_64` and `linux_debug.x86_64` under
`~/.local/share/godot/export_templates/4.7.1.stable/` (or set
`GODOT_EXPORT_TEMPLATES_DIR` to the directory that contains `4.7.1.stable/`).

The export must run from a **clean** worktree of the commit you are shipping.
The main checkout has untracked `.agents/` and `skills-lock.json`, so use a
separate worktree. Import first so any `.gd.uid` sidecars Godot generates are
committed before the export. Otherwise the export aborts with "worktree changed
during export".

```sh
git -C /root/mudds-shipyards worktree add --detach /root/.cache/mudds-shipyards/linux-<short> <commit>
godot --headless --audio-driver Dummy --path /root/.cache/mudds-shipyards/linux-<short> --import
git -C /root/.cache/mudds-shipyards/linux-<short> status --porcelain   # must print nothing

# Optional: print the planned outputs as JSON without writing anything.
/root/.cache/mudds-shipyards/linux-<short>/tools/release/export_linux_candidate.sh --dry-run

/root/.cache/mudds-shipyards/linux-<short>/tools/release/export_linux_candidate.sh
```

The script:

- refuses a dirty tree, and re-checks after the export that `HEAD` and a clean
  status still hold;
- runs `godot --headless --audio-driver Dummy --export-release "Linux"` under a
  wall-clock `timeout` (`EXPORT_TIMEOUT_SECONDS`, default 900);
- uses a private `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and
  `XDG_RUNTIME_DIR`, with `DISPLAY`/`WAYLAND_DISPLAY` unset. Only the export
  templates are linked in. Your editor settings, caches and saves are never
  used;
- checks that the output is a nonempty ELF file;
- stages every artifact in a temporary directory under `builds/linux/` and
  publishes by hard link, so it never overwrites an existing output. If it
  fails, it removes anything it already published.

On success it prints `path=`, `bytes=`, `sha256=`, `tarball=` and `result=`
lines.

## Silent startup check

```sh
tools/release/run_linux_startup_check.sh builds/linux/MuddsShipyards-<short>.x86_64
tools/release/run_linux_startup_check.sh builds/linux/MuddsShipyards-<short>-linux-x86_64.tar.gz
```

The check runs the exported game as
`<binary> --headless --audio-driver Dummy --startup-check`. It uses `env -i`
with a private `HOME`, all `XDG_*` directories under a fresh
`mktemp -d ${TMPDIR:-/tmp}/mudds-linux-startup-check.XXXXXX`, and stdin from
`/dev/null`. No audio device, display or user profile is touched. A check passes
only when **both** of these hold:

- the process exits 0, and
- the log contains `STARTUP_MENU_READY_OK` (and no `STARTUP_MENU_READY_FAILED`).

The game prints that sentinel from `StartupLoader._check_presented_menu` only
after the loading overlay is dismissed and the real `BEGIN SHIFT` button is
visible and enabled. A fixed `--quit-after` frame count does not prove the menu
is ready, and export templates may ignore an external `--script`, so neither is
used.

If you pass the tarball, the check unpacks it into the private profile, confirms
the launcher, icon and installer script are present, and checks the packaged
binary. That exercises the archive a player would download.

The check writes `<input>.startup-check.json` (`schema_version` 1, status,
exit code, sentinel count, binary SHA-256, wall time, reasons) and
`<input>.startup-check.log` beside the input. Set `STARTUP_CHECK_RESULT_DIR` to
write them elsewhere. It never overwrites an earlier result.
`STARTUP_CHECK_TIMEOUT_SECONDS` (default 300) is the independent wall-clock
abort. `--keep-profile` keeps the private profile for inspection, and
`--dry-run` prints the exact plan.

## Exported-game interruption check

Run the existing recovery probe with `--native-export` so the exported ELF
starts its embedded game directly. Export templates reject `--path` overrides;
the default editor/PCK probe mode cannot qualify this native executable.

```sh
PACKAGE_PATH=/absolute/path/MuddsShipyards-<short>.x86_64 \
PACKAGE_PROBE_RECOVERY_CONTEXT=pilot \
PACKAGE_PROBE_RESULTS_ROOT=/absolute/path/linux-recovery-results \
PACKAGE_PROBE_RUN_ID=pilot \
tools/release/run_package_probes.sh --in-world-interruption --native-export
```

Repeat separately with `cabin`, `rest` and `crew`, using a fresh result ID for
each run. Keep the original `.x86_64.export-result.json` beside the binary:
the check verifies its executable hash and records the compiled source commit
separately from the probe driver's commit. It launches no external pack or
script, uses headless/Dummy audio and private user directories, kills and reaps
its exact native game process, then restarts against that same private save.
The existing durable-boundary, one-payment, crash-event, clean-marker and
source/cache/artifact-parity checks still apply. This mode requires a Linux
x86_64 ELF and cannot be combined with `--source` or the standard script probes.

## Runtime platform audit

The runtime was read for Windows-only assumptions:

- **Build footer**: the revision stamp regex only matched `.exe`. It now also
  matches `MuddsShipyards-<7 hex>.x86_64`. Windows names are unchanged
  (`tests/linux_build_identity_test.gd`).
- **User data, saves, settings, diagnostics, crash recovery, support export,
  screenshots**: all use `user://` paths, and `ProjectSettings.globalize_path`
  where an absolute path is needed. There are no `%APPDATA%` literals, drive
  letters or backslash joins. The atomic publish paths (`UserDataStore`, the
  session diagnostic sink, `RuntimeSettings`) clear or move the target before
  they rename over it. None of them relies on a rename failing because the
  target exists. POSIX `rename(2)` replaces the target where Windows refuses,
  which is the more permissive case, so the Windows ordering works unchanged on
  Linux.
- **OS checks**: `OS.get_name()` appears only in support text
  (`--support-info`) and frame-capture metadata. It does not branch
  behaviour.
- **Renderer**: `project.godot` pins `forward_plus` with no per-platform driver
  override, so Linux uses Vulkan. A GPU without Vulkan fails at engine startup
  and needs `--rendering-driver opengl3`, which is the same fallback as on
  Windows.

## Validation status

The [Linux archive](../builds/linux/MuddsShipyards-f0e2c59-linux-x86_64.tar.gz),
[binary](../builds/linux/MuddsShipyards-f0e2c59.x86_64) and
[player notes](../builds/linux/MuddsShipyards-f0e2c59-linux-notes.txt) are published
in `builds/linux/`. Original export metadata retains build-time
`startup_check: NOT_RUN`; the executed qualification below is separate.

| Gate | Status |
| --- | --- |
| Linux export from a clean commit | PASS on published `f0e2c590a` binary/tarball |
| Headless isolated startup check (`STARTUP_MENU_READY_OK`) | PASS on published `f0e2c590a` binary and extracted tarball; exit 0, one ready record each |
| Exported-game pilot/cabin/rest/crew interruption | PASS on published `f0e2c590a`; all four native owned SIGKILL(-9)/restart(0) contracts pass with exact boundaries, receipts1→2 once, crash1 and clean markers. Eight known root warnings retained. Earlier `f139257f6` results remain historical |
| Isolated desktop-entry installer consumer | PASS only on earlier `f139257f6` archive; NOT_RUN on `f0e2c590a`: directory with spaces, exact Exec/Path/Icon, silent startup, unsafe-path refusal and uninstall preserving saved data. Stock launcher parsing used an inert stub; rendered launch remains unqualified |
| Clean install on a real Linux desktop (rendered, native GPU, audio) | NOT_RUN |
| Signing | Not applicable yet. The artifacts are unsigned, and the result JSON says so. |

Canonical artifact/hash/ELF/PCK/tar/source-cache and raw recovery records are independently reviewed. Initial silent import used inherited HOME/XDG; export and runtime checks used private profiles. Earlier custom-basename artifacts are retained as UNQUALIFIED; canonical export and fresh checks establish this package. Newer mining `4311c94e4` is not qualified by these Linux results.

A headless pass under WSL establishes packaging, boot and the stated recovery behavior only. It
does not qualify native GPU rendering, audio or input on target Linux hardware.
Keep that gate open until someone runs it on real hardware.

## Tests

- `python3 tools/release/test_export_linux_candidate.py`: argument handling,
  dry-run planning, the preset contract, and the startup-check pass/fail rules
  against stub binaries. It never runs Godot.
- `godot --headless --audio-driver Dummy --path . --script res://tests/linux_build_identity_test.gd`
  must print `LINUX_BUILD_IDENTITY_TEST_OK`.
