# Bulwark folder retirement and remaining work

Assessed 2026-10-13 against main `5266aa53b56cee1af236b6b5f6e76a860ea2581b`.

## Decision

The original walkable cabin, physical gunner route, and combined solo gunner/recovery features are implemented and integrated into main. Do not replay the old branches or treat their intermediate failing logs as current bugs. No new runtime fix was justified by this audit. This handoff closes the dependency on the old working folders; it does **not** claim current release, native hardware, or human-play acceptance.

## Where the implementation went

| Original work | Original source | Integrated main commit | Verification |
| --- | --- | --- | --- |
| Walkable cabin | `9f5c94d4d8993603be772639e47c8bc00f2c0366` | `636fb9cd7df0c1fd627fa60f9abbe21738ea4fcb` | Identical stable patch ID `2068f7ea4b11b7e9271180fb729cfe1b2f3b5084`; cabin scene still identical at assessed main. |
| Supported aisle-to-gunner route and geometry consumers | `6c57c56d842b8886e373be94e76531806ef48226`, `d0025027a0f260aaf69ce562e717bdc6aaba56cb` | `5d6615c57b0803e58b30d35d26bd202e74577a0d` | Integrated ship-script blob matches original `aa0afb4583f689af500a2276be3916dd2484f3fb`; heavy/component/dorsal tests remain identical at assessed main. |
| Combined solo gunner and recovery, including final engine-idle correction | `2b7c2cd337790bb4d05ddc2e9fe6a12a3cb519a1` | `5d6615c57b0803e58b30d35d26bd202e74577a0d`, then `b6b7f3052ca11360b04a50ee516c324616331901` | All 18 changed file blobs from original range `94da8f0c0..2b7c2cd33` exactly match the latter main ancestor. |

Cabin census reconciliation landed in `d10ae7ab4fcb3e0d2260df58e4261d199e596f48`; connected-route counts were reconciled in `5d6615c57`. Subsequent content has newer census values: never restore historical constants from these logs. The ship subsequently received pressure-join winding correction `a3010770b`.

Delivered behavior: physically supported cabin/aisle walking; ordinary Interact into the gunner chair; HOLD and TOGGLE FIRE damaging a real target; standing and returning to the helm; moving-floor support; retained-Main chair recovery and awake safe-home recovery from a saved file; unpaid debt applied once; replacement-owner power protection; safe cleanup after craft removal. See the existing Bulwark delivery discussion in [ROADMAP.md](../../../ROADMAP.md) (search “95”) and the current production tests.

## What remains, and how to finish it

These are acceptance tasks on the chosen **current** release candidate, not reasons to retain an old `/tmp` checkout:

1. Run the existing focused regression below on a clean current candidate. Record its source SHA and actual results. Fix any reproduced current failure at its runtime owner; do not revive superseded failures from `ordinary*` or early `author1*` runs. Expected: every selected suite passes with exit 0 and the runner's diagnostic/source/cache gates intact.
2. For the exact exported package, verify strict startup (exit 0 **and** `STARTUP_MENU_READY_OK`) and the ordinary walk → chair → HOLD/TOGGLE FIRE → stand → helm → save/restart/recover path. Source tests do not qualify a different package. Use the existing safe release/export workflow; record the tested package identity.
3. Complete native Windows/GPU/controller/audio and human normal-controls/visual acceptance. These remain **NOT_RUN by this audit**. Run automated audio with Dummy and displays headlessly or on private Xvfb; real audible/human testing is separate.
4. Track separately evolved multiplayer and whole-release work in the existing roadmap/current candidate. Original solo integration is complete; a historical hosted first-shot miss whose cause is unproven is not a demonstrated current defect. Include the existing `bulwark_network_gunner_route_test` and required multiplayer/endurance gates when accepting that scope. The full unfiltered regression, current candidate integration and package/hardware gates are not replaced by this focused check.

Existing focused command, from a clean checkout (runner isolates suite user data). This command was inspected and its selection checked with `--list`; **Godot was not run in this documentation-only retirement**:

```bash
env -u DISPLAY -u WAYLAND_DISPLAY xvfb-run -a \
  tools/release/run_test_matrix.sh \
  --mode all --display-driver x11 --audio-driver Dummy --jobs 1 \
  --scope bulwark_heavy_gunship_test,in_flight_cabin_integration_test,session_recovery_resume_offer_test,bulwark_crew_gunner_gameplay_test,bulwark_component_damage_silhouette_test,bulwark_dorsal_silhouette_visual_test,game_flow_fleet_expansion_registration_test,geometry_census_retained_material_test,geometry_census_scenario_test,local_ship_transformed_input_test,crew_role_gameplay_authority_test,crew_seat_role_authority_test
```

## Preserved source and historical evidence

The original clean branch tips are pushed to `origin`:

- `codex/bulwark-walkable-cabin` → `9f5c94d4d8993603be772639e47c8bc00f2c0366`
- `codex/bulwark-gunner-route-oct09` → `d0025027a0f260aaf69ce562e717bdc6aaba56cb`
- `codex/solo-gunner-combined-oct09` → `2b7c2cd337790bb4d05ddc2e9fe6a12a3cb519a1`

[historical-evidence.tar.xz](historical-evidence.tar.xz) preserves the non-cache contents of all 83 top-level `/tmp/bulwark-*` directories, the nested `/tmp/halyard-gunner-runs/bulwark-regression-1`, and the three adjacent `bulwark-*` files. [The manifest](historical-evidence-manifest.json) lists exact original paths, file sizes and SHA-256 hashes plus the archive checksum. All 474 preserved files were read back from the archive and matched to their originals. Extract into a separate directory; members have relative `tmp/...` paths.

Only generated Godot/Mesa cache paths were omitted: `shader_cache` directory components and root `cache/godot` or `cache/mesa_shader_cache`. Small settings, saves/backups, diagnostics, failed-run logs, screenshots, custom scripts, handoff notes, and source-hash manifests are retained. The adjacent remote-aim diagnostic launchers are preserved for safety; their presence is not a claim that the separately evolved network work is finished.

Most useful historical entries:

- `tmp/bulwark-cabin-results/handoff.json`: cabin author, original checks and limitations; census-pending status superseded by integration above.
- `tmp/bulwark-gunner-route-results/handoff-physical.json`: route/consumer authors and iterative checks; ordinary-fire/recovery/census-pending statements superseded by later combined integration.
- `tmp/bulwark-gunner-combined-results/idle-pair-summary.json`: exact original final source, gunner **95 checks / 0 failures** and recovery **172 assertions**, real exit 0, zero reported engine/script/leak diagnostics and unchanged manifests. These qualify that historical source only.
- `tmp/bulwark-console-evidence/`: four custom visual investigation scripts, two screenshots and logs. All 11 files also match `/root/.cache/mudds-shipyards/roadmap-validation/bulwark-console-contact-visuals/`; [COPLANAR_SEAM_AUDIT.md](../../COPLANAR_SEAM_AUDIT.md) records the no-visible-defect conclusion.

## Folder retirement

After this handoff/archive commit and the three source refs are verified on origin, the 84 evidence/runtime directories listed in the manifest no longer hold unique work. They may be removed without losing code, notes, custom probes, screenshots or historical test records. The three source worktrees below were clean with no untracked authored files; ignored content was generated Godot/import cache. They may also be removed using normal `git worktree remove` (do not force a newly dirty tree):

- `/tmp/mudds-bulwark-walkable-cabin`
- `/tmp/mudds-bulwark-gunner-route-oct09`
- `/root/.cache/mudds-shipyards/roadmap-work/solo-gunner-combined-oct09`

Recheck status and active use immediately before removal. Keep the pushed refs and this archive. This assessment does not authorize broad removal of other `mudds-*`, remote-aim or roadmap folders. No original directories were deleted while preparing this handoff.
