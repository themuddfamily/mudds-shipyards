# Rime glacial world

Rime is the third visitable world, after Ember Moon (an airless caldera) and
Aurora (a temperate coast). It is a cold world with a thin atmosphere: a pale
ice shelf under a low ice-crystal overcast, with ground haze drifting on a
hard, steady wind.

## Getting there

1. Take a small or medium craft's pilot seat at Mudds and fly clear of the
   yard.
2. Open `Esc` -> Destination Board and press **Rime Glacial World**. The row
   reads 10,000 km, `ATMOSPHERIC`, `CRUISE // LAND // ICE-CORE SURVEY //
   RETURN`.
3. The shared cruise flies the craft out. Rime's body centre is 10,000 km on
   station-relative -X (`NearbySectorOrbitalRegistry.RIME_BODY_CENTER_ID`), so
   the way out needs committed common-world origin rebases. Rime streams in
   through `RimeGlacialStreamingBootstrap`/`RimeGlacialStreamingProductionBinding`,
   and the craft flies Rime's authored corridor (`rime_icefall_landing.tres`)
   down to a real `ShipBerth` lease and `HeroShip.request_berth_landing()`.
4. Press `E` to leave the seat, walk the icefall, walk back to the craft's
   boarding area and press `E` to board. Choose the board's return action to
   fly home and dock at the craft's registered berth.

Rime shares the journey coordinator's one surface-visit lane with Aurora. The
lane is admitted with a world id (`admit_aurora_visit(ship, engage, world_id)`)
and resolves the bootstrap/binding pair from it, so everything downstream (the
cruise binding, the origin transaction, the final-approach handoff and the
return) is the code Aurora already runs. While either visit holds the lane, the
other world's board row is shown unavailable.

## The place

Pad at region origin; the approach corridor runs out along +Z and is kept clear.

| Landmark | Region-local position | What it is |
| --- | --- | --- |
| Survey beacon | (-24, 0, -16) | Orange-lamp mast and signboard. Starts or abandons the survey. |
| Ice-core drill rig | (-54, 0, -46) | Tripod derrick over a core hole, a crate of cut cores, and an orange heated hut. |
| Serac field | (-8, 0, -68) viewpoint | Nine leaning faceted ice spires north of the trail, with a cairn at the viewpoint. |
| Pressure ridge gauge | (30, 0, -62) | Tilted ice slabs and a strain-gauge mast with a cyan lamp. |

An orange-lit survey trail runs pad -> beacon -> drill rig -> serac viewpoint ->
ridge gauge. A cyan-lit return path runs from the gauge back to the pad. Wind-cut
sastrugi, glossy glaze patches, dark boulders and a wind-scrolled haze sheet
fill the shelf. There are two shadowless practical lights: the beacon lamp and
the hut's warmth.

Every node is a descendant of `LandingRegion`, a `Node3D` in the authored body
frame, so every position is region-local and moves with the region during
origin rebases. `RimeGlacialAuthoredScene.audit()` reports
`region_placement_escaped` for any exploration node that stands outside the
region frame, which is the failure the Ember sweep found in thirteen
placements.

## Ice-core survey (optional)

Start at the beacon, extract a core at the drill rig, then log the ridge
strain gauge. Both checkpoints are out on the route, so neither can be
completed from the pad. The reward (`rime_ice_core_record`) goes through
`GameFlowRewardAuthority` exactly once per save. Progress is saved after each
step and survives a whole-`Main` re-entry through
`RimeExpeditionPersistenceBinding` (UserDataStore slot
`rime_expedition_active_visit`).

The hazard is the cold. While the survey runs, the suit heater drains for as
long as the explorer is away from warmth (120 s budget). It refills beside the
craft or at the heated hut; the drill-rig checkpoint is inside the hut's warmth.
If the heater empties, the survey fails with `suit_heat_depleted`. Nobody is
moved or hurt, the craft, the berth lease and the way home are untouched, and
the beacon starts a fresh survey. The HUD objective shows the heater level.

## Orbital silhouette

The backdrop's former grey body (`CelestialGreyBody`) is now Rime. It uses
`rime_orbital_silhouette.gdshader` (pale wind-combed ice bands, dark fractures,
bright caps, streaks of ice-crystal cloud and a thin cold limb) in the same
single draw submission as before.

## Streamed cost

The streamed generation has about 150 nodes (budget 210): the five-ring terrain
clipmap (about 40k triangles) plus authored props, most of the scatter in four
MultiMeshes. It has two shadowless lights. `get_streamed_cost()` reports the
exact numbers and `audit()` enforces the budgets.

## Tests (not yet run)

- `tests/rime_glacial_authored_scene_test.gd`: resources, terrain, atmosphere
  identity, landmarks, grounding, heat shelter, cost budgets, root-translation
  carry and plain-`Node` escape detection.
- `tests/rime_visit_loop_test.gd`: the production visit through a composed
  `Main`. It covers the board, cruise, rebases, landing, walking, the survey and
  its cold failure, re-entry, the one-time reward, reboarding, return and
  abandon.

Native GPU rendering and human visual review have not been run (`NOT_RUN`).
