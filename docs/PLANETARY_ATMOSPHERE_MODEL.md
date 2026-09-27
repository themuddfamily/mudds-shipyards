# Planetary atmosphere model

This is the single reference for how an atmosphere world behaves at the
game's scale. It covers units, the density and visibility model, the altitude
transition bands, entry heat, wind, interior/exterior audio, and the
performance trade-offs. The component documents it links to describe each
adapter's contract. This page describes how the adapters fit together and what
the numbers are.

Aurora is the only atmosphere world today. Ember is airless: it composes no
`PlanetaryAtmosphereComposition`, so none of the effects below can run there.

## Scale and units

| Quantity | Unit | Notes |
| --- | --- | --- |
| Distance, altitude, radius | metre (m) | Altitude is measured from the body's reference sphere. |
| Speed | metre per second (m/s) | Airspeed is the craft's speed in the body frame. Wind is not subtracted. |
| Density | kilogram per cubic metre (kg/m³) | |
| Optical coefficients | per metre (1/m), RGB | Rayleigh, Mie and absorption are summed into extinction. |
| Time | second (s) | Caller-owned only. No sampler has its own clock. |
| Intensities, blends, coverage | unitless, [0, 1] | |
| Audio cutoff | hertz (Hz) | |

Aurora's body radius is 120 km. That is roughly 1/53 of Earth's, a game-scale
body you can orbit in minutes. The atmosphere is 20 km thick, much thicker
relative to the body than Earth's, so a descent spends real time in air. The
streamed scene root sits at the body centre, so for any node,
`altitude = |scene_root.to_local(p)| - 120 000 m` and the local up vector is
the normalised body-local position. Near the landing site local up is +Y.
World-space vectors are body-local vectors multiplied by the scene root's
basis. Common-world origin rebases only translate that root.

Float32 positions about 120 km from the origin resolve to roughly 1 cm. The
narrowest band on this page is 3 km wide, so that precision is more than
enough.

## Density

`PlanetaryAtmosphereSampler` (see `PLANETARY_ATMOSPHERE_SAMPLER.md`):

```
rho(h) = rho_0 * exp(-(max(h - h_ref, 0) / H) ^ k)     for h < h_top
rho(h) = 0                                              for h >= h_top (exact vacuum)
```

Aurora's values are `rho_0 = 1.225 kg/m³`, `h_ref = 0 m`, `H = 4 000 m`,
`k = 1` and `h_top = 20 000 m`.

| Altitude | rho (kg/m³) | rho / rho_0 |
| --- | --- | --- |
| 0 km | 1.225 | 1.000 |
| 3 km (cloud base) | 0.579 | 0.472 |
| 6 km (cloud top) | 0.273 | 0.223 |
| 10 km (entry full) | 0.101 | 0.082 |
| 14 km | 0.037 | 0.030 |
| 18 km (entry start) | 0.0136 | 0.011 |
| 20 km and above | 0 | 0 |

## Visibility, fog and aerial perspective

- Extinction is `(rayleigh + mie + absorption) * rho / rho_0`, per RGB channel,
  in 1/m.
- Visibility is `min(1 / strongest_extinction, 20 km)`. At sea level on Aurora
  the blue channel (5.42e-5 /m) limits it to about 18.4 km. Above about 1 km
  the 20 km cap applies.
- Transmittance along a sight path of length `d` is
  `exp(-(extinction · luminance) * d)`.
- Fog uses `smoothstep((d - 1.5 km) / (12 km - 1.5 km)) * 0.22 * rho/rho_0 * weather_scalar`.
  It fades out with density, so fog thins on the way up and is exactly zero in
  vacuum.
- Sky colours come from `PlanetaryAtmosphereSampler` optical depth through
  `PlanetarySkyPresentation`. The horizon and ground-horizon colours shift
  from coastal blue to orbital dark with altitude.

## Transition bands

Every band is a pure function of altitude and caller inputs, and each band
starts or ends at an exact boundary.

| Band | Altitude | What changes |
| --- | --- | --- |
| Space ↔ sky | 20 km | Above the top: exact vacuum, dark sky, no fog. Ambient fill is `recipe * lerp(0.25, 1, smoothstep(1 - h/20 km))`. |
| Entry heat | 18 km → 10 km | The density ramp for compression glow (below). |
| Wind ceiling | 9 km → 6 km | Craft drift is zero above 9 km and full strength at 6 km and below. Between them it follows a smoothstep. |
| Cloud layer | 3 km – 6 km | The cloud shell sits at 126 km radius, base-inclusive and top-exclusive, with 0.55 coverage. |
| Surface ambience | 2.5 km → 0 km | Exterior wind and water beds fade in linearly toward the ground. |

The cloud shell drifts along the same authored wind vector that pushes the
craft (see Wind).

## Entry heat and compression

The sampler computes one intensity. The compression envelopes, the Arrow's
Ember-path heat adapter and the entry audio beds all consume that same number.

```
I      = D(rho) * S(v)                                    unitless, [0, 1]
D(rho) = clamp((rho(h) - rho(h_start)) / (rho(h_full) - rho(h_start)), 0, 1)
S(v)   = clamp((v - v_min) / (v_full - v_min), 0, 1)
```

On Aurora `h_start = 18 km`, `h_full = 10 km`, `v_min = 160 m/s` and
`v_full = 340 m/s`. At or below `h_full`, `D` is 1. Vacuum gives exactly 0.

Density drives the ramp instead of a linear altitude envelope, so the glow
builds the way air thickens. It stays faint near the top of the band and
strengthens quickly lower down. At full speed:

| Altitude | D | I at 600 m/s |
| --- | --- | --- |
| 18 km | 0.000 | 0.000 |
| 16 km | 0.101 | 0.101 |
| 14 km | 0.269 | 0.269 |
| 12 km | 0.545 | 0.545 |
| ≤ 10 km | 1.000 | 1.000 |

The dynamic pressure `q = ½ rho v²` (Pa) is not used directly. It would light
up ordinary sea-level flight: 118 m/s at 1.225 kg/m³ gives about 8.5 kPa. The
speed gate `S(v)` keeps normal atmospheric flight cold. Manual flight tops
out below 180 m/s, so compression glow comes from the fast cruise descent,
where the final-approach profile arrives at km/s speeds. That matches the
intended fiction.

**Who shows it.** `PlanetaryAtmosphereFlightEffects` (GameFlow, once per
physics tick) attaches one `HeroAtmosphericEntryEnvelopeBinding` under the
node name `PlanetaryAtmosphereEntryEnvelope` to whichever of the nine flyable
craft is active: Torrent, Arrow, Jovian, Zenith, Halyard, Bulwark, and the
three runtime-composed Cinder craft. The envelope is anchored to the craft's
landing-collision silhouette, so it fits every hull. The node name differs
from the Ember surface loop's `AtmosphericEntryExteriorEnvelope`, so the two
owners can never collide on one craft.

The Arrow's authored heat overlay (`PlanetaryEntryHeatPresentation`) is
deliberately not driven on Aurora. Its configuration is permanent, and a
configured target is what makes the Arrow's Ember-owned presenter treat a
descent as atmospheric. Configuring it for Aurora would therefore light plasma
on the next airless Ember descent. The Arrow gets the same generic envelope as
the other eight craft.

**Accessibility.** Under reduced flash the envelope is capped to a steady
cue of at most 0.42 opacity. The reduced-motion setting is forwarded to the envelope, and it also calms
the wind gusts (see Wind).

**Lifecycle.** The envelope is released in each of these cases:

- the atmosphere world unloads or is replaced by a new streamed generation
- the craft is lost, destroyed or replaced
- the craft rebuilds its visual root: the envelope reports `attachment_lost`
  and is re-attached after a 30-tick retry window
- the whole Main subtree detaches: `GameFlow._exit_tree` calls `reset()`, and
  re-entry re-attaches on the first resident tick.

## Wind

The authored wind is `wind_velocity_mps * weather_scalar`, in body-local m/s.
The Aurora bootstrap presents a weather scalar of 0.4
(`get_atmosphere_weather_scalar()`), so the wind is (4.8, 0, −1.6) m/s, about
5.1 m/s. The cloud shell and the craft drift both use this vector.

**Craft drift.** The drift is a lateral velocity carried through one move:

```
lateral = wind.slide(up)
gust    = 1 + A * (0.6 sin(1.3 t + φ) + 0.4 sin(3.7 t + 2φ))
cross   = (up × lateral̂) * |lateral| * 0.18 * A * sin(2.9 t + φ)
target  = (lateral * gust + cross) * 0.5 * sqrt(rho / rho_0) * ceiling_fade
drift   = first-order approach to target, τ = 0.8 s, |drift| ≤ 6 m/s
```

The terms are defined as follows:

- `A = 0.25 + 0.35 * effective_weather_intensity`. It is scaled by 0.35 under
  reduced motion.
- `t` is the weather clock in seconds.
- `φ = 0.0011 x + 0.0007 z`, from the body-local position, so gusts vary as
  you fly.

On Aurora near the ground this gives a steady drift of about 2.3 m/s with
roughly ±30% gusts. That is enough to see and correct for, but never enough
to lose a craft.

**Why a carried velocity, not a force.** HeroShip adds the drift before
`move_and_slide()`. Afterwards it removes whatever part of the drift the slide
did not already cancel against a collision. The drift therefore never builds
up in `velocity`, never fights flight assist or passive drag, and stops the
same tick the source stops submitting it. A force below the 2.8 m/s² passive
drag would have been invisible when hovering. A force above it would have
built up against flight assist.

**Always zero** when the craft is:

- landed
- berthed (docked latch)
- in landing assist
- in planetary cruise, including the authored approach corridor
- unpiloted, engine-off or destroyed.

`HeroShip.is_atmospheric_wind_drift_eligible()` and
`_consume_atmospheric_wind_drift()` both enforce this, so landings stay
exactly as stable as they were without wind. The drift is also zero above the
wind ceiling and in vacuum. When a craft becomes eligible again it ramps up
from rest.

**Clouds.** The flight effects run a weather clock, advanced by the physics
tick. The Aurora bootstrap passes it to the cloud shell as `caller_time_seconds`,
so the shell's wind offset is `wind * t`. The clock wraps at
`min(24 h, 900 km / |wind|)`, which is 24 h on Aurora. That keeps the offset
inside the cloud presenter's 1,048,576 m bound. The single pattern jump at the
wrap happens at most once a day of play.

## Interior and exterior audio

Aurora composes exactly two ambience voices: an exterior wind/coast bed on
its own `AuroraExteriorWind` bus with one low-pass filter, and a cabin bed.

**Interior blend.** `PlanetaryAtmosphereFlightEffects` computes a target
blend `b` from the pilot's actual state:

| State | Target b |
| --- | --- |
| Seated, canopy closed | 1.00 |
| Seated, canopy open | 0.45 |
| On foot inside a walkable craft interior (`MovingInteriorFrame` occupant) | 0.80 |
| On foot outside | 0.00 |

`b` moves toward the target at 1/1.1 per second and is smoothstep-eased
before it reaches the mix. Boarding, disembarking, opening or closing the
canopy, and stepping into or out of a cabin therefore fade over about a
second rather than switching. On arrival and re-entry the blend starts at its
target instead of mid-fade. Unload resets it.

**Mix** (`AuroraSurfaceAudioBinding`):

```
cabin      = lerp(1.0, 0.62, b)                       exterior wind/weather gain factor
open_air   = lerp(900 Hz, 18 kHz, wind_strength)      exterior cutoff outside
sealed     = min(open_air * 0.55, 1 400 Hz)           exterior cutoff through a closed hull
cutoff     = exp(lerp(ln open_air, ln sealed, b))     log-frequency sweep
exterior   = level_ext * lerp(1.0, 0.12, b)
cabin bed  = level_int * b
```

Wind strength is the gusting authored wind divided by 12 m/s, clamped to
[0, 1]. The exterior bed swells and brightens with the same gusts that buffet
the craft. A caller that supplies no blend falls back to `ship_perspective`,
with cockpit mapping to 1 and exterior to 0, which is the old behaviour. The
Aurora bootstrap re-presents audio as soon as the blend or wind moves, so a
fade keeps running even while the streaming focus is still.

## Performance trade-offs

- **No new renderer passes or lights.** The envelope is one small retained
  node tree per active craft, and only one craft is active at a time. The
  clouds write one uniform per presented focus.
- **Per physics tick** while an atmosphere world is resident, the flight
  effects do the following:
  - two pure sampler evaluations (entry and wind): arithmetic plus one
    detached dictionary each
  - one accessibility report read
  - at most one envelope presentation. The envelope is not re-presented while
    intensity stays zero, which is the common slow low-level case.
  - one wind submission.
- **When no atmosphere world is resident**, the cost is a single resolve that
  returns early. Ember pays nothing.
- **Audio** is re-presented only when the blend moves by more than 0.001 or
  the wind strength by more than 0.005, so gusts re-mix roughly every other
  tick.
- **Clouds.** Because the weather clock changes every tick, the atmosphere rig
  commits a new observation at every accepted focus even when the observer is
  still. For a still observer the sky, atmosphere and sun adapters should
  report `unchanged`, leaving only the cloud uniforms to write.
- **Determinism.** Wind and entry intensity are pure functions of position,
  speed and the weather clock. Nothing here is networked: Aurora visits are
  solo-only.
- **Not measured.** Native GPU cost and rendered human judgement of the glow,
  cloud drift and audio fades remain open gates (`NOT_RUN`). The software and
  headless runs that exercise this code establish behaviour only.

## Where the code lives

| Concern | File |
| --- | --- |
| Density, optics, cloud, wind and entry equations | `scripts/world/planetary_atmosphere_sampler.gd` |
| Per-tick flight effects (entry, wind, interior blend, weather clock) | `scripts/world/planetary_atmosphere_flight_effects.gd` |
| Generic craft compression envelope | `scripts/ships/hero_atmospheric_entry_envelope_binding.gd` |
| Arrow heat overlay adapter (Ember path; same equation) | `scripts/world/planetary_entry_heat_presentation.gd` |
| Wind drift application | `scripts/ships/hero_ship.gd`, "Atmospheric wind drift" block |
| Clock, blend and wind forwarding for Aurora | `scripts/world/aurora_temperate_streaming_bootstrap.gd` |
| Ambience mix | `scripts/audio/aurora_surface_audio_binding.gd` |
| Ambience playback | `scripts/world/aurora_temperate_authored_scene.gd` |
| GameFlow hook | `scripts/game/game_flow.gd`, "Planetary atmosphere flight effects" block |

Focused tests:

- `tests/planetary_entry_heat_all_craft_test.gd`
- `tests/planetary_wind_drift_test.gd`
- `tests/planetary_interior_exterior_audio_transition_test.gd`
- `tests/planetary_atmosphere_sampler_test.gd`
- `tests/planetary_entry_heat_presentation_test.gd`
- `tests/audio/aurora_surface_audio_binding_test.gd`
