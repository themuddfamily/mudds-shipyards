"""Schema-517 source provenance validator."""
from tools.package.source_hash_provenance_v516 import validate_v516 as _validate
def validate_v517(value,label="source_provenance_v517"):
    return [e.replace("516","517") for e in _validate(value)]
