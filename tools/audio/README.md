# Audio validation tools

The equivalent audio cleanup evidence/state contracts v383–v1057 share one
implementation, `audio_cleanup_evidence_state_validator.py`. Existing JSON schema
names and validation rules remain supported; no new evidence schema is introduced.

```sh
python tools/audio/audio_cleanup_evidence_state_validator.py summary.json
python tools/audio/audio_cleanup_evidence_state_validator.py summary.json --schema-version 999
python -m unittest discover -s tools/audio -p 'test_audio_cleanup_evidence_state*.py'
```

The first command selects the contract from the summary's `schema`. Use
`--schema-version` to require one exact legacy schema, equivalent to invoking its
former numbered script. Accepted schemas retain the versioned CLI `VALID` / `INVALID`
banners and exit codes. Python callers use `validate_summary(summary)` or
`validate_summary(summary, schema_version=999)` from the shared module.

The retired v383–v1057 script paths had no tracked consumers outside their own
matching tests: no runtime, release command, fixture, or documentation referenced
them. Those tests are now one parameterized suite covering every supported schema.
Earlier numbered validators remain because their contracts differ; this migration
does not reinterpret those schemas. Their matching tests still import the numbered
entrypoints. Other audio validator families are outside this consolidation.

Detached, native, hardware, and human-review statuses must still be `NOT_RUN`.
These summaries establish automated evidence only.
