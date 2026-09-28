# Handoff implementation status — 2026-09-28

**Update:** The user subsequently authorized validation. See
[VALIDATION_RESULTS.md](VALIDATION_RESULTS.md) for executed checks, discovered
fixes, measured signage results, checkpoint details and remaining gates.
The implementation-only snapshot below preserves the earlier deferred state.

This report records the implementation pass against the seven 2026-09-27 briefs.
Four agents worked in separate worktrees; the coordinating agent reviewed and
integrated their commits into `main`. The original briefs and frozen worktrees
are preserved.

**Validation is deferred.** The user explicitly answered “Keep testing deferred”
on 2026-09-28. No Godot invocation, import, parse check, test suite, rendered
capture or checkpoint build was performed in this pass. Authored regression
tests are not passing-test evidence. Runtime, visual, performance and native
Windows gates remain **NOT_RUN**. No changes were pushed.

## Delivered behavior

| Brief | Implemented change | Authored regression coverage |
| --- | --- | --- |
| 01 — helm restart | A recreated client helm increments its stream epoch; sequence zero can restart under the retained ledger seat. Six-argument callers retain the default stream argument. | Old-stream rejection and higher-stream acceptance, plus production GameFlow client-method recreation through an admitted adapter. |
| 02 — host seat exit | The ledger holds the host's pilot seat for the whole `_piloting` exit window. | Disembark and cabin-transition predicates retain the seat; on-foot state releases it. |
| 03 — observed actor | Debug/minimap, Cinder/common-origin and streaming samplers exclude a remotely piloted active craft. | Host-body identity while bound and after flight, release and disconnect; direct local-pilot selection still works. |
| 04 — remote input | Remote flight mode simulates the ship without taking the host's camera, mouse or input. A local pilot cannot be downgraded by a remote-mode request. | Local ownership guard and camera, mouse, wheel, click, pause and motion checks. |
| 05 — seeker torpedo | Aim ignores non-strikable interaction shapes and the target's torpedo pool. A no-damage proximity fuse preserves its reason, produces no burst and selects expired audio. | Offset boarding sphere versus hull; one damage application; no-damage fuse cleanup with both reduced-flash settings; audio expiry and duplicate suppression. |
| 06 — first hauler slug | New and reused player bolt pools attach to server replication before synchronous launch. | First publication and active flight before any physics tick, terminal retirement and offline guard. |
| 07 — station signs | Registry-driven directory, threshold and junction panels share one atlas/material/mesh. Placement checks solid and concave geometry, door clearance and stationary floor support. Unchanged deferred berth poses avoid a full rebuild. | Budgets, registry derivation, facing/height, independent collision and door-clearance queries, concave blockers, stationary/ramp support, placed Dock 04–06 rows and repeated-refresh stability. |

All seven briefs are integrated in these commits (main SHAs):

- `d45b43f96`, `ff482857f`: torpedo aim and near-miss presentation.
- `5bc62f2dd`: host's first hauler slug.
- `f5409f7db`: client helm stream epochs.
- `7e01fb570`: host seat exit window.
- `9e45f37b0`: remote flight mode.
- `3d329efdf`: local observed actor selection.
- `66f779aa9`: local-pilot guard and expanded helm regressions.
- `75a35002b`: signage component and generated atlas.
- `637b58462`: world build-stage and berth-refresh integration.
- `6cd3c8dcc`: signage regression suite and UID.
- `42a7bc72f`: asset registration and matching credits entry.
- `f24b83a71`, `0ebb5be6a`: stationary/ramp floor support and regression coverage.

These reuse the candidate commits named in the briefs, followed by the missing
implementation and test work. Cherry-picks merged without conflicts. No
authority acceptance rules, network payload schemas, roadmap entries or frozen
geometry counts were changed.

## Decisions and bounded exclusions

- **Ember surface seat:** `_piloting` already prevents a remote bind during the
  host's surface visit. Keeping the ledger seat now agrees with that refusal.
  Allowing a crewmate to take that helm during a visit would require a coordinated
  behavior change and is not part of this fix.
- **Torpedo shape ordering:** the first eligible strikable shape remains the aim
  target. Optional largest-shape preference was unnecessary for the reported bug.
  Detonation presentation requires confirmed damage; no invented terminal reason
  is sent to audio or the network.
- **Hauler publication during Aurora/Rime:** the pre-existing early-return gap
  remains outside brief 06's scope.
- **Client hauler audio:** remains deferred. The old pulse handler admits Torrent
  identities only; reliable hauler audio needs explicit duplicate and late-join
  presentation behavior beyond attaching the projectile observer.

## Remote-pilot consumer audit

| Consumer | Result from source review |
| --- | --- |
| GameFlow `_get_debug_actor`, `_capture_cinder_actor_sample` | Fixed through the local-flight helper; Ember surface sampling keeps its existing ordering. |
| Streaming `_sample_production_actor_position` | Fixed with an explicit remote-pilot exclusion. |
| Bomber payload advance/publish and bomber fire consumption | Safe: gated by `_piloting`. |
| Planetary cruise gate and convoy lifecycle acceptance/failure | Safe: gated by `_piloting`; accepted sample also checks ship identity. |
| Re-entry pilot reservation | Safe: local piloting, seated anchor and reservation required. |
| Restored Cinder convoy rebind | Safe: local piloting and free-flight conditions required. |
| Fleet registry state | Safe: describes occupancy, which includes remote pilots. |
| `_start_cinder_convoy` | Safe: production activity-start caller requires local piloting and free flight. |
| Journey `admit_aurora_visit` | Safe: production launch requires the local seated pilot and rejects network sessions; other caller restores a local visit. |
| `begin_aurora_return`, `_observe_aurora_return_tick` | Safe: active local visit/return; production return and cruise gates require local piloting. |
| `begin_ember_surface_journey`, `_rearm_retired_ember_final_approach` | Safe: local planetary cruise gate runs before admission or re-arming. |
| `_mudds_return_handback_rejection` | Safe: local seated player and ownership receipt required. |
| `_arm_ember_abandon_return_approach`, `_observe_abandon_return_departure_tick` | Safe: local-flight gate and local actor ownership required. |
| Ember surface loop consumers | Safe: local surface ownership, seat, reservation and command-source checks. |
| Cruise binding `_validate_live_ship` | Safe: flight capability check used behind production local-flight gates and matching actor samples. |

No additional consumer behavior changes were necessary in this bounded audit.

## Signage decisions and remaining measurements

The copied work from the frozen signage worktree was completed without changing
that worktree. The existing synchronous and staged world builders both execute
the new stage after activity restoration and before the old sign-budget pass.
Existing stage order, registry schema, consolidation roster and collision remain
unchanged. New script UID sidecars are committed.

| Original unfinished item | Resolution |
| --- | --- |
| Asset heading and credits | Atlas heading copied into `ASSETS.md`; matching credits entry added. |
| Ignored concave geometry | Actual world-space triangles now participate in box-overlap and floor-support checks. Report exposes checked count and zero ignored concave shapes. |
| Repeated rebuild cost | Compare the three deferred berth positions before scanning collision again. A changed berth set can trigger one rebuild; repeated unchanged notifications retain the batch. |
| Dead-end landmarks | Removed the south service gate destination. Garden Cupola retained based on the built room and unlocked connecting-door implementation. |
| Full atlas | Removing the south gate leaves 29 label cells used out of 30; arrow and blank cells retain their fixed indices. |
| Staged-load cost | One build stage, with duration exposed in the placement report. Actual loading time remains NOT_RUN. |
| Missing checks and sidecar | Authored the suite and committed its UID. Census measurements and visual review remain NOT_RUN. |

Planning permits 19 sites: one directory, seven thresholds and eleven junctions.
Collision rejection and triangle-budget trimming can reduce the placed count.
The implementation caps placement at 60 signs and 400 triangles, rendered by one
mesh batch with one material and one atlas texture. Deferred Dock 04–06 rows take
priority among threshold landmarks so nearer rows do not crowd them out.

Expected census contribution for a populated layer: **+1 renderer, at most +400
triangles, +1 material and +1 texture**. Exact sign/triangle counts, collision-free
coverage of all required destinations, atlas regeneration equality, loading cost
and visual readability are **not measured** in this pass. The atlas generator was
run once to author the updated SVG; repeatability testing was deferred.

Source review also corrected floor support: doors and moving bodies remain
obstacles but cannot support static signs; sloped box floors use their actual
surface rather than the high corner of a world-space bounding box.

## Static integration review

The combined source diff passed `git diff --check`. Review covered the shared
GameFlow changes, authority and presentation boundaries, signage build wiring,
and the authored regression assertions. Existing unrelated untracked files and
the original handoff briefs were left intact. This is implementation review,
not runtime validation; every deferred suite below is still **NOT_RUN**.

## Validation to run after authorization

Import the integrated source once with `godot --headless --audio-driver Dummy
--path . --import`, then parse-check changed scripts and run the suites below.
Each suite uses `godot --headless --audio-driver Dummy --path . --script
res://tests/<suite>.gd`. Require exit 0 and the suite's success marker; inspect
logs for script errors even when a success marker is present.

| Suite under `tests/` | Success marker |
| --- | --- |
| `network_remote_pilot_helm_test.gd` | `NETWORK_REMOTE_PILOT_HELM_TEST_OK` |
| `network_remote_craft_pose_test.gd` | `NETWORK_REMOTE_CRAFT_POSE_TEST_OK` |
| `network/game_flow_remote_ship_command_integration_test.gd` | `OK: GameFlow remote ship command integration` |
| `network/network_enet_boarding_ledger_test.gd` | `NETWORK_ENET_BOARDING_LEDGER_TEST_OK` |
| `network_client_boarding_seam_test.gd` | `NETWORK_CLIENT_BOARDING_SEAM_TEST_OK` |
| `cinder_streaming_actor_loss_lifecycle_test.gd` | `CINDER_STREAMING_ACTOR_LOSS_LIFECYCLE_TEST_OK` |
| `debug_overlay_test.gd` | `DEBUG_OVERLAY_TEST_OK` |
| `game_flow_minimap_activity_markers_test.gd` | `GAME_FLOW_MINIMAP_ACTIVITY_MARKERS_TEST_OK` |
| `cinder_streaming_production_journey_test.gd` | `CINDER_STREAMING_PRODUCTION_JOURNEY_TEST_OK` |
| `in_flight_cabin_integration_test.gd` | `IN_FLIGHT_CABIN_INTEGRATION_TEST_OK` |
| `ship_command_test.gd` | `SHIP_COMMAND_TEST_OK` |
| `seeker_torpedo_projectile_test.gd` | `SEEKER_TORPEDO_PROJECTILE_TEST_OK` |
| `torpedo_run_audio_test.gd` | `TORPEDO_RUN_AUDIO_TEST_OK` |
| `torpedo_boat_opponent_test.gd` | `TORPEDO_BOAT_OPPONENT_TEST_OK` |
| `network_remote_projectile_test.gd` | `NETWORK_REMOTE_PROJECTILE_TEST_OK` |
| `cinder_cargo_mass_driver_bolt_test.gd` | `CINDER_CARGO_MASS_DRIVER_BOLT_TEST_OK` |
| `station_wayfinding_test.gd` | `STATION_WAYFINDING_TEST_OK` |
| `station_route_registry_integration_test.gd` | `STATION_ROUTE_REGISTRY_INTEGRATION_TEST_OK` |
| `station_surface_playability_test.gd` | `STATION_SURFACE_PLAYABILITY_TEST_OK` |
| `sign_geometry_budget_test.gd` | `SIGN_GEOMETRY_BUDGET_TEST_OK` |
| `credits_page_test.gd` | `CREDITS_PAGE_TEST_OK` |
| `geometry_census_scenario_test.gd` | `GEOMETRY_CENSUS_SCENARIO_TEST_OK` |
| `geometry_census_retained_material_test.gd` | `GEOMETRY_CENSUS_RETAINED_MATERIAL_TEST_OK` |

The two census suites may reject the added signage against their frozen counts.
Record actual renderer, triangle, material and texture deltas; do not refreeze
the counts merely to obtain a pass. Review signage visually on an isolated
display after permission, including the directory and module thresholds.

Once focused validation succeeds, export a fresh Windows checkpoint from a clean
commit using the existing safe workflow. Place the EXE, ZIP and build notes in
`builds/windows/`. The silent isolated package smoke must use `--startup-check`
and require exit 0 plus `STARTUP_MENU_READY_OK`. Do not publish to Downloads.
