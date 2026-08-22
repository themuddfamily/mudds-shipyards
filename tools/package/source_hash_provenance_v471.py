"""Schema-471 source provenance validator."""
from tools.package.source_hash_provenance_v470 import validate_v470 as _validate
def validate_v471(value,label="source_provenance_v471"):
    return [e.replace("470","471") for e in _validate(value)]
