"""Schema-573 source provenance validator."""
from tools.package.source_hash_provenance_v572 import validate_v572 as _validate
def validate_v573(value,label="source_provenance_v573"):
    return [e.replace("572","573") for e in _validate(value)]
