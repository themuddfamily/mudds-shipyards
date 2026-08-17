# Planetary surface audio policy foundation

`PlanetarySurfaceAudioPolicy` is a pure, caller-driven recommendation policy
for the opaque audio hints already authored by `PlanetaryAtmosphereProfile`.
It does not resolve those IDs to assets and does not play, stop, mix, allocate,
or crossfade audio.

## Honest source contract

The atmosphere profile authors exactly two stable lookup hints:

- `exterior_audio_profile_id`;
- `interior_audio_profile_id`.

It also authors one absolute `exterior_wind_gain_db` and one nonpositive
`interior_attenuation_db`. There is no cabin-specific ID, catalog, stream,
loop, bus, mixer, playback, fade duration, or fade curve in that schema.
Accordingly, `cabin` is an explicit alias of `interior`; it never claims a
third asset. All returned IDs remain unresolved opaque values.

`configure(profile)` accepts one valid `PlanetaryAtmosphereProfile`, verifies
its zero-authority audit, configures a private deterministic atmosphere
sampler, and freezes detached profile, geometry, weather, and audio snapshots.
A failed configuration is retryable. A successful one is immutable and retains
no caller Resource.

## Exact observation contract

`evaluate(observation)` accepts one dictionary with exactly five keys:

```text
altitude_m: int|float
listener_context: StringName  # exterior | interior | cabin
grounded: bool
speed_mps: int|float
ambient_wind_scalar_unitless: int|float
```

No missing or extra key is accepted. Context must be a `StringName`, not a
coercible String. Altitude, speed, and wind scalar must be finite. Speed is in
the closed interval `[0, 100000] m/s`; wind scalar is in `[0, 1]`.

Validation priority is deterministic: dictionary shape, context, grounded
type, altitude type, speed range, and wind range are checked before configured
state; the configured body's altitude bounds and sampler contract follow. This
makes malformed observations return the same typed red even before setup.

The altitude datum is metres from the profile's reference surface. The minimum
accepted altitude is `-planet_radius_m`; the global atmosphere-profile maximum
is inclusive. Below the reference surface, density clamps to the sampler's
reference density. The atmosphere is half-open: altitude below its top remains
inside, while the exact top and all points above it are vacuum with exact zero
recommended intensity. Route identity and finite gain hints remain available
in vacuum; silence does not erase metadata.

The caller remains the sole authority for context, grounded status, speed, and
wind scalar. This policy cannot verify their provenance, freshness, coordinate
frame, or physical truth.

## Versioned game-scale equation

The profile has no audio speed-response field. This policy therefore declares
one explicit NEW tuning constant, separate from entry-effect thresholds:

```text
FULL_MOVEMENT_AIRFLOW_SPEED_MPS = 100
movement_speed_factor = clamp(speed_mps / 100, 0, 1)
movement_airflow = grounded ? 0 : movement_speed_factor
ambient_airflow = profile.weather_intensity * ambient_wind_scalar
merged_airflow = max(movement_airflow, ambient_airflow)
recommended_intensity = density_ratio * merged_airflow
```

All factors are clamped to `[0, 1]`. Grounded suppresses only movement-derived
airflow; ambient wind remains eligible. Maximum, rather than addition, prevents
two independently normalized caller hints from exceeding their common range.
This is `density_max_airflow_hints_v1`, a game-scale recommendation—not a claim
about real acoustics or authored source evidence.

Exterior selects the exterior ID and endpoint mix `(exterior=1, interior=0)`.
Interior and cabin select the interior ID and `(0, 1)`. Grounded/airborne mixes
are also exact complementary endpoints. These values are instantaneous routing
hints, not retained or timed crossfade state.

Gain fields remain finite and explicit:

```text
exterior context attenuation = 0 dB
interior/cabin context attenuation = authored interior_attenuation_db
unclamped recommended gain = authored exterior_wind_gain_db + context attenuation
recommended gain = clamp(unclamped gain, -80 dB, +24 dB)
```

Intensity is returned separately. The policy deliberately does not invent an
intensity-to-decibel curve, mute a bus, or claim that the selected ID resolves.

## Returned hints

An accepted result contains detached input, altitude classification, routing,
gain, endpoint-mix, intensity-component, and atmosphere-sample dictionaries.
Routing includes both available authored IDs, the selected opaque ID, explicit
cabins-as-interior truth, `profile_id_resolved=false`, and
`playback_requested=false`. Repeated complete observations are byte-for-byte
deterministic and cannot mutate policy state.

The policy evidence roster is exact and separate from the frozen source-profile
evidence: `{content_class: NEW, status: modern_interpretation,
source_bounded: false, confidence: none}`. Snapshot and audit expose detached
copies, audit validity self-checks all four key types and values, and the focused
suite freezes the same roster. It truthfully identifies the response equation
as new game-scale interpretation with no source-bounded confidence claim.

## Authority and limits

The exact common twelve-key authority roster is all `false`, including
`audio=false`. The policy recommends values but owns no AudioStreamPlayer,
AudioStream, bus, mixer, voice, or resolved audio asset. Its adjacent authority
roster also denies catalog resolution, resource loading, playback, voice
allocation, smooth crossfade/timing, caller observation truth, weather choice
or clock, wind simulation, movement, physics, streaming, gameplay, save, and
network control.

The implemented capability is limited to deterministic opaque routing/gain,
density-weighted intensity, and instantaneous endpoint hints. Audio-profile
resolution, production playback, mixer behavior, smooth crossfading, clock
ownership, and weather selection remain explicitly unimplemented.

Focused tests cover malformed and mutated profiles, exact frozen IDs/gains,
all three context routes, the cabin alias, surface/shell endpoints, vacuum,
grounded suppression, the exact 100 m/s speed endpoint, wind/movement priority,
gain clamping, source/result/audit mutation, repeat determinism, transport-safe
reports, and exact authority/capability rosters. Native audio and rendering are
outside this foundation, so no playback or render evidence is appropriate.
