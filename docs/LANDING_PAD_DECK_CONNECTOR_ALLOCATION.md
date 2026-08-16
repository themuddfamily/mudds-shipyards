# LandingPad deck-connector retained-resource trim

`ShipyardWorld` builds one childless black `DeckConnector` torus beneath each of
the three parked Power, Data, and Fuel umbilical-hose presentation assemblies.
Before this change those nodes had the same geometry/material recipe but retained
three private `TorusMesh` resources. No pre-existing test, route, berth, landing,
readiness, collision, evidence, or runtime script consumed the connector name;
the separately identified hose parents remain unchanged.

The bounded change shares one torus resource. It does not use `MultiMesh`, remove
or rename nodes, change parents, or merge submissions.

| LandingPad-local measure | before | after | delta |
| --- | ---: | ---: | ---: |
| connector nodes / visible copies | 3 | 3 | 0 |
| structural mesh-surface submissions | 3 | 3 | 0 |
| connector mesh resource identities | 3 | 1 | -2 |
| connector material identities | 1 | 1 | 0 |

Each copy retains its exact local position, zero rotation, unit scale, black
material, default layer/visibility/shadow state, and one surface. The torus
recipe is still authored at inner/outer radius `0.16/0.24` and `64 x 16`
tessellation. The existing global `TorusGeometryBudget` still produces the same
runtime `32 x 13` tessellation for all three copies.

`get_landing_pad_deck_connector_allocation_audit()` freezes those local facts and
rejects recipe, resource-identity, transform, material, submission, child,
metadata, processing, script, collision, navigation, light, audio, or camera
drift. Its returned
dictionaries and arrays are detached. The central-berth focused suite also turns
the audit red by mutating the shared recipe, replacing one node with an
exact-looking private mesh, and injecting authority under a connector, then
restores the live tree.

## Verification and limits

Run the focused suite with:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/central_berth_hero_test.gd
```

No Forward+ comparison is needed for this resource-identity-only slice: the
rendered mesh recipe, material, copies, transforms, and submissions are exact
equalities. Shared Godot resources remain mutable; the audit detects unintended
mutation but does not prevent assignment-time mutation.

This is not evidence for a driver draw-call, frame-time, GPU-time, VRAM, or
whole-scene budget improvement. It changes no berth, landing, collision, route,
readiness, evidence, naming, gameplay, lifecycle, or world authority. The guide
light resource cache and central service-line black-bin batch are outside scope.
