"""Schema-503 source provenance validator."""
from tools.package.source_hash_provenance_v502 import validate_v502 as _validate
def validate_v503(value,label="source_provenance_v503"):
    return [e.replace("502","503") for e in _validate(value)]
