"""Schema-504 source provenance validator."""
from tools.package.source_hash_provenance_v503 import validate_v503 as _validate
def validate_v504(value,label="source_provenance_v504"):
    return [e.replace("503","504") for e in _validate(value)]
