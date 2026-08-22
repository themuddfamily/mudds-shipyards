"""Schema-428 source provenance validator."""
from tools.package.source_hash_provenance_v427 import validate_v427 as _validate
def validate_v428(value,label="source_provenance_v428"):
    return [e.replace("427","428") for e in _validate(value)]
