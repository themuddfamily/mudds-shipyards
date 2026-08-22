"""Schema-581 source provenance validator."""
from tools.package.source_hash_provenance_v580 import validate_v580 as _validate
def validate_v581(value,label="source_provenance_v581"):
    return [e.replace("580","581") for e in _validate(value)]
