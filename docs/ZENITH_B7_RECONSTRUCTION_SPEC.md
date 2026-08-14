# B7-Observed Zenith Reconstruction Specification

Status: frozen evidence boundary with an accepted **bounded partial runtime
reconstruction of the Zenith-class Interceptor observed in B7**. B7 was
uploaded on 2012-03-18; its recording date and live game-build revision are
unknown. This specification does not date the model to 2012, establish
continuity with the 2009/2010 ship, claim an exact historical reproduction, or
authenticate the current implementation.

This sheet converts the evidence registered in
[`RESEARCH.md`](../RESEARCH.md) and the machine-readable
[`source ledger`](research/source_ledger.json) into a bounded art target. Only
the large forms that remain legible in the registered B7 rendition belong to
the source core. Dimensions, fine construction, systems, handling, materials,
interior layout and berth placement remain unknown or modern design.

The accepted project-original implementation keeps the B7-recognition forms in
a removable `SourceCore` and all standalone-game additions in `ModernSystems`.
Its authored close/far presentation contains 47,274 / 5,412 triangles across 22
runtime meshes and 22 surfaces; imported art remains presentation-only. The
authoritative runtime uses 24 independently pinned mixed collision shapes. Those
counts, focused lifecycle tests, and rendered captures validate the remake asset
and integration contracts only; they do not add historical evidence or satisfy
the six-gate authenticated-reconstruction policy.

## Versioned identity and role

Use the public reconstruction label:

> **Zenith-class Interceptor — B7-observed reconstruction**

That label deliberately scopes “Interceptor” to the B7 observation. It does not
silently resolve the surviving creator-authored role conflict:

| ID | Dated evidence | Safe use |
| --- | --- | --- |
| A5 | Official page captured 2010-02-05, reporting a 2010-01-28 page update; names the VIP “Zenith-class Interceptor” | Creator-authored evidence for the Interceptor wording at that page state. The capture and page-update dates are separate events. |
| A9 | Official VIP Shirt description whose page claims a 2009 creation date; calls Zenith a “Fighter” | Creator-authored evidence for the Fighter wording at that asset state. Retain it as a conflict rather than treating it as an error. |
| B7 | Runtime message says “Regenerating Zenith-class Interceptor” and remains tied to one appearing, approached, boarded and flown craft | Decisive name-to-model evidence for the bounded B7-observed Interceptor version. The upload date does not identify the recording date or build. |

The evidence does not establish whether A5, A9 and B7 describe the same model or
game revision. Never shorten the versioned claim to “the canonical Zenith
Interceptor” in provenance or authenticity text.

## B7 rendition and rights boundary

The exact public rendition inspected for this audit is:

```text
SHA-256:  c716c506d9fd7042ac98720e8815725cf083d24967bc8c9f842cdfa58e8ca144
bytes:    2,264,402
video:    854 x 480, constant 11 fps
duration: 48 s
```

Source: Becker260, [*The Flight*](https://www.youtube.com/watch?v=J0GVOdxftXI),
uploaded 2012-03-18.

No licence or redistribution permission is recorded. The video, screenshots,
frame crops and extracted source assets must not be committed, bundled, shipped
in a build, or treated as project-owned media. The repository retains only the
citation, rendition hash, frame anchors, bounded observations and this written
specification.

An independently and lawfully obtained study copy can be checked outside the
tracked tree with commands equivalent to:

```bash
zenith_b7_source=/absolute/path/to/independently-obtained-b7-rendition.mp4
sha256sum -- "$zenith_b7_source"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,avg_frame_rate \
  -show_entries format=duration,size -of default=noprint_wrappers=1 \
  "$zenith_b7_source"
mkdir -p docs/research/private/zenith-b7
for zenith_b7_frame in 368 372 373 400 440 460 467 468; do
  ffmpeg -v error -i "$zenith_b7_source" \
    -vf "select=eq(n\,$zenith_b7_frame)" -frames:v 1 \
    "docs/research/private/zenith-b7/f${zenith_b7_frame}.png"
done
```

`docs/research/private/` is ignored and must remain local. Frame numbers are
zero-based decoded-frame indices for the exact registered rendition. Do not
transfer them to a different transcode without independently validating its
decoded frame sequence.

## Frame-resolved feature index

| B7 anchor/view | Direct bounded observation | Confidence and limit |
| --- | --- | --- |
| `00:33.455`, `f368` | Exact “Regenerating Zenith-class Interceptor” message begins over a fixed berth view. | High for the observed label. |
| through `00:33.818`, `f372` | The relevant berth remains empty. | High for the empty-berth state in this shot. |
| `00:33.909`, `f373` | A pale craft appears at that berth without a cut. | High for label-to-instance continuity; low for fine geometry at this distance. |
| `00:36.364`, `f400` | Approach view resolves a very wide swept delta/arrow planform and a raised central forward body. | Medium-high for width-dominant macroform; not an orthographic proportion measurement. |
| `00:40.000`, `f440` | Closer elevated/oblique view resolves broad clean triangular side planes, a pronounced raised centre/spine, and repeated simple step/strake shapes. | Medium for feature presence and hierarchy; low for exact topology, count or symmetry. |
| `00:41.818`, `f460` | Oblique underside/side view resolves a deep faceted central body, lateral triangular forms and at least one cylindrical or pod-like exterior form. | Medium for visible form; low for count and placement. Its function is unknown. |
| `00:42.455`, `f467` | Distant side/three-quarter view retains the same pale craft, with a compact raised wedge/slab, a long upper strake and repeated subdivisions. | Medium for the recurring broad language; low for exact dimensions and construction. |
| `f468` and later | A discontinuity begins; later imagery is outside the identity chain. | Excluded. It must not support Zenith geometry, palette, systems or handling. |

B7 therefore supplies a high-confidence name-to-model lock and a bounded broad
macroform, not reconstruction-grade dimensions. Compression, perspective,
changing attitude and short exposure prevent CAD-grade measurements.

## Source-core art target

The first read of the removable `SourceCore` should preserve:

1. A width-dominant, low, full-delta/arrowhead planform with broad swept side
   planes. It must remain visibly distinct from Torrent's compact longitudinal
   wedge and upright-rail hierarchy.
2. A pale off-white/light-grey dominant exterior. B7 supports relative value,
   not an exact albedo swatch, paint system, reflectance or weathering level.
3. A tall, faceted central forward body continuing into a raised dorsal spine or
   slab. The centre must remain readable above the broad side planes.
4. Long upper/side strakes and repeated simple stepped subdivisions. Preserve
   their rhythm without inventing exact panel count or topology.
5. Only subordinate lateral or ventral fins that can be visually traced to the
   indexed B7 views.
6. Cylindrical or pod-like forms only where their placement and count have been
   checked against the indexed frames. Tag every such form
   `historical_function_unresolved`; B7 does not prove an engine, weapon, tank or
   escape-pod function.

No absolute metre scale survives. Any runtime envelope is a modern ergonomic
normalization and must be documented separately from the source feature index.
Do not derive exact plan ratios from a single perspective frame.

## Explicitly unsupported details

B7 does not establish:

- an exact length, span, height, avatar-relative scale or berth transform;
- the number, purpose or internal construction of pod-like forms;
- propulsion count, engine placement, exhaust shape or thrust colour;
- weapon type, hardpoint count, muzzle positions or combat performance;
- landing gear, docking receiver, RCS, service ports or navigation lights;
- canopy, hatch, entry side, seat count, instruments or cockpit plan;
- armour, acceleration, top speed, turn response, roll response or endurance;
- exact colours, materials, PBR response, panel seams, decals or weathering; or
- continuity with a 2009 model, an A5 page state, or any specific game build.

These details cannot be recovered by borrowing Torrent, Arrow, Jovian or a
modern opponent's visual identity.

## Modern systems and gameplay boundary

All standalone-game additions live under a removable `ModernSystems` subtree or
carry equivalent `modern_interpretation` metadata. Those modern additions
include pressure glazing, pilot controls, engine internals, exhaust, recessed
weapons, navigation/RCS lights, landing gear, boarding aids, docking hardware,
damage anchors, PBR materials, small service detail and numeric flight balance.

The first playable slice follows these constraints:

- Treat it as a modern agile-interceptor role with lateral trade-offs rather
  than a direct upgrade over Torrent. None of its handling numbers are historic.
- Reuse the project's shared walking, interaction, engine, flight, fire, camera,
  landing, damage and exit controls. B7 supplies no Zenith-specific key map.
- Provide a physically reachable pilot position because B7 directly shows an
  approach-to-boarding-to-flight chain. A single-pilot cockpit is an economical
  modern scope, not a recovered seat-count claim.
- Do not add a walkable cabin or multi-crew room without new evidence.
- Do not make Zenith a paid/VIP gameplay advantage. A5/A9 document historical
  VIP association, not a requirement for the standalone remake's progression.
- Treat any station berth assignment, landing receiver, docking aid and access
  route as modern placement. No registered source maps Zenith to a current berth.

## Cross-ship exclusion rules

- Do not import Zenith's wide delta, long-strake or pod-like language into the
  B5-observed Torrent reconstruction.
- Do not use B7 to authenticate the current Arrow or Jovian silhouettes. Their
  source roles remain separate, and neither has a secure model lock.
- Do not reuse the modern range opponent as historical Zenith geometry.
- Keep shared gameplay helpers source-neutral; visual geometry must remain
  class-specific and replaceable.

## Reconstruction acceptance checks

The current implementation is accepted only as a bounded partial reconstruction
because all of these remain true:

1. Its public identity remains “B7-observed”; no UI, manifest or document turns
   the upload date into a recording date, model date or game-build revision.
2. A feature sheet compares the source core only with `f373–f467`, explicitly
   excludes `f468+`, and labels every observation, inference and modern choice.
3. Front/three-quarter, true dorsal, underside/side and berth captures read as
   one very wide pale delta/arrow craft with a raised central wedge/spine, long
   strakes and stepped subdivisions.
4. Removing `ModernSystems` leaves the complete source-recognition macroform.
5. Pod-like forms retain an unknown-function tag; no documentation silently
   promotes them to engines, weapons or escape pods.
6. A physical boarding capture proves the modern route without claiming an
   original canopy, hatch, seat count or access side.
7. The A5 Interceptor/A9 Fighter conflict remains visible in the ledger,
   evidence matrix and public provenance.
8. Tests and captures validate gameplay, collision and presentation separately
   from historical fidelity; passing them does not authenticate the ship.
