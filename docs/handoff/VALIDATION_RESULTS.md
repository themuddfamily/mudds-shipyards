# Handoff validation — 2026-09-28

The user authorized the previously deferred checks. Four agents validated the
independent workstreams, and the coordinator integrated the fixes and checked
the combined checkpoint source. No changes were pushed.

## Fixes found by execution

- `0780f4d7d`, `596ea4e84`: explicitly bind controller B to menu cancel and A to
  menu accept, preserving keyboard bindings. The engine's loaded defaults lacked
  these button mappings; Credits could not return and menu buttons could not
  activate from a controller.
- `85fa9adf9`: the fleet threshold's narrow connector had no safe sign placement
  near its midpoint. Also search the registry-derived arrival landing without
  reducing collision clearance. Mark the sign mesh explicitly non-walkable.
- `5cdc0736c`: place the craft-pose test in unobstructed flight and require actual
  movement. Previously the host ship collided with the station while the
  shapeless client proxy integrated velocity as though flight were unobstructed.
- `a29fbd33a`: retain boarding refusals for 2.8 seconds instead of overwriting
  them on the next same-craft proximity refresh. Other transitions supersede the
  refusal. Test retention and expiry without disabling production prompt updates.

## Focused suite results

Every passing suite below exited 0, emitted its expected success marker and had
no script/parse errors. Import and changed-script checks also passed. Automated
Godot calls used Dummy audio and headless mode, except the explicitly isolated
Xvfb signage captures. Tests used private user-data directories.

| Group | Passing suites |
| --- | --- |
| Remote piloting and boarding | `network_remote_pilot_helm_test`, `network_remote_craft_pose_test`, `network/game_flow_remote_ship_command_integration_test`, `network/network_enet_boarding_ledger_test`, `network_client_boarding_seam_test`, `in_flight_cabin_integration_test`, `ship_command_test` |
| Combat | `seeker_torpedo_projectile_test`, `torpedo_run_audio_test`, `torpedo_boat_opponent_test`, `network_remote_projectile_test`, `cinder_cargo_mass_driver_bolt_test` |
| Journey and observers | `cinder_streaming_actor_loss_lifecycle_test`, `debug_overlay_test`, `game_flow_minimap_activity_markers_test`, `cinder_streaming_production_journey_test` |
| Signage and credits | `station_wayfinding_test`, `station_route_registry_integration_test`, `station_surface_playability_test`, `credits_page_test`, `geometry_census_retained_material_test` |
| Checks protecting the discovered fixes | `controller_pause_navigation_prompt_test`, `boarding_confirmation_game_flow_test` |

These are **23 distinct passing suites**. Two other requested suites retain
pre-existing failures, documented below. Success here is not a full-matrix or
human-playtest qualification.

The first concurrent boarding run exceeded its body-position tolerance (2.29 m
versus 1.5 m). The investigating agent's three subsequent runs did not reproduce
it; the isolated run converged to 0.00 m with five corrections. No prediction
logic or tolerance was changed. Failure-only diagnostics were retained for any
recurrence. The final combined-source repeat also passed (1.32 m difference).
A separate overlapping network run warned that LAN discovery's port
was unavailable; its actual loopback session and peers succeeded.

## Signage measurements and visual review

- 19 placed signs: one directory, seven thresholds and eleven junctions.
- 380 triangles; one renderer, surface, material and atlas texture.
- Zero skipped sites or collision conflicts. Dock 04, 05 and 06 labels are present.
- The atlas regenerated identically twice. SHA-256:
  `4be0c1b5396b49ac2542c0784fc52a6a67c9c977adc9824780f73665df798d6b`.
- Same-scene signage-only census: +380 triangles, +1 renderer/surface/mesh,
  +1 bound/retained material, +1 texture (4,194,304 uncompressed bytes), +2 nodes,
  and no additional lights.
- Observed build durations: 75.832–103.037 ms during headless checks, 83.555 ms
  during rendered capture. These are host measurements, not native-GPU timings.
- Directory, fleet threshold and fabrication threshold were captured at 3 m and
  reviewed at 1280×720 under Xvfb/x11, Compatibility rendering and Mesa llvmpipe.
  Text, shape cues and arrows were readable; no mirrored or clipped rows were
  observed. Capture exited 0 with `SIGNAGE_CAPTURE_OK` and no errors.

## Inherited failing gates — not refrozen

`sign_geometry_budget_test` fails because the existing 44 TextMesh signs total
81,226 triangles against the 80,000 ceiling. The pre-handoff `92a30f7ff` run is
byte-identical, including this failure. The worst individual sign is 4,141
triangles. New textured signage does not add TextMesh lettering; neither the
budget implementation nor its limits changed.

`geometry_census_scenario_test` fails 8 of 17 assertions on both `92a30f7ff` and
the integrated signage source. The frozen whole-scene counts and streamed-Cinder
delta were already stale. Actual triangles change from 1,750,757 to 1,751,137
resident and 1,905,779 to 1,906,159 with Cinder loaded: exactly the +380 signage
triangles in each case. The streamed Cinder bucket and loaded-minus-resident
deltas are unchanged. Across all handoff changes, each scenario gains four
nodes; two belong to the signage layer. No frozen counts were changed.

## Checkpoint and remaining gates

Checkpoint source: `a29fbd33a4c44c60fd69dfe5b7aa8b21de613ba2`.
The final clean-source run passed GameFlow parsing plus the helm, client boarding,
signage and Credits suites. Export used `tools/release/export_windows_candidate.sh`
from a clean worktree; the source stayed clean throughout.

Artifacts in this repository's `builds/windows/`:

- `MuddsShipyards-a29fbd3.exe` — 177,031,936 bytes.
- `MuddsShipyards-a29fbd3-checkpoint.zip` — 100,405,541 bytes.
- `MuddsShipyards-a29fbd3-notes.txt` — player-visible changes, validation and hashes.

ZIP integrity and its embedded EXE hash were verified. PowerShell extracted that
ZIP into a private temporary directory, then ran the native Windows EXE with
`--headless --audio-driver Dummy --startup-check`, isolated profile paths and a
180-second abort deadline. It exited **0**, emitted **STARTUP_MENU_READY_OK**, and
logged no script errors. Reported time to menu interaction was 18.087 seconds.
The private executable/profile directory was removed afterward. No desktop
window or audible test was used.

EXE SHA-256: `afadcb7a102f81c5b133310a85c13b3485e76bc15342b7a93b211d7998948127`.
ZIP SHA-256: `6ec942f0b95ce24bbc0e9b3b7e55ac1d863a62af0f2fe0741470aabf194805fa`.

Native GPU performance, real-controller hardware, human visual/gameplay review,
and the full project matrix remain **NOT_RUN**. The inherited geometry failures
above remain open; this pass does not claim every project test is green.

## Logs and captures

Evidence is preserved outside source at
`/root/.cache/mudds-shipyards/handoff-validation/`:

- `remote/`, `combat/`, `journey/`: assigned suites and focused fixes.
- `signage/`: suite logs, exact census results, capture report and three WebP images.
- `baseline/`: pre-handoff reproductions of the two inherited failures.
- Root-level logs: script checks, Credits/controller reruns, final combined-source
  checks and checkpoint export/startup results.

The [implementation report](IMPLEMENTATION_STATUS.md) records the original
commits and bounded audit decisions. Its deferred-validation language describes
the earlier implementation-only pass, superseded by this report.
