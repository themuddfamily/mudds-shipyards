"""Schema-521 source provenance validator."""
from tools.package.source_hash_provenance_v520 import validate_v520 as _validate
def validate_v521(value,label="source_provenance_v521"):
    return [e.replace("520","521") for e in _validate(value)]
