"""Schema-440 source provenance validator."""
from tools.package.source_hash_provenance_v439 import validate_v439 as _validate
def validate_v440(value,label="source_provenance_v440"):
    return [e.replace("439","440") for e in _validate(value)]
