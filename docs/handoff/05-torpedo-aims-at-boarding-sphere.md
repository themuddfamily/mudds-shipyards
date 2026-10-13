# Handoff 05: Seeker torpedo aims and fuses on the boarding sphere, not the hull

- **Priority:** P2 (visible combat bug: torpedo detonates beside the ship and does no damage).
- **Roadmap item:** Torpedo boat opponent / Torpedo Run sortie (combat opponent roster).
- **Status at handoff:** 2026-09-27, read against `main` @ `92a30f7ff`. Not fixed on main.
- **Prior partial work:** yes. Branch `worktree-wf_bde904a0-40e-2`, commit `b0cb8d684`. It fixes the aim and adds an aim regression test. The near-miss presentation and its test are only partly done. See "Prior partial work".

## Context
Seeker torpedoes, the torpedo boat opponent and the Torpedo Run sortie all landed on 2026-09-27:
- `7680a0cd0` added the torpedo boat, its seeker-torpedo opponent and Torpedo Run.
- `d40b65d92` added tests for torpedo hit, dodge and shoot-down, and for the torpedo boat contract. These tests use a synthetic single-box target only.
- `3757dabc6` holds the charge lenses steady under reduced flash.
- `d648f079b`, `19e819638` and `794ca97a0` added the Torpedo Run reward receipt and the torpedo audio (`TorpedoRunAudio`: launch, lock, flight, intercept, detonation and expired cues).
- `aca8cb9e4` releases the visuals of dormant opponents from the resident tree. The torpedo pool is a direct child of the craft, not of the released visual root, so that change does not affect this bug.

## Problem
`_find_aim_shape` returns the first enabled `CollisionShape3D` anywhere under the target. The seeker steers at that shape and the proximity fuse measures against it.

On every production hero ship (Torrent, Bulwark, Halyard) the first such shape is `ShipBoardingArea/BoardingRange`:
- It is a 4.5 m interaction sphere, offset from the hull. Offsets: Torrent (-3.2, 0.55, 0.65), Bulwark (-5.9, 0.48, 1.0), Halyard (-3.3, -0.05, -11.6).
- It sits on the INTERACTABLE layer (`collision_layer = 8`, set in `scenes/interaction/ship_boarding_area.tscn`).
- That layer is not in `PhysicsLayers.HITSCAN_QUERY_MASK`, which is `WORLD | PLAYER | SHIP | TARGET` (`scripts/core/physics_layers.gd:71`, `:27`).

A torpedo coming from the boarding side fuses within 3.2 m of a point that is off the hull. The arrival sweep in `resolve_projectile_arrival` misses the hull. `_terminate_slot` still starts the burst because `reason == &"proximity_fuse"`. `TorpedoRunAudio.present_resolved` also plays `CUE_DETONATION` for any `proximity_fuse`. The player sees and hears a detonation that deals no damage.

## Where (main @ 92a30f7ff)
- `scripts/combat/seeker_torpedo_projectile.gd`
  - `launch()` (line 164): at line 194 it sets `slot["target_shape"] = _find_aim_shape(target)`.
  - `_advance_slot()` (line 421): the proximity fuse check is at lines 444-450 and uses `PROXIMITY_FUSE_METERS := 3.2` (line 68).
  - `_target_point()` (line 488): returns the aim shape's `global_position`. If there is no aim shape, it falls back to `target.global_position`.
  - `_find_aim_shape()` (lines 502-509): the bug.
  - `_detect_contact()` (line 512): the ray uses `HITSCAN_QUERY_MASK`.
  - `_terminate_slot()` (line 542): lines 570-571 run `if damaged or reason == &"proximity_fuse": _start_burst(...)`.
  - `_start_burst()` (line 679): draws the same burst for every caller, whether hit, fizzle or intercept.
- `scripts/combat/torpedo_run_audio.gd`, `present_resolved()` (line 134): line 136 is `detonated := damaged or reason == &"proximity_fuse"`.
- `scripts/network/network_remote_projectile_replicator.gd`, `_on_resolved()` (line 233): sets `kind` from `result.hit` and forwards `record.terminal_reason`. It is already correct for a miss and is listed here only because it consumes the record.
- Scenes involved: `scenes/ships/torrent_interceptor.tscn`, `bulwark_heavy_gunship.tscn` and `halyard_crew_transport.tscn`. Each ship is a `CharacterBody3D` with `collision_layer = 4` (SHIP) and a `ShipBoardingArea` instance.

## Failure scenario
1. Start a Torpedo Run and fly a hero ship (for example Torrent).
2. Put the ship's boarding side (for Torrent, local -X) towards the torpedo boat and hold still.
3. The torpedo homes on the boarding sphere's centre, about 3.3 m off the hull, and fuses within 3.2 m of it.
4. The sweep from the fuse position to that point misses the SHIP body. `result.damaged` is false and hull health is unchanged.
5. The burst appears and the detonation cue plays anyway: a hit that did nothing.

## What to do
1. **Aim only at strikable shapes.** In `_find_aim_shape`, accept a shape only if its parent is a `CollisionObject3D` whose `collision_layer & HITSCAN_QUERY_MASK != 0`. This skips Area3D interaction volumes on INTERACTABLE. Skip the target's own torpedo-pool hurtboxes. If no shape qualifies, return null so the seeker falls back to `target.global_position`.
   - Acceptable alternative: aim at the centre of the strikable shapes' combined AABB. Optionally, prefer the largest strikable shape over the first one.
2. **Claim a detonation only when something was hit.** A `proximity_fuse` ending whose resolver result has `damaged == false` is a near miss. It must not play `CUE_DETONATION` or show the full detonation burst. Show a small or reduced fizzle, or no burst.
   - Preferred: decide this in `TorpedoRunAudio.present_resolved` from the result (`detonated := damaged`, or `damaged or result.hit` if striking world geometry should count). Do not rewrite `terminal_reason` in the pool.
   - Contracts that must not change:
     - the signal signatures `torpedo_resolved(record, result)`, `torpedo_abandoned`, `torpedo_intercepted` and `torpedo_launched`;
     - the terminal reason set in the record: `impact`, `proximity_fuse`, `lifetime`, `range`;
     - `LiveCombatAuthority` resolver authority, so that every flown-out ending still goes through `resolve_projectile_arrival`;
     - one hit per torpedo;
     - reduced-flash behaviour;
     - the network replicator payload (`kind` from `result.hit`).

## Prior partial work
Branch `worktree-wf_bde904a0-40e-2`, worktree `/root/mudds-shipyards/.claude/worktrees/wf_bde904a0-40e-2`, based on `92a30f7ff`. When this brief was written the worktree was clean and had one commit, `b0cb8d684`. That agent may still be running. **Do not edit that worktree.**

What the commit does:
- `_find_aim_shape` now keeps only shapes whose parent `CollisionObject3D` is on a hitscan-queried layer. A new helper, `_is_under_torpedo_pool`, skips the pool's own hurtboxes. This part matches recommendation 1 and looks correct.
- In `_terminate_slot`, a `proximity_fuse` ending with no damage still calls `_start_burst`, which draws the full detonation burst. The commit comment calls this a "fizzle", but `_start_burst` is the same burst for every caller. Audio gets a duplicated record with `terminal_reason = &"proximity_fuse_near_miss"`, so `present_resolved` plays `CUE_EXPIRED`. The emitted `torpedo_resolved` record is unchanged.
- `tests/seeker_torpedo_projectile_test.gd` gains `_test_offset_interaction_volume`. It builds a SHIP `CharacterBody3D` with an offset INTERACTABLE `ShipBoardingArea` sphere, added first, and a hull box. It asserts three things:
  - the aim shape is the hull;
  - a target that has only an interaction volume returns null;
  - a torpedo launched from the boarding side damages the hull once (34 damage).
  This covers the aim.

What remains:
- (a) The near miss still shows the full burst. Either give it a distinct, smaller fizzle or no burst, or accept the full burst explicitly and record that decision.
- (b) No test covers the near-miss path: a `proximity_fuse` ending with `damaged == false` that must play `CUE_EXPIRED`, not `CUE_DETONATION`. The audio fix relies on an invented terminal reason. Moving the decision into `TorpedoRunAudio` is cleaner.
- (c) Optional: prefer the largest strikable shape over the first.

How to reuse it: create your own branch from main, then run `git cherry-pick b0cb8d684`, then build (a) and (b) on top.

## Files you own / must not touch
- **Own:** `scripts/combat/seeker_torpedo_projectile.gd`, `scripts/combat/torpedo_run_audio.gd`, `tests/seeker_torpedo_projectile_test.gd`, `tests/torpedo_run_audio_test.gd`.
- **Do not touch:**
  - `scripts/network/network_remote_projectile_replicator.gd`
  - the ship scenes and `scenes/interaction/ship_boarding_area.tscn`: do not move or re-layer the boarding sphere
  - `scripts/core/physics_layers.gd`
  - `LiveCombatAuthority`
  - `ROADMAP.md`
  - the other agent's worktree
- **Collisions:** check the other `docs/handoff/*.md` briefs. Any brief that touches the torpedo boat, `seeker_torpedo_projectile.gd` or the torpedo audio must be done one after the other with this one, not in parallel.

## Project rules
- Every Godot invocation must include `--audio-driver Dummy`. `--headless` alone does not silence audio.
- Rendered runs only headless, or under Xvfb with `--display-driver x11` and `DISPLAY`/`WAYLAND_DISPLAY` unset. Never run on the user's desktop.
- A fresh worktree needs `godot --headless --audio-driver Dummy --path <wt> --import` once before anything else.
- Create your work with `git -C /root/mudds-shipyards worktree add -b <branch> <path> main`. In an existing worktree, update with `git merge --ff-only main`. Never `reset --hard`.
- Commit the generated `.gd.uid` sidecar together with any new script.
- Do not add evidence validators, versioned validators or schema bumps (AGENTS.md).
- Do not edit `ROADMAP.md`. Do not push.

## Testing
**Current user instruction: do not run any tests until the user says testing may start.** Write the tests now; run them later.

Tests to add or update now (written, not run):
- `tests/seeker_torpedo_projectile_test.gd`: keep `_test_offset_interaction_volume` from `b0cb8d684`. Add a near-miss case: fuse a torpedo against a target whose aim point is off every strikable shape, for example a target with no hitscan body so the seeker falls back to its origin. Assert that `torpedo_resolved` fires once with `damaged == false`, that no health changes, and that the flight count returns to 0. Also assert your chosen burst behaviour.
- `tests/torpedo_run_audio_test.gd`: assert that a `proximity_fuse` result with `damaged == false` plays `CUE_EXPIRED` and not `CUE_DETONATION`. Keep the existing assertion "a torpedo that hits detonates once" passing.

Suites to run later, from the worktree root:
| Suite | Command | Success marker |
|---|---|---|
| Seeker torpedo projectile | `godot --headless --audio-driver Dummy --path . --script res://tests/seeker_torpedo_projectile_test.gd` | `SEEKER_TORPEDO_PROJECTILE_TEST_OK` |
| Torpedo Run audio | `godot --headless --audio-driver Dummy --path . --script res://tests/torpedo_run_audio_test.gd` | `TORPEDO_RUN_AUDIO_TEST_OK` |
| Torpedo boat opponent | `godot --headless --audio-driver Dummy --path . --script res://tests/torpedo_boat_opponent_test.gd` | `TORPEDO_BOAT_OPPONENT_TEST_OK` |
| Network remote projectile | `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_projectile_test.gd` | `NETWORK_REMOTE_PROJECTILE_TEST_OK` |

## Definition of done
- [ ] The seeker aim point is never an INTERACTABLE/Area3D interaction shape. With no strikable shape it falls back to `target.global_position`.
- [ ] A torpedo from the boarding side of a hull-plus-offset-sphere ship damages the hull exactly once.
- [ ] A proximity-fuse near miss (no damage) plays no detonation cue and shows no full detonation burst.
- [ ] The signal signatures, terminal reasons, resolver path and network payload are unchanged.
- [ ] The regression tests above are written, and `.gd.uid` sidecars are committed for any new files.
- [ ] The four suites pass once the user allows testing.

## Deliverable
Deliver commits on your own branch from main, not pushed, plus a short report containing:
- the commit SHAs and subjects, and the files changed;
- the status of items 1, 2(a) and 2(b) and of the optional largest-shape item: done, skipped or declined, with the reason;
- the suites to run later, with their markers, and whether any were run (none should be until the user allows it).
