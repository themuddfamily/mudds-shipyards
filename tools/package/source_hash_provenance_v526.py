"""Schema-526 source provenance validator."""
from tools.package.source_hash_provenance_v525 import validate_v525 as _validate
def validate_v526(value,label="source_provenance_v526"):
    return [e.replace("525","526") for e in _validate(value)]
