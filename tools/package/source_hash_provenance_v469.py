"""Schema-469 source provenance validator."""
from tools.package.source_hash_provenance_v468 import validate_v468 as _validate
def validate_v469(value,label="source_provenance_v469"):
    return [e.replace("468","469") for e in _validate(value)]
