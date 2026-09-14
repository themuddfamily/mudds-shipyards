# Long-session soak

`tests/long_session_soak_test.gd` drives production `Main` through N full play
cycles in one process (default 12, `KETH_SOAK_CYCLES` overrides), rotating across
all nine flyable craft. Each cycle starts and abandons one nearby-sector activity
(the station perimeter-defense encounter), walks to the craft with real
locomotion input, boards with a real `interact` press, wakes propulsion through
the automatic-propulsion demand, launches, flies a leg, fires the live weapon,
returns through the berth's own published assist-capture lane, lands with the
real landing assist and disembarks. Every third cycle also takes real non-fatal
damage in flight and then loses and recovers the craft through the berth
regeneration lifecycle; every fourth cycle commits the production settings and
session saves and streams the whole `Main` subtree out of the tree and back in.

Each cycle prints one `SOAK_CYCLE` JSON line; the run ends with a `SOAK_SUMMARY`
JSON line. The log is the evidence.

Settings and session commits go to an injected in-memory `UserDataStore`, so the
soak never writes the player's `user://` state and never races other suites for
that file.

Run: `godot --headless --audio-driver Dummy --path . --script
res://tests/long_session_soak_test.gd`. Default (12 cycles) takes ~134 s alone
and ~142 s inside `run_test_matrix.sh` at `--jobs 8`, so it fits the matrix's
default 180 s per-suite timeout. `KETH_SOAK_CYCLES=48` is an evidence-only run
(~9 min).
`KETH_SOAK_MATERIAL_CENSUS=off|boundary|all` controls the retained-material
census (default `boundary`: the warm-up boundary and the final cycle).

## 48-cycle counters, before and after the fixes

Cycle 4 is the warm-up boundary (the first point at which a plain sortie, a
damage/destruction cycle and a whole-`Main` re-entry have each run once).

| counter | before: c4 → c48 (range) | after: c4 → c48 (range) |
| --- | --- | --- |
| `scene_nodes` | 11496 → **11520** (11483–11520, monotonic) | 11495 → 11496 (11483–11496) |
| `object_nodes` | 12220 → **12244** (12207–12244, monotonic) | 12219 → 12220 (12207–12220) |
| `objects` (ObjectDB) | 24662 → **26364** (+1702, monotonic) | 24938 → 24988 (24938–25060) |
| `static_memory` | 474.3 → **480.0 MB** (+5.7 MB, monotonic) | 472.4 → 473.7 MB (+1.3 MB) |
| `combat_sources` | **9 ↔ 12** (12 only on re-entry cycles) | 12 (flat) |
| `hud_controls` | 1320 → 1322 (1309–1322) | 1321 → 1322 (1309–1322) |
| `orphan_nodes` | 5–6 (flat) | 5–6 (flat) |
| `audio_players` | 80 (flat) | 80 (flat) |
| `particle_systems` / emitting | 45 / 0 (flat) | 45 / 0 (flat) |
| `timers` / `timers_running` | 21 / 0 (flat) | 21 / 0 (flat) |
| `tweens` | 0–3 (transient) | 1–3 (transient) |
| `retained_materials` | 969 (flat) | 969 (flat) |
| `render_objects_in_frame` | 0 (headless; recorded, not meaningful) | 0 |

The three leaking counters before the fixes climbed steadily across all 44
post-warm-up cycles: `objects` by about 37 per cycle, and `scene_nodes` /
`object_nodes` by two per whole-`Main` re-entry. After the fixes every counter
sits inside a fixed band for the whole run, and the 48-cycle run passes the
suite's own flatness assertions (211 assertions, zero failures). At the final teardown
`OBJECT_NODE_COUNT` returned to the pre-boot baseline in both runs, and orphan
nodes were zero after teardown in both, so nothing survived process teardown —
the growth was all within the live session, which is exactly what a player
experiences.

The six orphan nodes reported while `Main` is alive are stable, not a leak:
production deliberately retains a few detached helper `Node`s (for example the
three `BomberPayloadBinding` holders inside `FleetExpansionAudioBinding`). They
are freed with the tree.

The retained-material *fingerprint* is recorded but not asserted: its descriptors
carry the scene path each material was reached through, and a regenerated berth
presentation legitimately changes those paths without retaining one extra
material. The count is the leak-bearing half of that census.

## What leaked, and what was fixed

### 1. Two dead semantic-audio adapters per whole-`Main` re-entry

`scripts/audio/optional_semantic_audio_composition.gd` built a fresh
`CinderLoadmasterAudioProductionBinding` and
`PlanetaryFinalApproachAudioProductionBinding` in every `attach()` and added both
as children. `detach()` — which `_exit_tree()` calls on every detach — cleared
`_attached` but never removed or freed them, so `GameFlow`'s
`_initialize_optional_semantic_audio()` added a second, third, fourth dead pair
on each re-entry. Measured at +2 nodes and about +51 ObjectDB objects per
re-entry, unbounded.

Player-facing: every station re-entry (a save/reload or a streamed re-entry)
permanently added two abandoned crew/final-approach audio adapter nodes to the
live tree, so a long session's node count and memory grew with the number of
re-entries.

Fix: reuse the retained adapters when they already exist, exactly as the
navigator composition beside them already did. Focused assertion in
`tests/audio/optional_semantic_audio_composition_test.gd`: four detach/attach
rounds must not change the composition's child count.

### 2. The HUD palette registry retained every control it ever tinted

`scripts/ui/hud.gd` registers a palette target for every control, rect and style
box it builds, and retired entries were pruned **only** inside `set_hud_palette()`
— which a normal session never calls. Worse, style-box entries held the
`StyleBoxFlat` strongly, so the registry became the last owner of every freed
control's box and those entries could never be detected as retired even by a
palette change. Every rebuilt HUD page (the nearby-activity rows rebuild on every
re-entry and on several sortie transitions) added about 42 permanent entries;
measured at roughly +110 entries per re-entry and +42 per sortie, unbounded, and
the dominant contributor to the ObjectDB and static-memory growth.

Player-facing: HUD memory grew steadily through a long session and an
accessibility-palette switch walked an ever-growing registry, so it got slower
the longer the session had run.

Fix: hold style boxes by `weakref`, add a liveness predicate, and prune
amortized — one sweep per `PALETTE_TARGET_PRUNE_STRIDE` (128) new registrations —
in addition to the existing full prune on a palette change. Focused assertion in
`tests/accessibility_presets_test.gd`: forty page rebuilds with no palette change
must leave the registry within one stride of its starting size.

### 3. The live-combat source roster went invalid the moment the perimeter defense ended

`scripts/activities/station_defense_encounter_content.gd` retired its three
session hostile source registrations on every terminal activity state and only
restored them on the next `start()`. Between those two points
`get_live_source_registration_contract()` — and through it
`GameFlow.get_live_combat_source_roster_audit()` — reported the whole production
roster as invalid, and the next `_initialize_live_combat()` (a whole-`Main`
re-entry, or the deferred fleet-registry refresh that follows Dock 04/05/06
composition) pushed `ERROR: Live combat source roster is invalid: …`. The soak saw
this as `combat_sources` oscillating 9 ↔ 12: a re-entry re-wired the sources and
made the roster valid again, then the next abandoned encounter invalidated it.

Player-facing: after finishing or abandoning the station perimeter-defense
encounter, the three dormant perimeter raiders held no damage or fire identity in
the shared resolver, and the game's own roster audit reported the production
combat roster as broken until the encounter was started again.

Fix: when the activity returns to `idle`, restore the same resting registration
the content acquired when it was configured. Terminal states still retire the
live roster, so the existing "retire every hostile source before reward recovery"
contract is unchanged. Focused assertion in
`tests/station_defense_encounter_content_test.gd`: returning to idle restores the
exact resting three-source roster without arming the picket.

## What remains

- **Dock 04's approach lane is obstructed for the Cinder cargo hauler.** The
  craft is accepted for capture on its own berth's published approach pose and
  then makes no progress against the dock structure, so the assist aborts with
  `approach_obstructed` after its four-second stall timeout and the player can
  never park it. Reproduced on every cargo-hauler cycle of both 48-cycle runs.
  The obstruction is authored dock geometry, which this suite does not own; it is
  recorded in `KNOWN_OBSTRUCTED_RETURN_CRAFT_IDS` so that *only* this craft may
  fail a physical return, and fixing Dock 04 makes that assertion fail, which is
  the signal to delete the entry. The other eight craft complete real assisted
  berth returns.
- **`hud_controls` moves between 1319 and 1322** depending on which toasts and
  status cards are live at the sampling instant. It is bounded across 48 cycles
  and does not trend, so it is tolerated rather than pinned.
- **`static_memory` still drifts about 1.3 MB across 48 cycles.** That is inside
  allocator noise at this scale and no longer correlates with cycle count the way
  the pre-fix 5.7 MB climb did.
- **Headless render counters are not meaningful.** `RENDER_TOTAL_OBJECTS_IN_FRAME`
  is recorded for completeness and reads zero without a display.
