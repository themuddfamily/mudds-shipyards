# Planetary atmosphere transition validator

`PlanetaryAtmosphereTransitionValidator` is a reusable, renderer-neutral seam
between `PlanetaryAtmosphereSampler` and
`PlanetaryAtmospherePresentationEnvelope`. It configures both policies from
one validated `PlanetaryAtmosphereProfile`, copies their snapshots, and rejects
the composition unless their exact atmosphere and cloud boundary contracts
agree. It does not make an atmospheric world visitable or claim production
integration.

## Stable game-scale contract

All altitude, path, and speed inputs retain the profile's `game_scale_si`
units: metres from the profile's surface datum, metres of local sight path,
and metres per second. The sun observation is a signed spherical-horizon
clearance in radians supplied by the caller; no ephemeris or radial frame is
derived here. Four positive spatial widths are explicit presentation tuning:
atmosphere-top metres, cloud-base metres, cloud-top metres, and sun-visibility
radians. They are validated by the envelope and are not physical profile
fields.

The cross-check freezes these inclusive/exclusive rules:

| Boundary | Sampler | Envelope/raw truth | Envelope weight |
| --- | --- | --- | --- |
| atmosphere top | exact vacuum | `altitude < top` is false | atmosphere weight zero |
| cloud base | layer inclusive | `base <= altitude < top` is true | observer weight zero at edge |
| cloud top | layer exclusive | inside is false | observer weight zero at edge |

The sampler remains authoritative for density, optical depth/transmittance,
visibility, fog, wind, cloud coverage, and entry effect. The envelope remains
authoritative for one-sided smooth presentation weights. `evaluate` returns
detached copies of both outputs plus a named altitude phase, so a later caller
can blend or route values without inventing a second boundary policy.

## Purity and performance boundary

Configuration is one-time and atomic; failed profile or width input is
retryable. Evaluation is stateless, has no delta or clock input, and performs
one bounded sampler call and one bounded envelope call. It retains no source
Resource and mutating caller-owned profile data after configuration cannot
retune the result. The validator owns no renderer, fog volume, cloud geometry,
weather clock, physics, gameplay, streaming, origin shift, audio, save, or
network authority. Temporal fade, hysteresis, weather selection, and actual
renderer application remain later caller-owned work.

The focused suite proves exact atmosphere/cloud endpoints, atomic rejection,
detached snapshots, cadence independence, the combined identity, and the
zero-authority audit. It is intentionally a foundation check rather than a
full-world or performance-matrix claim.
