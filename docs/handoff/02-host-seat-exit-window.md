# Handoff 02: Host releases its pilot seat before it has left it

- **Priority:** P2.
- **Roadmap item:** Phase 7 multiplayer, host seat occupancy and remote piloting.
- **Status at handoff:** 2026-09-27, read against `main` at `92a30f7ff`. The bug is live on main.
- **Prior partial work:** yes. There is a candidate fix in commit `effab5d97` on branch `worktree-wf_bde904a0-40e-1`. It looks correct from reading, with one behaviour question noted below. It has not been run.

## Context

The host player's own seat is an occupancy in the boarding ledger. GameFlow reconciles it every authority tick from what the host is doing. A peer the ledger seats in a pilot seat gets the host's craft bound to its helm.
- `bac902c40`: host seat occupancy in the ledger, plus the reconciler.
- `28d9271d0`: `_bind_network_remote_pilot`, which refuses `host_is_piloting`.
- `d000b9a4f`: seam suite. When the host's boarding is refused, the crewmate keeps the helm it was bound to.
- Design notes: `docs/MOVING_INTERIOR_LATENCY.md`, section "The host's own seat is a ledger occupancy".

## Problem

Two conditions disagree during the host's own exit:
- `_network_host_desired_pilot_ship()` stops returning the craft as soon as the exit **starts**. That happens either when `phase == DISEMBARKING`, or once `active_ship.set_piloted(false)` has run in `_leave_seat_into_cabin()`. Either way the reconciler releases the host's ledger seat right away.
- `_bind_network_remote_pilot()` keeps refusing `host_is_piloting` while `_piloting` is still true. `_piloting` only goes false after the exit animations and awaits finish.

If a peer claims the seat inside that window, the ledger grants it, but the bind is refused and never retried. The peer's client then flies a private copy while the host's craft never moves. The host's next boarding press is refused `seat_occupied` until the peer disembarks.

## Where (main @ 92a30f7ff)

- `scripts/game/game_flow.gd`
  - `_network_host_desired_pilot_ship()`, lines 8745-8753. The condition is `if _piloting and active_ship.is_piloted() and phase != Phase.DISEMBARKING`.
  - `_reconcile_network_host_boarding_seat()`, lines 8756-8778. It releases when the desired seat is null, and re-asks a refused seat every 30 ticks.
  - `_bind_network_remote_pilot()`, lines 8830-8870. The `host_is_piloting` refusal is at lines 8837-8840.
  - `_on_network_boarding_intent_result()`, line 10034. It calls `_bind_network_remote_pilot` once for a pilot-seat `boarded` result (line 10059) and once for a swap into the pilot seat (line 10085). Both ignore the result.
  - The landed disembark is near lines 8559-8591:
    - `phase = Phase.DISEMBARKING` (8561);
    - `set_piloted(false)` (8572);
    - several `await`s;
    - `_piloting = false` (8591).
  - `_leave_seat_into_cabin()`, lines 10910-10963:
    - `set_piloted(false)` (10942);
    - `await player.disembarking_completed`;
    - `_piloting = false` (10963).

## Failure scenario

1. The host is flying the Halyard. A client is aboard in a berth, or on the deck.
2. The host starts a disembark, or leaves the seat into the cabin. On the next tick the reconciler releases the host's ledger seat.
3. During the roughly 1-2 s exit animation, the client presses the pilot seat. It may be promoted from a berth through a swap, or come in through the hatch. The ledger grants the seat, and the host's bind returns `host_is_piloting`.
4. The client is seated locally and streams helm packets. The host has no binding, so nothing moves on the host. The host's craft is now held by the peer, and the host's own board press is refused `seat_occupied`.

## What to do

**Recommended** (this is what `effab5d97` does): hold the host's seat for exactly as long as the bind refuses. `_network_host_desired_pilot_ship()` returns `active_ship` whenever `_piloting` is true (the `BOARDING` branch and the destroyed check stay). A peer claiming mid-exit is then refused `seat_occupied` and can press again once the host is off the seat.

**Acceptable alternative:** keep the current seat release, and add a pending bind that is retried every tick once `_piloting` goes false. Remember a refused `host_is_piloting` grant, and drop it if the ledger releases the seat meanwhile. This is more code and still has a period in which the peer's copy is private.

**Behaviour question to check (either fix):** on an Ember surface visit, `_piloting` stays true while the host is on foot. See the comment in `_capture_cinder_actor_sample()`, around lines 5650-5655. With the recommended fix, the host would hold its pilot seat for the whole surface walk. On main, however, the bind already refuses in that state, so a peer could never usefully fly it then anyway. The recommended fix only makes the ledger agree with the bind. If you judge the surface case needs a peer to be able to take the helm, both predicates must change together through a shared helper. Do not change only one of them.

**Contracts that must not change:**
- The reconciler must still release on every way out of the seat: disembark, leave into cabin, aborted boarding, a destroyed craft, respawn and session stop.
- The 30-tick re-ask cadence.
- Ledger refusal reasons.
- `_bind_network_remote_pilot`'s refusal must not be removed. It is the last guard against taking the helm out of the host's hands.

## Prior partial work

The prior work is on branch `worktree-wf_bde904a0-40e-1`, in worktree `/root/mudds-shipyards/.claude/worktrees/wf_bde904a0-40e-1`. Its HEAD at writing was `24c908d75`, with a clean tree.
- **`effab5d97`** "Host keeps its ledger pilot seat until it is off the seat, not when its exit starts" contains:
  - the one-line predicate change and doc comment in `_network_host_desired_pilot_ship()`;
  - a synchronous probe `_assert_the_host_keeps_its_seat_while_climbing_out()` in `tests/network_remote_pilot_helm_test.gd`, called at the start of section A. It sets `_piloting`/`phase` directly and restores them.
- **Assessment:** complete and correct as far as reading shows. The test only probes the predicate. It does not drive a real mid-exit peer claim.
- **How to reuse it:** create your own branch from main and run `git cherry-pick effab5d97`. It is not textually dependent on `db19b78bf` (Handoff 01). If the test hunk fuzzes, it is only because D2 is absent. **Do not edit that worktree.**

## Files you own / must not touch

- **You own:** `_network_host_desired_pilot_ship()` in `game_flow.gd`, and the new host-seat probe in section A of `tests/network_remote_pilot_helm_test.gd`.
- **Read only:** `_bind_network_remote_pilot`, the disembark and leave-seat flows, and the reconciler body. If you take the pending-bind alternative, you would also own a new helper plus one call site in `_advance_network_boarding_authority` (lines 8734-8742). Coordinate with Handoff 04 before touching `_bind_network_remote_pilot` itself.
- **Shared files:** `game_flow.gd` is shared with 01, 03, 04 and 06, in disjoint functions, so this can run **in parallel**. The helm test is shared with 01 (D2) and 04 (section A and E asserts). Section A is also edited by 04, directly after the camera check, so merge 02 before 04.

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
- The predicate probe from `effab5d97`. It covers mid-disembark: seat held. Once on foot: released.
- Optionally, add a second probe for the leave-into-cabin state: `_piloting` true, `phase == IN_FLIGHT_CABIN`, `active_ship.is_piloted()` false. The seat must still be held.

Run later:
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_remote_pilot_helm_test.gd` (success marker `NETWORK_REMOTE_PILOT_HELM_TEST_OK`).
- `godot --headless --audio-driver Dummy --path . --script res://tests/network/network_enet_boarding_ledger_test.gd` (the host seat and session stop). Check its final `print` for the marker.
- `godot --headless --audio-driver Dummy --path . --script res://tests/network_client_boarding_seam_test.gd` (success marker `NETWORK_CLIENT_BOARDING_SEAM_TEST_OK`).

## Definition of done

- [ ] The host's ledger seat is held whenever `_bind_network_remote_pilot` would refuse `host_is_piloting`, and released once `_piloting` is false.
- [ ] A peer's claim in the exit window is refused `seat_occupied`. It is not granted and left unbound.
- [ ] Every existing release path still releases.
- [ ] The Ember surface question is answered in the report.
- [ ] Focused probe written. Suites listed for later.

## Deliverable

Deliver commits on your own branch from main. Then give a short report with:
- the commits and the files touched;
- whether you cherry-picked or reimplemented;
- your answer on the Ember surface case;
- the status of each item above;
- the suites to run once testing may start.
