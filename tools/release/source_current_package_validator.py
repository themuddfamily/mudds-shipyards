#!/usr/bin/env python3
"""Verify that a release record and package still describe the current source.

This is a cheap post-build evidence check.  It does not export, launch Godot,
or rerun the matrix: it compares the recorded source revision and package
metadata with the checked-out tree and the bytes of one supplied executable.
"""

import argparse
import json
import re
import sys
from pathlib import Path

import package_inventory
import release_candidate


MAX_RECORD_BYTES = 8 << 20
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _load_record(path):
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise release_candidate.EvidenceError(f"cannot read release record: {path}") from error
    if len(raw) > MAX_RECORD_BYTES:
        raise release_candidate.EvidenceError("release record is unreasonably large")
    try:
        record = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise release_candidate.EvidenceError("release record is not valid UTF-8 JSON") from error
    if not isinstance(record, dict):
        raise release_candidate.EvidenceError("release record root is not an object")
    release_candidate.validate_record_schema(record)
    return record


def _compare(label, actual, expected):
    if actual != expected:
        raise release_candidate.EvidenceError(
            f"source-current {label} mismatch: recorded {expected!r}, actual {actual!r}"
        )


def validate_source_current(repository, artifact_path, record_path):
    """Return a compact PASS report or raise EvidenceError.

    The caller owns the artifact path explicitly so a stale similarly-named
    executable cannot accidentally satisfy the check.
    """
    repository = repository.resolve()
    artifact_path = artifact_path.resolve()
    record_path = record_path.resolve()
    record = _load_record(record_path)
    source = release_candidate.inspect_source(repository)
    recorded_source = record["source"]
    _compare("revision", recorded_source["revision"], source["revision"])
    _compare("short revision", recorded_source["short_revision"], source["short_revision"])
    _compare("dirty state", recorded_source["dirty"], False)

    artifact = record["artifact"]
    _compare("artifact name", artifact["name"], artifact_path.name)
    if not artifact_path.is_file():
        raise release_candidate.EvidenceError(f"release artifact is missing: {artifact_path}")
    data = release_candidate._bounded_read(artifact_path, 2 << 30, "release artifact")
    actual_sha = release_candidate._sha256_bytes(data)
    _compare("artifact size", artifact["size"], len(data))
    _compare("artifact SHA-256", artifact["sha256"], actual_sha)
    _compare("artifact source revision", artifact["source_short_revision"], source["short_revision"])
    actual_pe = release_candidate.inspect_pe(data)
    _compare("PE metadata", artifact["pe"], actual_pe["pe"])
    _compare("signing metadata", artifact["signing"], actual_pe["signing"])

    base, pack_end = package_inventory.find_pck(data)
    parsed = package_inventory.parse(data, base, pack_end)
    recorded_inventory = record["evidence"]["package_inventory"]
    _compare("PCK offset", recorded_inventory["pck_offset"], parsed["pck"]["offset"])
    _compare("PCK size", recorded_inventory["pck_size"], parsed["pck"]["size"])
    _compare("PCK format", recorded_inventory["pck_format"], parsed["pck"]["format"])
    _compare("PCK entry count", recorded_inventory["entry_count"], parsed["pck"]["entry_count"])
    _compare(
        "PCK path manifest SHA-256",
        recorded_inventory["path_manifest_sha256"],
        parsed["pck"]["sorted_path_manifest_sha256"],
    )
    if not SHA256_RE.fullmatch(actual_sha):
        raise release_candidate.EvidenceError("computed artifact SHA-256 is malformed")

    probes = record["evidence"]["package_probes"]
    if probes["status"] != "PASS" or probes["total_probes"] < 1 or probes["total_pass_assertions"] < 1:
        raise release_candidate.EvidenceError("recorded package probes are not a passing non-empty run")
    return {
        "status": "PASS",
        "source_revision": source["revision"],
        "artifact_name": artifact_path.name,
        "artifact_sha256": actual_sha,
        "pck_format": parsed["pck"]["format"],
        "pck_entry_count": parsed["pck"]["entry_count"],
        "package_probe_run_id": probes["run_id"],
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = validate_source_current(args.repository, args.artifact, args.record)
    except (release_candidate.EvidenceError, OSError, ValueError) as error:
        print(f"source-current-package: ERROR: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
