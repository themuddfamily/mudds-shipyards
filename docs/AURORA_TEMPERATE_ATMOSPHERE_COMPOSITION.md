# Aurora temperate atmosphere composition

This is a NEW, standalone atmospheric resource and renderer-composition
foundation. `aurora_temperate_world`, `aurora_temperate_atmosphere`, and
`aurora_temperate_terrain` share the 120,000 m sea-level datum and pass the
existing world-composition validator.

`AuroraTemperateAtmosphereComposition` owns one sibling `WorldEnvironment` and
one `PlanetaryAtmosphereWorldRig`. An explicit `configure()` call configures the
rig first, then installs only the rig-owned Environment in that sibling target.
It accepts caller-owned body-local observations through `present_observation`;
it has no clock or process loop and restores the prior Environment on detach.

It is not a planet scene, streaming location, landing loop, `Main`/`GameFlow`
binding, camera owner, or production-world integration. Ember remains airless
and untouched.

Focused evidence, after static review:

```sh
godot --headless --editor --path . --quit
tools/run_affected_suites.sh --jobs 1 planetary_atmosphere_composition_test
```
