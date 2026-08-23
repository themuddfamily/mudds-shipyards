# Fleet Visual Grammar

Status: **design reference derived from the implemented craft.** This
document describes the shared language a *new* craft must speak to look like it
belongs to this fleet. It is written from what
`torrent_provisional`, `arrow_provisional`, `jovian_provisional`,
`zenith_b7_observed` and `halyard_new_design` actually do in the production
`res://scenes/main.tscn`, not from intention.

The first four are the original vertical slice. The fifth, the Halyard Crew
Transport, is the first craft designed *against* this document rather than
described by it; where it had to bend a rule, the rule and the reason are named
in place rather than quietly dropped.

Writing it satisfies the Phase 5 precondition
("only after the original fleet's shared visual grammar is documented"). It adds
no craft and authenticates nothing. Nothing in this file upgrades any historical
confidence: the evidence vocabulary and every status remain owned by
[`docs/research/ship_evidence_matrix.json`](../research/ship_evidence_matrix.json)
and the source ledger.

## How to read this document

This repository's recurring failure is documentation that quietly stops matching
the code, so the claims here are graded and, where possible, machine-checked.

| Grade | Meaning |
| --- | --- |
| **Measured** | Produced by running code. The measuring code is named. If the code changes, the value changes with it. |
| **Frozen** | A constant that a test asserts against the live production scene. Named with its constant and file. Changing the implementation without changing the constant turns a suite red. |
| **Asserted** | A reading of the implementations that no test enforces. Named with the file and line it was read from. Treat these as descriptive, not binding. |

Four tables in this document — marked `GRAMMAR-PALETTE`,
`GRAMMAR-AUDIT-CONSTANTS`, `GRAMMAR-SURFACE` and `GRAMMAR-EVIDENCE` — are parsed
and compared against the code and the ledger by
[`tests/fleet_visual_grammar_doc_test.gd`](../../tests/fleet_visual_grammar_doc_test.gd).
That suite fails if a floor stated here stops matching the constant that
enforces it, if a surface value stated here stops matching its source file, or if
an evidence status stated here stops matching the matrix. It also fails if this
document drops one of those claims, adds one nothing backs, or uses any of the
per-ship prohibited wording the matrix records. The document is the subject under
test, not an oracle: a wrong document turns it red exactly as loudly as wrong
code does.

The primary enforcement mechanism for the grammar itself is
[`tests/fleet_role_differentiation_test.gd`](../../tests/fleet_role_differentiation_test.gd)
(174 assertions at the time of writing). This document explains and points at
that suite rather than restating it. Perceptual colour maths lives in exactly one
place, [`tests/fleet_colour_metrics.gd`](../../tests/fleet_colour_metrics.gd),
which is deliberately outside the `tests/*_test.gd` glob so the audit and any
design-time probe measure with one implementation.

---

## 1. Silhouette and proportion language

### What every craft shares

1. **Bilateral symmetry about a single longitudinal axis, forward is `-Z`.**
   Every muzzle, engine plume, navigation light, damage anchor and escape pod is
   authored as a mirrored pair at `±x` with identical `y` and `z` — Torrent's
   muzzles at `±2.82`, Zenith's at `±1.25` and its wing damage anchors at
   `±4.55`, Arrow's escape pods at `±1.62`. The only deliberately one-sided
   elements in the fleet are the boarding and exit markers, which are always to
   port; see §5.
2. **One dominant mass with subordinate lateral planes.** Each craft reads as a
   central body that the wing/side surfaces broaden, never as a wing that carries
   a pod. They differ in *which* mass dominates, not in whether one does.
3. **Planar, faceted, low-part-count construction.** Large clean planes with
   stepped subdivisions and small bevels. The Torrent spec states this as a
   requirement — "Do not smooth those stations into an organic teardrop. Modern
   bevels should be small enough that the large planar facets and stepped
   construction remain the first read"
   ([`docs/TORRENT_2011_RECONSTRUCTION_SPEC.md`](../TORRENT_2011_RECONSTRUCTION_SPEC.md))
   — and every other craft follows it.
4. **A low overall stance.** Every craft is wider or longer than it is tall by a
   wide margin; nothing in the fleet is a vertical form.
5. **No two craft share a planform ratio.** The family read comes from
   construction language, not from repeated proportions.

### How they separate (Asserted — read from the named collision constants)

Collision envelopes are gameplay normalization, not silhouette measurements, but
they are the only fleet-wide numbers authored in one comparable unit, so they are
the practical proxy for "how big and what shape".

| Craft | Dominant read | Envelope source | Approximate span × length |
| --- | --- | --- | --- |
| Torrent | Compact longitudinal wedge; tall raised central/aft mass dominant; two-tier swept side planes subordinate; two tall aft rails; paired round housings beside the aft body | `scripts/ships/hero_ship.gd:3050-3056` (`WingCollision` 7.2 × 1.5 × 6.3, `HullCollision` 4.6 × 2.35 × 9.0) | 7.2 × 9.0 |
| Arrow | Slender length-dominant fuselage; a 32-section elliptical loft with a thin wide wing plane and two semantically identified escape pods | `scripts/ships/arrow_recon_ship.gd:477-478` (hull 3.1 × 1.65 × 12.2, wing 11.1 × 0.48 × 4.9) | 11.1 × 12.2 |
| Zenith | Width-dominant full delta/arrowhead; broad swept side planes with a raised faceted central body continuing into a dorsal spine, long strakes, repeated stepped subdivisions | `scripts/ships/zenith_interceptor.gd:36-38` (`EXPECTED_LANDING_COLLISION_BOUNDS` size 14.42 × 4.2755 × 10.45) | 14.42 × 10.45 |
| Jovian | Large slab/box freighter hull wrapped around a walkable interior; its exterior is dimensioned by its cargo hold | `scripts/ships/jovian_light_freighter.gd:21-23` (`FLIGHT_COLLISION_BOUNDS` size 18.55 × 6.2 × 26.2, `INTERIOR_BOUNDS` 11.44 × 4.6 × 17.25) | 18.55 × 26.2 |
| Halyard | Long narrow faceted octagonal pressure tube — the only craft whose dominant mass is a tube rather than a plate, wedge, delta or slab — with a proud octagonal bow docking collar, a lit band of ten cabin windows a side, a dorsal service spine, and a transverse tail yoke carrying four engines in one row | `scripts/ships/halyard_crew_transport.gd` (`FLIGHT_COLLISION_BOUNDS`, `INTERIOR_BOUNDS` 5.2 × 3.6 × 22.7) | 9.6 × 28.3 |

The two evidence-bounded craft are the only ones whose proportions have a
written band. Torrent's is a target table with confidence grades
(`span/length` preferred `0.88`, band `0.85–0.94`, "never a width-dominant
`>1.0` arrowhead"); Zenith's is the opposite instruction — width-dominant, and
"visibly distinct from Torrent's compact longitudinal wedge and upright-rail
hierarchy". Arrow and Jovian have no proportion evidence at all and are free
modern interpretation.

---

## 2. Colour system

The fleet uses a **two-layer colour system**, and the two layers have opposite
rules. This is the single most load-bearing distinction in the grammar.

### Layer 1 — shared, and deliberately not differentiating

Every craft uses the same engine and navigation language, so these read as
"fleet", not as "which craft":

| Element | Torrent | Arrow | Jovian | Zenith | Halyard |
| --- | --- | --- | --- | --- | --- |
| Engine emission | `64efff` | `7cf5ef` | `70eee7` | `07bddc` | `68f0ef` |
| Port nav | `ff5c55` | `ff6460` | `ff635d` | `ff0305` | `ff5f58` |
| Starboard nav | `78ee9b` | `7cf0a3` | `70e995` | `04f230` | `74ec97` |

(Asserted, read from `scripts/ships/hero_ship.gd:75-79`,
`scripts/ships/arrow_recon_ship.gd:41-45`,
`scripts/ships/jovian_light_freighter.gd:51-53`,
`scenes/ships/presentation/zenith_authored_presentation.gd:189-192`,
`scripts/ships/halyard_crew_transport.gd`.)

Cyan-family engine glow, red to port, green to starboard. A new craft keeps this
identical. Differentiating a craft through its engine colour breaks the family
read *and* breaks the navigation convention.

### Layer 2 — per-craft, and hard-separated

Identity is carried by exactly two things: the **body tone** (the brightest
opaque albedo holding at least a tenth of the craft's visible surface area — the
colour a player reads off the hull at a glance) and the **identification accent**
(`HeroShip.identification_accent`, applied to trim, harnesses and cockpit
displays).

<!-- GRAMMAR-PALETTE:BEGIN -->

| Key | Value | Frozen by |
| --- | --- | --- |
| `body_tone_torrent` | `e8e2cf` | `EXPECTED_BODY_TONE` in `tests/fleet_role_differentiation_test.gd` |
| `body_tone_arrow` | `7891ab` | `EXPECTED_BODY_TONE` |
| `body_tone_jovian` | `e0ab74` | `EXPECTED_BODY_TONE` |
| `body_tone_zenith` | `bac8d6` | `EXPECTED_BODY_TONE` |
| `accent_torrent` | `f0b94d` | `EXPECTED_ACCENTS` |
| `accent_arrow` | `45dee6` | `EXPECTED_ACCENTS` |
| `accent_jovian` | `b32620` | `EXPECTED_ACCENTS` |
| `accent_zenith` | `2f5fbe` | `EXPECTED_ACCENTS` |
| `body_tone_halyard` | `6e7a3e` | `EXPECTED_BODY_TONE` |
| `accent_halyard` | `341024` | `EXPECTED_ACCENTS` |

<!-- GRAMMAR-PALETTE:END -->

### The separation floors

Separation is measured perceptually — sRGB → linear → optional Viénot 1999
dichromat simulation → CIE L\*a\*b\* → CIEDE2000 — by
`tests/fleet_colour_metrics.gd`, under four vision models
(`normal`, `protanopia`, `deuteranopia`, `tritanopia`).

<!-- GRAMMAR-AUDIT-CONSTANTS:BEGIN -->

| Key | Value | Frozen by (constant in `tests/fleet_role_differentiation_test.gd` unless noted) |
| --- | --- | --- |
| `body_tone_floor` | 12.0 | `BODY_TONE_FLOOR` |
| `accent_floor` | 25.0 | `ACCENT_FLOOR` |
| `torrent_accent_floor` | 30.0 | `TORRENT_ACCENT_FLOOR` |
| `body_tone_minimum_share` | 0.10 | `BODY_TONE_MINIMUM_SHARE` |
| `pale_body_minimum_lightness` | 78.0 | `PALE_BODY_MINIMUM_LIGHTNESS` |
| `vision_model_count` | 4 | `VISION_MODELS` in `tests/fleet_colour_metrics.gd` |
| `seat_to_cockpit_camera_rise_m` | 1.76 | `SEAT_TO_COCKPIT_CAMERA_RISE` |
| `eye_above_head_bone_minimum_m` | 0.15 | `EYE_ABOVE_HEAD_BONE_MINIMUM` |
| `eye_above_head_bone_maximum_m` | 0.35 | `EYE_ABOVE_HEAD_BONE_MAXIMUM` |
| `head_hull_clearance_minimum_m` | 0.5 | `HEAD_HULL_CLEARANCE_MINIMUM` |
| `boarding_fallback_reach_m` | 7.0 | `BOARDING_FALLBACK_REACH` (mirrors `GameFlow.BOARDING_FALLBACK_REACH`) |
| `minimum_staged_distance_m` | 7.05 | `MINIMUM_STAGED_DISTANCE` |
| `minimum_walk_metres` | 1.2 | `MINIMUM_WALK_METRES` |
| `higher_is_better_axis_count` | 10 | `HIGHER_IS_BETTER` |
| `lower_is_better_axis_count` | 3 | `LOWER_IS_BETTER` |
| `handling_axis_count` | 16 | `ShipDefinition.get_flight_profile()` + `get_systems_profile()` |
| `minimum_differing_handling_axes` | 14 | `differing >= 14` in `_test_role_differentiation` |
| `small_craft_envelope_maximum_m` | 15.0 | `SMALL_CRAFT_ENVELOPE_MAXIMUM` |
| `interior_minimum_volume_m3` | 300.0 | `INTERIOR_MINIMUM_VOLUME` |
| `freighter_envelope_minimum_x_m` | 15.0 | `INTERIOR_CRAFT` freighter envelope gate |
| `freighter_envelope_minimum_z_m` | 25.0 | `INTERIOR_CRAFT` freighter envelope gate |
| `freighter_passenger_seat_minimum` | 4 | `INTERIOR_CRAFT` freighter seat-count gate |
| `crew_transport_envelope_minimum_x_m` | 8.0 | `INTERIOR_CRAFT` transport envelope gate |
| `crew_transport_envelope_minimum_z_m` | 25.0 | `INTERIOR_CRAFT` transport envelope gate |
| `crew_transport_seat_minimum` | 6 | `INTERIOR_CRAFT` transport seat-count gate |

<!-- GRAMMAR-AUDIT-CONSTANTS:END -->

**Why the floors are so far above the just-noticeable difference.** CIEDE2000 is
scaled so that roughly `1.0` is a JND for two large patches held side by side and
`~2.3` is the practical JND. At-a-glance craft identification is a much harder
task: the hulls are never adjacent, are seen at different distances, attitudes
and lighting, and are matched against colour memory rather than against each
other. The runtime also multiplies each authored albedo tint by a bound hull map
and then tonemaps it, compressing authored differences further. The body floor is
an order of magnitude above the patch JND for that reason. The full argument is
in the header of `tests/fleet_role_differentiation_test.gd`; it is not repeated
here so it cannot drift.

**Measured headroom today** (printed as `FLEET_COLOUR_EVIDENCE` by the audit):

| Vision model | Minimum body-tone separation | Minimum accent separation |
| --- | ---: | ---: |
| normal | 16.95 | 42.57 |
| protanopia | 16.62 | 37.38 |
| deuteranopia | 16.91 | 31.38 |
| tritanopia | 17.45 | 34.19 |

Do not treat that headroom as budget. The minimum over a set is monotonically
non-increasing as craft are added: a new craft can only lower it, and it lowers
it against **every** existing tone at once.

**Measured consequence, recorded because it binds the next craft.** The Halyard
was required to clear those minima outright rather than the frozen floors, and it
does — body `6e7a3e` at 19.06 and accent `341024` at 31.60 — so the table above is
unchanged by its arrival. Producing that accent used the last of the space: a
full sweep of the sRGB cube against the four existing accents under all four
vision models found that **every** colour clearing both accent floors is either a
near-neutral grey at ~25.1 or a dark violet below L\* 27. There is no bright
chromatic accent left. A sixth craft either takes a value that lowers the fleet
minimum, or the accent role has to be re-thought — a second cue (a shape, a
marking, a light pattern) rather than a sixth hue.

**The pale boundary.** `PALE_BODY_CRAFT` freezes Torrent and Zenith at
`L* >= 78.0`. This is an *evidence* constraint, not a taste one: B5/B6 record a
high-value low-saturation off-white across every silhouette-defining Torrent mass,
and B7 observes a pale exterior as a relative value. Those two craft cannot be
pulled apart in hue or value without contradicting a registered source
observation, which is what caps how far the palette can be spread. Arrow and
Jovian carry no such claim — `palette` is explicitly listed among their unknowns
in the evidence matrix — and were moved to slate and warm tan precisely because
they were free to move.

**Recorded history, so it is not repeated.** The audited state before the
readability pass was four craft sharing one near-white body tone (Torrent
`#e8e2cf`, Arrow `#e9eee9`, Jovian `#e7e4d6`, Zenith `#e6e2d5`) whose closest
pair measured **CIEDE2000 0.82** in normal vision and **0.45** under simulated
deuteranopia — below the JND — while the widest pair reached only 7.3; the
Arrow/Jovian/Zenith accents additionally clustered in cyan-teal at 6.40 under
protanopia. The family read had been achieved by making the craft
indistinguishable. That is the specific failure this grammar exists to prevent.

---

## 3. Material and surface treatment

### What the original four vertical-slice craft share

- `StandardMaterial3D`, per-pixel shading, Burley diffuse, Schlick-GGX specular.
- A registered PBR map trio per hull family: `<craft>-hull-albedo-v1.png`,
  `-normal-v1.png`, `-roughness-v1.png`, with roughness read from the **red
  channel** (`TEXTURE_CHANNEL_RED`). Frozen for Arrow and Jovian by
  `tests/fleet_pbr_test.gd`, for Torrent by `tests/torrent_hero_art_test.gd:152`
  and `tests/torrent_authored_asset_test.gd:682`.
- **Clearcoat enabled on every hull material**, at a low roughness. This is the
  fleet's semi-matte painted-alloy read.
- In the two *authored* (Blender-imported) presentations, emissive and glass
  roles have shadow casting explicitly disabled
  (`torrent_hero_presentation.gd:136-137`, `zenith_authored_presentation.gd:206-207`).
  The two procedurally built craft set no `cast_shadow` at all. This is an
  inconsistency, not a rule: a new authored craft should follow the authored
  convention.
- Exactly two hull material keys per craft — a primary and a shade/secondary —
  which are the craft's stable public material API
  (`pearl`/`ceramic` on Arrow, `hull_warm`/`hull_cool` on Jovian,
  `ivory`/`light` on the Torrent fallback,
  `PaleCeramicHull`/`PaleFacetSecondary` on Zenith).

### Normal relief and clearcoat, per craft (machine-checked)

The fleet does **not** standardise `normal_scale`. Each craft picks a value in a
low band suited to its map and its size; the station family, by contrast,
standardised on `1.0`. A ship hull authored at `1.0` reads as station plating.

<!-- GRAMMAR-SURFACE:BEGIN -->

| Key | Value | Read from |
| --- | --- | --- |
| `normal_scale_torrent_procedural` | 0.32 | `scripts/ships/hero_ship.gd` |
| `normal_scale_torrent_authored_hero` | 0.18 | `scenes/ships/presentation/torrent_hero_presentation.gd` |
| `normal_scale_torrent_macroform_atlas` | 0.2 | `scenes/ships/presentation/torrent_authored_macroform.tscn` |
| `normal_scale_arrow` | 0.62 | `scripts/ships/arrow_recon_ship.gd` |
| `normal_scale_jovian` | 0.68 | `scripts/ships/jovian_light_freighter.gd` |
| `normal_scale_halyard` | 0.46 | `scripts/ships/halyard_crew_transport.gd` |
| `normal_scale_zenith_hull` | 0.18 | `scenes/ships/presentation/zenith_authored_presentation.gd` |
| `normal_scale_zenith_secondary` | 0.10 | `scenes/ships/presentation/zenith_authored_presentation.gd` |
| `normal_scale_station_panel` | 1.0 | `scripts/world/fleet_dock_comb.gd` |
| `clearcoat_torrent_procedural` | 0.58 | `scripts/ships/hero_ship.gd` |
| `clearcoat_torrent_authored_hero` | 0.34 | `scenes/ships/presentation/torrent_hero_presentation.gd` |
| `clearcoat_arrow` | 0.48 | `scripts/ships/arrow_recon_ship.gd` |
| `clearcoat_jovian` | 0.42 | `scripts/ships/jovian_light_freighter.gd` |
| `clearcoat_halyard` | 0.30 | `scripts/ships/halyard_crew_transport.gd` |
| `clearcoat_zenith` | 0.25 | `scenes/ships/presentation/zenith_authored_presentation.gd` |

<!-- GRAMMAR-SURFACE:END -->

The ship band is `0.10 – 0.68`. A new craft picks a value inside it and pairs it
with its own map set at a UV scale matched to its panel size.

### Triplanar or UV, decided by how the hull is built (Asserted)

| Hull construction | Projection | Examples |
| --- | --- | --- |
| Procedurally lofted or box-built in GDScript | `uv1_triplanar = true`, sharpness `4.0–4.5`, `uv1_scale` tuned per craft (Torrent `0.17`, Jovian `0.24`, Arrow `0.34`) | `scripts/ships/hero_ship.gd:3475-3477`, `arrow_recon_ship.gd:230-232`, `jovian_light_freighter.gd:364-366` |
| Authored in Blender and imported with UVs | `uv1_triplanar = false`, anisotropic mipmap filtering | `torrent_hero_presentation.gd:163-165`, `zenith_authored_presentation.gd:234-235` |

Triplanar exists to keep the panel treatment stable across a procedural loft and
to avoid stretched seams at ring caps. A UV-authored asset does not need it and
should not pay for it.

### The map-reuse rule

Each craft gets its own map set. This is a rule with a recorded cause: the Jovian
originally reused the Arrow's small ceramic panel swatch and "made two
intentionally different classes read as the same procedural prop at normal
viewing distance"
(`scripts/ships/jovian_light_freighter.gd:348-350`), and `tests/fleet_pbr_test.gd`
now asserts specifically that "Jovian no longer reuses the Arrow candidate's
panel swatch". Loading Torrent's maps onto fleet variants also "permanently
contaminated the resource cache" (`scripts/ships/hero_ship.gd:3461-3463`), which
is why that load is gated behind
`_uses_torrent_reconstruction_presentation()`.

The standing exception is Zenith, which reuses the `torrent-hull-*` trio at its
own `normal_scale` and its own tint. It is an exception, not a precedent.

---

## 4. Scale to role

Size, tags, interior provision and cockpit count are one interlocking claim, and
`_test_interior_provision` cross-checks all four directions of it.

### Small craft

- Compatibility tags include `small_craft`; **must not** include `freight`,
  `cargo` or `light_freighter`.
- Collision envelope under `small_craft_envelope_maximum_m` in both `x` and `z`.
- Exactly one `CockpitInterior` volume containing exactly one `*SeatAnchor*`
  `Marker3D` — the single pilot station the fighter role implies.
- **No** `WalkableInterior`, `CargoBay`, `PassengerCabin` or
  `InteriorOccupantVolume` node, **no** `MovingInteriorFrame`, and **no**
  `get_walkable_interior_report` / `get_interior_root` method. A fighter must
  "claim no walkable interior it does not have".

Torrent, Arrow and Zenith are all small craft. Their roles are separated by
handling and silhouette, not by size band.

### Medium craft with an interior

- Tags include `medium_craft` and the craft's own role tag (`light_freighter`,
  `crew_transport`).
- Collision envelope above `small_craft_envelope_maximum_m` on **at least one**
  horizontal axis, plus that craft's own frozen per-axis floors in
  `INTERIOR_CRAFT`. The Jovian clears the band on both axes (a slab); the Halyard
  clears it on length alone (a tube). What is enforced is that a craft with an
  interior is not small, and that a craft that is not small has an interior —
  both directions, over every craft in the fleet.
- Publishes a walkable interior report whose root is **connected to the ship
  frame** (`detached_interior` false), with at least that craft's own frozen seat
  minimum, an exterior access marker, an interior deck marker, and interior
  bounds of at least `interior_minimum_volume_m3` that are a walkable volume
  rather than a token cavity.
- Implements the `in_flight_cabin` contract
  (`HeroShip.get_in_flight_cabin_report()`), because a craft with a connected,
  bounded, physically walkable cabin has somewhere for its pilot to stand.
- Uses `MovingInteriorFrame` so passenger collision stays stable through flight.

### The rule this expresses

**Interior provision is a consequence of envelope, and the declared tags must
agree with both.** A craft may not be small and claim cargo authority, and may
not be large and publish no interior — a large empty hull is a scale claim the
gameplay does not honour. The cockpit-to-hull relationship scales with it:
measured head-to-hull clearance runs 0.531 m (Zenith, the tightest cockpit in the
fleet) → 0.561 m (Torrent) → 1.401 m (Arrow) → 3.010 m (Halyard) → 3.256 m
(Jovian).

---

## 5. Cockpit and boarding conventions

### The seat and eye-point convention

- `PilotSeatAnchor` is a `Marker3D` parented to `CockpitInterior`, which is
  itself a child of the craft's visual root (`TorrentVisual/CockpitInterior`,
  `ZenithVisual/CockpitInterior`, and the equivalents on Arrow, Jovian and
  Halyard).
  A seat anchor on a loose marker outside the functional cockpit fails the audit.
- **`PilotSeatAnchor` is a feet-frame marker, not a cushion height.**
  `PlayerController` treats its own root as a feet frame and carries its hips
  0.72 m above it, so the anchor is authored at *cushion height minus 0.72 m*.
- `CockpitCamera` is a `Camera3D`, also parented to `CockpitInterior`, positioned
  exactly `seat_to_cockpit_camera_rise_m` above the seat anchor in `y` and aimed
  along the craft's own nose axis (`dot > 0.999` against the craft's `-Z`).
- **Consequence, measured on all five craft: the cockpit camera lands `+0.201 m`
  above the seated pilot's head bone.** That figure is printed as
  `FLEET_SEATING_EVIDENCE` by the audit; it is a *measurement*, produced by the
  frozen 1.76 m rise plus the shared pilot rig. What is enforced is the exact
  1.76 m rise and the `0.15 – 0.35` band, not the 0.201 m itself.
- The seated pilot's head bone must stay at least
  `head_hull_clearance_minimum_m` below the top of the craft's own rendered hull,
  so the skull does not cross a closed canopy.

This convention has already failed once and is frozen exactly, not as a band,
for that reason: Zenith placed its cockpit camera 0.859 m *below* the seated
pilot's head bone (a chest-height view) and left the head bone only 0.061 m under
its own hull crown, because its `PilotSeatAnchor` had been authored at
seat-cushion height instead of feet-frame height. See the re-freeze note in
`tests/zenith_interceptor_test.gd`.

### The boarding convention

- Every craft carries an exterior `BoardingPoint` `Marker3D` on the **port
  (`-x`) side**, a `ShipBoardingArea` `Area3D` co-located with it, and an
  `ExitPoint` further outboard, rotated to face away from the hull and placed
  beyond the craft's own collision so re-enabling the player capsule cannot wedge
  it inside the landed craft.
  (Torrent `-3.2`, Arrow `-2.45`, Jovian `-3.4`, Zenith `-7.65`, Halyard
  `-4.90` in `x`.)
- Boarding is **physical**. `GameFlow` offers no boarding prompt beyond
  `boarding_fallback_reach_m`. The audit stages the avatar past
  `minimum_staged_distance_m`, asserts no candidate exists, then walks it in with
  real left-stick joypad input through the live `PlayerController`, asserting at
  least `minimum_walk_metres` walked on production collision before the prompt
  appears.
- Muzzles are a mirrored `LeftMuzzle` / `RightMuzzle` pair.
- Entry copy is per craft and lives in the `ShipDefinition`
  (`entry_noun` / `entry_open_verb` / `entry_close_verb` / `boarding_verb`) —
  Torrent "open canopy", Arrow and Zenith "raise/seal canopy", Jovian
  "raise/seal pilot hatch", and Halyard "raise/seal flight deck hatch". The
  vocabulary is data, not a subclass constant.

---

## 6. Evidence-bounded versus free

This is the axis on which the fleet is least uniform, and the one a new craft is
most likely to get wrong.

<!-- GRAMMAR-EVIDENCE:BEGIN -->

| ship_id | name_to_model_status | model_sources | implementation_status |
| --- | --- | --- | --- |
| `torrent` | `bounded_partial_reconstruction` | `B5`, `B6` | `b5_observed_partial_reconstruction` |
| `zenith` | `bounded_partial_reconstruction` | `B7` | `b7_observed_partial_reconstruction` |
| `arrow` | `unknown` | — | `provisional_modern_candidate_frozen` |
| `jovian` | `unknown` | — | `provisional_modern_candidate_frozen` |

<!-- GRAMMAR-EVIDENCE:END -->

### What is actually bounded

| Craft | Bounded by evidence | Free modern design |
| --- | --- | --- |
| Torrent | Name and interceptor role (A3); the B5-observed identity chain; broad macroform and silhouette hierarchy; pale low-saturation exterior; one central visibly **red** seat; a small warm forward panel; presence and rough location of the paired round housings (function unresolved) | Absolute scale, all dimensions in metres, systems, entry mechanism, materials and PBR response, weapons, handling, engine interpretation, landing gear, continuity with 2009 |
| Zenith | Name and the B7 Interceptor label (with the A5/A9 Interceptor-vs-Fighter conflict left explicit); width-dominant delta/arrow planform; pale off-white/light-grey exterior as a *relative value*; raised faceted central body into a dorsal spine; long strakes and stepped subdivisions; the presence of a pod-like form tagged `historical_function_unresolved` | Everything else, explicitly: length, span, height, scale, pod count and purpose, propulsion, weapons, landing gear, canopy, seat count, cockpit plan, exact colours, materials, handling, berth placement |
| Arrow | Name, reconnaissance role, and a **written** two-escape-pod count from A3's dated page text. Nothing visual. | Silhouette, proportions, pod appearance and placement, cockpit, entry, sensors, engines, weapons, **palette**, materials, handling — all of it |
| Jovian | Name and light-freighter role from A3's dated page text. Nothing visual. | Silhouette, dimensions, **colours**, interior, ramp, cockpit and access route, capacity, engines, weapons, materials, handling, berth — all of it |

Arrow and Jovian carry `name_to_model_status: unknown` with `model_sources: []`.
No registered source ties any craft to either name. A3 is page text with no
imagery; the B3/B4 label strings sit inside bulk `fleet.labels_*` claims with no
frame or timestamp anchor and no craft tied to them, and B3 `f1879` shows a
regeneration label changing over an *unchanged* visible craft. Their silhouettes
are the project's own design wearing a historical name — and that is recorded, not
hidden.

### What a new craft's evidence status is

`ShipDefinition.EvidenceStatus.NEW`. Not `PROVISIONAL`. A new craft has no
historical claim to be provisional about, and `ShipDefinition.audit()` will warn
if references are attached to a `NEW` design, treating them as
inspiration/provenance rather than authentication.

---

## 7. What a new craft must NOT do

This is the operative section. Everything above describes; this constrains.

### It must not collapse the colour separation

1. **Do not pick a body tone within `body_tone_floor` CIEDE2000 of any existing
   body tone, under any of the four vision models.** Same for accents against
   `accent_floor`. Check with the shared maths — `preload(
   "res://tests/fleet_colour_metrics.gd").minimum_separation(values, mode)` over
   all four vision models — before authoring anything, not after.
2. **Do not spend the measured headroom.** The current minima (16.62 body,
   31.38 accent) are the *fleet's* margin, not a per-craft allowance. Adding a
   sixth tone lowers the minimum against all five existing tones simultaneously.
3. **Do not take a pale near-white body.** "Pale" is a source observation owned
   by exactly two craft, not a family trait. A new craft has no pale claim to
   make, and the pale region of the space is already occupied at the floor by
   Torrent and Zenith.
4. **Do not reuse the warm ivory `#e8e2cf` family as a default fleet hull.** That
   is precisely the state the audit recorded as broken.
5. **Do not take a warm gold accent.** Torrent's gold carries the stricter
   `torrent_accent_floor` because it is the player's home craft's at-a-glance cue.
6. **Do not differentiate through the engine or nav colours.** Those are the
   shared layer. Cyan engine, red port, green starboard, unchanged.

### It must not break the family read

7. **Do not standardise the hull on `normal_scale = 1.0`.** That is the station
   family's value (`normal_scale_station_panel`, enforced by
   `tests/station_surface_playability_test.gd` and
   `tests/station_triplanar_material_test.gd`). A ship hull at 1.0 reads as
   station plating, not as a vessel.
8. **Do not reuse another craft's hull map set.** Author a new
   `<craft>-hull-albedo/normal/roughness-v1` trio. The Jovian/Arrow shared-swatch
   defect is the recorded reason this rule exists.
9. **Do not build an organic, smoothly blended, or asymmetric hull.** Planar,
   faceted, stepped, bilaterally symmetric about `-Z`.
10. **Do not duplicate an existing planform ratio or an existing dominant-mass
    hierarchy.** Family comes from construction language, silhouettes must
    separate.
11. **Do not give the craft a vertical stance or a wing-dominant-over-body
    hierarchy.** Nothing in the fleet reads that way.

### It must not imply evidence that does not exist

12. **Do not use any of the known historical ship names for a modern design.**
    The current list is the `ships` array of
    `docs/research/ship_evidence_matrix.json` — fourteen names, of which twelve
    sit at `name_to_model_status: unknown` (everything except Torrent and
    Zenith), including the ten not yet implemented. Each has an open
    `next_evidence_gate`; attaching one to new geometry manufactures a
    name-to-model claim the ledger does not hold and closes that gate with an
    answer nobody found. A new craft gets a new name.
13. **Do not present a new craft as a variant, successor, or family member of
    Arrow or Jovian.** There is no lineage there to inherit. Arrow and Jovian have
    no name-to-model mapping at all; a craft described as "in the Arrow family"
    inherits from nothing while *sounding* like it inherits from a source, which
    is worse than inventing outright — it launders a modern design into the
    historical record.
14. **Do not import Zenith's wide-delta, long-strake or pod language, or
    Torrent's aft-rail and paired-round-housing language.** Those are the two
    evidence-bounded silhouettes. Borrowing them makes a modern craft read as a
    reconstruction and, per the Zenith spec's cross-ship exclusion rules,
    contaminates the source-core boundary in both directions.
15. **Do not use any of the prohibited wording** recorded per ship under
    `prohibited_wording` in `docs/research/ship_evidence_matrix.json`. Those
    strings are the specific phrasings that would turn a modern candidate into a
    claimed reconstruction, and they are deliberately not reproduced here — read
    them from the matrix. `tests/fleet_visual_grammar_doc_test.gd` fails if any
    of them appears anywhere in this document, and
    `tests/research_evidence_test.gd` guards the ledger side.
16. **Do not attach historical evidence references as authentication.** Use
    `EvidenceStatus.NEW`, and describe influence as influence.
17. **Do not let a render, a test pass, or an attractive silhouette raise a
    status.** Only a new registered ledger anchor can do that.

### It must not break the physical contracts

18. **Do not author `PilotSeatAnchor` at cushion height.** It is a feet-frame
    marker. This exact mistake put Zenith's camera 0.859 m below the pilot's head.
19. **Do not float the cockpit camera off the hull, off-axis, or at a rise other
    than `seat_to_cockpit_camera_rise_m`.** Both anchors are parented to
    `CockpitInterior`, and the camera looks along the craft's own nose axis.
20. **Do not seat the pilot's head within `head_hull_clearance_minimum_m` of the
    craft's own hull top.**
21. **Do not offer boarding without a walk.** No teleport-in boarding, no prompt
    beyond `boarding_fallback_reach_m`, exterior boarding point on the port side,
    exit point clear of the craft's own collision.
22. **Do not claim an interior the craft does not have,** and do not declare
    `freight`/`cargo`/`light_freighter` tags without a connected walkable interior
    that meets the medium-craft gates. Equally, do not build a large hull with no
    interior.
23. **Do not fork `GameFlow`, landing, combat resolution, or lifecycle logic.**
    A new craft supplies handling, collision, anchors, audio profile, tags and
    presentation. If the role genuinely needs a new capability, build that
    capability as its own typed component first (Phase 5 specification, step 4).
24. **Do not weaken the frozen four-craft vertical-slice roster** to make room.
    Test the old and expanded rosters explicitly.

### It must not be a straight upgrade

25. See section 8. No craft may strictly dominate another.

---

## 8. The lateral-trade-off rule, operationally

### The definition

A craft's handling is a vector over **16 axes** (`handling_axis_count`) — the 12
flight-profile fields plus the 4 systems-profile fields of `ShipDefinition`. Of
those, **13 have an unambiguous "better for the pilot" direction**:

- `higher_is_better_axis_count` where more is better: `maximum_speed`,
  `thrust_acceleration`, `brake_acceleration`, `boost_speed`,
  `boost_multiplier`, `yaw_speed_degrees`, `roll_speed_degrees`,
  `throttle_response`, `maximum_hull`, `landing_maximum_speed`.
- `lower_is_better_axis_count` where less is better: `passive_drag`,
  `engine_start_time`, `weapon_cooldown`.

The three excluded axes — `flight_assist_strength`, `visual_bank_degrees`,
`maximum_mouse_turn_degrees` — are feel axes with no better direction, and are
excluded on purpose.

**The rule:** for every *ordered* pair `(A, B)` of distinct craft, `B` must beat
`A` on at least one of the 13 trade-off axes. With eight craft that is 56 ordered
pairs, all 56 of which the audit asserts. Equivalently: no craft's handling
vector weakly dominates another's across all 13 axes.

Two further conditions stop the rule being satisfied trivially:

- **Distinctness.** Every unordered pair must differ on at least
  `minimum_differing_handling_axes` of the 16 axes. Measured today, the minimum
  across all pairs is exactly 14 of 16 — the fleet is at the floor, not above it.
- **Signature.** Each craft must be the *sole* extreme on its own axes:
  Jovian alone owns the highest hull and the lowest top speed; Zenith alone owns
  the highest yaw and roll while owning the lowest hull; Arrow alone owns the
  highest boost speed, paying for it in launch acceleration and weapon cadence;
  Torrent alone owns the strongest boost multiplier, the fastest cadence and the
  most forgiving landing gate; Halyard alone owns the highest sustained top speed
  while owning the worst acceleration, braking, throttle response, boost
  multiplier, turn rates and landing gate, and the longest spool and cadence.

### How it is measured

`_count_advantages(first, second)` in
`tests/fleet_role_differentiation_test.gd` counts, over the 13 axes, how many
`second` wins. The audit reads the profiles from the *live* `ShipDefinition`
resources carried by the craft in the production Main scene, so it measures the
handling that actually ships rather than a constant declared somewhere in source.

### Expanded production matrix

The three original-modern production craft now have explicit `.tres` handling
definitions. Their advantage and weakness are intentional: the cargo hauler
trades acceleration and hull for freight stability, the bomber trades turn
rate and cadence for hull and braking, and the light interceptor trades hull
and drag tolerance for speed, boost and turn response. Each has at least one
advantage and one weakness against every other craft; none strictly dominates.

| Craft | Definition | Signature advantage | Deliberate weakness |
| --- | --- | --- | --- |
| Cinder cargo hauler | `assets/ships/cinder_cargo_hauler_new_design.tres` | `maximum_hull` and `passive_drag` over fighters | `maximum_speed`, `thrust_acceleration`, `weapon_cooldown` |
| Cinder long-range bomber | `assets/ships/cinder_long_range_bomber_new_design.tres` | `maximum_hull` and `brake_acceleration` among new craft | `yaw_speed_degrees`, `roll_speed_degrees`, `weapon_cooldown` |
| Cinder light interceptor | `assets/ships/cinder_light_interceptor_new_design.tres` | `maximum_speed`, `boost_multiplier`, `roll_speed_degrees` among new craft | `maximum_hull`, `passive_drag`, `engine_start_time` |

The expanded advantage counts below are `B` over `A`, measured by
`tests/fleet_role_differentiation_test.gd` from the eight production
definitions. They are a balance matrix, not historical evidence.

| B over A | Torrent | Arrow | Jovian | Zenith | Halyard | Cargo | Bomber | Interceptor |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Torrent | — | 8 | 11 | 5 | 10 | 11 | 11 | 7 |
| Arrow | 5 | — | 11 | 3 | 10 | 11 | 11 | 4 |
| Jovian | 2 | 2 | — | 2 | 11 | 11 | 6 | 2 |
| Zenith | 8 | 8 | 11 | — | 10 | 11 | 11 | 7 |
| Halyard | 3 | 3 | 2 | 3 | — | 2 | 6 | 3 |
| Cargo | 2 | 2 | 11 | 2 | 2 | — | 9 | 11 |
| Bomber | 2 | 2 | 6 | 2 | 6 | 4 | — | 2 |
| Interceptor | 7 | 4 | 2 | 7 | 3 | 2 | 2 | — |

### The current margin, and why it is thin

Advantage counts today (`B` over `A`), computed from the eight
`assets/ships/*.tres` files with the same two axis lists:

| B (row) beats A (column) on | Torrent | Arrow | Jovian | Zenith | Halyard |
| --- | ---: | ---: | ---: | ---: | ---: |
| **Torrent** | — | 8 | 11 | 5 | 10 |
| **Arrow** | 5 | — | 11 | 3 | 10 |
| **Jovian** | 2 | 2 | — | 2 | 11 |
| **Zenith** | 8 | 8 | 11 | — | 10 |
| **Halyard** | 3 | 3 | 2 | 3 | — |

The minimum is **2**: the freighter's, the transport's, and the three new
craft's narrowest matchups. Jovian's entire lateral case against every fighter is
`maximum_hull` and `passive_drag` and nothing else; the transport's case against
the freighter is `maximum_speed` and `boost_speed` and nothing else. The audit
asserts only `> 0`, so this is a measured margin, not a frozen floor — but it is
the real constraint on a sixth craft. "A freighter, but slightly faster" has
almost no room left to exist without dominating something.

### How a designer checks a candidate before building

1. Write the candidate `ShipDefinition` values first — before any geometry.
2. Run `get_validation_errors()`. The schema already constrains the trade-off
   space: `boost_speed >= maximum_speed`, `brake_acceleration >= passive_drag`,
   `landing_maximum_speed <= maximum_speed`, and every field has a hard range.
3. For each of the eight existing craft, count advantages **in both directions**
   over the 13 axes. Both counts must be `> 0`. Any zero means one of the two
   craft is strictly dominated and the candidate is not shippable.
4. Count differing axes against each existing craft. Fewer than
   `minimum_differing_handling_axes` of 16 means the candidate is a near-duplicate
   of something that already exists, whatever its silhouette says.
5. Name the candidate's signature axis — the one thing it is the sole extreme
   on — and name what it pays for it. If neither exists, the craft has no role.
6. Check the candidate does not take a signature away from an existing craft. The
   original signature assertions above are frozen; a new craft that out-rolls Zenith
   or out-hulls Jovian turns them red.
7. Only then build geometry, and add the craft to the fleet so
   `tests/fleet_role_differentiation_test.gd` measures it for real.

Steps 3–6 are a table exercise on eight `.tres` files and take minutes. They are
cheap precisely because they happen before art.

---

## 9. What this document deliberately does not cover

- **Any handling value as a recommendation.** The trade-off rule constrains
  relationships between craft; it prescribes no numbers.
- **Audio.** `audio_profile_id` is fleet data (`standard_fighter`,
  `efficient_twin_recon`, `heavy_quad_freighter`) but no measured audio grammar
  has been established, and inventing one here would be exactly the unevidenced
  assertion this document argues against.
- **LOD triangle budgets.** Zenith's 47,274 / 5,412 authored levels are its own
  frozen contract, not a fleet target; the other four are built differently.
- **Damage, destruction and debris presentation.** Phase 6 scope.
- **Berth and station-side visual language.** Owned by
  `docs/research/STATION_TOPOLOGY.md` and the station module suites. The only
  cross-reference made here is the deliberate `normal_scale` divergence.
- **Whether any of this is historically correct.** It is not a claim about the
  original ships. It is a description of what this project built, and a
  constraint on what it builds next.
