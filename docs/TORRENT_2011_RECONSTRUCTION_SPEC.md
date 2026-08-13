# Dated-2011 Torrent Reconstruction Specification

Status: implementation constraint for a **modern interpretation of the observed
2011 Torrent-class Interceptor**. This is not evidence that the 2009 launch
model was identical, and it is not a claim that the source supplies CAD-grade
dimensions.

This sheet converts the primary/contemporary evidence registered in
[`RESEARCH.md`](../RESEARCH.md) into a bounded art target. Large source-visible
forms are mandatory. Fine construction, systems and materials remain modern
design unless an item below says otherwise.

## Evidence boundary

| ID | Direct evidence used here | Permitted use |
| --- | --- | --- |
| B5, [`gcYx2zm1TfI`](https://www.youtube.com/watch?v=gcYx2zm1TfI), uploaded 2011-06-29 | Torrent label `f306`/`10.200`; empty berth through `f321`; uncut spawn `f322`/`10.733`; approach and entry `f390–465`; occupied red seat `f465`; chase/aft `f510`; dorsal `f690`; side/dorsal `f870–900`; clean aft `f1050–1080`; close side/front `f1230` | Decisive dated-2011 identity and all reconstruction measurements below. Stop before the unrelated Atlantis regeneration around `46.5 s`. |
| B6, [`duOswIVCYKQ`](https://www.youtube.com/watch?v=duOswIVCYKQ), uploaded 2011-04-21 | Torrent label `f1987–2007`; partial compatible pale craft `f1996–2000`; small warm-yellow upper/forward patch | Corroboration only. Occlusion and perspective make it unsuitable for envelope measurements. |
| B7, [`J0GVOdxftXI`](https://www.youtube.com/watch?v=J0GVOdxftXI), uploaded 2012-03-18 | Uncut Zenith label, spawn, boarding and flight `f368–467` | Positive exclusion: its much wider full-delta/arrow, long-strake and pod language belongs to Zenith, not Torrent. |

The preserved B5 source used for this audit is 640 x 480 at 30 fps, 2,753
frames, SHA-256
`c1f1ed745ce507729228c62deee7798c9af51d98681f2dda65acba0d5a36948d`.
All pixel coordinates below refer to that original public rendition, not an
AI-upscale or interpolated frame.

## What the frames actually measure

These are projected image measurements with a practical uncertainty of about
2–3 pixels from compression. None of the cameras is orthographic. Ratios from a
single view therefore remain projections; the target bands below deliberately
allow for pitch, yaw, perspective and clipping.

| Frame and view | Original-frame measurement | Reliable implication |
| --- | ---: | --- |
| `f690`, dorsal/rear | full pale silhouette `131 x 145 px`; raised central dorsal panel about `58 x 117 px`; blunt aft step about `81 x 17 px` | Centrebody is narrow and long; side planes broaden it; aft is visibly stepped. The projected width:length of `0.90` is foreshortened and is not a true plan ratio. |
| `f900`, side/dorsal | unobscured silhouette `132 x 71 px` | Projected length:height `1.86`; pointed nose, rising dorsal line and tall aft mass. |
| `f1050`, nearly aft | silhouette `114 x 72 px`; central aft face about `61 x 44 px`; dark inset about `51 x 33 px` | Projected width:height `1.58`; central box is `0.535` of span; its large darker inset is a recurring aft landmark. |
| `f410`, close aft | round-form centres approximately `(180.5,187.5)` and `(512.5,186.5)`, radii about `26.3` and `28.9 px`, common midline `x ~= 346.5` | A nearly equal bilateral pair exists beside the aft body. It does not prove their function. |
| `f465`, occupied cockpit | red component about `70 x 32 px`; avatar torso approximately the same projected width; warm-yellow/translucent opening roughly `x=237…449`, `y=180…282`, partly occluded | One central seat, one-avatar cockpit, visibly red seating and a warm forward aperture/panel. |

A useful cross-view lower estimate divides the clean aft `W/H = 114/72` by the
side-view `L/H = 132/71`, producing `W/L ~= 0.85`. Repeated near-plan frames
range from projected `0.84` to `0.95` after excluding the tiny centre peg.
Together they support a preferred blockout around `W/L = 0.88`. This
triangulation is still only an estimate because ship attitude changes, but it
is stronger than treating any single dorsal projection as an orthographic plan.

For the paired forms, the close-aft diameters are only about `0.10–0.11` of the
same-view total span. Independent side projections give diameter about
`0.09–0.10 L`; combined with the width:length band, this supports `D/W ~= 0.11`
and not a large nacelle-dominant interpretation. The side views also repeat a
longitudinal extent near `0.40 L`, making them long, slim housings in the source
silhouette even though their purpose is unknown.

No defensible absolute metre scale survives. In the spawn view, the craft and
avatar are at different depths. The frames establish a compact, one-avatar,
walk-in interceptor rather than a numeric length. Absolute metres below are an
ergonomic normalization for the remake's 1.936 m pilot.

## Reconstruction target

### Normalized proportions

| Quantity | Preferred target | Acceptable evidence-bounded band | Confidence |
| --- | ---: | ---: | --- |
| overall span / length | `0.88` | `0.85–0.94`; never a width-dominant `>1.0` arrowhead | Medium |
| overall flight-silhouette height / length | `0.54` | `0.53–0.59` | Medium |
| central/aft body width / overall span | `0.535` | `0.52–0.55` | Medium-high |
| central aft face height / overall height | `0.61` | `0.52–0.70` | Medium |
| each side-plane outboard extension / overall span | `0.23` | `0.19–0.27` | Medium-high |
| upright rail height above box / overall height | `0.36–0.40` | `0.30–0.46` | Medium |
| round housing diameter / overall span | `0.11` | `0.09–0.13` | Medium-high |
| round housing centre offset / half-span | `0.70–0.74` | `0.62–0.80` | Medium |
| round housing fore-aft length / overall length | `0.40` | `0.36–0.44` | Medium-high |
| darker aft inset width / central aft face width | `0.84` | `0.72–0.90` | Medium-high |
| darker aft inset height / central aft face height | `0.75` | `0.65–0.84` | Medium-high |

The silhouette hierarchy matters more than any endpoint in these bands:

1. A tall, raised central cockpit/aft mass must dominate.
2. Shorter two-level swept side planes broaden that mass without turning it
   into a full delta.
3. Two pale upright aft rails/fins must dominate the rear outline; a joining
   cross-member is an inferred way to preserve the U-like read, not a separately
   authenticated B5 part.
4. The round forms must sit beside and remain subordinate to the aft body.

### Design-normalized metre envelope

For the current Godot root, 1.936 m pilot and existing cockpit interaction, use
this nominal source-directed shell:

```text
forward is -Z

length:  8.40 m       nose z = -4.80, aft z = +3.60
span:    7.20 m       x = -3.60 ... +3.60
height:  4.54 m       y ~= -0.75 ... +3.79, including parked modern hardware
W/L:     0.857
H/L:     0.540
```

This is approximately `4.34 x 3.72 x 2.35` standing remake-avatar heights. The
authored span is near the lower edge of the evidence band; a later art pass may
move it toward the `0.88` preferred ratio without changing the hierarchy. It
is deliberately labelled a modern ergonomic choice, not a recovered Roblox
stud measurement. A later global scale change is acceptable if these ratios,
single-pilot access and berth clearance stay intact.

If integration keeps a `10–11 m` authored length, scale this entire envelope
uniformly by about `1.19–1.31` rather than stretching one axis. The same authored
envelope then becomes roughly `8.6–9.4 m` span and `5.4–5.9 m` overall height. That
project-scale choice remains provisional presentation geometry, not source
measurement.

Recommended construction coordinates are starting values, not historical
claims:

| Assembly | Nominal local bounds or transform |
| --- | --- |
| central pressure body | `x ~= +/-1.9`; faceted stations from `z=-4.8` to `+3.5`; narrow at the nose and broadest through the aft third |
| blunt aft box | `x ~= +/-1.9`, `y ~= 0.0…2.35`, `z ~= +1.2…+3.5`; simple pale frame around a large darker recessed aft plane |
| side planes | tips `x ~= +/-3.6`; begin no farther forward than the faceted nose shoulder; reach maximum span in the aft half; use two readable vertical/planform tiers |
| aft rails/fins | centred near `x ~= +/-1.55`; base around `y=2.15`, top around `y=3.79`; occupy the aft third (`z ~= +1.1…+3.4`); the source projects about `0.38 H` protrusion above the body roof and about `0.49 H` full visible rail height; use a simple body-width sill/cross-member only where needed to reproduce the U-like rear read |
| paired round housings | fore-aft axes; centres near `x ~= +/-2.5`, `y ~= 1.0`; nominal diameter `0.80 m` (`0.72–0.94 m` band) and fore-aft length `3.35 m` (`3.0–3.7 m` band); begin near the `0.59 L` longitudinal station and extend through the aft zone; set metadata that historical function is unresolved |
| pilot seat | preserve a central anchor close to `x=0`, current `y ~= 1.56`, `z ~= 0`; one occupant only; make cushion/back unmistakably crimson/red |
| warm forward panel | central, restrained, ahead of the seat around the forward cockpit bulkhead; it may be glazing or an aperture, but must not become a large cyan identity shape |

A practical symmetric planform for the first reconstruction can use these
normalized half-shell landmarks (`u=0` nose, `u=1` aft, `v=0` centreline,
`v=1` wing tip):

```text
nose tip                 (u=0.00, v=0.00…0.05)
faceted nose shoulder    (u=0.10…0.16, v=0.22…0.30)
centrebody/cockpit        (u=0.25…0.65, v=0.42…0.50)
aft box outer wall        (u=0.68…1.00, v=0.52…0.58)
side-plane outer break    (u=0.30…0.42, v=0.62…0.72)
maximum side-plane span   (u=0.72…0.92, v=1.00)
stepped trailing tip      (u=0.92…1.00, v=0.88…0.96)
```

Do not smooth those stations into an organic teardrop. Modern bevels should be
small enough that the large planar facets and stepped construction remain the
first read.

## Source-safe required features

| Element | Required implementation read | Confidence and evidence |
| --- | --- | --- |
| identity label | “2011-source-locked Torrent reconstruction” or equally explicit dated wording; keep 2009 equivalence unproved | High: A3 name/role plus B5 uncut identity chain |
| overall form | compact pale, low-part-count, faceted wedge with a rising centre/aft volume | High broad silhouette: B5 `f322`, `f690`, `f870–900`, `f1230` |
| nose | short pointed/faceted nose with a chamfered shoulder, not a long smooth point | Medium-high: B5 `f322`, `f870–900`, `f1230` |
| centre/aft | long raised central spine into a tall blunt box; large darker aft rectangle may be a function-neutral inset | High form, medium function: B5 `f510`, `f690`, `f1050–1080` |
| side planes | bilateral swept triangular planes with visibly stepped/two-tier edges, subordinate to the body | Medium-high: B5 `f322`, `f510`, `f690`, `f1230` |
| aft rails/fins | two tall pale uprights producing the dominant U-like aft outline | High presence; medium exact topology/symmetry: B5 `f510–660`, `f750–840`, `f1050–1080` |
| paired round forms | equal bilateral circular/cylindrical housings directly beside the aft body | High presence/location, low purpose: B5 `f410`, `f510–660`, `f750–840` |
| longitudinal subdivisions | faceted nose break around `0.13–0.18 L`; housing/equipment zone begins near `0.59 L`; blunt box transition around `0.74–0.77 L` | Medium: repeatable side projections at B5 `f330–345`, `f870–900` |
| cockpit | physically reachable central single-pilot space in the same world | High: B5 `f390–510` |
| seat | one directly visible red seat; use a dark shell if desired, but the red cushion/back must remain legible | High: B5 `f465` |
| forward panel | small warm pale-yellow/amber or neutral-translucent opening/panel | Medium: B5 `f450–465`; B6 `f1996–2000` |
| exterior palette | high-value low-saturation off-white/light grey across all silhouette-defining masses | Medium-high relative colour; low exact swatch: B5/B6 |

## Palette and material boundary

The recordings prove relative colour blocks, not PBR parameters. Representative
compressed B5 medians were approximately neutral `RGB 166/165/168` on the
lit flight body, warm `140/131/98` in the more saturated portion of the forward
panel, and red-orange `162/39/16` in the seat. These are observations of the
recording pipeline, not albedo swatches.

For a modern material target:

- Keep at least about 70% of the source-core exterior visually pale and
  low-saturation under neutral light; a practical albedo family is warm
  off-white around `#D5D3CC` with restrained neutral-grey structural recesses.
- Use a small amber/warm-yellow panel around `#CBB968`; if transparent, keep it
  neutral enough that it does not read as a luminous sci-fi shield.
- Use a clearly red/crimson seat family around `#A83227` to `#B54432`.
- Use semi-matte painted alloy/composite as an explicitly modern finish. Subtle
  roughness and normal maps are welcome; dense noisy greebling must not erase
  the large clean planes.
- Cyan may remain on tiny displays or navigation/status lights, but it must not
  be the Torrent's canopy or silhouette signature.

## Superseded pre-v1 implementation details

The source-directed reconstruction v1 replaced or subordinated the following
details from the earlier prototype. This list is retained as a design-history
and regression boundary, not as a description of the current implementation:

- The earlier approximately `13.24 m / 9.8 m = 1.35` span:length arrowhead was
  width-dominant. The v1 source-directed target is about `0.85` and below `1.0`.
- The earlier smoothly rounded multi-section nose/centrebody hid the source's
  large planar facets and steps.
- The broad low wing shell dominated the earlier centrebody. B5 reverses that
  hierarchy: tall central/aft volume first, side planes second.
- The large cyan one-piece sealed canopy conflicted with the small warm/neutral
  forward aperture and visually open/simple source cockpit.
- Teal/dark upholstery suppressed the strongly visible red-seat cue.
- Small tail fins plus visually dominant detailed turbines did not reproduce the
  tall pale rail/fin and blunt aft-box hierarchy.
- Long exposed gun rails and large external pods pushed the craft toward B7's
  securely Zenith-linked language.

## Modern-detail zones

The following are allowed because they improve the standalone remake, but no
source claim should be attached to them. Keep them modular, recessed or
silhouette-secondary:

- a neutral-clear pressure canopy, hatch, hinge, seals and latches;
- instrument displays, stick, throttle, pedals, restraints and life-support;
- interpretation of the round housings as propulsion equipment;
- turbines, nozzles, exhaust colour and engine-light animation;
- weapon type, hardpoint count, muzzle locations and doors;
- retractable landing gear, docking receiver, clamps and boarding steps;
- RCS clusters, service panels, vents, fasteners and navigation lights;
- PBR metallicity, clearcoat, normal/roughness maps, weathering and panel seams;
- numeric handling, acceleration, speed, armour and damage behaviour.

Place modern systems in a separate subtree or tag them with equivalent
`modern_interpretation` metadata. Tag the paired source housings with a specific
`historical_function_unresolved` flag even if gameplay uses them as engines.

## Reconstruction acceptance checks

A source-directed art revision is ready for visual review when all of these are
true:

1. Orthographic debug bounds fall inside the broad ratio bands above, with
   `span < length` and central/aft body width near half the span.
2. Profile, dorsal and aft captures immediately read as the same compact stepped
   wedge, rather than three unrelated plates or a full delta.
3. The aft capture resolves, in order, the pale body frame, large darker aft
   inset, two tall uprights, two subordinate round housings and short side-plane
   tips.
4. A boarding capture shows a physical one-person route, a clearly red seat and
   the restrained warm/neutral forward panel.
5. Removing the modern-detail subtree leaves the complete source-recognition
   silhouette intact.
6. The gameplay collision, seat/boarding anchors, camera, muzzle contracts,
   landing and reuse paths continue to work, without claiming that those modern
   systems are source-authenticated.
7. Documentation continues to distinguish the high-confidence **2011 identity
   lock** from the partial reconstruction-detail gate and unproved 2009
   equivalence.
