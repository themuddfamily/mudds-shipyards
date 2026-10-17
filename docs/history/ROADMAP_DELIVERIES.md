# Recorded roadmap deliveries

Moved from ROADMAP.md on 2026-10-17. These are source-specific historical
results, not the active queue or proof of current full-project acceptance.
Return to the [working roadmap](../../ROADMAP.md).

**E1 — Torrent combat/reuse capability (DONE).** Parent: original performance
§5/combat. [Runner usage](../../docs/PERFORMANCE_BENCHMARK_RUNNER.md) documents selected
`torrent_range_combat_reuse_route`. On7c5e85787, its eight-second smoke records17
sampled shots/hits, six destructions and five production reuses, stable identity/
healthy hull, plus saved JSON and active-fire abort:19 focused checks PASS.
Original default152 and Python record15 pass on20e7519ff, before the combat-only
staging/diagnostic repair; those results remain source-specific. Initial blocked
staging failure is retained; exterior-side staging now verifies the actual
reticle and first authority shot hit DRONE-01. No target/acceptance relaxation.
Complete guards and owned cleanup independently verify; temporary checkout is
removed (~259MB logical). Raw initial/default and corrected `repaired/` records:
`/srv/mudds-work/range-combat-benchmark-results-20261017/`.
Selected false/null admission, default two-route protocol and original full timing
floors remain. Full combat-duration/rendered/native checks are NOT_RUN. Gameplay
is unchanged; latest playable stays b6af782. Stop reached.

E3 raw: `/srv/mudds-work/bulwark-default-boundary-results-20261017/`.
Its clean temporary worktree is removed. This diagnostic is separate from E1/E2
delivery counts; it neither changes the game nor proves the historical timeout's
cause. The catalog still requires graphics for the optional capture-bearing suite.

Completed bounded tasks below retain their detailed results in Git, build notes
or the named raw report. None closes a parent or phase gate.

| Task | Outcome / source |
| --- | --- |
| PLAN | Bounded roadmap and 36-parent scope crosswalk delivered in `5d3476af5`; original requirements preserved in the reference. |
| LINUX-BUNDLE | Managed installer shipped and actual archive transactions verified in `653c1459d`; [package notes](../../builds/linux/MuddsShipyards-653c145-linux-notes.txt). |
| BASE-DIAG[Rime second scenario] | `89974fce0` locates original 300s timeout inside second held-edge loop; full suite still FAIL. Raw report: `/srv/mudds-work/rime-pad-boundary-results-20261017/report.txt`. Failed rendered-mode attempt retained separately; no runtime fix claimed. |
| PERF-FIX[dormant chase cameras] | `d0e129f8d` removes dormant correction work and preserves active/activation clearance; reviewed, measured and [packaged](../../builds/windows/MuddsShipyards-d0e129f-notes.txt). No FPS/Rime300s claim. |
| SCOPE-LIMIT definition | `43111884d` records guest counting, nine-craft seat/role facts and a finite [release-target proposal](../../docs/COMPLETION_SCOPE.md#session-capacity-contract-and-pending-release-target). Final target remains WAITING on owner choice. |
| NET-BROWSER[guest-capacity wording] | `f676c5016` corrects labels without count/protocol changes; existing UI checks and [matching checkpoint](../../builds/windows/MuddsShipyards-f676c50-notes.txt) pass. |
| NET-CREW[Jovian engineer] functional probe | Current `f676c5016` package route passes 72 checks with host/one client; one retained Xvfb VSync warning leaves strict zero-diagnostic qualification open. Raw report in COMPLETION_SCOPE. |
| NET-CREW[Halyard engineer] functional probe | Current `f676c5016` actual Halyard route passes 76 checks; one retained Xvfb VSync warning leaves strict diagnostic qualification open. Raw report in COMPLETION_SCOPE. |
| NET-CREW[Bulwark gunner] | Current `f676c5016` route passes: remote and moving-host gunner shots each damage registered targets 100→78; stand/reseat and pilot-disconnect ownership checks pass. Scope in COMPLETION_SCOPE. |
| Q1 · BASE-DIAG[Emberline late peer] | Historical first unmet dependency identified: later dead-peer baseline before reset. One instrumented `e026cf620` isolated original-cap probe passes; no production fix/root cause claimed. |
| Q2 · PERF-SELECT[existing benchmark scenarios] | `47adf7c6e` adds one-route selection while preserving default two-route/full-protocol acceptance; 127 focused assertions and 11 Python checks pass. [Usage](../../docs/PERFORMANCE_BENCHMARK_RUNNER.md). |
| Q3 · NET-CREW[Halyard passenger default route] | Actual `f676c5016` stationary-cabin chair/walk/reseat and migration-generation rebind/disconnect route passes 73 checks, no emitted runtime diagnostics; moving-craft acceptance remains open. |
| Q4 · BASE-DIAG[Patrol restore] | One `e8f24ff00` original-cap probe still times out. Historical retirement boundary passes; repeated world/fleet startup dominates. Full Patrol acceptance remains FAIL; follow-up below. |
| Q5 · BASE-DIAG[Resume offer] | `df66dcded` original300s probe passes Main16 real-file recovery; stops in Main17 next passenger interaction after151 passes. Main18/19 unentered; no runtime fix. Raw: `/srv/mudds-work/resume-offer-boundary-results-20261017/report.txt`; full suite remains FAIL. |
| Q6 · WORLD-SHARED[Aurora arrival contract] | Bounded lookup recovered historical source `47ffce740562dd3ac3d52f66736796f5639068fd`; original invocation/setup/raw peer receipts missing. Definition ends with missing-input handoff; physical landing requirement remains open. |
| D1 · GUIDED[f676c50 Linux package] | Exact current ELF passes original Guided3/3 in49.503/51.084/49.409s, zero diagnostics, original91 neutral shutdown frames and0.17m physical exit error. Inputs/actors/profiles/displays close; source/package guards match, independently verified. Raw: `/srv/mudds-work/f676-guided-acceptance-20261017/`. |
| D2 · NET-CREW[Halyard moving source route] | Exact `7412a6e509b2807fcf80a7a0dd93593c9664d941` passes132 checks/zero diagnostics in213.078s. Host/two independent passengers/late observer, supported walks1.278/1.175m and both chair routes pass; actual cruise/rebase assertions hold. Inputs/32 actors/five displays/socket/lane cleanup independently verified. Raw: `/srv/mudds-work/moving-halyard-source-results-20261017/result.json`. |
| D5 · PERF-ROUTE[Halyard stationary cabin walk] | `53e63831a` adds physical cabin route selection; 152 focused Godot assertions and11 Python checks pass. Final sample walks39.575m on5.2m aisle with support/occupancy/stationary hull retained. Default two-route admission unchanged; no hardware qualification. Raw: `/srv/mudds-work/cabin-benchmark-results-20261017/final/report.txt`. |

**Latest attempt: Q4-FIX candidate withheld; startup requirement remains open.**
One fresh Main locates station dressing consolidation as the largest of47 world
build stages (~856ms). A guard-order/duplicate-check candidate avoids483 signal
checks (2,875→2,392); that measured portion falls239.779→208.585ms. The normalized
station snapshots are byte-identical across5,886 nodes and the focused existing
batch test passes59 assertions. But consolidation wall time is856.972→871.612ms,
world subtree5.021→5.191s and Main attach11.559→11.822s in the single pair.
No overall startup improvement is demonstrated; this does not prove a causal
regression either. The patch is retained externally and **not integrated**. No
full Patrol rerun, checkpoint/export or native qualification follows. Per-run
complete source/cache guard hashes were not captured, so no such stability claim
is made. Original runtime remains unchanged; temporary checkout and unused build
preparation removed. Raw patch/results/report:
`/srv/mudds-work/station-startup-fix-results-20261017/`.
Q4's original300s full Patrol FAIL remains unchanged.

### Delivery batch D1–D5: complete

All **five scheduled outcomes** are accepted only on their recorded source/build
and scenario. This is a completed batch, not project completion. Disposable
worktrees are removed. The next small batch is specified above. Do not expand
these completed network-menu checks into capacity, flight or endurance work.

| Order / existing family instance | Kind / status | Observable result | Working estimate |
| --- | --- | --- | --- |
| D1 · GUIDED[f676c50 Linux package] | Qualification · DONE | Recorded f676c50 package completes original Guided 3/3; Sandbox and Settings remain open. | Runs49.503/51.084/49.409s; total effort not timed |
| D2 · NET-CREW[Halyard moving shared-cruise source route] | Qualification · DONE on `7412a6e50` | Original moving/rebase/two-passenger/chair/late-observer route passes132 checks, zero diagnostics. Source only; canonical landing/package qualification remain open. | Suite213.078s; total effort not timed |
| D3 · NET-BROWSER[live menu host and first guest] | Runtime repair and checkpoint · DONE on `b6af78202` | Stable browser Disconnect works for both peers; source full menu route, guest count0→1→0 and browser reuse pass. Fresh paired checkpoint passes focused UI and startup checks. | Source live/default108/7; source/package262 each; total effort not timed |
| D4 · NET-BROWSER[second independent menu guest] | Executable release check · DONE on `99d57eb82` | Same real menu host admits two distinct guests; UI-driven counts0→1→2→1→0, remaining authentication and all actual exits0 pass. | Default7 / one-guest108 / two-guest181; total effort not timed |
| D5 · PERF-ROUTE[Halyard stationary cabin walk] | Executable benchmark capability · DONE on `53e63831a` | Selectable physical aisle shuttle works; partial reports cannot qualify full performance protocol. | Final suite ~206s; total effort not timed |

Completed execution steps within D3/D4, not additional parent outcomes:

| Step | Finish line | State |
| --- | --- | --- |
| D3 source repair | Existing HUD/focus/manual/default checks and full real one-guest menu route pass with UI leave and browser reuse. | DONE; independently reviewed on b6af78202. |
| D3 checkpoint | Clean Windows EXE/ZIP/notes and matching Linux package; focused payload/startup checks; remove disposable worktrees. | DONE; 8 package checks pass,262 assertions and3 strict startups; cleanup complete. |
| D4 implementation | Extend the existing menu test to a second real guest; commit one exact invocation and unchanged bounds. | DONE; existing test extended, reviewed and committed before execution. |
| D4 acceptance | Run that route once: distinct identities, counts0→1→2→1→0, remaining guest connected, all exits0 and owned closure. | DONE on99d57eb82; first run passes, no runtime repair needed. |

Batch count: **5 of 5 outcomes DONE; zero remain in this batch**. Remaining
project outcomes and all ten phase exit gates stay open. D4 changes only an
export-excluded test; the latest playable checkpoint remains b6af782.

D3 packaging retained an initial comparison failure: a fresh import regenerated
node IDs in65 scenes. Independent decoded comparisons found every other byte
unchanged; runtime IDs are not assumed semantically irrelevant. Only the unrun
package checks resumed on the same exports, all passing. Source/index/cache/engine
and process/socket/lane closure verify. Two disposable worktrees and the duplicate
archive extraction are removed (~1.08GB logical). Raw source:
`/srv/mudds-work/browser-disconnect-fix-results-20261017/accepted/`;
package records: `artifacts/checkpoint-b6af782/` and
`/srv/mudds-work/browser-disconnect-checkpoint-20261017/`.

**D1 — Guided playthrough on f676c50.** Parent: normal-controls core
playthrough, Guided subcriterion only. Input: exact
`builds/linux/MuddsShipyards-f676c50.x86_64`, SHA256
`05042e1a8158d41c805f0cced7521452b0bea969b205f87e66429642b2916f21`.
Owner/files: root; unchanged `tools/release/run_native_sortie.py`, whose current
SHA256 is `a63a3dd9c35d91f9985e5cf4d3b731c081a1a2ecd13e9178fc66e2532f61c991`.
Command, repeated with three distinct output directories under the owned run root:
`python3 tools/release/run_native_sortie.py builds/linux/MuddsShipyards-f676c50.x86_64 --route guided --output <owned-run-root>/run-1`.
The driver owns Xvfb/XTest and explicitly uses x11/Dummy audio. Hold ordered lanes
and freeze package/driver inputs before starting. Acceptance: three fresh-process/
profile walk, board, launch, target-practice, interceptor, return, land, shutdown
and physical-exit completions, each at original 300 s cap, zero diagnostics, released
inputs and reaped game/helper/display. Preserve shutdown waits and exit criteria.
Stop at 3/3 or the first failure; no repair or retry inside qualification. Record
current-package result, not inheritance from e085. Sandbox, Settings, physical
devices and native GPU remain separate requirements. No new build for this check.

**D2 — Moving Halyard passenger route.** Parent: travelling-weapon/moving-crew
integration, moving passenger slice. Owner/files: root;
`tests/network/halyard_network_shared_planetary_cruise_test.gd` and its existing
base `tests/network/halyard_network_passenger_route_test.gd`.
Freeze clean source `7412a6e50` (resolve full commit before checkout) and pinned
`/tmp/mudds-tools/godot-4.7.1/godot`; use copied cache/private profiles, independent
owned X displays and ordered runtime lanes. Exact source-check command inside
that isolation:
`xvfb-run -a bash tools/release/run_test_matrix.sh --godot /tmp/mudds-tools/godot-4.7.1/godot --mode graphical --display-driver x11 --audio-driver Dummy --jobs 1 --timeout 300 --scope tests/network/halyard_network_shared_planetary_cruise_test.gd`.
The derived suite enables shared cruise and existing serialized chair barriers;
do not replace it with the stationary base default or host-gunner variant.
Participants: orchestrator, playing host, two independent cabin clients, late
observer. Exterior approaches and initial flight envelope are staged. Acceptance:
actual craft travels >8,000m at >50m/s and commits origin shift; both remote bodies
retain supported walking >0.6m, chair/stand/reseat and ownership; late observer
sees current state; disconnect cleans bodies/journey. Preserve readiness/refusal/
cancellation cases already in this scenario. Original caps: outer300 s, Main 60 s,
client completion 120 s, host/observer 60 s, exit 10 s; chair 8 s, readiness 12 s and crossing 35 s
barriers unchanged. Require suite success, zero diagnostics, actual child exits 0
and complete teardown. Stop at pass or first failed boundary. This source result
is not actual-package, canonical planetary landing, 30-minute endurance or final
capacity qualification; those parent requirements remain open. No automatic
package variant or unchanged retry follows.

**D3 — Real menu host, first guest and stable browser Disconnect (DONE).**
Parent: production browser and first slice of original server/two-client baseline.
Production owner: `scripts/ui/hud.gd`; existing HUD/focus tests and
`tests/network/game_flow_server_browser_integration_test.gd` retain the contract.
Exact source `b6af78202` passes default7 and live108 using
`--live-menu-one-guest --live-results <owned-output>` at original300s bounds.
Real independent Main peers use Host, LAN Refresh/select/Join, authenticate,
Begin Shift, pause → browser → Disconnect, then Refresh/Back/Resume. Counts0→1→0,
matching authenticated identities, both actual exits0 and owned closure verify.
HUD/focus/manual regression passes; [clean paired checkpoint notes](../../builds/windows/MuddsShipyards-b6af782-notes.txt)
record fresh source/package checks. Initial missing-button, compile and numeric-
array comparison failures remain in raw records; corrected runs are separate.
No package multiplayer, two-guest, capacity, flight, endurance or phase closure.
Stop reached; D4 below records the separate two-guest follow-up.

**D4 — Two guests on the same menu-hosted session (DONE).** Parent: original
server/two-client baseline, menu-admission slice only. Existing
`tests/network/game_flow_server_browser_integration_test.gd` now supports
`--live-menu-two-guests --live-results <owned-output>`. Root-reviewed source
`99d57eb821c9ba3953eab473c161d26ff62e4d79` passes unchanged default7, existing
one-guest108 and new two-guest181, zero diagnostics, each at original300s cap.
Actual host and two Main guests use real LAN Refresh/row/Join and browser
Disconnect. Distinct authenticated identities/player instances agree; counts
0→1→2→1→0 and remaining guest authentication after first departure pass. All five
peer OS exits across the two live modes are0. Root independently verifies11,871
source files/index/cache645/engine and all six stage guards; eight actual engine
environments and29 recorded process identities, display paths/authority and
socket/lane closure verify. Private headless/X11, Dummy audio; stock-root notice
flag disclosed. Temporary clean worktree removed (~259MB logical); raw records:
`/srv/mudds-work/two-guest-menu-results-20261017/`. Production files are unchanged;
b6af782 remains latest playable. No actual-package multiplayer, capacity, flight,
seat-race, damage, canonical journey, endurance or full-baseline claim. Original
three-process authority24s cap is unchanged. Stop reached; no further menu cases
are implied by this completed card.

**D5 — Executable Halyard cabin benchmark.** Parent: required fleet/cabin
performance scenarios; native-machine measurement is a separate dependent task.
Owner/files: root assigns one agent `tools/performance/benchmark_runner.gd`,
`run_native_windows_benchmark.ps1`, the existing runner/record-validator tests and
`docs/PERFORMANCE_BENCHMARK_RUNNER.md`. Implement selectable
`halyard_cabin_walk_route`. Separate selectable names from the unchanged original
default two-route order; keep existing full-report admission strict. Initial state:
fresh production Main/Begin Shift, healthy stationary unpiloted Halyard at home;
stage enabled unseated player once on its live cabin deck and establish support/
registered occupancy. Use live seat-derived waypoints and steering from
`tests/halyard_continuous_role_route_test.gd`. Shuttle with normal movement input;
no actor transform writes after staging. Acceptance: selected smoke proves actual
craft-local movement; focused route proves an out-and-back and movement during
sampling, retaining floor support/occupancy and stationary hull. Reject idle,
blocked, warm-up-only or out-of-cabin reports. Extend existing tests for default
both, original selections, cabin selection, abort/input release and partial-report
rejection; original 300 s test caps remain. Full selected timing retains both
3,600 frames/60 s warm-up and 18,000 frames/600 s sampling. Cabin-only reports always
remain diagnostic (`representative_pass=false`, budget result null); no native
PowerShell execution under the Windows hold. Stop after executable selection,
focused checks and usage docs. No new report version, hardware claim, moving-cabin
claim or replacement of existing full performance acceptance.


## E2 · Ember surface walking benchmark (DONE)

Accepted source `00ffaa045cf13a4a5e2ba2ae949551dabbb1e32e` adds selected
`ember_surface_walk_route` to the existing runner. Actual Main streaming and
origin rebase load Ember; held movement walks the authored nine-leg path.
Default 152, combat 19 and surface 24 Godot checks pass, each at the unchanged
300-second cap, zero diagnostics. Python record tests pass 15/15 on this source.
The 45-second focused primitive records 135.6478m sampled walking, one sampled
outbound and return visit, supported/enabled control, stable world/frame identity
and gravity 1.62m/s². Smoke/report roundtrip, invalid-progress rejection and
Escape during sampled walking pass; original gravity is restored before Player
exit, inputs/cursor released and Main removed. The explicit benchmark adapter
uses the production gravity policy; actual Host journey binding is unqualified.

Root independently verifies all 11,871 tracked inputs/index, cache645, pinned
engine and six before/after stage guards; actual three engine environments use
headless/Dummy and correct exclusive modes/private profiles. All eight owned
process identities are absent; socket/display and ordered runtime lanes close.
The clean author checkout is removed; donor cache and raw results retained at
`/srv/mudds-work/ember-surface-benchmark-results-20261017/`.
Surface log SHA256:
`74269c6049d74b4827df033feda36c262510e3f6f47852c923ee0d1756ba0bd4`.

All three remaining steps E2.1–E2.3 are complete. Observed guarded batch took 410.1s; earlier implementation effort
and manual closure effort were not timed. Selected
reports remain false/null for full-protocol/performance admission; schema1,
default two routes and public 3,600/60s warmup plus18,000/600s sample floors stay.
Full-duration, rendered/native performance and canonical planetary journeys are
NOT_RUN. These export-excluded changes do not change gameplay; latest playable
remains b6af782. No additional benchmark work is authorized by this completion.

## ACT-HUD · Hulk restoration instruction (DONE)

After engaging the breaker, the objective now says “Auxiliary bus powering up;
securing the salvaged cell” instead of asking the player to hold the gallery.
The existing activity design advances automatically while the sector is loaded;
this corrects the instruction without inventing a proximity rule. Source review
confirms exactly one executable objective literal changed; the adjacent comment
now describes actual behavior. `git diff --check` passes. No engine test or new
checkpoint for this wording-only correction; latest playable remains b6af782.
Canonical hulk flight/walking/revisit remains unqualified: the existing integration
suite stages positions rather than driving continuous ordinary traversal.

Cleanup removed the ancestor-integrated, clean and inactive retired checkout
`/srv/mudds-work/retired-worktrees/mudds-network-snapshot-cost-20261017`
(244,210,371 logical bytes). Verified no process cwd/path arguments referenced it
and no ignored files outside generated `.godot` existed. Other retired worktrees
with unique changes or captures are preserved. No test/qualification claim follows.

## HULK · Continuous interior traversal (acceptance FAILED)

Implementation `a97723864b4fe555ddf2c1d4e0fa0f8a1fbcb30d` replaces interior
waypoint teleports with ordinary held-input movement on the same Player capsule.
The existing six-point 73.713m route, normal gravity/speed/collision and 300s suite
cap remain. Begin Shift uses the existing production seam; a single initial
shelf placement remains staging, as do flight/dock and later fringe/rebase cases.

One full headless/Dummy run exits1: 52 checks pass, waypoint1 fails. Player
settles on verified hulk collision and reaches waypoint0, but remains exactly
(-96,21.80265,-450) when aiming at waypoint1 (-96,23,-466) until the unchanged
leg budget expires. The original static doorway ray passes. No continuous-walk
acceptance, geometry defect or full expedition acceptance is claimed. Earlier
real-file rejected-save/recovery/once-only reward checks pass in this run.

Source review finds no camera/menu suppression seam in the enabled on-foot
Player input path. Contact/penetration is a hypothesis only. Next bounded task:
HULK-DIAG[shelf stall contact], one first-stall trace of raw/sampled movement,
physics/embodiment state, velocity and slide collider/normal/depth/travel, then
one same-cap run. Do not change placement/geometry or retry unchanged based on
suspicion. Stop after identifying the actual rejecting owner or one missing fact.

Root independently verifies 11,873 source files/index/cache645/engine and both
stage guards; actual isolated engine environment, all four owned process
identities absent and sockets/display/ordered lanes closed. Clean integrated
checkout removed; donor cache retained. Raw failure:
`/srv/mudds-work/hulk-continuous-walk-results-20261017/`.
Log SHA256 `d45d22811f783986ba1ffe5b3b06668d4ececb78ebb59006c7667ddc1b9b41ee`.
No runtime change or checkpoint follows this failed acceptance.

## HULK-DIAG · Shelf stall contact (DONE; route still FAIL)

On `7f2056d227d8b5ad4a53c4ccfe78f30ce3c0a91c`, one instrumented unchanged-cap
run again passes52/fails1. Terminal held sample proves raw and sampled forward
(0,-1), control/physics/can_process true, unpaused, ON_FOOT0, remote drive false.
All three slide contacts identify actual hulk Exterior/DockShelf, upward normals,
depth0.1993484497m, travel0, forward remainder -0.009444m. This identifies physical
shelf penetration, not menu/input suppression; onset is not captured.

No geometry, route, placement, deadline or physics behavior was changed by this
trace. Existing bounded descending-floor recovery is the next production seam
to inspect; its admission currently excludes first landing and all slide contacts.
A candidate must reproduce onset safely rather than rescue arbitrary overlaps.
Root verifies11873 source/index/cache645/engine before/after, actual isolated
headless/Dummy environment, all4 owned identities absent and socket/lane closure.
Raw `.../hulk-continuous-walk-results-20261017/contact-trace/`; log SHA256
`6be10102c9220d20a34ef4bf38b80e0ac3aacf22045b5b5354479c59e58786e9`.
Clean checkout is retained only for the named next runtime repair; no checkpoint
or continuous-walk acceptance is claimed.

## HULK-FIX · First-landing recovery candidate (WITHHELD)

Candidate `a6cf457d8` would admit first-landing/floor-only contacts into existing
bounded overlap recovery. It was not integrated. The actual-size shelf fixture
was integrated alone as `395a392ca`; unchanged Player passes the complete
`player_step_up_assist_test.gd`, including first landing at22.00008 above shelf22
and >4m ordinary walking. Thus it does not reproduce the full-Main stall and
cannot prove the candidate repairs it. The redundant fixture was reverted in
`4ecc25317`; runtime and Player test bytes match pre-attempt source.

Baseline guard/source/index/cache645/engine, actual isolated headless/Dummy
profile and all4 owned process/socket/lane closure independently verify. Log
SHA256 `7aec9d18238c792d6d3e8fe507d21d4e82201a63b5b95afe206da058eed21020`.
Raw `.../hulk-continuous-walk-results-20261017/floor-repair/baseline/`; fixture
and withheld candidate patches are in its parent. Clean checkout removed.
No runtime change/checkpoint follows. Next single missing fact is full-scene
landing onset: actual motor stage, native prior floor flags, moving-frame and
containment context on the reused Player versus the standalone's fresh Player.
Trace the existing placement, not another isolated fixture or generic rescue.
