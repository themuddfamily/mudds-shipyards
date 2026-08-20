# End-to-end scenario and re-entry manifest

`tools/release/e2e_scenario_manifest.json` is the machine-readable declaration
for the bounded packaged core-loop scenario. It names the lifecycle steps, the
five current flyables, repeat requirements, and the state that must survive a
whole-`Main` detach/re-entry. It is intentionally not a playthrough result:
the checked-in record is `pending` until a clean source revision, package run,
and fresh-process evidence are available.

Validate the declaration without starting Godot:

```sh
python3 tools/release/e2e_scenario_manifest.py \
  tools/release/e2e_scenario_manifest.json
python3 -m unittest tools/release/test_e2e_scenario_manifest.py
```

The contract keeps four concerns separate:

- `steps` describe the ordered player-visible lifecycle and each expected
  result; they do not grant gameplay authority.
- `reentry.identity_fields` identifies the retained logical session. The
  `preserved_fields` and `reset_fields` lists must be disjoint, and stale
  generations and duplicate completion must be rejected.
- `repeat_policy` states the minimum fresh-process and same-world repetition
  required before declaring the scenario green.
- `evidence` records observed runs only after their source, package, and
  artifact provenance exists. `pending` is allowed for planning; `pass`
  requires a clean source commit, a passing package result, and all required
  fresh-process runs.

The validator checks schema, stable IDs, lifecycle ordering, re-entry
invariants, duplicate runs, safe artifact paths, and (when `--root` is given)
artifact hashes. It does not launch the game, assess visual quality, replace a
human playthrough, or claim native-Windows performance.
