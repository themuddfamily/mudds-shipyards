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
48 scripts: 12 required, 36 historical, and 0 deprecated. The twelve required
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
- `classification`: `required`, `historical`, or `deprecated`;
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

## Known limitations

- Discovery is a conservative lexical source scan, not a GDScript parser or
  call-graph analysis. An image writer hidden entirely behind a helper without
  the checked markers would need a discovery-rule update.
- The tool validates registered fallback roots and environment-variable names;
  it cannot constrain a caller's runtime environment override or dynamic file
  label. Godot harnesses remain responsible for their own runtime path safety.
- The twelve required harnesses freeze exact expected PNG counts. Historical
  rows may retain a null count while their image inventory is explicitly
  pending; no cardinality or hash is inferred for them.
- Source-freeze and image-inventory verification are pending in this initial
  registry. The validator checks evidence shape and state transitions but does
  not manufacture hashes or treat historical narrative as machine evidence.
- A render profile is declared metadata. This validator does not inspect the
  active GPU, display server, viewport size, renderer result, pixels, manifests,
  or human review evidence.
- Non-GDScript capture tooling and external CI/service harnesses are outside the
  current `tests/` and `tools/` discovery boundary.
