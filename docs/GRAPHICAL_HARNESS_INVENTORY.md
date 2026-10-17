# Graphical harness inventory

`tools/release/graphical_harness_registry.json` is the checked-in ownership and
review roster for scripts that produce rendered image evidence. It is an
inventory foundation, not a capture runner: validation never starts Godot,
opens a display, writes an image, or approves pixels.

Run the focused check from the repository root:

```sh
python3 tools/release/graphical_harness_inventory.py
python3 -m unittest -v tools/release/test_graphical_harness_inventory.py
```

Use `--json` for a detached, key-sorted machine-readable result. The reported
SHA-256 is over the sorted discovered paths and canonicalized registry entries;
it changes when either surface changes. `--root` and `--registry` exist for
isolated fixtures and release automation.

## Required graphical readiness

The same tool has a metadata-only report and an opt-in release check:

```sh
python3 tools/release/graphical_harness_inventory.py --required-readiness
python3 tools/release/graphical_harness_inventory.py --required-readiness --json
python3 tools/release/graphical_harness_inventory.py --required-readiness --strict
```

The report consumes only the checked-in registry. For each of the thirteen
mandatory IDs, it reports the source-freeze status, declared image-inventory
status and PNG count, original-resolution human-review status, and an exact
stage/reason blocker. Harnesses and blockers are emitted in stable ID and stage
order, with a deterministic readiness fingerprint. Invalid registry structure
always exits nonzero. A structurally valid report exits zero by default so it
can expose pending work; `--strict` exits nonzero unless all thirteen harnesses
have all three completed evidence stages.

Human `readiness: ready` means that machine evidence is ready to be inspected;
it remains a strict blocker. Only `readiness: reviewed`, with the required
bounded evidence reference after verified source and image declarations,
satisfies the human-review stage. The report never upgrades a state, inspects
pixels, or infers human approval from `review_status`.

At this revision three source/image declarations are verified: caption presenter
at exact `06d22013a`, freighter at exact `e159ac3c5`, and freight berth at exact
`689e2ed0e`. Their human-review readiness values are `ready`, not `reviewed`;
the other ten rows remain pending. The human-inclusive report has `ready=0`,
`required=13`, and 33 blockers: 20 machine stages and 13 human stages. Human
stages are excluded from the owner's completion requirement without representing
them as performed. Both text and JSON reports still state
`render_execution=false` and `human_review_performed=false` because the report
itself only reads metadata. These source-specific captures do not qualify all
thirteen harnesses on one final frozen candidate.

The unchanged caption-presenter harness passes on clean `06d22013a`, producing
exactly one 1600×900 PNG, exit 0, one success marker and zero diagnostics. The
complete source, import cache and registry match before/after; all owned actors
are reaped. Cold private XDG locations, private Xvfb x11, Dummy audio and
Forward+ Vulkan llvmpipe retain the original camera, layout, six-frame wait and
300-second cap. The 12-second wall span includes manifests. Original-resolution
agent inspection finds the complete two-line caption readable, with unclipped
speaker/category text and positive panel margins. No human or native GPU review
is implied. Raw artifacts: `artifacts/caption-presenter-06d22013a/`. Source CSV
SHA-256: `f7d80540649732b6c8f0b11ced4ab5fc4106a3b176c54ff22bf167ae1b91ecb7`; image inventory CSV SHA-256:
`007b57314cebdeeacee964e5ecd9e9389980ba15a973e1acf914506a0c786c45`.

The separately run unchanged full production-caption harness on the same source
remains **FAIL**: exit 124 at its original 300-second engine cap, no success
marker and no image. Its 307-second wall span includes manifests. The supervisor
terminates and reaps the owned processes; no Godot warning/error precedes the
supervisor's timeout error. Source, complete import cache and registry remain
unchanged. Raw failed artifacts: `artifacts/caption-production-06d22013a/`.
There is no unchanged retry, no promoted production-HUD inventory and no claim
that the smaller presenter frame establishes production layout acceptance.

A separate stage-timing diagnostic based on `bdc6a9272` reaches Main readiness
at 39.20s and the first production `frame_pre_draw` at 42.62s, then observes no
`frame_post_draw`. Sampled busy Godot worker instruction pointers are inside
`libvulkan_lvp.so`, while the main thread waits and llvmpipe draw workers are
idle; this is consistent with cold software-driver pipeline compilation.
The diagnostic is deliberately aborted once the boundary is established
(exit 143, owned descendants reaped). It changes logging in a temporary copy,
not canonical waits, camera, quality or production behavior, and is not capture
acceptance. No justified production fix or unchanged full retry follows from
this evidence. Raw stage log, native samples and logging patch remain in
`artifacts/caption-production-driver-diagnostic/`; the original timeout and
pending production-HUD source/image declarations remain unchanged.

The unchanged original freighter harness completed all four 1280×720 views
within its original 300-second cap on clean frozen source and import cache,
under private Xvfb x11 / Dummy / Forward+ Vulkan llvmpipe with fresh private XDG
locations. Source, registry and complete import cache stayed unchanged.
Original-resolution agent inspection confirms the visible cabin readout,
coherent distant cargo lids and bonnet cooling fields. Native LOD preserves all
5,410 near triangles; a controlled close roof image remains byte-identical.
Distant-only top surfaces remove the demonstrated broken vertical-return
outlines; sparse authored attachments and pressure joints remain. The scoped
software-rendered `JOVIAN-ROOF-001` finding is resolved. Target-GPU, temporal,
whole-fleet and broader art-direction acceptance remain open.

Earlier `5c76d023c` passed the capture contract but failed visual inspection
because a separate housing covered its text. Its unaccepted raw images and
exports remain preserved. The intermediate distant-lid candidate passed its
focused suite but retained broken field outlines, which were corrected before
this final canonical capture. Current source retains housing clearance,
merged-triangle engineer visibility, corrected normals and gasket support;
fitout batching preserves native LOD and colour data. No human or native GPU
qualification is implied.

Actual manifests, PNGs and logs are retained locally under
`artifacts/jovian-freighter-e159ac3c5/`; source CSV SHA-256 is
`c23fd45dee6a2981745a0323004d47c535b10a3f1f4fc2c5722e8240838bd5c4`, and image-inventory CSV SHA-256 is `475f0ef490e8511f53078831d35b4c8b6af8132e708f2d75e3b655799e87f94f`.
[Checkpoint notes](../builds/windows/MuddsShipyards-e159ac3-notes.txt) identify
exact packaged source and validation. Later test, registry and documentation
changes are not part of the captured or exported source.

The freight berth's two required views pass on frozen `689e2ed0e` with exact
1400×900 PNGs, exit 0, one success marker, zero diagnostics and unchanged
source/registry/complete import cache. The original cameras, environment,
TAA/MSAA, 10/8 waits, real door physics budget and 300s cap remain. Direct
SceneTree capture now calls Boot's production display-aspect policy; the old
KEEP path rendered 1400×787 inside a 1400×900 window. That `b7c275d77` baseline
remains a resolution FAIL. Root inspected both corrected originals; the
separate controlled walking-view pair proves the formerly hidden exterior
FREIGHT CONTROL legend is now fully readable. The two required views alone
do not expose that entire legend. Supplemental pairs are not canonical frames.
Raw final artifacts are `artifacts/jovian-freight-berth-689e2ed0e/`, including
separate before/after sign images. Source CSV SHA-256: `19ee9d4ddac93c07842b2510f2f6a305d2b61e7ee36f13d23464dcb8700ace5d`;
image-inventory CSV SHA-256: `2e056bfb5d320daac70eafb96b7a82a3ba9679572fe16efc080ff984e26d33dc`.
[Freight checkpoint notes](../builds/windows/MuddsShipyards-689e2ed-notes.txt)
identify the exact source/package and remaining scope. No native GPU or human
review is claimed. Later handoff metadata is outside that captured source.

The new `cinder-streaming-transition-render` requirement freezes 24 declared
HIGH/LOW × normal/reduced-motion transition frames. Its exact state, camera,
threshold, and manifest contract is documented in
`docs/CINDER_STREAMING_TRANSITION_EVIDENCE.md`; all three registry evidence
stages remain pending and no human pixel review is claimed.

On 2026-10-17, `6cf94bd39` updates the station-operations runner to the exact nine-craft/nine-berth production roster. Its one original-cap Forward+ llvmpipe attempt times out at 300 seconds before initial render settling, with no PNGs; source/index/status/import-cache guards remain unchanged. The roster assertions are not reached. The registry stays pending for this harness. Raw run: `/srv/mudds-work/station-operations-capture-20261017/`.

## Current required capture commands

The current source inventory contains **13 required harnesses and 143 PNGs**.
Berth feedback now includes the Bulwark's three states, for **18**, and varied
encounters includes `plate_04b_scatter_fan.png`, for **18**. The registry and
validator require these complete source inventories, replacing their stale
15/17 declarations (139 total). Only the caption-presenter, freighter and freight-berth source/image stages are
verified as described above; matching a declared count alone does not qualify
any captured image.

The table names the exact source-owned filename sets. Counts exclude manifests,
logs, import sidecars, and the station-operations optional wayfinding-only PNG.

| Harness script under `tests/` | PNGs | Resolution | Filename set |
| --- | ---: | --- | --- |
| `caption_presenter_forward_render.gd` | 1 | 1600×900 | `caption-presenter-forward-plus.png` |
| `caption_production_forward_render.gd` | 1 | 1600×900 | `caption-production-forward-plus.png` |
| `cinder_streaming_transition_render.gd` | 24 | 2560×1440 | `%02d_<scenario>_<state>.png`, ordered `SCENARIOS` × `STATES` |
| `capture_berth_feedback.gd` | 18 | 2560×1440 | `CAPTURE_FILES`, including Bulwark frames 16–18 |
| `capture_combat_visuals.gd` | 7 | 2560×1440 | `CAPTURE_FILES` |
| `capture_hero_cell.gd` | 18 | 2560×1440 | `CAPTURE_FILES` |
| `capture_jovian_freight_berth.gd` | 2 | 1400×900 | `freight_berth_overview.png`, `freight_control_room.png` |
| `capture_jovian_freighter.gd` | 4 | 1280×720 | `jovian_freighter_exterior.png`, `jovian_cargo_ramp.png`, `jovian_cargo_interior.png`, `jovian_passenger_cabin.png` |
| `capture_player_motion.gd` | 9 | 2560×1440 | `CAPTURE_FILES` |
| `capture_scenes.gd` | 27 | 2560×1440 | `CAPTURE_FILES` |
| `capture_station_operations.gd` | 7 | 2560×1440 | `CAPTURE_FILES`; exclude separate `08_wayfinding_pylon_player_eye.png` |
| `capture_varied_encounters.gd` | 18 | 1600×900 | `play_01`–`play_07`, `plate_01`–`plate_10`, plus `plate_04b_scatter_fan.png` |
| `capture_zenith_visuals.gd` | 7 | 2560×1440 | `CAPTURE_FILES` |

Run serially only in the owner's prepared private Xvfb session, with its explicit
X11/DZN environment and isolated user data. `GODOT_BIN` must name the pinned
editor, `PROJECT_ROOT` the frozen imported checkout, and `CAPTURE_ROOT` a fresh
canonical absolute directory outside the checkout and protected old outputs.
Provide a separate private user-data profile for each invocation. Clear inherited
parse-only, staging-only, and wayfinding-only capture flags. These scripts are
outside the matrix's `*_test.gd` discovery; graphical matrix completion does not
run this image roster. The existing 300-second outer cap is retained below;
individual capture scripts do not declare a separate wall-clock cap.

```bash
: "${GODOT_BIN:?}" "${PROJECT_ROOT:?}" "${CAPTURE_ROOT:?}" "${DISPLAY:?}" "${XAUTHORITY:?}"
capture=(env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET timeout 300s "$GODOT_BIN"
  --path "$PROJECT_ROOT" --display-driver x11 --audio-driver Dummy
  --rendering-method forward_plus --rendering-driver vulkan)

env MUDDS_CAPTION_CAPTURE_DIR="$CAPTURE_ROOT/caption-presenter" "${capture[@]}" --resolution 1600x900 --script res://tests/caption_presenter_forward_render.gd
env MUDDS_CAPTION_CAPTURE_DIR="$CAPTURE_ROOT/caption-production" "${capture[@]}" --resolution 1600x900 --script res://tests/caption_production_forward_render.gd
env KETH_CINDER_TRANSITION_CAPTURE_DIR="$CAPTURE_ROOT/cinder-transitions" "${capture[@]}" --resolution 2560x1440 --script res://tests/cinder_streaming_transition_render.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/berth-feedback" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_berth_feedback.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/combat-visuals" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_combat_visuals.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/hero-cell" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_hero_cell.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/jovian-freight-berth" "${capture[@]}" --resolution 1400x900 --script res://tests/capture_jovian_freight_berth.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/jovian-freighter" "${capture[@]}" --resolution 1280x720 --script res://tests/capture_jovian_freighter.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/player-motion" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_player_motion.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/scenes" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_scenes.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/station-operations" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_station_operations.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/varied-encounters" "${capture[@]}" --resolution 1600x900 --script res://tests/capture_varied_encounters.gd
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/zenith-visuals" "${capture[@]}" --resolution 2560x1440 --script res://tests/capture_zenith_visuals.gd
```

The ten `MUDDS_CAPTURE_OUTPUT_DIR` consumers route their published PNGs and
applicable manifests together, retaining their exact legacy defaults when unset.
Gameplay capture retains its existing private `user://` temporary staging.
Separate output directories are mandatory: gameplay and freighter captures share
some PNG basenames. External logs must follow each harness's declared log path.
Require exit 0, its full-capture success marker, the complete correctly sized
image set, and unchanged frozen inputs. Parse/staging success is not capture
success. Source/image verification and original-resolution human review remain
pending until actually performed; these commands claim no execution or approval.

The current optional `capture-station-defense-approach-lane-cue` witness is
registered as `supplementary`, not one of the thirteen broad required captures.
It renders one HUD-free 1600×900 frame of the steady approach chevron from more
than thirty metres, with a capture-only reference deck and camera. Its exact
filename is `station_defense_approach_lane_forward_plus.png`; the default is
`user://captures/station-defense-approach-lane`, or set `MUDDS_CAPTURE_OUTPUT_DIR`
to a canonical absolute directory. Output ancestors and the PNG leaf reject
links, including broken links. In the same private session it can be invoked as:

```bash
env MUDDS_CAPTURE_OUTPUT_DIR="$CAPTURE_ROOT/station-defense-approach" "${capture[@]}" --resolution 1600x900 --script res://tests/capture_station_defense_approach_lane_cue.gd
```

Require exit 0, `STATION_DEFENSE_APPROACH_LANE_CAPTURE_OK`, and that one complete
PNG. Its source/image verification and original-resolution human review remain
pending. This scoped witness does not qualify broad station/combat art review.

## Discovery boundary

The validator scans all `.gd` files recursively below `tests/` and `tools/`. A
script is relevant when either condition holds:

- its filename begins with `capture_` or ends with `_render.gd`; or
- its source contains a rendered-viewport readback marker and `save_png`.

This includes optional graphical branches in otherwise headless `*_test.gd`
suites and image-writing visual probes. It excludes headless geometry/counting
probes and PNG asset processors such as `generate_material_maps.gd` and
`simulate_dichromacy.gd`, because they do not read rendered viewport evidence.

At the foundation revision the rule discovers and the registry covers exactly
49 scripts: 13 required, 36 historical, and 0 deprecated. The thirteen required
IDs and their exact expected PNG counts are hard-frozen in the validator, so a
registry edit cannot silently remove or demote one, or weaken its image count.
Zero deprecated is
intentional; no still-present script had checked-in evidence of explicit
retirement. A future retired-but-retained script must use `deprecated` plus
`retired`, rather than silently disappearing from the registry.

## Registry contract

Every row has:

- `id`: stable lowercase kebab-case identity, independent of file moves;
- `script`: canonical repository-relative `.gd` path under `tests/` or `tools/`;
- `classification`: `required`, `supplementary`, `historical`, or `deprecated`;
- `output`: the default safe root, `png`/`png_set`/`png_set_and_manifest`
  contract, and an optional documented environment override;
- `render`: explicit `required: true` plus the expected Forward+ profile; and
- `review_status`: registry-triage status, not an assertion that the images
  received human art approval;
- `source_freeze`: independent pending/verified state and an exact manifest
  SHA-256 when verified;
- `image_inventory`: independent pending/verified state, exact expected PNG
  count when known, and an inventory SHA-256 when verified; and
- `human_review`: pending/ready/reviewed state, a mandatory original-resolution
  requirement, and a bounded evidence reference only after review.

Classification is deliberately separate from matrix membership:

- `required` means current release or production documentation names the
  harness as an active graphical review surface. It does not join the headless
  matrix and is not run by this tool.
- `supplementary` means an optional runtime capture supports focused regression
  review without adding a mandatory release surface.
- `historical` means the script remains useful for on-demand diagnostic or
  change-specific evidence but is not a current release obligation.
- `deprecated` means a retired harness remains in the source tree temporarily.

`reviewed_current` and `reviewed_historical` mean the registry classification
was checked against current or explicitly historical documentation.
`pending` exposes unreviewed classification debt. `retired` is required for a
deprecated row. These statuses say nothing about pixel quality or source
authenticity. In particular, `reviewed_current` means only that the registry
classification was reviewed; it never means that a human reviewed current
pixels. That claim exists only in `human_review`.

The three evidence states fail closed independently. A verified source freeze
requires a 64-character lowercase SHA-256. A verified image inventory requires
a positive exact integer count and its own SHA-256. Human review cannot become
`ready` or `reviewed` until both machine evidence states are verified, and a
`reviewed` row also requires an evidence reference. All current rows remain
explicitly `pending`; this foundation records contracts and review debt rather
than inventing evidence from old prose.

Output roots are restricted to ignored `res://artifacts`, `user://`, or `/tmp`
locations. Script paths reject absolute paths, traversal, backslashes,
non-canonical forms, symlink entries, and repository escapes. The validator
also rejects missing or undiscovered registered scripts, unregistered
discoveries, duplicate JSON keys/IDs/scripts, unknown fields, invalid enums,
incompatible classification/review pairs, malformed scalar/container types,
non-integer schema versions, mandatory-ID demotion, and mandatory image-count
drift. Errors are deduplicated and sorted so the same checkout produces the
same diagnostic order.

## Updating the roster

Add or remove the script and registry row in the same change, choose the output
fallback that the script actually uses, and run both commands above. A new
resolution-specific profile should be added to the validator only when the
harness freezes that exact viewport; otherwise use `project_forward_plus` or
`forward_plus_runtime_viewport`. Do not label old evidence `deprecated` merely
because it is not a release gate.

The station bevel pass is historical change-specific evidence: its twelve frames
use `user://station_bevel_capture/<tag>` unless `KETH_BEVEL_CAPTURE_DIR` supplies
another root. The cloud-shadow runtime test has a supplementary two-frame capture
only when `MUDDS_CLOUD_SHADOW_CAPTURE_DIR` names an existing directory; it has no
authored output default and freezes a 960 × 720 viewport during capture. Their
source, image and human-review states remain pending. Adding these registrations
does not complete any of the thirteen mandatory review surfaces.

## Known limitations

- Discovery is a conservative lexical source scan, not a GDScript parser or
  call-graph analysis. An image writer hidden entirely behind a helper without
  the checked markers would need a discovery-rule update.
- The tool validates registered fallback roots and environment-variable names;
  it cannot constrain a caller's runtime environment override or dynamic file
  label. Godot harnesses remain responsible for their own runtime path safety.
- The thirteen required harnesses freeze exact expected PNG counts. Historical
  rows may retain a null count while their image inventory is explicitly
  pending; no cardinality or hash is inferred for them.
- Source-freeze and image-inventory verification are pending in this initial
  registry. The validator checks evidence shape and state transitions but does
  not manufacture hashes or treat historical narrative as machine evidence.
- Required-readiness is a registry-state check, not a filesystem image
  verifier. A future evidence-producing workflow must calculate and record the
  declared manifests before strict readiness can pass.
- A render profile is declared metadata. This validator does not inspect the
  active GPU, display server, viewport size, renderer result, pixels, manifests,
  or human review evidence.
- Non-GDScript capture tooling and external CI/service harnesses are outside the
  current `tests/` and `tools/` discovery boundary.
