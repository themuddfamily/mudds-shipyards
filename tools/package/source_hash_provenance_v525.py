"""Schema-525 source provenance validator."""
from tools.package.source_hash_provenance_v524 import validate_v524 as _validate
def validate_v525(value,label="source_provenance_v525"):
    return [e.replace("524","525") for e in _validate(value)]
