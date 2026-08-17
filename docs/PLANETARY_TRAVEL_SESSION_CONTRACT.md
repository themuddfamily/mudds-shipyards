# Planetary travel session contract

`PlanetaryTravelSession` is a standalone Phase 10 lifecycle foundation. It
records one reusable planetary visit from validated composition data,
caller-supplied physics time, and explicit external observations. This slice
does not wire the session into production.

## Configuration and ordered loop

Construction requires four inputs: a stable session ID, a valid
`PlanetaryWorldDefinition`, one configured `PlanetaryCoordinateFrame`, and the
exact detached result of `PlanetaryWorldCompositionValidator`. The report is
strictly schema-, identity-, datum-, bounds-, evidence-, and authority-checked,
then deeply frozen. A lookalike report with extra fields, errors, mismatched
world/terrain/atmosphere IDs, invalid surface bounds, inconsistent radius, or
anything other than the common 12-key all-false authority roster is rejected.

The atmospheric route is exact:

`ORBIT_APPROACH → ATMOSPHERIC_ENTRY → DESCENT → SURFACE_FLIGHT → LANDED → ON_FOOT → REBOARDED → TAKEOFF → ASCENT → ORBIT_RETURN → COMPLETED`

An airless composition follows the same route but transitions directly from
`ORBIT_APPROACH` to `DESCENT`. `FAILED` and `ABORTED` are distinct terminal
states. Only an explicit `reset()` returns a started journey to `IDLE`.
Reset advances the session generation and tombstones delayed calls; calling it
again while already `IDLE` rejects without consuming another generation.

Every mutator requires the current session generation. Attachment, clock, and
transition methods also require the current attachment generation. Attachment
accepts only the configured world ID and exact coordinate-frame object.
Detach preserves state, clocks, reports, and samples; same-object re-entry
increments only attachment generation, with no phase replay.

## Caller physics and absolute observations

No process loop or wall clock exists. `advance_physics()` accepts finite caller
delta from 0 through 0.25 seconds. Zero freezes the session. Total accepted time
is bounded to 604,800 seconds. Rejected calls leave state byte-for-byte
unchanged.

Flight observations carry a canonical absolute orbital-coordinate dictionary,
the current coordinate-frame generation, and a finite non-negative speed no
greater than 100,000 m/s. The speed limit is only an input bound, not a flight
or landing rule. The coordinate frame validates and decodes the absolute record
to body-local position. World-streaming positions are never persisted.

Lifecycle prerequisites are intentionally limited to composed facts, authored
anchors, and explicit caller confirmations:

| Current state | Required observation | Next state |
| --- | --- | --- |
| `ORBIT_APPROACH` | canonical absolute position plus caller-confirmed orbital handoff | `ATMOSPHERIC_ENTRY`, or `DESCENT` when airless |
| `ATMOSPHERIC_ENTRY` | radial distance at or inside the validated composition report's atmosphere outer shell | `DESCENT` |
| `DESCENT` | radial distance at or inside the world's authored navigation-anchor radius, with an exact landing-composition report already bound | `SURFACE_FLIGHT` |
| `SURFACE_FLIGHT` | caller-confirmed landed fact plus exact bound world/body/terrain/region identity | `LANDED` |
| `LANDED` | caller-confirmed player-on-foot and ship-still-landed facts | `ON_FOOT` |
| `ON_FOOT` | caller-confirmed reboarded and ship-still-landed facts | `REBOARDED` |
| `REBOARDED` | caller-confirmed takeoff-started and not-landed facts | `TAKEOFF` |
| `TAKEOFF` | canonical absolute position plus caller-confirmed surface clearance | `ASCENT` |
| `ASCENT` | radial distance at or beyond the world's authored orbital-anchor radius | `ORBIT_RETURN` |
| `ORBIT_RETURN` | canonical absolute position plus caller-confirmed orbital handoff | `COMPLETED` |

There is no session-authored 80/100 km shell, landing radius, landing altitude,
landing slope, landing speed, or touchdown threshold. The atmosphere boundary
comes from the frozen world composition. Surface and orbit boundaries come
from its validated surface data and the world's authored navigation/orbital
anchors. Landing geometry and eligibility remain in the landing contracts.

## Landing composition and rebasing

Before `DESCENT` can enter `SURFACE_FLIGHT`, the caller must bind the exact
detached result of `PlanetaryLandingCompositionValidator`. The session validates
the complete report schema, empty errors, world/body/terrain/region IDs,
sea-level datum, body radius, finite body-local region centre, evidence roster,
and common 12-key all-false authority report. The report supplies composition
identity only; it never proves a live ship has landed.

Landing composition is body-local and therefore remains valid when only the
world-streaming origin rebases. Its report retains the coordinate-frame
generation at which the join was validated as provenance, but a later rebase
does not invalidate the body-local identity. Every new absolute flight sample,
however, must name the coordinate frame's current generation. Tests freeze both
behaviours: stale local-mapping generations reject, while the same canonical
absolute orbital coordinate and bound landing identity survive a rebase.

## Commit, snapshot, and authority rules

State, progress, duration, terminal reason, and last sample commit before any
signal. Domain signals precede `presentation_changed`. On the final sample,
`phase_changed` observes `COMPLETED` before `session_completed`. Synchronous
subscriber attempts to call any mutator return `reentrant_call` and cannot
alter the committed snapshot.

`get_presentation_snapshot()` is deeply detached and remains available while
detached. It includes state/next-state/branch IDs, session and attachment
generations, last observed coordinate-frame generation, caller clocks,
progress, last accepted absolute sample, frozen landing composition, and a
HUD-ready presentation dictionary. It does not reference or mutate HUD code.

The session and both required composition reports publish the exact common
12-key authority roster, all `false`: renderer, gameplay, streaming, save,
network, physics, world generation, terrain generation, collision generation,
origin shift, weather clock, and audio. The session additionally exposes flat
compatibility flags showing no gameplay, ship movement, landing, terrain,
reward, streaming, save, or render authority. Completion is only a typed
lifecycle result; it grants no reward and causes no movement, landing, terrain
generation, streaming, persistence, or rendering action.

## Focused validation

Run only:

```bash
godot --headless --editor --path . --quit
godot --headless --audio-driver Dummy --path . \
  --script res://tests/planetary_travel_session_test.gd
```

The focused suite covers atmospheric and airless ordering, strict composition
reports, composed shell/authored-anchor boundaries, current-generation
absolute samples, body-local landing rebase invariance, caller timing,
abort/fail/reset, IDLE reset, detach/re-entry, stale tokens, deep snapshots,
committed signal chronology, subscriber re-entry, and zero authority.
