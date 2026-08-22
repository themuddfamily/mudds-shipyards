"""Schema-425 source provenance validator."""
from tools.package.source_hash_provenance_v424 import validate_v424 as _validate
def validate_v425(value,label="source_provenance_v425"):
    errors=_validate(value)
    return [e.replace("424","425") for e in errors]
