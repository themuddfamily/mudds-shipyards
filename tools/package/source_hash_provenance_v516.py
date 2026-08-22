"""Schema-516 source provenance validator."""
from tools.package.source_hash_provenance_v515 import validate_v515 as _validate
def validate_v516(value,label="source_provenance_v516"):
    return [e.replace("515","516") for e in _validate(value)]
