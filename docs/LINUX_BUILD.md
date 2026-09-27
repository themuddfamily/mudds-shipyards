# Linux x86_64 build

Linux x86_64 is a supported desktop export target alongside Windows. This page
covers how a Linux candidate is exported, packaged and startup-checked, and
what has been validated so far.

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

| Gate | Status |
| --- | --- |
| Linux export from a clean commit | NOT_RUN (run in the testing phase with the commands above) |
| Headless isolated startup check (`STARTUP_MENU_READY_OK`) | NOT_RUN |
| Clean install on a real Linux desktop (rendered, native GPU, audio) | NOT_RUN |
| Signing | Not applicable yet. The artifacts are unsigned, and the result JSON says so. |

A headless pass under WSL establishes packaging and boot behaviour only. It
does not qualify native GPU rendering, audio or input on target Linux hardware.
Keep that gate open until someone runs it on real hardware.

## Tests

- `python3 tools/release/test_export_linux_candidate.py`: argument handling,
  dry-run planning, the preset contract, and the startup-check pass/fail rules
  against stub binaries. It never runs Godot.
- `godot --headless --audio-driver Dummy --path . --script res://tests/linux_build_identity_test.gd`
  must print `LINUX_BUILD_IDENTITY_TEST_OK`.
