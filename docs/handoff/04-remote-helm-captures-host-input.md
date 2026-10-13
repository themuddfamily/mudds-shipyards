# Handoff 04: Remote helm binding takes over the host's mouse and input

- **Priority:** P2.
- **Roadmap item:** Phase 7 multiplayer, remote piloting (a crewmate flies the host's craft).
- **Status at handoff:** 2026-09-27, read against `main` at `92a30f7ff`. The bug is live on main.
- **Prior partial work:** yes. There is a candidate fix in commit `c36821ba9` on branch `worktree-wf_bde904a0-40e-1`. It looks mostly correct from reading; one guard is missing (see below). It has not been run.

## Context

`28d9271d0` ("Remote pilots fly the host's craft instead of a private client copy") binds the host's copy of the craft to a `NetworkRemotePilotCommandSource`. It does this through `HeroShip.set_command_source()` and then calls `HeroShip.set_piloted(true)` to switch flight simulation on. `set_piloted()` is the **local** boarding API. Besides flight, it also:
- makes the ship camera current;
- emits `boarded`;
- sets `Input.mouse_mode = CAPTURED` on non-headless hosts.

In addition, the ship's `_unhandled_input` treats every input event as its pilot's. `c7b2ff9df` later added ship ownership and helm release, but kept the same call.

## Problem

On a non-headless host, a remote pilot's grant can happen while the host is on foot or in a menu. When it does:
- The mouse is captured.
- The bound craft's `_unhandled_input` consumes the host's wheel events and marks them handled, which breaks the host's chase and third-person zoom.
- The craft re-captures the cursor on any click.
- The craft reacts to `pause` by setting the mouse visible.
- It also queues the host's mouse motion as look motion for the remote craft.

The camera was already patched back by hand at the bind site. Mouse mode and input were not.

## Where (main @ 92a30f7ff)

- `scripts/ships/hero_ship.gd`
  - `var _piloted` (line 311).
  - `_ready()`, lines 570-572: sets the camera current and captures the mouse when `_piloted`.
  - `_unhandled_input()`, lines 631-661. It checks only `if not _piloted: return`. It then handles pause (637), wheel zoom (641-648), mouse re-capture (650-653) and look motion (655-661).
  - `set_piloted()`, lines 664-690, which includes the mouse capture at 686.
  - `apply_look_motion()` (694).
  - `set_command_source()` (707).
  - The `_set_camera_current(_piloted)` calls in `set_cockpit_view()` (961) and `_build_markers_and_camera()` (7143).
  - `commit_reset_for_reuse()` sets `_piloted = false` at about line 2410.
  - `is_piloted()` (2218).
- `scripts/game/game_flow.gd`
  - `_bind_network_remote_pilot()`, lines 8830-8870. At 8858-8866 it saves the viewer camera, calls `set_command_source(source)` and then `set_piloted(true)`, and restores the camera.
  - `_unbind_network_remote_pilot()`, lines 8873-8899. It calls `hero.set_piloted(false)` unless `hero == active_ship and _piloting`, and then restores the camera.

## Failure scenario

1. A windowed (non-headless) host is on foot in third person, with the mouse visible in a menu or free.
2. A client takes the Halyard's pilot seat through the ledger. The host binds, and `set_piloted(true)` captures the host's mouse.
3. The host scrolls to zoom its third-person camera. The Halyard's `_unhandled_input` eats the wheel event for its own chase distance.
4. The host clicks a UI element. The cursor is re-captured.
5. The host presses pause. The mouse goes visible, but the craft keeps reacting to later clicks.

## What to do

**Recommended** (this is what `c36821ba9` does): add a remote-piloted mode to `HeroShip`.
- Add `var _remote_piloted := false`.
- Add `set_remote_piloted(piloted: bool)`. It performs the flight half of `set_piloted`:
  - `_ensure_command_source()`;
  - `_invalidate_command_delivery`;
  - `_retire_planetary_cruise` on a change;
  - sets `_piloted`;
  - `reset_stream()` if the source is local;
  - `_clear_pending_look_motion()` when turning off.

  It does **not** touch the camera, the mouse mode or `boarded`. `set_remote_piloted(false)` is a no-op unless the craft is in remote mode.
- Add `is_remote_piloted()` and a private `_is_piloted_from_this_machine()`.
- `_unhandled_input` returns early when `_remote_piloted`.
- `apply_look_motion` and every `_set_camera_current(_piloted)` call use `_is_piloted_from_this_machine()`.
- `set_piloted()` and `commit_reset_for_reuse()` clear `_remote_piloted`.
- In GameFlow, `_bind_network_remote_pilot` calls `craft.set_remote_piloted(true)` and drops its camera save and restore. `_unbind_network_remote_pilot` calls `hero.set_remote_piloted(false)` and drops its camera restore.

**Minimum acceptable alternative:**
- `_unhandled_input` returns early when `get_command_source()` is not a `LocalShipInputSource`.
- The bind site saves `Input.mouse_mode` before `set_piloted(true)` and restores it afterwards.

This is weaker: the camera is still switched and restored by hand.

**Contracts that must not change:**
- Local piloting through `set_piloted()` must behave byte-identically: camera, mouse capture, `boarded`, input and the look pipeline.
- `is_piloted()` stays true for a remote-piloted craft. Flight code (`_physics_process` around lines 598 and 607, and every other `_piloted` check) and callers across the game depend on it. Handoff 03 separates "piloted" from "piloted from here".
- The command-source seam and stream-epoch rules in `set_command_source()`.

## Prior partial work

The prior work is on branch `worktree-wf_bde904a0-40e-1`, in worktree `/root/mudds-shipyards/.claude/worktrees/wf_bde904a0-40e-1`. Its HEAD at writing was `24c908d75`, with a clean tree.
- **`c36821ba9`** "Remote helm flies the host's craft without taking the host's mouse or input" implements the recommended fix in `hero_ship.gd` (+50/-6) and `game_flow.gd` (bind and unbind). It also adds two asserts to `tests/network_remote_pilot_helm_test.gd`:
  - section A: `_craft.is_remote_piloted()` after the grant;
  - section E: `not _craft.is_remote_piloted()` after the ledger disembark.
- **Issue found by reading:** `set_remote_piloted(true)` has no guard against a craft that this machine is already flying. It would silently downgrade a locally piloted craft to remote mode and drop the host's camera and input ownership. An earlier uncommitted draft had this guard, and it was lost:
  ```gdscript
  if piloted and _piloted and not _remote_piloted:
      return  # this machine is flying it; a remote helm never takes it over here
  ```
  Today the bind refuses `craft == active_ship and _piloting`, so the case is unlikely, but restore the guard.
- **Not covered:** the test has no direct input assertion.
- **How to reuse it:** create your own branch from main and run `git cherry-pick c36821ba9`.
  - The `hero_ship.gd` and `game_flow.gd` hunks are independent of the fixer's earlier commits.
  - The test hunk in section A uses `effab5d97` (Handoff 02) as its context, so it may conflict on main alone. If it does, re-apply the two asserts by hand.
  - **Do not edit that worktree.**

## Files you own / must not touch

- **You own:**
  - The `hero_ship.gd` regions listed above, plus the new `set_remote_piloted`, `is_remote_piloted` and `_is_piloted_from_this_machine`.
  - `_bind_network_remote_pilot()` and `_unbind_network_remote_pilot()` in `game_flow.gd`, from the bind line through the unbind's camera handling.
  - The remote-mode asserts in the helm test.
- **Do not touch:**
  - `_network_host_desired_pilot_ship` (Handoff 02).
  - The helm stream and `build_helm_intent` (Handoff 01).
  - `_get_debug_actor`, `_capture_cinder_actor_sample` and `cinder_streaming_production_binding.gd` (Handoff 03).
  - Projectile code (Handoff 06).
- **Dependency:** Handoff 03's preferred fix calls your `is_remote_piloted()`. Keep that exact name and meaning (`_piloted and _remote_piloted`).
- **Shared files:** `game_flow.gd` is shared with 01, 02, 03 and 06 in disjoint functions, and the helm test with 01 and 02. This can run **in parallel**. Merge after 02, and before 03.

## Project rules

- Every Godot invocation must include `--audio-driver Dummy`.
- Rendered runs happen only headless, or under Xvfb with `--display-driver x11` and `DISPLAY`/`WAYLAND_DISPLAY` unset. Never run on the user's desktop.
- A fresh worktree needs `godot --headless --audio-driver Dummy --path <wt> --import` once. Treat this as waiting on the testing go-ahead.
- Create your work with `git -C /root/mudds-shipyards worktree add -b <branch> <path> main`. In an existing worktree, use `git merge --ff-only main`. Never use `reset --hard`.
- Commit the generated `.gd.uid` sidecar with any new script.
- Do not add evidence validators or schema bumps (see AGENTS.md). Do not edit `ROADMAP.md`. Do not push.

## Testing

**Current user instruction: do not run tests until the user says testing may start.**

Write now, in `tests/network_remote_pilot_helm_test.gd` section A. Headless cannot observe mouse capture, so assert behaviour:
- After the grant, `_craft.is_remote_piloted()` is true.
- Feed `_craft._unhandled_input()` an `InputEventMouseButton` (wheel up, pressed). `_craft.get_chase_camera_distance()` must be unchanged afterwards (`hero_ship.gd:996`).
- Feed an `InputEventMouseMotion`. No look motion may be queued.
- In section E, keep the release assert.
- Optionally, add a pure `HeroShip` unit check to an existing ship test: `set_piloted(true)` followed by `set_remote_piloted(true)` leaves `is_remote_piloted()` false (this is the guard).

Run later:
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_pilot_helm_test.gd` (success marker `NETWORK_REMOTE_PILOT_HELM_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_craft_pose_test.gd` (success marker `NETWORK_REMOTE_CRAFT_POSE_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/in_flight_cabin_integration_test.gd` (success marker `IN_FLIGHT_CABIN_INTEGRATION_TEST_OK`). This covers local seat enter and exit.
- `godot --headless --audio-driver Dummy --path . --script res://tests/ship_command_test.gd` (success marker `SHIP_COMMAND_TEST_OK`).

## Definition of done

- [ ] A remote binding never changes `Input.mouse_mode`, the current camera, or the host's handling of wheel, click, pause or motion.
- [ ] The craft still flies from the remote helm, and `is_piloted()` is true while bound.
- [ ] `set_piloted()` behaviour is unchanged. The diff of that function adds only the `_remote_piloted = false` line.
- [ ] The guard against downgrading a locally piloted craft is present.
- [ ] Focused asserts written. Suites listed for later.

## Deliverable

Deliver commits on your own branch from main. Then give a short report with:
- the commits and the files touched;
- the cherry-pick and conflict notes;
- the status of the guard;
- the status of each item above;
- the suites to run once testing may start.
