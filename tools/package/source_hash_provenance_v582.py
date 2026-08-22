"""Schema-582 source provenance validator."""
from tools.package.source_hash_provenance_v581 import validate_v581 as _validate
def validate_v582(value,label="source_provenance_v582"):
    return [e.replace("581","582") for e in _validate(value)]
