# Arrow berth: the parked craft overhangs its own deck

**Status:** open design decision, needs the project owner. Nothing implemented.

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
