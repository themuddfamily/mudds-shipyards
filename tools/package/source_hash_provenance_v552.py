"""Schema-552 source provenance validator."""
from tools.package.source_hash_provenance_v551 import validate_v551 as _validate
def validate_v552(value,label="source_provenance_v552"):
    return [e.replace("551","552") for e in _validate(value)]
