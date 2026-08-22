"""Schema-564 source provenance validator."""
from tools.package.source_hash_provenance_v563 import validate_v563 as _validate
def validate_v564(value,label="source_provenance_v564"):
    return [e.replace("563","564") for e in _validate(value)]
