"""Schema-451 source provenance validator."""
from tools.package.source_hash_provenance_v450 import validate_v450 as _validate
def validate_v451(value,label="source_provenance_v451"):
    return [e.replace("450","451") for e in _validate(value)]
