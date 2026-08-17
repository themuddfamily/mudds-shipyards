# Planetary landing region definition

`PlanetaryLandingRegionDefinition` is a typed, data-only contract for one
landing region on one planetary body. It is intentionally independent of the
parallel planetary world, atmosphere, terrain, and coordinate-frame contracts.
A later composition layer may resolve those resources by the stable world/body
IDs, but this definition imports none of them and owns none of their lifecycle.

## Identity and coordinate contract

`world_id`, `body_id`, and `region_id` are stable lowercase snake-case IDs whose
first character is a lowercase letter. The planetary scene root is the body's
physical centre. `body_local_center_m` is the radial vector from that
body-centred scene-root origin, in metres.
`body_local_basis` is a finite, unit-scale, right-handed orthonormal tangent
frame: +Y is surface normal and +X/+Z form the surface plane. All child geometry
is expressed relative to that region frame, avoiding any implied world-space or
floating-origin transform.

The definition declares an independent sea-level datum: `body_radius_m`,
`minimum_elevation_m`, and `maximum_elevation_m`. The canonical defaults are a
120,000 m radius and an elevation range of -2,500 m to +8,500 m, producing an
inclusive valid surface-radius envelope of 117,500 m to 128,500 m. The default
region centre `(0, 120000, 0)` therefore lies exactly at sea level. Validation
requires the centre's radial length to remain inside the declared envelope. A
later composition resolver may compare these declarations with a planetary
world or terrain profile; this resource has no dependency on or authority over
either contract.

Approach corridors are deterministic oriented boxes. Each record has a stable
ID, region-local transform, positive half extents in metres, and exact target
touchdown-pad ID; basis -Z is inbound travel. Every declared pad must have at
least one corridor. The boxes are geometry envelopes only, not triggers or
flight rails.

Touchdown pads have stable IDs, region-local transforms, explicit width/length,
and one named egress anchor. Surface-route anchors are stable named points only:
the definition does not create edges, claim traversability, or move an actor.
Declared corridor, pad, compatible-ship-tag, and anchor order is retained.

## Eligibility limits

Compatible ship tags are a non-empty stable-ID roster. Surface slope is in
degrees; roughness, vertical clearance, approach altitude, and on-foot egress
width are metres. Approach altitude is measured along region-frame +Y above its
tangent plane. These values let a later authority decide eligibility, but this
resource never accepts a landing, assigns a pad, leases space, or certifies live
terrain.

Every scalar, vector, basis, transform, collection count, and dimension is
finite and bounded. Cross-field validation rejects mismatched typed arrays,
duplicate IDs/tags, missing corridor targets, pads without approaches, unknown
egress anchors, a region centre outside the declared radial surface envelope,
insufficient projected corridor height, pad normals beyond the surface-slope
limit, and inverted altitude or elevation limits.

## Evidence, snapshots, and authority

The foundation is explicitly `NEW` / `modern_interpretation`, scoped to the
body-local landing-region contract; it makes no recovered historical geometry
claim. Evidence notes are required and optional references are validated for
stable presentation.

Snapshot and audit methods build deeply detached dictionaries and ordered record
arrays, including safe deterministic output for an invalid resource. The audit
publishes the unit system, orientation conventions, validation errors, and
common nested `evidence` and `authority` reports. Landing motion, berth, lease,
terrain, gameplay, reward, streaming, save, renderer, network, ship, and
surface-route authority are all explicitly false.

## Deliberate limits

This resource does not sample terrain, generate collision, reserve or lease a
pad, steer or land a ship, build an on-foot graph, test live clearance, render
markers, stream a body, grant rewards, save state, or synchronize over a
network. It has no `Main`, `GameFlow`, HUD, planetary profile, coordinate-frame,
or scene-tree dependency. Every such integration remains a later explicit
owner decision.
