# Handoff 01: Remote helm stream restart is refused as stale

- **Priority:** P1 (a remote pilot can lose control of the host's craft for minutes).
- **Roadmap item:** Phase 7 multiplayer, remote piloting (a crewmate flies the host's craft through the boarding ledger).
- **Status at handoff:** 2026-09-27, read against `main` at `92a30f7ff`. The bug is live on main.
- **Prior partial work:** yes. There is a candidate fix in commit `db19b78bf` on branch `worktree-wf_bde904a0-40e-1`. It looks correct from reading, but it has not been run.

## Context

A peer that the host's boarding ledger seats in a pilot seat streams its helm to the host as movement intents. The host flies its own copy of the craft from those intents.
- `28d9271d0`: remote pilots fly the host's craft instead of a private client copy. Added the client helm stream and `NetworkRemotePilotCommandSource`.
- `bac902c40`: boarding ledger gains the atomic seat swap, a live tick clock and host seat occupancy.
- `c7b2ff9df`: when a client leaves its flying pilot seat for the cabin, it swaps into a berth and the host unbinds the helm. If every berth is taken, the swap is refused and the client **keeps** the pilot seat.
- Design notes: `docs/MOVING_INTERIOR_LATENCY.md`, sections "Remote pilots fly the host's craft" and "Leaving the flying pilot seat tells the ledger".

## Problem

The client resets its helm stream to sequence 0 whenever it is briefly not piloting, but it always sends `stream_id` 0. The host keeps its per-seat movement record, including `last_sequence = N`, for as long as the ledger seat is held. N grows at about 15 per second. `NetworkMovementAuthority.accept_intent` therefore refuses every new packet as `stale_sequence` until the new sequence passes N. After a long flight that takes minutes. Meanwhile the host's `NetworkRemotePilotCommandSource` goes silent for `HOLD_TICKS` (30) and falls to neutral, so the host's craft coasts and ignores the pilot.

## Where (main @ 92a30f7ff)

- `scripts/game/game_flow.gd`
  - Lines 750-753: the `_network_remote_helm` and `_network_remote_helm_sent` vars.
  - `_advance_network_remote_helm_stream()`, lines 8949-8980. It resets `_network_remote_helm = {}` whenever the peer is not `_piloting` (line 8955) and restarts at `{"sequence": 0}` (line 8961). At line 8973 it calls `build_helm_intent(...)`, which takes no stream id.
  - Other resets of `_network_remote_helm = {}`: 6265 (`_on_network_session_stopped`), 9080 (`_present_network_remote_craft_lost`), 10599 (`_present_network_client_helm_released`).
  - `_request_network_client_boarding()` (starts at line 10259; the retained-seat branch is at 10268-10273). A peer that already holds the pilot seat and is in `Phase.IN_FLIGHT_CABIN` sits back down with `_board_ship_locally` and returns `pilot_seat_retained`. **No ledger event is sent.**
  - `_leave_seat_into_cabin()`, lines 10910 onward. It calls `_request_network_client_helm_release()` at about line 10970. That function (line 10573) may be refused `seat_occupied`, and then the client keeps the seat.
- `scripts/network/network_remote_pilot_command_source.gd`, `build_helm_intent()` lines 93-120. It hard-codes stream id `0` in `MovementIntent.create(peer_id, ship_id, entity_generation, 0, sequence, ...)`.
- `scripts/network/network_movement_authority.gd`, `accept_intent()` lines 189-239.
  - `stream_id < last` is refused `stale_stream`.
  - Same stream with `sequence <= last_sequence` is refused `stale_sequence`.
  - A higher stream must start at sequence 0.
  - `register_avatar` (line 108) starts a record at `stream_id = -1`.
- Host bind and unbind: `_bind_network_remote_pilot` (8830) calls `reset_remote_ship_pilot` then `register_remote_ship_pilot`, which gives a fresh record. That happens only on a ledger grant.

## Failure scenario

1. The host is running. A client boards the Halyard pilot seat through the ledger, and the host binds the helm.
2. The client flies for 5 minutes, so the host record reaches `last_sequence` of about 4500.
3. All four cabin berths are held. The client idles its engine offline and leaves the seat into the cabin. `_request_network_client_helm_release` is refused, so the client keeps the ledger pilot seat. `_piloting` becomes false, so `_network_remote_helm` is cleared.
4. The client presses the seat again and takes the `pilot_seat_retained` path, which sends no ledger event. The helm stream restarts at sequence 0 on stream 0.
5. The host refuses every packet as `stale_sequence` for about 5 minutes. After 30 ticks the host's craft goes neutral, and the pilot's local prediction diverges from the host's copy.

## What to do

**Recommended** (this is what `db19b78bf` does): keep a per-client helm stream epoch that increments every time the client recreates the helm stream, and send it as `stream_id`.
- In GameFlow, add `var _network_remote_helm_stream_epoch := -1`. When `_advance_network_remote_helm_stream()` creates a new `_network_remote_helm` (the `ship_id` mismatch branch), increment the epoch and store it as `"stream_id"`.
- Give `build_helm_intent()` a trailing parameter `stream_id: int = 0` and pass `maxi(stream_id, 0)` to `MovementIntent.create`.
- A fresh host record (`stream_id -1`) accepts any stream starting at 0. A kept record accepts a higher one.

**Acceptable alternative:** reset the sequence only when the ledger claim (`ship_id` or role) changes, not whenever `_piloting` drops. That is more fragile, because every clearing path listed above would need to preserve the sequence.

**Contracts that must not change:**
- The `NetworkMovementAuthority` acceptance rules.
- The wire field mapping in `network_remote_pilot_command_source.gd` (`move_axis` = yaw/throttle, `look_yaw` = roll, `look_pitch` = pitch, `run`/`crouch`/`jump` = boost/brake/hover).
- `SEND_INTERVAL_TICKS` and `HOLD_TICKS`.
- Existing callers of `build_helm_intent` with 6 arguments, such as `tests/network_remote_craft_pose_test.gd:345`, must keep working through the default argument.
- Do not send ledger events from the `pilot_seat_retained` path.

## Prior partial work

The prior work is on branch `worktree-wf_bde904a0-40e-1`, in worktree `/root/mudds-shipyards/.claude/worktrees/wf_bde904a0-40e-1`, based on `92a30f7ff`. Its HEAD at writing was `24c908d75`, with a clean tree.
- **`db19b78bf`** "Remote helm restarts on a higher stream id so the host accepts it from sequence zero" is the full recommended fix: the epoch var, the epoch bump in `_advance_network_remote_helm_stream`, the `stream_id` parameter on `build_helm_intent`, and test section D2 in `tests/network_remote_pilot_helm_test.gd`. D2 asserts that a restart on the old stream is `stale_sequence` and that a restart on stream 1 is accepted. From reading, it looks complete and correct.
- **Gap in that commit's test:** D2 drives the authority with a bare adapter and hand-picked stream ids. It does not prove that GameFlow's client code actually bumps the epoch.
- **How to reuse it:** create your own branch from main and run `git cherry-pick db19b78bf`. The commit is self-contained: it touches only `game_flow.gd`, `network_remote_pilot_command_source.gd` and the helm test. **Do not edit, reset or commit in that worktree.** Another agent may still be using it.

## Files you own / must not touch

- **You own:**
  - `game_flow.gd`: the helm vars (lines 750-753 plus the new epoch var) and `_advance_network_remote_helm_stream()`.
  - `build_helm_intent()` in `network_remote_pilot_command_source.gd`.
  - Section D2 and the `_run()` line that calls it in `tests/network_remote_pilot_helm_test.gd`.
- **Do not touch:**
  - `_network_host_desired_pilot_ship` (Handoff 02).
  - `_bind_network_remote_pilot` and `_unbind_network_remote_pilot`, and `hero_ship.gd` (Handoff 04).
  - `_get_debug_actor` and `_capture_cinder_actor_sample` (Handoff 03).
  - Projectile and bolt-pool code (Handoff 06).
  - The boarding-request functions (read them only).
- **Shared files:** `game_flow.gd` is shared with 02, 03, 04 and 06, but in disjoint functions, so this can run **in parallel**. `tests/network_remote_pilot_helm_test.gd` is also edited by 02 (section A) and 04 (sections A and E). The hunks are separate, so expect at most trivial merge conflicts. Suggested merge order: 01, then 02, then 04, then 03, then 06.

## Project rules

- Every Godot invocation must include `--audio-driver Dummy`.
- Rendered runs happen only headless, or under Xvfb with `--display-driver x11` and `DISPLAY`/`WAYLAND_DISPLAY` unset. Never run on the user's desktop.
- A fresh worktree needs `godot --headless --audio-driver Dummy --path <wt> --import` once. Treat this as waiting on the testing go-ahead.
- Create your work with `git -C /root/mudds-shipyards worktree add -b <branch> <path> main`. In an existing worktree, use `git merge --ff-only main`. Never use `reset --hard`.
- Commit the generated `.gd.uid` sidecar with any new script.
- Do not add evidence validators or schema bumps (see AGENTS.md). Do not edit `ROADMAP.md`. Do not push.

## Testing

**Current user instruction: do not run tests until the user says testing may start.**

Write now:
- Keep D2 from `db19b78bf`.
- If you can do it without a new suite, add one assertion that exercises the GameFlow client path: a production client `GameFlow` whose `_network_remote_helm` is cleared and then re-advanced sends a higher `stream_id`. If that is impractical without a production client harness, say so in your report instead.

Run later:
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_pilot_helm_test.gd` (success marker `NETWORK_REMOTE_PILOT_HELM_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_craft_pose_test.gd` (success marker `NETWORK_REMOTE_CRAFT_POSE_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/network/game_flow_remote_ship_command_integration_test.gd` (success marker `OK: GameFlow remote ship command integration`).

These suites were written but have never been run (see `8a8c61ea6` and the docs).

## Definition of done

- [ ] A client helm stream recreated while the ledger seat is unchanged is accepted by the host from sequence 0.
- [ ] A restart on the old stream id is still refused.
- [ ] `build_helm_intent` keeps working when called with 6 arguments.
- [ ] No changes outside the owned regions.
- [ ] Focused test written. Suites listed for later.

## Deliverable

Deliver commits on your own branch from main. Then give a short report with:
- the commits (SHAs) and the files touched;
- whether you cherry-picked `db19b78bf` or reimplemented it, and any conflicts;
- the status of each item above;
- the suites to run once testing may start.
