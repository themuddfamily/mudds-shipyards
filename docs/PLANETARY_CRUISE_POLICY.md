# Planetary Cruise Policy

`PlanetaryCruisePolicy` is a pure, stateless recommendation contract for a
future long-leg ship-control owner. It does not move a craft or make cruise
available in production.

## Production handling audit

Ember's published absolute separation from the station is exactly 8,000,000 m.
Current production `HeroShip` handling clamps normal/boost speed and integrates
acceleration using caller physics delta. The checked-in ship definitions yield:

| Craft | normal m/s | boost m/s | thrust m/s² | boosted thrust m/s² | brake m/s² | 8,000 km at boost |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Torrent | 82 | 118 | 34 | 52.70 | 48 | 18.83 h |
| Halyard | 108 | 116 | 11 | 11.88 | 19 | 19.16 h |
| Jovian | 56 | 76 | 16 | 20.80 | 25 | 29.24 h |
| Arrow | 94 | 132 | 29 | 41.18 | 42 | 16.84 h |
| Zenith | 94 | 126 | 42 | 59.64 | 54 | 17.64 h |

Acceleration to those caps takes seconds and does not materially close the
multi-hour distance gap. There is no production cruise-capability or verified
forward-corridor provider at this boundary. Therefore this foundation returns
only bounded desired values and requires a later `HeroShip`/input integration
to apply them through physical movement and collision-aware clearance.

## Exact caller observation

`evaluate(observation)` accepts one dictionary with exactly these fields:

- `distance_to_destination_meters: float`, 0..1,000,000,000;
- `closing_speed_meters_per_second: float`, -100,000..100,000;
- `alignment_dot: float`, -1..1;
- `verified_clearance_meters: float`, 0..1,000,000,000;
- `clearance_verified`, `obstacle_detected`, `currently_participating`,
  `piloted`, `destroyed`, `landing_active`, and `combat_active`, all `bool`.

No delta, clock, node, resource, callable, or collision query enters the policy.
The caller owns the truth and freshness of every field. In particular,
`clearance_verified=true` is not created by the policy; later integration must
derive it from a real physical corridor query and fail closed when unavailable.

## Tuned recommendation

The immutable `ember_eight_megameter_minutes_v1` default recommends 20,000 m/s,
500 m/s² acceleration, and 750 m/s² braking. A zero-to-cruise-to-zero idealized
8,000 km leg is 433.33 s, or 7.22 minutes. That is a policy projection, not a
claim that any current craft can produce those values.

The stopping envelope is:

`v² / (2 * 750) + v * 2 seconds + 25,000 m`.

At the desired cruise speed it is 331,666.67 m. Fresh participation additionally
requires the 400,000 m acceleration distance, so both its minimum verified
forward clearance and destination distance are 731,666.67 m. Current participants use
the lower 0.980 alignment retention threshold; fresh engagement requires 0.995.
The inclusive braking boundary disengages. Obstacles, missing clearance proof,
destroyed/unpiloted craft, active landing, or combat all disengage in a frozen
priority order. Braking values remain hints; landing and combat gates return no
braking request so the policy cannot contend with those owners.

## Output and authority

Every accepted evaluation returns detached desired participation, target speed,
signed acceleration hint, explicit braking request/deceleration hint, current
stopping envelope, required verified clearance, required destination distance,
and a stable reason/state. Malformed observations return the same complete safe
shape with participation and actuation hints cleared.

The audit publishes the common twelve-key authority roster—renderer, gameplay,
streaming, save, network, physics, world generation, terrain generation,
collision generation, origin shift, weather clock, and audio—with every value
`false`. The adjacent roster also denies ship control, throttle input, movement,
collision/clearance proof, landing/combat/streaming decisions, and rewards.

Remaining production work must add a real physical clearance source, decide how
each craft attains and exits the recommended envelope, integrate player input
and feedback, and verify collision/landing/combat interaction. None of that is
silently provided here.
