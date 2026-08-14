# Research evidence data

This directory makes the historical claims in [`RESEARCH.md`](../../RESEARCH.md)
reproducible without redistributing third-party media.

- [`source_ledger.json`](source_ledger.json) is the source-of-truth inventory for
  A1–A10, B1–B7, and C1–C3. It separates upload, archive, recording, and game
  build dates; records exact observation anchors; and carries a rights status for
  every source.
- [`source_ledger.schema.json`](source_ledger.schema.json) defines the typed
  contract used by the automated research test.
- [`STATION_TOPOLOGY.md`](STATION_TOPOLOGY.md) keeps each observed station graph
  in its own version scope before mapping the current station onto those motifs.
- [`ship_evidence_matrix.json`](ship_evidence_matrix.json) applies the same six
  reconstruction gates to every currently known ship name.
- [`../ZENITH_B7_RECONSTRUCTION_SPEC.md`](../ZENITH_B7_RECONSTRUCTION_SPEC.md)
  deliberately versions the A5/A9 role conflict and freezes the non-media,
  frame-bounded source core now used by the bounded partial B7-observed Zenith
  implementation. Implementation and capture acceptance do not authenticate it.

## Source-media policy

The repository tracks citations, metadata, hashes, extraction instructions, and
bounded observations. It does **not** track source videos, screenshots, Roblox
place files, or extracted third-party assets. Public availability is not a
licence. Every ledger entry therefore defaults to `permission_not_recorded` and
`do_not_bundle_or_commit` unless written permission is later recorded.

`docs/research/private/` and `docs/research/tmp/` are ignored. They may be used
for an authorised local study copy, but must never be relied upon at runtime or
included in a build. A complete-rendition SHA-256 authenticates only the exact
bytes inspected; it does not grant redistribution rights.

## Reproducing an observation

1. Obtain the source independently from its registered URL, subject to its
   terms and applicable law.
2. Keep it outside the tracked tree.
3. Verify the complete bytes with `sha256sum` when the ledger supplies a hash.
4. Extract the registered zero-based frame or time anchor without interpolation.
5. Compare only the bounded observation and limitation fields. Do not infer a
   recording date or build revision from an upload date.

The current B5 audit used a 640×480, constant-30-fps, 2,753-frame public
rendition with SHA-256
`c1f1ed745ce507729228c62deee7798c9af51d98681f2dda65acba0d5a36948d`.
That file is intentionally absent from the repository.

The B7 Zenith audit used an 854×480, constant-11-fps, 48-second public
rendition of 2,264,402 bytes with SHA-256
`c716c506d9fd7042ac98720e8815725cf083d24967bc8c9f842cdfa58e8ca144`.
That file and every extracted frame are also intentionally absent.

## Frame convention

All ledger frame numbers are zero-based decoded-frame indices. `time_ms` is a
human navigation aid; when both are present, the decoded frame is authoritative
for the registered rendition. No frame number may be transferred to a different
rendition unless its timing and frame sequence have been independently checked.
