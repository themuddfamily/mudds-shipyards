"""Schema-478 source provenance validator."""
from tools.package.source_hash_provenance_v477 import validate_v477 as _validate
def validate_v478(value,label="source_provenance_v478"):
    return [e.replace("477","478") for e in _validate(value)]
