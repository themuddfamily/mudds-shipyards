"""Schema-434 source provenance validator."""
from tools.package.source_hash_provenance_v433 import validate_v433 as _validate
def validate_v434(value,label="source_provenance_v434"):
    return [e.replace("433","434") for e in _validate(value)]
