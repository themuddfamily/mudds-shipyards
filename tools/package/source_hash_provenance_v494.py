"""Schema-494 source provenance validator."""
from tools.package.source_hash_provenance_v493 import validate_v493 as _validate
def validate_v494(value,label="source_provenance_v494"):
    return [e.replace("493","494") for e in _validate(value)]
