# Aurora temperate authored scene

This NEW standalone witness gives Aurora one body-centred ocean sphere, one
bounded +Y landing patch, and one caller-driven spherical terrain clipmap. The
clipmap consumes Aurora's real terrain profile and commits five 65 × 65 radial
rings: 21,125 vertices, 40,096 visible triangles and one 7,904-triangle
finest-ring collision shape. One shared vertex-colour material separates shore,
lowland, highland, rock and snow. The complete 600 m approach box sits inside a
750 m flat envelope, and the authored landing-floor disc occupies a deliberate
94 m visual opening rather than fighting the generated surface. The atmosphere
composition remains the sole `WorldEnvironment` owner; this scene does not
configure it automatically.

It owns no streaming, player, camera, gameplay, landing decision, origin
shifting, save, network, navigation, or production binding. Terrain rebuilds
remain explicit caller operations and collision currently exists only on the
finest 256 m ring. It does not make Aurora visitable.

## Detached surface-route and landmark audit

The existing landing declaration supplies exactly one `NEW` / modern,
non-traversable `aurora_pad_to_staging` polyline: the authored `aurora_pad`
at `(0, 0, 0)`, then `aurora_egress` at `(18, 0, 0)`, then `aurora_staging` at
`(42, 0, 0)`, all in region-local metres. The scene audit resolves those points
from the landing resource and requires the three existing marker nodes to match.
It publishes this only as detached content data; `traversable` and
`route_authority` are explicitly false.

This is neither a navigation graph nor a clearance/traversal claim. The bounded
96 m patch remains the sole authored centre support, surrounded by generated
finest-ring collision outside its 48 m half-width. No Player, NavigationRegion,
landing decision, streaming, production binding, Main/GameFlow ownership, or
origin/rebase application is introduced.

## Standalone renderer witness

`tests/capture_aurora_temperate_visuals.gd` is an evidence-only native
Forward+ witness for this standalone scene. It instantiates Aurora alone,
configures its already-authored atmosphere composition with one fixed
body-local observation, and adds one temporary evidence camera at the authored
ApproachEntry looking at the authored pad. It captures the exact same pose in
HIGH and LOW renderer profiles; the LOW frame is a profile-difference witness,
not a quality ranking.

The harness rejects headless, Mobile, Compatibility, and non-X11 execution and
publishes no fallback artifacts. A successful native run publishes only its two
frames, capture log, source digest, and immutable evidence manifest in a
versioned directory under `artifacts/aurora_temperate_visuals/captures/`; the
root `evidence_manifest.json` is an atomic pointer to one complete version.
No prior complete capture is deleted before that pointer switches. The manifest
is explicitly `NEW`,
`modern_interpretation`, `source_bounded=false`, `confidence=none`, and
`production_witness=false`.

The native witness is deliberately separate from headless focused tests. Run it
only when a native capture has been explicitly authorized:

```sh
godot --path . --display-driver x11 --rendering-driver vulkan \
  --audio-driver Dummy --script tests/capture_aurora_temperate_visuals.gd
```

Those artifacts prove only that this standalone authored scene configured and
rendered its fixed observation—including the committed terrain—under the named
native renderer. They do not prove Main/GameFlow integration, streaming,
visitability, Player or production-camera ownership, movement, landing
eligibility, collision beyond the finest ring, runtime focus updates,
weather/time progression, audio, save/networking, performance, visual fidelity,
or production visual quality.
