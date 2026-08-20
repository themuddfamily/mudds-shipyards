# Rendered-evidence capture-set gate

`tools/validate_visual_capture_set.py` is the source-current integrity check
for a checked-in rendered-evidence set. It validates the manifest schema and
frame/state inventories, exact PNG dimensions and RGB8/non-interlaced headers,
per-frame byte counts and SHA-256 values, and the source-manifest SHA-256 and
file count recorded by the capture.

Run the bounded check from the project root:

```sh
python3 tools/validate_visual_capture_set.py artifacts/combat_visuals/evidence_manifest.json
```

This gate intentionally does not render, compare pixels, assess composition,
or replace the human visual review required by ROADMAP items 625 and 967–970.
It is evidence that the named capture files are still the files described by
the record, not evidence of final art quality, native hardware performance, or
historical authenticity. A changed frame or source tree must produce a new
capture record rather than an edited hash.
