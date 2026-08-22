"""Schema-426 source provenance validator."""
from tools.package.source_hash_provenance_v425 import validate_v425 as _validate
def validate_v426(value,label="source_provenance_v426"):
    return [e.replace("425","426") for e in _validate(value)]
