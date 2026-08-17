# Planetary world definition contract

`PlanetaryWorldDefinition` is the Phase 10 data boundary for describing one
authored visitable body. It is deliberately a foundation, not a planetary
runtime. No definition is placed in production by this slice.

## Typed schema

All positions use metres relative to the future planetary scene root. The four
anchor transforms are right-handed, unit-scale orthonormal coordinate frames
with distinct stable IDs:

- `scene_anchor` defines the authored scene frame.
- `navigation_anchor` is the detached navigation/distance reference.
- `orbital_anchor` is the intended orbital handoff frame.
- `surface_anchor` is the intended surface handoff frame.

Every anchor component must be finite and within ±100,000,000 m. This bound is
a data-safety limit, not a promise that the engine can render that span without
origin management. `body_radius_metres` is finite and bounded to
1–100,000,000 m. The chosen value may represent an intentionally compressed
game scale and must be documented by the authored world later.

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

The test covers valid data, stable-ID/path/reference rejection, atmosphere and
landing-region consistency, evidence rules, finite radius and coordinate-frame
bounds, unit-scale bases, deterministic deep-copy audits, explicit zero
authority, and a temporary Resource save/load round trip.
