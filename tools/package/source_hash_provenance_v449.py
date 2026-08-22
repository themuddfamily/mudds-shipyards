"""Schema-449 source provenance validator."""
from tools.package.source_hash_provenance_v448 import validate_v448 as _validate
def validate_v449(value,label="source_provenance_v449"):
    return [e.replace("448","449") for e in _validate(value)]
