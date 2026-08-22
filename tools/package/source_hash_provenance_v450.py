"""Schema-450 source provenance validator."""
from tools.package.source_hash_provenance_v449 import validate_v449 as _validate
def validate_v450(value,label="source_provenance_v450"):
    return [e.replace("449","450") for e in _validate(value)]
