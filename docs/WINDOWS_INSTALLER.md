# Windows installer (per-user, unsigned)

`tools/release/build_windows_installer.sh` turns an exported checkpoint
executable into a per-user NSIS installer, and
`tools/release/verify_windows_installer.ps1` exercises that installer natively
on Windows. Both are Phase 9 packaging capabilities; neither signs anything, and
a green verification does not grant distribution rights or replace the human
gates that remain open.

## Building

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
- Upgrading is installing the new build over the old location; files are
  overwritten and the registry rewritten. Player settings and saves live under
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
the Start Menu folder, or its own install directory) already exists, installs
into `<ProbeRoot>\install`, and seeds an owned `APPDATA`/`LOCALAPPDATA`
profile under `<ProbeRoot>\profile` with a marker file in the user-data folder.
Steps, each recorded in the JSON result and fatal on first failure:

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
   the seeded user data.
6. `silent_uninstall`: `uninstall.exe /S`; the install directory, Start Menu
   folder and both registry keys must be gone within the wait window, and the
   seeded user data must survive.

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

## Still open

- Signing: the installer and the executable are unsigned; SmartScreen will
  warn. Credentials stay outside the repository and no signing step exists.
- Upgrade across different builds (old → new executable), rollback, corrupt
  user-data recovery through the installed binary, a second desktop platform,
  and a human walk through the interactive (non-silent) pages are not covered
  by the verifier. The compile test in
  `tools/release/test_build_windows_installer.py` pins the script contract
  (per-user, no `HKLM`, no recursive or user-data deletion, provenance
  recorded) and builds a stub installer when `makensis` is present.
