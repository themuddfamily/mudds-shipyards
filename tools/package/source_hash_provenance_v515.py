"""Schema-515 source provenance validator."""
from tools.package.source_hash_provenance_v514 import validate_v514 as _validate
def validate_v515(value,label="source_provenance_v515"):
    return [e.replace("514","515") for e in _validate(value)]
