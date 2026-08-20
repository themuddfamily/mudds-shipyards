#!/usr/bin/env python3
"""Fail-closed validation of package signing and installer evidence.

This validates an operator-produced record only.  It never invokes signing,
installer, or native platform tooling; metadata alone must not become a claim
that an artifact was executed or that a signature grants distribution rights.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
SIGNATURE_STATES = {"VERIFIED", "UNVERIFIED", "UNSIGNED", "UNKNOWN"}
INSTALLER_STATES = {"VERIFIED", "UNVERIFIED", "NOT_PROVIDED", "UNKNOWN"}
NATIVE_STATES = {"PASS", "FAIL", "NOT_RUN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and len(value) == 64 and all(c in "0123456789abcdefABCDEF" for c in value)


def validate_evidence(value: Any, label: str = "evidence") -> list[str]:
    """Return all contract violations; an empty list means structurally valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "artifact_path", "artifact_sha256", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("artifact_sha256")) and not _digest(value["artifact_sha256"]):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest")

    signature = value.get("signature_status")
    if signature not in SIGNATURE_STATES:
        errors.append(f"{label}.signature_status is invalid")
    if signature == "VERIFIED":
        for key in ("signature_tool", "signer_subject", "signature_evidence"):
            if not _text(value.get(key)):
                errors.append(f"{label}.{key} is required for VERIFIED signature")
        if value.get("signature_grants_distribution_rights") is not False:
            errors.append(f"{label}.signature_grants_distribution_rights must be false")
    elif value.get("signature_evidence") is not None:
        errors.append(f"{label}.signature_evidence must be null unless signature is VERIFIED")
    if value.get("signature_grants_distribution_rights") not in (False, None):
        errors.append(f"{label}.signature_grants_distribution_rights must be false")

    installer = value.get("installer_status")
    if installer not in INSTALLER_STATES:
        errors.append(f"{label}.installer_status is invalid")
    if installer == "VERIFIED":
        for key in ("installer_path", "installer_sha256", "installer_provenance"):
            if not _text(value.get(key)):
                errors.append(f"{label}.{key} is required for VERIFIED installer")
        if _text(value.get("installer_sha256")) and not _digest(value["installer_sha256"]):
            errors.append(f"{label}.installer_sha256 must be a 64-character hex digest")
    elif any(value.get(key) is not None for key in ("installer_path", "installer_sha256", "installer_provenance")):
        errors.append(f"{label}.installer evidence must be null unless installer is VERIFIED")

    native = value.get("native_execution_status")
    if native not in NATIVE_STATES:
        errors.append(f"{label}.native_execution_status is invalid")
    native_evidence = value.get("native_execution_evidence")
    if native == "NOT_RUN" and native_evidence is not None:
        errors.append(f"{label}.native_execution_evidence must be null when native execution is NOT_RUN")
    if native in {"PASS", "FAIL"} and not _text(native_evidence):
        errors.append(f"{label}.native_execution_evidence is required when native execution ran")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_evidence(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("PACKAGE_SIGNING_INSTALLER_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_SIGNING_INSTALLER_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
