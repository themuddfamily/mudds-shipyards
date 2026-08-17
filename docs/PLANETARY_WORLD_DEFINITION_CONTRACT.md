# Planetary world definition contract

`PlanetaryWorldDefinition` is the Phase 10 data boundary for describing one
authored visitable body. It is deliberately a foundation, not a planetary
runtime. No definition is placed in production by this slice.

## Typed schema

All positions use game-scale SI metres relative to the future planetary scene
root, which is exactly the planetary body centre. `body_radius_metres` is the
radial distance from that centre to the shared sea-level datum. Its composable
vertical-slice default is exactly 120,000 m, matching atmosphere
`planet_radius_m` and terrain `reference_planet_radius_meters`; it is not an
Earth-scale claim. The four anchor transforms are right-handed, unit-scale
orthonormal coordinate frames with distinct stable IDs:

- `scene_anchor` defines the authored scene frame and has its origin at the body
  centre.
- `navigation_anchor` is the detached navigation/distance reference.
- `orbital_anchor` is the intended orbital handoff frame and must be strictly
  outside the sea-level radius.
- `surface_anchor` is the intended surface handoff frame and must have a
  positive body-centred radius.

Every anchor component must be finite and within ±100,000,000 m. This bound is
a data-safety limit, not a promise that the engine can render that span without
origin management. `body_radius_metres` is finite and bounded to
1,000–100,000,000 m. A resolved terrain profile may place a surface anchor above
or below sea level, so exact surface-envelope validation remains composition
work; the standalone resource can still reject a centre-point surface handoff.

`scene_path` is a trimmed `res://` `.tscn` reference without traversal. The
definition validates path syntax only. It never loads the path and therefore
does not claim that the scene exists or is production-ready.

Atmosphere, terrain, and landing regions are stable logical references:

- `has_atmosphere=true` requires one `atmosphere_definition_id`; an airless body
  must leave it empty.
- `terrain_definition_id` is always required.
- `landing_region_ids` is an ordered, unique roster of 1–32 stable IDs.

Catalog/resource resolution belongs to later integration owners. This keeps the
schema useful before atmosphere, terrain, and landing-region profile classes
exist, without smuggling loader behavior into a shared `Resource`.

The IDs are logical foreign keys, not aliases: after resolution,
`atmosphere_definition_id` must exactly equal the resolved atmosphere
`profile_id`, and `terrain_definition_id` must exactly equal the resolved
terrain `profile_id`. The standalone resource validates their grammar but
cannot prove this equality without catalog inputs.

Stable IDs use 1–64 lowercase snake-case characters, start with a letter, and
contain neither leading/trailing nor repeated underscores. Display copy,
content notes, scene paths, evidence references, and reference counts have
explicit limits frozen in the script and focused test.

## Evidence boundary

The evidence enum uses the repository's controlled vocabulary:
`authenticated`, `bounded_partial_reconstruction`, `provisional_candidate`,
`modern_interpretation`, and `unknown`. Historical statuses require at least
one source reference. `authenticated` still requires an external manual dossier
review; the definition cannot perform or imply that review. References attached
to `modern_interpretation` record provenance or inspiration only.

The focused fixture is explicitly invented `modern_interpretation`. It does not
claim a historical planet, production placement, or shipped planetary content.

## Ownership and lifecycle boundary

The resource is immutable-by-convention declarative data. `audit()` and
`get_audit_report()` return detached dictionaries; landing/evidence rosters are
copied, and `duplicate_definition()` provides a typed detached copy.

Every audit explicitly reports:

- `gameplay_authority=false`
- `streaming_authority=false`
- `save_authority=false`

Those compatibility flags remain at the audit root. The canonical nested
`authority` object additionally publishes the common renderer, gameplay,
streaming, save, network, physics, world-generation, terrain-generation,
collision-generation, origin-shift, weather-clock, and audio keys, all false.
The nested `evidence` object uses the common `content_class`, `status`, `scope`,
`references`, and `notes` shape while retaining the world's historical-claim
and manual-review details.

Serialization as a normal Godot `Resource` does not grant save authority. A
future owner must separately validate reference existence, compose coordinate
frames, stream scenes and terrain, manage origin shifts, bind navigation and
landing systems, and persist session state. This contract starts none of those
systems and owns no activities, rewards, ships, landing motion, or terrain.

## Focused acceptance

Run only:

```bash
godot --headless --editor --path . --quit
godot --headless --audio-driver Dummy --path . \
  --script res://tests/planetary_world_definition_test.gd
```

The test covers the 120 km sea-level default, body-centred and radial anchor
rules, stable-ID/path/reference rejection, atmosphere and landing-region
consistency, evidence rules, finite radius and coordinate-frame bounds,
unit-scale bases, common nested audit shapes, deterministic deep-copy audits,
explicit zero authority, and a temporary Resource save/load round trip.
