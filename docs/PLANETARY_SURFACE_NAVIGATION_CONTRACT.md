# Planetary surface navigation contract

`PlanetarySurfaceNavigationContract` is the authored, body-local route seam
for one landing region. It complements `PlanetaryLandingRegionDefinition`:
landing data declares pads and named egress anchors, while this resource adds a
small directed route graph to landmarks that a later production navigator may
consume.

The contract validates stable node IDs, finite body-local metre positions,
bounded segment lengths, known edge endpoints, duplicate/self-loop rejection,
and reachability from the first egress node. Each node carries one opaque
surface audio profile ID. Those IDs are checked against the existing strict
`PlanetarySurfaceAudioCatalog`; this contract does not resolve streams or
request playback.

It owns no movement, navigation execution, terrain/collision generation,
streaming/origin management, weather, audio bus, gameplay, save, or network
authority. Positions are authored hints until a production owner proves terrain
support and physical traversal. The route and audio evidence are NEW,
modern-interpretation content with no historical claim.

Focused check:

```bash
godot --headless --audio-driver Dummy --path . \
  --script res://tests/planetary_surface_navigation_contract_test.gd
```
