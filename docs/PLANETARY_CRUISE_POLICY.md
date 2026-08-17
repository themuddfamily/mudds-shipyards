# Planetary Cruise Policy

`PlanetaryCruisePolicy` is a pure, stateless recommendation contract for a
future long-leg ship-control owner. It does not move a craft, cast collision,
or make cruise available in production.

## Production handling audit

Ember's published absolute separation from the station is exactly 8,000,000 m.
Current production `HeroShip` handling clamps normal/boost speed and integrates
acceleration using caller physics delta. The checked-in definitions yield:

| Craft | normal m/s | boost m/s | thrust m/s² | boosted thrust m/s² | brake m/s² | 8,000 km at boost |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Torrent | 82 | 118 | 34 | 52.70 | 48 | 18.83 h |
| Halyard | 108 | 116 | 11 | 11.88 | 19 | 19.16 h |
| Jovian | 56 | 76 | 16 | 20.80 | 25 | 29.24 h |
| Arrow | 94 | 132 | 29 | 41.18 | 42 | 16.84 h |
| Zenith | 94 | 126 | 42 | 59.64 | 54 | 17.64 h |

Acceleration to those caps takes seconds and does not materially close the
multi-hour gap. No production cruise capability or verified full-hull forward
corridor provider exists at this boundary. This foundation therefore returns
desired values only. Later `HeroShip`/input integration must implement physical
movement and supply the exact proof below.

## Exact caller observation (schema 2)

`evaluate(observation, expected_coordinate_frame_generation)` takes the
authoritative caller's current positive safe-integer frame generation separately
from the observation, then accepts exactly these fields:

- `distance_to_destination_meters: float`, 0..1,000,000,000;
- `ship_speed_meters_per_second: float`, 0..100,000, the magnitude of current
  world velocity;
- `closing_speed_meters_per_second: float`, -100,000..100,000;
- `alignment_basis: StringName`, as defined below;
- `alignment_dot: float`, -1..1;
- `coordinate_frame_generation: int`, 1..9,007,199,254,740,991;
- `verified_clearance_meters: float`, 0..1,000,000,000;
- `clearance_sweep_distance_meters: float`, 0..1,000,000,000;
- `clearance_proof_generation: int`, in the same bounds;
- `clearance_sweep_basis: StringName`;
- `clearance_full_hull`, `clearance_verified`, `obstacle_detected`,
  `currently_participating`, `piloted`, `destroyed`, `landing_active`, and
  `combat_active`, all `bool`.

No delta, clock, node, resource, callable, or collision query enters the policy.
Both observation generations must equal the separate expected generation before
a verified proof can participate; equal-but-stale values therefore fail when
the current owner supplies its advanced generation.

## Exact geometry proof

The caller first computes the normalized cruise direction from the tracked
craft to the destination in one current coordinate-frame generation.

When `ship_speed_meters_per_second > 0`, `alignment_basis` must be
`normalized_velocity_forward`, `alignment_dot` is the normalized cruise
direction dotted with normalized world velocity, and the exact scalar identity
`closing_speed = ship_speed * alignment_dot` must hold. At exactly zero speed,
closing speed must be exactly zero, `alignment_basis` must be
`normalized_ship_forward_zero_speed`, and the dot is instead normalized cruise
direction dotted with the craft's normalized physical forward axis. Thus a
stopped craft can be aligned without inventing a velocity direction.

A valid clearance proof is a current-generation continuous sweep, from the
current transform with orientation held fixed, of every enabled non-null
`CollisionShape3D` whose nearest `CollisionObject3D` ancestor is the tracked
ship body itself. Shapes owned by nested trigger `Area3D` nodes are therefore
not hull shapes. The sweep follows the same normalized cruise direction. It
checks physics bodies on the tracked ship body's current collision mask and
excludes the tracked ship body's own RID; it does not treat trigger areas as
physical blockers. The observation must state:

- `clearance_sweep_basis == normalized_cruise_direction`;
- `clearance_proof_generation == coordinate_frame_generation`;
- `clearance_full_hull == true` when `clearance_verified == true`;
- `clearance_sweep_distance_meters` as the attempted sweep length;
- `verified_clearance_meters` as the collision-free prefix.

If `obstacle_detected == false`, the verified prefix must exactly equal the
sweep distance. If it is `true`, the prefix ends at an initial overlap or the
first blocking-body contact in the closed sweep interval, including a contact
exactly at the requested endpoint; the prefix may therefore equal the sweep
distance. An obstacle claim requires a verified current full-hull sweep. An unavailable proof is represented only by
`clearance_verified == false`, `obstacle_detected == false`, and zero verified
clearance. These rules let the policy reject stale, partial, basis-mismatched,
or internally contradictory proof while retaining zero query authority.

## Tuned recommendation and boundaries

The immutable `ember_eight_megameter_minutes_v1` default recommends 20,000 m/s,
500 m/s² acceleration, and 750 m/s² braking. The idealized zero-to-cruise-to-zero
8,000 km estimate is exactly 433.333333333 s, or 7.222222222 minutes. It is a
policy projection, not a current-craft capability claim.

The stopping envelope is
`ship_speed² / (2 * 750) + ship_speed * 2 seconds + 25,000 m`.
At target speed it is 331,666.666667 m. Fresh participation also requires the
400,000 m acceleration distance, so required sweep clearance and destination
distance are 731,666.666667 m.

Fresh engagement accepts alignment exactly at 0.995 and rejects the next
representable value below it. A current participant accepts exactly 0.980 and
rejects the next representable value below that. The speed deadband is inclusive:
closing speeds from target minus 1 m/s through target plus 1 m/s return a neutral
cruise hint; the next representable values outside request acceleration/braking.
Destination braking boundaries are inclusive disengagement boundaries.

For schema-valid observations, the complete gate priority is: destroyed,
not-piloted, landing-active, combat-active, clearance-unverified,
obstacle-detected, alignment-below-threshold, insufficient-verified-clearance,
then destination-braking-envelope. Destroyed, unpiloted, landing, and combat
return no braking request to avoid contending with their owners. The remaining
safety gates request braking only above the 1 m/s speed deadband.

## Output and authority

Every accepted evaluation returns detached desired participation, target speed,
signed acceleration hint, explicit braking/deceleration hint, current stopping
envelope, required verified clearance, required destination distance, and a
stable reason/state. Malformed geometry or primitives return the same complete
safe shape with participation and actuation hints cleared.

The audit publishes the common twelve-key authority roster—renderer, gameplay,
streaming, save, network, physics, world generation, terrain generation,
collision generation, origin shift, weather clock, and audio—with every value
`false`. Its adjacent roster also denies ship control, throttle input, movement,
collision/clearance proof, landing/combat/streaming decisions, and rewards.

Remaining production work must provide the generation-bound full-hull sweep,
decide how each craft physically attains/exits the envelope, integrate player
input/feedback, and verify collision, landing, and combat interaction.
