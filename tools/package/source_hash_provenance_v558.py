"""Schema-558 source provenance validator."""
from tools.package.source_hash_provenance_v557 import validate_v557 as _validate
def validate_v558(value,label="source_provenance_v558"):
    return [e.replace("557","558") for e in _validate(value)]
