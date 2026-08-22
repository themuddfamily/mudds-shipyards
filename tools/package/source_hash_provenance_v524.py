"""Schema-524 source provenance validator."""
from tools.package.source_hash_provenance_v523 import validate_v523 as _validate
def validate_v524(value,label="source_provenance_v524"):
    return [e.replace("523","524") for e in _validate(value)]
