# Scene geometry budget — representative mid-range Windows PC

Status: **modern interpretation.** These are presentation-engineering numbers
chosen by measuring this project. Nothing here is a recovered or authenticated
value, and nothing here is a claim about the original game.

First written 2026-08-16, against the scene at that date. Measured with
`tools/geometry_census.gd`. Regression-gated for lettering by
`tests/sign_geometry_budget_test.gd`.

---

## What this document can and cannot say

The machine this project is developed on renders through **llvmpipe, a software
rasteriser**. Frame time measured there is a property of the CPU emulating a GPU,
not of the game. So this budget deliberately contains **no frame-time, GPU-time
or VRAM-occupancy figures**, and none should be added to it from this
environment. Anyone who does measure them must record the hardware, driver,
resolution and graphics profile alongside, as Phase 9 item 7 of `ROADMAP.md`
already requires.

What *is* measurable here, and is identical on the player's Windows GPU build
because it is a property of the scene rather than of the renderer:

- triangle counts, per bucket and per object
- mesh instances and surfaces (the upper bound on draw submissions)
- unique meshes, materials and shaders (state changes)
- texture count and uncompressed texture bytes
- `Light3D` count and how many of those cast shadows
- particle systems
- scene-tree node count

Those are the budget's currency. They are **whole-scene ceilings, not per-frame
figures** — Godot frustum- and occlusion-culls, so what a frame actually submits
is a fraction of these. A whole-scene ceiling is still the right thing to hold,
because it is what bounds load time, memory, and the worst-case wide shot, and
because it is the only figure this project can currently verify.

## The target machine

Defined here so future work has something concrete to check against rather than
"mid-range".

| | Minimum | Target |
| --- | --- | --- |
| CPU | 4 core / 8 thread, ~2018 desktop class | 6 core / 12 thread, ~2022 desktop class |
| RAM | 8 GB | 16 GB |
| GPU | GTX 1060 6 GB / RX 580 8 GB class | RTX 3060 8 GB / RX 6600 8 GB class |
| Display | 1920x1080 | 1920x1080, headroom toward 2560x1440 |
| Renderer | Forward+ | Forward+ |

The reason the budget below leans on **draw calls, materials and shadow-casting
lights** rather than on raw triangles is that this is where a GPU of that class
actually runs out first. An RTX 3060 will chew through a million and a half
triangles without noticing; what costs it, and much more so the minimum spec's
CPU, is thousands of separate draw submissions, hundreds of distinct materials,
and lights that force the scene to be re-rasterised into a shadow map. The
triangle ceiling is a coarse headroom marker, not the binding constraint.

## The budget

Measured with `godot --headless --audio-driver Dummy --script res://tools/geometry_census.gd`.

| Metric | Measured 2026-08-16 | Budget | Headroom |
| --- | ---: | ---: | ---: |
| Scene triangles | 1,333,590 † | **1,800,000** | 26% |
| Mesh instances | 3,605 | **4,200** | 17% |
| Surfaces (draw-call upper bound) | 3,612 | **4,300** | 19% |
| Unique meshes | 1,790 | **2,200** | 23% |
| Unique materials | 458 | **550** | 20% |
| Unique shaders | 0 | **8** | — |
| Textures / uncompressed bytes | 22 / 107 MiB | **40 / 192 MiB** | 79% |
| `Light3D` nodes | 203 | **240** | 18% |
| …of which shadow-casting | 14 | **16** | 14% |
| Particle systems | 16 | **24** | 50% |
| Scene-tree nodes | 5,752 | **7,000** | 22% |
| `TextMesh` lettering, total | 60,829 (4.3% of scene) | **80,000 and ≤ 5%** | 32% |
| `TextMesh` lettering, worst sign | 4,239 | **6,000** | 42% |

† **This figure is arithmetic, not a census run, and it is the one number in this
table that has not been measured end to end.** The ring budget below landed
after the last full census. Its inputs *are* measured: `tools/torus_census.gd`
read every one of the 129 live `TorusMesh` instances out of the built scene, and
the scene total it was subtracted from — 1,418,938 — is a census run of the same
day. What was not re-run is the census itself after the final tessellation floor
was raised, because the session ended first. The next census run should replace
this number and this footnote with a measured value; if the two disagree,
**believe the census.**

The 1,418,938 baseline is also worth recording because it does not match the
1,410,035 written here on 2026-08-16 for the same commit-range. The 8,903
difference is other work landing in parallel, not a measurement error, and it is
left visible rather than reconciled away.

The headroom column is an **allowance to spend**, not slack. The roadmap still
owes enemy craft, a walkable freighter interior, station-wide modelling and a
sibling's new craft. Roughly a fifth to a quarter of growth is what that has to
fit into before something needs LOD, instancing or impostors rather than more
budget.

Shadow-casting lights are the tightest line and the most important one. Fourteen
of 203 lights cast shadows; each of those re-rasterises the geometry in its range
every frame it is visible. Two more is the whole allowance. A new module that
wants six shadow-casting work lights has to take them from somewhere.

## Where the geometry actually is

Whole scene, after the sign fix:

| Bucket | Triangles | Share |
| --- | ---: | ---: |
| `ShipyardWorld/HabitatSpine` | 293,979 | 20.8% |
| `ShipyardWorld/AftJunctionStack` | 221,146 | 15.7% |
| `TorrentInterceptor` | 139,502 | 9.9% |
| `ShipyardWorld/SpaceBackdrop` | 127,296 | 9.0% |
| `ShipyardWorld/NearbySectorCluster` | 117,457 | 8.3% |
| `JovianLightFreighter` | 76,508 | 5.4% |
| `ArrowReconShip` | 66,012 | 4.7% |
| `ShipyardWorld/OperationalLattice` | 59,764 | 4.2% |
| `ShipyardWorld/LandingPad` | 59,221 | 4.2% |
| `ZenithInterceptor` | 52,686 | 3.7% |
| everything else | 196,464 | 13.9% |

By kind, which is the more useful cut:

| Mesh kind | Triangles | Share | Instances | Triangles each |
| --- | ---: | ---: | ---: | ---: |
| `ArrayMesh` | 894,198 | 63.4% | 3,511 | 254 |
| `SphereMesh` | 236,856 | 16.8% | 2,802 | 84 |
| `TorusMesh` | 128,316 † | 9.6% | 129 | 995 |
| `TextMesh` | 60,829 | 4.3% | 31 | 1,962 |
| `BoxMesh` | 2,556 | 0.2% | 213 | 12 |
| everything else | 1,908 | 0.1% | 25 | 76 |

The kind table sums to 24 triangles short of the scene total: twelve `Label3D`
nodes, two triangles each, which have no `Mesh` resource to classify. They are
listed here only to show what `Label3D` costs next to `TextMesh` — a quad and a
font atlas versus real triangulated glyph contours.

`ArrayMesh` at 63% is the authored art — Torrent, Zenith, the pilot, the central
berth hero cell, the two `MultiMesh` fields — spread over 3,511 objects at 254
triangles each. That is geometry doing its job and it is not a target.

## Named next targets, in measured order

These came out of the census and are **not done**. They are recorded here so the
next pass starts from a number.

1. **`TorusMesh`: done, and for less than the estimate. See "The ring fix" below.**
   213,664 → 128,316, a saving of 85,348 rather than the ~150,000 estimated here.
   The gap is the estimate's fault, not the pass's: it assumed `24 x 8` would be
   indistinguishable on a small collar, and rendered, it is not.
2. **`ShipyardWorld/SpaceBackdrop/ParallaxStars`: 124,800 triangles.** Large, but
   it is a single `MultiMeshInstance3D` of `radial_segments = 6, rings = 3`
   spheres — one draw call, already deliberately cheap per star, and the census
   counts its instanced geometry in full. Left alone: it is loud in a triangle
   census and quiet in a frame. Recorded so nobody "optimises" it twice.
3. **`NearbySectorCluster/DebrisField/DebrisChips`: 56,160 triangles**, 520
   instances in one `MultiMesh`. Same reasoning as above.
4. **Per-frame draw calls, GPU time, VRAM and frame-time percentiles are still
   unmeasured** and cannot be measured from this environment. Phase 9 item 7's
   benchmark runner is what closes that, on real Windows hardware.

## The ring fix, for the record

The second thing this budget was used for, and the first time it said **no**.

Before: 129 `TorusMesh` rings and collars, 213,664 triangles, **15.2% of the
scene**, 1,656 each. Nine builders — five station modules and four ship visuals —
had each fixed its own tessellation (`rings` 40-64, `ring_segments` 12-18) and
applied it to everything from a 148-metre moonlet ring to a 10-centimetre pipe
clamp. After: 128,316 triangles, 995 each, a saving of **85,348 triangles, 6.0%
of the whole scene**.

Owned by `scripts/world/torus_geometry_budget.gd`, swept once from
`game_flow.gd` because the rings are spread across `ShipyardWorld` *and* the four
ship scenes that are siblings of it. It changes `rings` and `ring_segments` only,
never upward, so it cannot move, resize, recolour or re-material anything.

**The estimate above was wrong and the reason matters.** It guessed ~150,000
triangles on the assumption that `24 x 8` is indistinguishable on a small collar.
It is not. The rule was first written as a pure angular-error budget — allow the
sagitta of the segmented circle to subtend at most two pixels at the distance the
ring is realistically seen from — and that rule took the 10 cm exterior pipe
clamps down to `18 x 9`. Built into the live world and photographed at walk-up
range, `18 x 9` is a **visibly polygonal ring**: straight runs and hard corners
around the top and lower-left of the silhouette. That is exactly the tell this
project is spending its effort escaping, so the reduction was refused and the
floor raised until it wasn't visible.

The floor was chosen by sweeping that clamp through `48x16`, `32x12`, `24x12`,
`20x10` and `18x9` in the live world and looking at each at 3x magnification:
`32x12` is smooth, `24x12` shows a faint flattening at the top, `20x10` has clear
corners, `18x9` is plainly a polygon. **`32 x 12` is the floor**, and it costs
about 11,000 triangles that `24 x 12` would have saved. The general lesson, which
the arithmetic missed: a silhouette *polygon* is detectable well below the point
where its deviation from a circle is two pixels, because the eye reads
straightness and corners rather than absolute error.

**Twenty of the 129 rings are left exactly as authored, and that is the point of
the pass.** The tolerance is calibrated so the budget's own answer for a large
ring is 40 — the value `nearby_sector_cluster.gd` already uses on the biggest
circles in the game. Everything a player reads *as a circle* was already at 40 or
finer than the rule asks for, so all of it is untouched to the segment: the
**Cinder Reach beacon signal and trim rings** (the named risk), the 148 m and
132 m moonlet rings, the six Reach moonlet crater rims, the Cinder Reach drum
collars, the derelict habitat can's torn rim, and the Jovian outer dock ring. The
saving comes entirely from rings authored at 48 and 64 — collars, sockets,
bearings, gimbals and clamps, none of which are circles anybody looks at.

Checked by looking, not asserted: `tests/capture_torus_smoothness.gd` builds both
tessellations out of one frozen scene and photographs fourteen rings at two
framings each. What was rendered and judged clean is recorded in the session
report; the half-metre dock mast collar at 0.6 m and the 9 m landing pad rings at
both walk-up and whole-ring framing are the two that mattered most, and both are
indistinguishable at 1:1.

## The lettering fix, for the record

The first thing this budget was used for. Before: 31 signs, 315,360 triangles,
**18.9% of the entire scene**, 10,172 triangles per sign — about forty times the
average cost of an authored art mesh. After: 60,829 triangles, 4.3%, 1,962 per
sign. Scene total 1,664,566 → 1,410,035, a **15.3% reduction in the whole scene
from one change to how text is built**.

Two levers, both owned by `scripts/world/sign_geometry_budget.gd`:

- `depth` 0.020-0.030 → **0.0**. Extrusion is 75% of a `TextMesh`: a duplicate
  back face plus a wall of quads around every contour segment. At these depths
  and node scales it was three to twenty millimetres of lettering that no camera
  in the game is placed to see.
- `font_size` 64 → **48**, with `pixel_size` derived so `font_size * pixel_size`
  is unchanged. `font_size` is a curve-tessellation setting, not a size setting;
  world size is preserved to within 0.4% of width and 2.9% of height, both inside
  the panel each legend sits on.

Legibility was checked by looking, not asserted: `tests/capture_sign_legibility.gd`
renders four signs — the main navigation board, the densest lettering in the
game, a berth identity legend, and sector wayfinding read from a moving craft —
at reading distance, at distance, and from behind, before and after. At 1080p the
after shots are indistinguishable from the before shots, and the extrusion's
removal actually cleans up shading noise inside the glyph strokes on the
close-range terminal. `font_size = 32` was rendered too and is also legible; 48
was kept because the extra 23,000 triangles is 1.4% of the scene and is not worth
spending the whole quality margin of the one object class whose job is to be read,
particularly above 1080p.

One deliberate behaviour change, photographed in the "back" shots: a flat sign has
no back face, so a sign viewed from its non-reading side now shows nothing instead
of showing **mirrored text**. Every sign in the world is mounted on an opaque
board, panel or wall, so in most cases nothing changes at all. The one place it is
visible — looking out of the Dock Operations pod through its glazing — previously
read `SNOITAREPO KCOD` and now reads as clean glass. That is the MAP-004 mirrored-
legend complaint getting quieter, not louder.

## How to check this

```
# Whole-scene census. Add KETH_CENSUS_JSON=path to diff two runs.
godot --headless --audio-driver Dummy --script res://tools/geometry_census.gd

# Per-ring breakdown: world-space radii, authored vs budgeted tessellation.
godot --headless --audio-driver Dummy --script res://tools/torus_census.gd

# Lettering and ring regression gates.
tools/release/run_test_matrix.sh --scope sign_geometry_budget_test \
  --scope torus_geometry_budget_test

# Look at the signs. Needs a display; xvfb is fine, --headless is not
# (headless has no rasteriser and writes blank frames).
KETH_SIGN_CAPTURE_TAG=after xvfb-run -a -s '-screen 0 1920x1080x24' \
  godot --path . --resolution 1920x1080 --rendering-method forward_plus \
  --audio-driver Dummy --script res://tests/capture_sign_legibility.gd

# Look at the rings. Writes a matched authored/budgeted pair per shot out of one
# frozen scene, plus a 4x magnification of each silhouette.
xvfb-run -a -s '-screen 0 1920x1080x24' godot --path . --resolution 1920x1080 \
  --rendering-method forward_plus --audio-driver Dummy \
  --script res://tests/capture_torus_smoothness.gd

# Choose a floor by looking, rather than by arithmetic: photograph one ring at
# explicit tessellations.
KETH_TORUS_CAPTURE_ONLY=exterior_pipe_clamp \
KETH_TORUS_CAPTURE_SWEEP=48x16,32x12,24x12,20x10,18x9 \
xvfb-run -a -s '-screen 0 1920x1080x24' godot --path . --resolution 1920x1080 \
  --rendering-method forward_plus --audio-driver Dummy \
  --script res://tests/capture_torus_smoothness.gd
```
