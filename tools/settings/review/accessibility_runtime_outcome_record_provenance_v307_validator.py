"""Validate v307 runtime accessibility outcome provenance."""
from __future__ import annotations
import argparse,json
from pathlib import Path
from tools.settings.review import accessibility_runtime_outcome_record_provenance_v306_validator as _base
SCHEMA="accessibility_runtime_outcome_record_provenance_v307_evidence_v1"
def validate_runtime_outcome_record_provenance(value):
    if not isinstance(value,dict): return ["record must be an object"]
    candidate=dict(value); candidate["schema"] = _base.SCHEMA; candidate["schema_version"]="v306"
    errors=_base.validate_runtime_outcome_record_provenance(candidate)
    if value.get("schema") != SCHEMA: errors.append("schema")
    if value.get("schema_version") != "v307": errors.append("schema_version")
    return errors
def validate(path):
    try:return validate_runtime_outcome_record_provenance(json.loads(Path(path).read_text(encoding="utf-8")))
    except (OSError,json.JSONDecodeError) as exc:return [f"unreadable: {exc}"]
def main(argv=None):
    parser=argparse.ArgumentParser();parser.add_argument("provenance",type=Path);errors=validate(parser.parse_args(argv).provenance)
    print("ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_V307_INVALID" if errors else "ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_V307_READY: review and native gates remain open");return bool(errors)
if __name__=="__main__":raise SystemExit(main())
