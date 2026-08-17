# Planetary world composition validator

`PlanetaryWorldCompositionValidator` is the authority-free join between one
`PlanetaryWorldDefinition` and the atmosphere and terrain profiles resolved from
its logical IDs. The individual Resources remain independently reusable; this
validator proves the relationships that none can validate alone.

## Shared coordinate and scale contract

The planetary scene root is the body centre. The one radius datum is radial
distance from that centre to sea level, in game-scale SI metres. The current
vertical-slice defaults deliberately compose at exactly 120,000 m:

- world `body_radius_metres = 120000`;
- atmosphere `planet_radius_m = 120000`, top altitude `20000`;
- terrain `reference_planet_radius_meters = 120000`, elevation envelope
  `-2500..8500`.

Existing public suffixes remain stable. Canonical accessors expose `meters` at
the composition boundary. Radius equality is exact: profiles are authored data,
not noisy measurements, so approximate equality would conceal scale drift.

The world scene anchor stays at the body centre. Its surface anchor radius must
fall within `body radius + terrain minimum..maximum elevation`. Its orbital
anchor must be at or beyond both the maximum terrain radius and, when present,
the atmosphere outer radius. The navigation anchor must lie between the lowest
terrain radius and the orbital handoff. These checks describe handoff data only;
the validator moves no node and grants no origin-shift, flight, landing, physics,
streaming, or rendering authority.

## Resolution and atmosphere rules

`terrain_definition_id` must exactly equal the resolved terrain `profile_id`.
An atmospheric world requires exactly one profile whose `profile_id` equals
`atmosphere_definition_id`; an airless world requires an empty logical ID and a
null atmosphere input. All IDs use the same first-letter lowercase snake-case
grammar.

For an atmospheric world, the world, atmosphere, and terrain sea-level radii
must be exactly equal. Maximum terrain elevation must not exceed atmosphere-top
altitude. This first vertical slice therefore cannot silently put authored peaks
outside its atmospheric shell.

## Result and ownership boundary

`validate_composition()` returns a detached dictionary with `valid`, structured
error records (`code`, `field`, `message`), stable component identities, radius
facts, component evidence snapshots, and the common all-false authority roster.
`audit()` is an equivalent detached reporting seam. The validator retains no
Resource, creates no catalog, loads no scene, and owns no renderer, gameplay,
streaming, save, network, physics, generation, origin-shift, weather-clock, or
audio behavior.

The focused test contains one atmospheric green fixture, one airless green
fixture, detached-report mutation witnesses, and structured-red cases for
missing/incorrect references, invalid identities, exact radius drift, terrain
crossing the atmosphere shell, surface anchors below/above the terrain envelope,
navigation anchors below terrain/above orbit, atmospheric orbit below the outer
shell, and airless orbit below the terrain shell. Exact inclusive green cases
freeze both terrain-envelope endpoints, navigation at its lower and upper
handoffs, atmospheric orbit at the atmosphere shell, and airless orbit at the
terrain shell.
