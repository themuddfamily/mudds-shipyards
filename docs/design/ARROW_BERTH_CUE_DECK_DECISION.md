# Arrow berth: the parked craft overhangs its own deck

**Status:** **CLOSED, 2026-08-16. Option A taken at 16.8 m.** The player independently
confirmed the defect from play on 2026-08-16 ("the walkway to enter isn't wide enough to
get around to the side — you can get in this one by jumping over the rails"), which made it
a P1 reachability defect rather than an open design question. See "Decision taken" at the
foot of this record for what was implemented, what the re-measurement confirmed, and how
the four owner questions were answered.

**Provenance note:** this record is reconstructed from an analysis pass run against
`fcfa58e`. The original agent's document and its `bugs.md` edits were lost when the
coordinator force-removed its worktree before confirming the merge had landed — the
measurements below are quoted from that pass's report, and the two marked
`UNVERIFIED-AFTER-LOSS` should be re-measured before anyone acts on them.

## What reproduces on `main`

`bugs.md` recorded the Arrow berth's cue strips as overhanging the deck they mark.
The analysis found the defect is larger than recorded, and that the cue is a symptom
rather than the defect.

- `PortBerthNode`'s collision box measures `x = -49.000 … -37.000` — **12.0 m**, not
  the roughly `-49.5 … -36.5` the original record assumed.
- The four `Boundary_*` cue strips sit at `x = [-50.100, -49.940]` and
  `[-36.060, -35.900]`. They do not merely overhang: each lies **entirely beyond the
  deck**, nearest edge **0.940 m** clear of any structure. Downward probes hit
  structure **0 of 16** times; the three sibling berths hit **16 of 16**.
- Sibling hover for comparison: **0.180–0.350 m**, unchanged by the lighting pass or
  the colourblind cue re-freeze.

## The finding that reframes it

**The parked Arrow's nose projects 0.450 m past the deck edge**, with 2 of its 4
footprint corners unsupported. `ArrowHullCollision` is **12.2 m** long; the deck is
**12.0 m** across. The craft does not fit the pad it is parked on.

A second premise in the original record is also false. It assumed the cue "honestly
advertises the Arrow's `landing_half_extents`" and therefore could not be shrunk
without lying. Measured: cue is `6.3 / 7.2` against an envelope of `8.0 / 9.0`, and
the four berths use **four unrelated ratios** (0.60–0.83). Nothing derives one from
the other, so re-authoring the cue constant is presentation work, not a false claim.

## Shrinking the landing envelope is disproved, not merely expensive

Measured Arrow collision union requires half-extents `(5.550, 1.675, 6.450)`. The
envelope-to-hull ratio is **1.44× / 1.40× — the tightest in the fleet** (Jovian
1.73/1.55, Zenith 2.89/2.42, Torrent 3.33/3.54). The hard floor before
`contains_oriented_bounds(dock, bounds, 0.05)` fails is `(5.600, 1.725, 6.500)`.

It would also not make the Arrow harder to land — production acquisition uses
`assist_capture_half_extents (22, 14, 32)`, untouched — it would move the craft
toward a silent "cannot dock at all" cliff.

## Options

| | Change | Sites | Touches | Verdict |
|---|---|---|---|---|
| **A** | Widen the port node deck | `shipyard_world.gd:2426`, no frozen literal | walkable geometry + collision | **Recommended** |
| **B** | Shrink envelope **and** cue | 6 sites, 4 drift assertions, a `landing_clearance_test` fixture | landing contract | Recommend against |
| **C** | Shrink the cue only | 3 sites, 1 assertion | nothing behavioural | Cheapest interim |
| **D** | Re-scope and record only | — | — | Fallback |
| **E** | Rotate the berth | — | — | Rejected on measurement |

**Option A detail.** Measured floor **16.8 m** (Zenith parity, 1.30 m clearance);
18.0 m gives 1.90 m and matches the advertised envelope. Knock-ons measured:
`RegistryPodDeck` / `RegistryPodThreshold` share the node's exact x span, so widening
leaves a **1.5–3.0 m re-entrant ledge**; the two edge rail posts per side end up
inboard of the new edge. Silhouette frames show widening does **not** intrude on any
composed void, but at 18.0 m the port node becomes a near-square plate and
port/starboard symmetry breaks — **16.6–16.8 m reads better**.

**Option C caveat.** At `cue_half_length 7.2 → 5.9` the cue becomes shorter than the
craft, breaking the one invariant all four berths currently hold (cue ⊃ parked craft).

**Why no cue size fixes this.** The fleet grammar is `cue ⊃ parked craft` and
`pad ⊃ cue`. On a 12.0 m deck under a 12.2 m craft, **no cue size satisfies both.**

## Recommendation

**Option A at 16.6–18.0 m**, scheduled as a proper walkable-geometry task including
the registry seam and the rail posts. If that cannot be scheduled, take **Option C**
as an explicitly recorded interim. **Do not take Option B.**

## Decisions needed from the owner

1. Is the port node's 12 × 17 m footprint source-bounded, or blockout?
2. Is port/starboard node symmetry a rule, or incidental?
3. Does the registry deck widen with the node, or does the node taper around it?
4. May a presentation pass re-author `cue_half_length`?

## Why no test caught this

`tests/capture_berth_feedback.gd` passes **503 assertions with zero failures** while
the cue hangs in vacuum, and the full matrix is green. Every frozen contract in the
berth-feedback set describes the cue's own geometry and material; **none relates the
cue to the deck beneath it**. `UNVERIFIED-AFTER-LOSS`: the claim that no berth suite
asserts pad-supports-cue was reported but not re-checked after the loss.

---

## Decision taken — 2026-08-16

**Option A, at 16.8 m.** `PortBerthNode` goes from `Vector3(12.0, 1.2, 17.0)` to
`Vector3(16.8, 1.2, 17.0)` about the same centre `x = -43.0`, so the deck now spans
`x = -51.400 … -34.600`.

### Re-measurement before acting

Every number this record depends on was re-measured against the live scene first, and all
of them held:

| Quantity | Recorded | Re-measured |
|---|---|---|
| `PortBerthNode` collision span | `-49.000 … -37.000`, 12.0 m | identical |
| `ArrowHullCollision` length | 12.2 m | identical (`x = -49.450 … -37.250`) |
| Nose projection past the deck edge | 0.450 m | identical |
| Unsupported footprint corners | 2 of 4 | identical |
| Cue strip positions | `-50.100 / -35.900` | identical |
| Cue clearance from any structure | 0.940 m | identical |
| `RegistryPodDeck` / `Threshold` x span | shares the node's span exactly | identical |
| Edge rail posts per side | 2, at `|x| = 37` and `49` | identical |

The `UNVERIFIED-AFTER-LOSS` claim — that no berth suite relates the cue to the deck beneath
it — was also re-checked and is **true**: the berth-feedback suites assert the cue's own
geometry, materials and lease states and nothing about what is underneath it. The new
`_test_parked_craft_are_fully_supported_by_their_berth_decks` in
`tests/station_traversal_defect_witness_test.gd` is the first assertion that does.

### What the widening resolves by itself

The cue strips at `x = -50.100` and `-35.900` now land **1.300 m inside** each deck edge, so
`pad ⊃ cue ⊃ parked craft` holds for the first time. **No cue constant was re-authored**:
`cue_half_width 6.3` and `cue_half_length 7.2` are untouched, and the berth-feedback
contract did not move. Option C was therefore never needed, and Option B stays rejected.

### The reachability half, which the recorded analysis did not cover

The player's "you can get in this one by jumping over the rails" is a second, independent
defect at the same site, and widening alone does not fix it. `BranchRail` ran
`x = -42.5 … -11.5` at both `z = 12.0` and `z = 19.0` — five metres **past** the 7 m branch
arm it guards and straight across the berth node — at 1.06 … 1.24 m high. The parked
Arrow's sensor wing (`x = -44.200 … -39.300`) blocks a standing capsule at the only gap in
that rail, and its hull blocks the corridor's middle, so the 7 m approach corridor was
sealed on both sides and the walkway beside the craft could only be entered over a rail.
Each rail now ends exactly where its arm ends. The post roster per rail is unchanged at
five.

### The four questions this record left for the owner

1. **Is the 12 × 17 m footprint source-bounded or blockout?** Blockout. Nothing in the
   module contract, the topology evidence or the frozen-count suites pins it; the only
   assertions that moved were the ones that name the collider, and each is re-frozen in the
   open.
2. **Is port/starboard node symmetry a rule, or incidental?** Treated as incidental. The
   port node is 16.8 m and the starboard node stays 12.0 m, because only the port node has a
   craft parked on it. Both branch arms were trimmed to butt their node rather than overlap
   it by 0.5 m, so the two sides stay consistent in *construction* even where they differ in
   size.
3. **Does the registry deck widen with the node, or does the node taper around it?**
   **The node tapers.** Widened to 16.8 m the pod deck reaches `x = -51.400`, which puts it
   underneath the Jovian freight branch's connection lattice: measured live, that adds
   `ConnectionDeckA`, `ConnectionDeckB` and `LatticePost5` to the freight module's
   legacy-overlap set, all three sharing the pod deck's exact `y = 0.380` top plane, where
   `tests/jovian_freight_berth_transform_test.gd` deliberately admits exactly one declared
   handoff leaf. Three new coplanar decks on a walked route is a worse defect than the
   2.4 m re-entrant ledge it removes. The ledge is accepted and recorded here.
4. **May a presentation pass re-author `cue_half_length`?** Moot — see above; the cue is
   correct at its published size once the pad is the right size.

### Knock-on the widening did create, and how it is bounded

`PortBerthNode`'s north face (`z = 24.000`) now meets the freight lattice's
`ConnectionDeckA` south face (`z = 24.000`) along 1.8 m of x. The two **butt**: shared
volume is exactly zero, and the freight suite's overlap query only reports it because its
shape cast inflates both shapes by 0.002 m. The suite's declared-seam roster is re-frozen
from one pair to two, and a new assertion requires that pair to share zero volume — which is
stricter than the count it replaces. The result is continuous floor where the node
previously stopped 0.6 m short of the freight branch.

### Regressions that now hold this

- `tests/station_traversal_defect_witness_test.gd`
  - `_test_arrow_berth_can_be_walked_around` — one standable cell on each face of the parked
    craft must be in the no-jump flood from the production spawn marker.
  - `_test_arrow_berth_rails_no_longer_fence_the_walkway` — the production controller,
    bounded, no jump, from the branch-arm handoff to both flanks.
  - `_test_parked_craft_are_fully_supported_by_their_berth_decks` — all four footprint
    corners of every parked craft must have structure beneath them.
