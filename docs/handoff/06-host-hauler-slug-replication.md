# Handoff 06: Host's own Cinder hauler slugs reach clients

- **Priority:** P3.
- **Roadmap item:** Phase 7 multiplayer, replicated combat presentation (remote projectiles).
- **Status at handoff:** 2026-09-27, read against `main` at `92a30f7ff`.
  - Mostly **already covered on main** by `c7b2ff9df`.
  - One real gap remains: the host's first slug after its bolt pool is created is never replicated.
  - The production wiring is untested.
- **Prior partial work:** none for this finding. The fixer branch `worktree-wf_bde904a0-40e-1` (HEAD `24c908d75`) does not touch projectiles.

## Context

- `a2c1a7a5f` "Fire the Cinder cargo hauler mass driver as travelling bolts". The hauler's shots left the hitscan `authoritative_shot_submitted` path, which is where GameFlow builds the player-pulse network context (`_on_authoritative_shot_submitted`, `scripts/game/game_flow.gd:11165`). They now go through the GameFlow-owned `_player_bolt_pool` (a `MassDriverBoltPool`, which is a `TravellingBoltProjectile`). After that commit, clients saw neither the host's hauler shots nor their impacts.
- `4aaa160a4` added `scripts/network/network_remote_projectile_replicator.gd`.
- `c7b2ff9df` wired it into GameFlow. The host observes `_player_bolt_pool` as `KIND_SLUG`, with source `&"player-mass-driver"`, and the torpedo boat's pool. Clients present the records.
- `8a8c61ea6`: `tests/network_remote_projectile_test.gd` (written, never run). It uses bare adapters and stand-in pools, **not** GameFlow.
- Design notes: `docs/MOVING_INTERIOR_LATENCY.md`, "Remote projectiles".

## Problem (re-assessed by reading)

**Covered.** The review asked whether the replicator covers the host player's own `_player_bolt_pool`, and not just remote-piloted craft. It does.
- `_advance_network_remote_projectiles()` (`game_flow.gd:9156-9175`) calls `replicator.observe_pool(_player_bolt_pool, KIND_SLUG, &"player-mass-driver")`.
- That pool is fed only by `_on_projectile_fired()` → `_launch_player_travelling_bolt()`. `_on_projectile_fired` returns unless `firing_ship == active_ship` (line 11068), and clients return before launching (line 11070).
- So the pool only ever holds the **host player's own** shots. A remote helm never fires, because `NetworkRemotePilotCommandSource` carries no fire edge.
- `observe_pool()` connects `bolt_launched`, `bolt_resolved` and `bolt_abandoned` (replicator lines 87-117). Each becomes a record through `_publish_network_remote_projectile()` (`game_flow.gd:9178`). The client routes records carrying `RECORD_KEY` to `_present_network_remote_projectile()` (`_on_projectile_replica_packet`, line 5439). Late joiners get `republish_for_peer` (line 6292).

**Remaining gap 1: the first shot is lost.** `_player_bolt_pool` is created lazily *inside* the shot:
1. `_launch_player_travelling_bolt()` (line 11134) calls `_ensure_player_bolt_pool()` (line 11113). That creates the pool and immediately calls `pool.launch()`.
2. `launch()` emits `bolt_launched` synchronously (`scripts/combat/travelling_bolt_projectile.gd:176`, inside `launch()` at line 132).
3. The replicator only starts observing on the next `_advance_network_remote_projectiles()` tick (called at `game_flow.gd:4484`).

So the host's first hauler slug in a session is never published, and neither is the first after the pool is recreated. The client also never sees that slug's burst: `_end_flight` finds no active entry and returns (replicator line 249).

**Remaining gap 2 (note only, out of scope):** the whole server publication block, including `_advance_network_remote_projectiles()`, sits after the Aurora and Rime early returns in `_physics_process` (lines 4452-4465). No slugs are replicated during those visits. Record this in the report; do not fix it here.

**Remaining gap 3 (owner decision):** the replicator draws a slug and a burst but plays no audio on clients. Before `a2c1a7a5f`, the hitscan pulse replica path did play audio. Check `_on_player_pulse_replica_packet`, and report whether clients should hear the host's hauler fire and impact. Only implement it if it is small and uses the existing `combat_audio` presentation.

## Where (main @ 92a30f7ff)

- `scripts/game/game_flow.gd`:
  - `_on_projectile_fired` (11066);
  - `_ensure_player_bolt_pool` (11113-11127);
  - `_launch_player_travelling_bolt` (11134-11145);
  - `_ensure_network_remote_projectile_replicator` (9140-9152);
  - `_advance_network_remote_projectiles` (9156-9175);
  - `_publish_network_remote_projectile` (9178-9192);
  - `_clear_network_remote_projectiles` (9213);
  - the physics call site (4484).
- `scripts/network/network_remote_projectile_replicator.gd`: `observe_pool`, `is_observing`, `get_audit`. Read only, unless something is proven wrong.

## Failure scenario

1. The host hosts a session, and a client joins.
2. The host boards the Cinder cargo hauler and fires its mass driver once. `_player_bolt_pool` is created during this shot.
3. On the client, no slug and no impact burst appear for that shot. Later shots do appear.

## What to do

**Recommended:** observe the pool as soon as it exists, on a server.
- Add a helper, for example `_observe_player_bolt_pool_for_network(pool)`. On a server with a live session, it calls `_ensure_network_remote_projectile_replicator().observe_pool(pool, KIND_SLUG, &"player-mass-driver")`.
- Call it from `_ensure_player_bolt_pool()` right after `add_child` and `bind_authority`, before it returns the new pool.
- `observe_pool` is idempotent (`already_observed`), so the existing per-tick check in `_advance_network_remote_projectiles()` can stay as a backstop. It still covers a pool created before hosting started.

**Acceptable alternative:** create and observe `_player_bolt_pool` eagerly when the session starts as server (`_on_network_session_started`).

**Contracts that must not change:**
- Records flow host → client only, and clients never open flights or apply damage.
- The player-pulse tick stamping in `_publish_network_remote_projectile`.
- `_on_projectile_fired`'s client refusal and `active_ship` guard.
- The replicator's record shape and `RECORD_KEY`.

Do not re-route hauler shots back through the hitscan path.

## Prior partial work

None. Nothing on `worktree-wf_bde904a0-40e-1` touches this area. If you consult that worktree, do so read-only.

## Files you own / must not touch

- **You own:**
  - `_ensure_player_bolt_pool()`, the new observe helper, and (if needed) `_advance_network_remote_projectiles()` in `game_flow.gd`;
  - any focused test you add.
- **Read only:** `network_remote_projectile_replicator.gd`, `mass_driver_bolt_pool.gd` and `travelling_bolt_projectile.gd`. Change them only for a proven defect, and say so in the report.
- **Do not touch:**
  - helm stream (01);
  - host seat (02);
  - actor samplers (03);
  - bind and unbind and `hero_ship.gd` (04).
- **Shared files:** `game_flow.gd` is shared with 01-04 in disjoint regions, so this is **fully parallel**.

## Project rules

- Every Godot invocation must include `--audio-driver Dummy`.
- Rendered runs happen only headless, or under Xvfb with `--display-driver x11` and `DISPLAY`/`WAYLAND_DISPLAY` unset. Never run on the user's desktop.
- A fresh worktree needs `godot --headless --audio-driver Dummy --path <wt> --import` once. Treat this as waiting on the testing go-ahead.
- Create your work with `git -C /root/mudds-shipyards worktree add -b <branch> <path> main`. In an existing worktree, use `git merge --ff-only main`. Never use `reset --hard`.
- Commit the generated `.gd.uid` sidecar with any new script.
- Do not add evidence validators or schema bumps (see AGENTS.md). Do not edit `ROADMAP.md`. Do not push.

## Testing

**Current user instruction: do not run tests until the user says testing may start.**

Write now. Prefer extending an existing production-host network suite, such as `tests/network_remote_pilot_helm_test.gd` or `tests/network_remote_craft_pose_test.gd`, over creating a new one. The assertion:
- On the production host `GameFlow`, after `host_network_session()` and with `_player_bolt_pool` still null, launch one bolt with `_host._launch_player_travelling_bolt(hauler, weapon_id, origin, dir)`. Use the hauler and its travelling weapon id; `_player_weapon_is_travelling` picks the weapon.
- Then assert, synchronously and before any physics tick:
  - `get_network_remote_projectile_replicator().get_audit().published == 1`;
  - `.active_flights == 1`.
- If a bare client is connected, optionally assert that it receives a record with `remote_projectile_record`.

Run later:
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_projectile_test.gd` (success marker `NETWORK_REMOTE_PROJECTILE_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/cinder_cargo_mass_driver_bolt_test.gd` (success marker `CINDER_CARGO_MASS_DRIVER_BOLT_TEST_OK`).
- The suite you extended, with its marker.

## Definition of done

- [ ] The host's first hauler slug in a session is published: it has a launch record and a terminal.
- [ ] The report states, with the evidence above, that the host player's own pool was already covered by `c7b2ff9df`.
- [ ] Gaps 2 and 3 are recorded, and gap 3 is either decided or implemented small.
- [ ] Solo (no session) hauler fire is unchanged: no replicator is created offline.
- [ ] Focused assert written. Suites listed for later.

## Deliverable

Deliver commits on your own branch from main. Then give a short report with:
- the commits and the files touched;
- the status of each gap;
- the suites to run once testing may start.
