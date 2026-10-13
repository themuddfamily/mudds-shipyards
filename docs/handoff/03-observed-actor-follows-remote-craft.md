# Handoff 03: Host's observed actor follows a crewmate's craft

- **Priority:** P2.
- **Roadmap item:** Phase 7 multiplayer, remote piloting. It interacts with Cinder/Ember streaming, the minimap and the common-world origin.
- **Status at handoff:** 2026-09-27, read against `main` at `92a30f7ff`. The bug is live on main.
- **Prior partial work:** yes. There is a candidate fix in commit `24c908d75` on branch `worktree-wf_bde904a0-40e-1`. It **depends on `c36821ba9`** (Handoff 04). It covers the three main samplers. The wider `is_piloted()` audit has not been done. Nothing has been run.

## Context

- `28d9271d0`: the host binds a remote pilot's grant to the host's own copy of the craft and calls `set_piloted(true)` on it. Handoff 04 changes this to `set_remote_piloted(true)`; in both versions `is_piloted()` stays true.
- `active_ship` is never cleared. It is the Torrent at startup and the last-boarded craft after that.
- `_get_debug_actor()` and `_capture_cinder_actor_sample()` were written before multiplayer (for example `6448c4566`, the Cinder convoy integration). They assume that "active_ship is piloted" means "this machine is flying it".

## Problem

Both functions pick `active_ship` as the observed actor when `_piloting or active_ship.is_piloted()`. When a crewmate flies the host's `active_ship` remotely, the check passes while the host is on foot. The host's minimap, debug overlay, Cinder/Ember streaming actor, destination briefings and floating-origin rebasing then follow the crewmate's craft. When the peer disconnects far away, the binding is released and the sample jumps back to the host's body in a single tick, which causes a streaming and origin discontinuity.

## Where (main @ 92a30f7ff)

- `scripts/game/game_flow.gd`
  - `_get_debug_actor()`, lines 3584-3595. The predicate is at line 3590. Consumers:
    - `get_debug_overlay_snapshot()` (3531);
    - `get_minimap_snapshot()` (3717).
  - `_capture_cinder_actor_sample()`, lines 5649 to about 5710.
    - The Ember surface host phases are handled first (5656-5676).
    - Then the ship predicate at line 5680.
    - Consumers: `_physics_process` (4458, 4464 and 4502), which feeds `_planetary_journey.advance_world` / `advance_aurora_visit`, streaming and origin.
  - Other `is_piloted()` consumers to audit (the function names are the anchors):
    - `_advance_bomber_payload_loop` (4577), `_publish_bomber_payload_snapshot` (4757), `_planetary_cruise_gate_reason` (5757), `_convoy_lifecycle_accepts_sample` (5800), `_convoy_lifecycle_failure_reason` (5821), `_capture_pilot_reservation_for_reentry` (5893) and `_try_rebind_restored_cinder_convoy` (15870). All of these also require `_piloting`, so they are safe.
    - `_consume_cinder_bomber_fire_pressed` (7604) is guarded by `_piloting` at 7594, so it is safe.
    - `_fleet_registry_state` (7884) means "occupied", and remote counts as occupied, so it is probably correct. Confirm.
    - `_start_cinder_convoy` (14448) checks only `active_ship.is_piloted()`. Find its callers and check whether it can run while the host is on foot.
- `scripts/world/cinder_streaming_production_binding.gd`, `_sample_production_actor_position()`, lines 485-500. It uses `active_ship.is_piloted()` at line 492. **This is the same bug.**
- `scripts/game/planetary_journey_coordinator.gd` uses `_flow.active_ship.is_piloted()` without `_flow._piloting`, so audit these:
  - `admit_aurora_visit` (299);
  - `begin_aurora_return` (460);
  - `_observe_aurora_return_tick` (530);
  - `begin_ember_surface_journey` (1087);
  - `_rearm_retired_ember_final_approach` (1263);
  - `_mudds_return_handback_rejection` (1586);
  - `_arm_ember_abandon_return_approach` (2067);
  - `_observe_abandon_return_departure_tick` (2149).

  Line 695 already requires `_flow._piloting`.
- Also check `scripts/world/ember_surface_loop_host.gd` and `scripts/control/planetary_cruise_production_binding.gd:1559`. These are not expected to be affected, because they run only inside a local surface journey or a cruise. Confirm and note it.

## Failure scenario

1. The host has flown the Torrent (so `active_ship` is the Torrent), then disembarked onto the station deck.
2. A client boards the Torrent's pilot seat. The host binds, and the Torrent is now `is_piloted()`.
3. The client flies 20 km away. The host's minimap centres on the Torrent, and Cinder streaming loads cells around the Torrent instead of around the host's body. Origin rebasing follows the Torrent too.
4. The client disconnects. The binding releases, and the next `_capture_cinder_actor_sample()` returns the host's body 20 km away, in a single tick.

## What to do

**Recommended** (this is what `24c908d75` does): add a helper and use it in both GameFlow samplers.
```gdscript
func _active_ship_flown_from_here() -> bool:
	return _piloting or (active_ship.is_piloted() and not active_ship.is_remote_piloted())
```
Add `and not active_ship.is_remote_piloted()` to `cinder_streaming_production_binding.gd:492` as well.

This keeps every offline and local path identical, including test harnesses that call `set_piloted(true)` directly without `_piloting`, and it excludes only a remote-bound craft.

**Alternative if Handoff 04 has not merged yet:** use `not _network_remote_pilots.has(active_ship.get_ship_id())` in GameFlow. The streaming binding would then need to ask GameFlow through a method.

**Rejected:** dropping `or active_ship.is_piloted()` entirely. It may break harnesses and paths that pilot without the `_piloting` latch.

Then audit every consumer listed above. For each one, record it as one of:
- **safe:** it is also gated on `_piloting`, or it means "occupied";
- **fixed:** you applied the same exclusion;
- **needs owner decision.**

Fix only those that a host could reach while on foot.

**Contracts that must not change:**
- Solo and offline actor selection.
- The Ember surface phase ordering in `_capture_cinder_actor_sample()`.
- The sample dictionary shape (`available`, `position`, `actor_kind`, `actor_instance_id`, `reason`).
- The streaming binding's result shape.

## Prior partial work

The prior work is on branch `worktree-wf_bde904a0-40e-1`, in worktree `/root/mudds-shipyards/.claude/worktrees/wf_bde904a0-40e-1`. Its HEAD at writing was `24c908d75`, with a clean tree.
- **`24c908d75`** "Host's observed actor stays on its own body while a crewmate flies active_ship" contains:
  - `_active_ship_flown_from_here()`, placed after `_get_debug_actor`;
  - that helper used in `_get_debug_actor` and `_capture_cinder_actor_sample`;
  - the streaming-binding exclusion.

  It has no test, and no audit of the other consumers.
- **Assessment:** correct for the three samplers from reading. It needs `HeroShip.is_remote_piloted()` from `c36821ba9`.
- **How to reuse it:**
  - Branch from main **after** Handoff 04 has merged, then run `git cherry-pick 24c908d75`.
  - Or, if you must start before that, branch from main and `git cherry-pick c36821ba9 24c908d75`, and rebase once 04 lands. Tell the integrator about the duplicated commit.
  - **Do not edit that worktree.**

## Files you own / must not touch

- **You own:**
  - `_get_debug_actor()`, the new `_active_ship_flown_from_here()`, and the ship predicate in `_capture_cinder_actor_sample()`, all in `game_flow.gd`;
  - `_sample_production_actor_position()` in `cinder_streaming_production_binding.gd`;
  - any audited consumer you actually change, in `planetary_journey_coordinator.gd` or elsewhere in `game_flow.gd`.
- **Do not touch:**
  - `hero_ship.gd` (Handoff 04 owns `is_remote_piloted`; call it, do not change it);
  - bind and unbind (04);
  - the helm stream (01);
  - the host seat predicate (02);
  - projectiles (06).
- **Shared files:** `game_flow.gd` is shared with 01, 02, 04 and 06 in disjoint functions. **Depends on 04.** You can write it in parallel, but merge it after 04.

## Project rules

- Every Godot invocation must include `--audio-driver Dummy`.
- Rendered runs happen only headless, or under Xvfb with `--display-driver x11` and `DISPLAY`/`WAYLAND_DISPLAY` unset. Never run on the user's desktop.
- A fresh worktree needs `godot --headless --audio-driver Dummy --path <wt> --import` once. Treat this as waiting on the testing go-ahead.
- Create your work with `git -C /root/mudds-shipyards worktree add -b <branch> <path> main`. In an existing worktree, use `git merge --ff-only main`. Never use `reset --hard`.
- Commit the generated `.gd.uid` sidecar with any new script.
- Do not add evidence validators or schema bumps (see AGENTS.md). Do not edit `ROADMAP.md`. Do not push.

## Testing

**Current user instruction: do not run tests until the user says testing may start.**

Write now. Prefer extending `tests/network_remote_pilot_helm_test.gd` section B, where the host is on foot and the peer flies the craft. Assert:
- `_host._capture_cinder_actor_sample().actor_kind == &"player"`, and the sample's instance id is the host's player;
- `_host._get_debug_actor() == _host.player`;
- after release (section E), the same holds.

Note: in that suite the host's `active_ship` may not be the Halyard. If so, make the Halyard the host's `active_ship` in setup, or write a pure `GameFlow` probe instead.

Run later:
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_pilot_helm_test.gd` (success marker `NETWORK_REMOTE_PILOT_HELM_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/cinder_streaming_actor_loss_lifecycle_test.gd` (success marker `CINDER_STREAMING_ACTOR_LOSS_LIFECYCLE_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/debug_overlay_test.gd` (success marker `DEBUG_OVERLAY_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/game_flow_minimap_activity_markers_test.gd` (success marker `GAME_FLOW_MINIMAP_ACTIVITY_MARKERS_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/cinder_streaming_production_journey_test.gd`. Check its final `print` for the marker.

## Definition of done

- [ ] While a crewmate flies the host's `active_ship` and the host is on foot, the host's actor sample, debug actor and streaming actor are the host's own body.
- [ ] Solo and local piloting are unchanged.
- [ ] Every `is_piloted()` consumer listed above is classified in the report as safe, fixed or needs owner decision.
- [ ] Focused asserts written. Suites listed for later.

## Deliverable

Deliver commits on your own branch from main. Then give a short report with:
- the commits and the files touched;
- the dependency on 04 and how you resolved it;
- the audit table (consumer, then safe, fixed or decision);
- the suites to run once testing may start.
