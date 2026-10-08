# Windows installer (per-user, unsigned)

`tools/release/build_windows_installer.sh` turns an exported checkpoint
executable into a per-user NSIS installer, and
`tools/release/verify_windows_installer.ps1` exercises that installer natively
on Windows. Both are Phase 9 packaging capabilities. Installers are unsigned
by default; optional signing is described in
[Windows code signing](WINDOWS_CODE_SIGNING.md). A green verification does not
grant distribution rights or replace the human gates that remain open.

## Building

Keep checkpoint executables, installers, ZIPs and notes in this repository's
`builds/windows/`. The older Downloads location mentioned in the historical
verification result below is no longer a publication destination.

```sh
tools/release/build_windows_installer.sh builds/windows/MuddsShipyards-<sha7>.exe
```

Requirements: `makensis` (NSIS 3; `apt-get install nsis` on the WSL side), a
source executable named by `export_windows_candidate.sh`, and a repository
whose history contains the seven-character revision in that name (the full
commit is resolved from it; `MUDDS_INSTALLER_FULL_COMMIT` overrides the lookup
for installers built outside the source worktree). The product version comes
from `project.godot` `config/version`. The build does not need a clean
worktree because it only consumes an already exported artifact.

Outputs beside the source executable (or at the optional second argument):

- `MuddsShipyards-<sha7>-setup.exe`: solid-LZMA NSIS installer (83 MB for the
  173 MB `8e84c94` executable, 71 s to compress).
- `…-setup.exe.sha256` and `…-setup.exe.installer-result.json` (schema 1:
  source and installer SHA-256/bytes, build label `<version>+<sha7>`, source
  commit, `signing: unsigned`, `native_verification: NOT_RUN`).
- `…-setup.exe.makensis.log`.

`makensis` runs with `-WX`, so its insecure-filename warning is fatal: a bare
`setup.exe` output name is refused because Windows loads compatibility shims
into processes with that name.

## What the installer does

- Installs for the current user only (`RequestExecutionLevel user`, default
  `%LOCALAPPDATA%\Programs\Mudds Shipyards`); no elevation and no `HKLM`.
- Writes `MuddsShipyards.exe`, `source-commit.txt` (product, version, build
  label, full source commit, `signing=unsigned`) and `uninstall.exe`.
- Start Menu folder with launch and uninstall shortcuts.
- `HKCU\…\Uninstall\MuddsShipyards` (DisplayName, DisplayVersion =
  build label, InstallLocation, DisplayIcon, UninstallString,
  QuietUninstallString with `/S`, NoModify, NoRepair, EstimatedSize) and
  `HKCU\Software\Mudds Shipyards` (InstallLocation, SourceCommit, BuildLabel,
  and `UpgradedFrom` when a previous install was replaced).
- Silent install: `MuddsShipyards-<sha7>-setup.exe /S /D=C:\target` (`/D=` must
  be last and unquoted, as NSIS requires). Silent uninstall: `uninstall.exe /S`.
- Upgrading or rolling back installs the requested build over the old location.
  The payload is extracted to an owned sibling `MuddsShipyards.exe.pending`,
  then moved into place with `MoveFileExW` replacement. Replacement retries
  transient file contention for up to 9.75 seconds. A permanent replacement
  failure exits nonzero and preserves the previous executable and provenance;
  an existing pending file is refused without changing it. Registry metadata
  advances only after successful replacement. Player settings and saves live under
  `%APPDATA%\Godot\app_userdata\Mudds Shipyards` and are never written, read
  or removed by the installer or the uninstaller. The uninstaller deletes only
  the three files it wrote, the shortcuts and the two registry keys; a
  directory holding anything else is left in place rather than removed
  recursively.

## Native verification

```sh
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
  -File tools/release/verify_windows_installer.ps1 \
  -Installer C:\path\MuddsShipyards-<sha7>-setup.exe \
  -ExpectedExeSha256 <sha256 of the exported exe> \
  -ExpectedCommit <full commit> \
  -ProbeRoot C:\Users\<you>\AppData\Local\Temp\mudds-installer-probe-<sha7> \
  -ResultPath C:\...\installer-verification.json
```

The verifier refuses to run if the real per-user install (either HKCU key,
the Start Menu folder, the default installation directory, its own install
directory or an existing probe profile) already exists, installs
into `<ProbeRoot>\install`, and seeds an owned `APPDATA`/`LOCALAPPDATA`
profile under `<ProbeRoot>\profile` with a marker file in the user-data folder.
The marker's contents must remain byte-identical through every transition and
uninstall. Probe roots must be absolute; use a fresh private directory for each
run. Steps are recorded in the JSON result and fatal on first failure:

1. `silent_install`: `/S /D=` exits 0.
2. `installed_files`: the installed executable's SHA-256 equals the exported
   one; `source-commit.txt` names the expected commit and `signing=unsigned`.
3. `registry_and_shortcuts`: both keys carry the expected values, no
   `UpgradedFrom` after a clean install, both shortcuts exist and the launch
   shortcut targets the installed executable.
4. `installed_startup_check`: the installed executable runs
   `--headless --audio-driver Dummy --startup-check` under the owned profile
   and must exit 0 with `STARTUP_MENU_READY_OK`.
5. `silent_upgrade_over_existing`: installing the same build again exits 0,
   leaves the executable byte-identical, records `UpgradedFrom`, and keeps
   the seeded user data. Hash, provenance, registry and shortcuts are checked
   again, then `upgraded_startup_check` requires exit 0 and the sentinel.
6. `silent_uninstall`: `uninstall.exe /S`; the install directory, Start Menu
   folder and both registry keys must be gone within the wait window, and the
   seeded user data must survive.

For a real old-to-new upgrade and rollback, add all three previous-build
arguments to the invocation above:

```text
-PreviousInstaller C:\path\MuddsShipyards-<old-sha7>-setup.exe
-PreviousExpectedExeSha256 <sha256 of the previous exported exe>
-PreviousExpectedCommit <full previous commit>
```

This mode requires distinct full commits and executable hashes, and distinct
installer bytes. It first installs the previous build and runs the same clean
install checks. `locked_upgrade_preserves_previous` then holds an exclusive
read handle on the previous executable while running the new installer with a
two-minute process timeout. It requires exit 2, the previous executable hash,
byte-identical provenance, unchanged values in both registry keys, retained
user data, and removal of the pending payload. The lock is released in a
`finally` block before verification or failure cleanup. This regression runs
only in cross-build mode and requires installers built with staged replacement.
`silent_upgrade_over_existing` then installs the new build and
requires the new executable hash, new file/registry provenance and
`UpgradedFrom=<previous commit>`. After successful new-build startup,
`silent_rollback_to_previous` reinstalls the previous installer over the same
location and requires the previous executable hash and provenance, with
`UpgradedFrom=<new commit>`. `rolled_back_startup_check` then requires the old
binary to exit 0 with the sentinel before the final uninstall. Each startup
uses a fresh log to prevent a stale sentinel from passing a failed run.

The schema 1 JSON adds `mode`, previous-build input/hash fields, and `cleanup`.
A failure preserves its original step diagnostic and attempts guarded cleanup
only after the probe passed preconditions and started its own installation.
Cleanup refuses keys or shortcuts pointing at another install, removes only
the three known installer files and any probe-owned pending payload, owned
shortcuts and registry keys, and never
recursively removes installation or Start Menu directories. Logs and the seeded
probe profile remain for inspection. `cleanup.status=FAIL` means cleanup also
failed; inspect its detail before rerunning in a fresh probe root. A precondition
failure leaves existing installations untouched and reports `NOT_RUN` cleanup.

### Result for checkpoint `8e84c94` (2026-09-15)

All seven steps passed natively on the development machine
(`/root/.cache/mudds-shipyards/installer-8e84c94/installer-verification.json`):
installer SHA-256 `18b8976b2db3c7f04501540e5a3588746cad2dafa73e052d798775882278334a`,
installed executable SHA-256 matched the export
(`61c5ad06…602d`), DisplayVersion `0.12.0+8e84c94`, EstimatedSize 169,354 KB,
installed startup check exit 0 with the sentinel in 13.4 s, upgrade recorded
`UpgradedFrom`, uninstall removed directory, shortcuts and keys and preserved
the seeded user data. The installer and its `.sha256` sit beside the
checkpoint executable in `/mnt/c/Users/themu/Downloads/`.

### Native cross-build result — 2026-10-08

The fixed installer workflow passed 11 native steps with checkpoint `fc20b84` as the previous executable and `28fc594` as the new executable: clean install, exact hash/provenance/registry checks, silent startup, a deliberately locked-target failure that preserves the old binary and metadata, successful upgrade/startup, rollback/startup, and uninstall preserving seeded user data. All three startups used `--headless --audio-driver Dummy --startup-check`, exited 0 and printed `STARTUP_MENU_READY_OK`. The original overwrite failure and the passing result are retained under `/root/.cache/mudds-shipyards/roadmap-validation/` (`installer-fc20-6affa-native.json` and `installer-atomic-fc20-28fc-native.json`).

Both installers were compiled using atomic-replacement packaging code `ce2dfa065`; native verification used `3cc442fda`. This proves rollback with a rebuilt previous installer, not every legacy installer. Artifacts remain in `builds/windows/`:

- `MuddsShipyards-28fc594-setup.exe`: SHA-256 `5a16d5d4327cfd4eabc12e1ddf5d5ffb42d40a8716cdb14cc4e74e1e47136568`.
- `MuddsShipyards-fc20b84-atomic-setup.exe`: SHA-256 `7f8cf93aa393fde5bc8b3e02a1b5c16fb0ac289c184b4492ed1bd0252495644b`.

This is silent native packaging acceptance on the development machine. Interactive installation, gameplay, clean-machine/hardware qualification and trusted signing remain open.

## Still open

- Trusted signing qualification: these checkpoint installer probes are unsigned
  and do not establish Authenticode trust or SmartScreen reputation. Optional
  signing tooling exists; see [Windows code signing](WINDOWS_CODE_SIGNING.md).
  Trusted certificate credentials and qualification remain external gates.
- Cross-build upgrade and rollback are now supported by this verifier; a passing
  result requires actually running it against distinct old/new artifacts. The
  historical result above exercised only same-build reinstallation.
- Corrupt user-data recovery through the installed binary, a second desktop
  platform, native GPU behavior and a human walk through the interactive
  (non-silent) pages are not covered by this silent headless verifier.
  The compile test in
  `tools/release/test_build_windows_installer.py` pins the script contract
  (per-user, no `HKLM`, no recursive or user-data deletion, provenance
  recorded) and builds a stub installer when `makensis` is present.
