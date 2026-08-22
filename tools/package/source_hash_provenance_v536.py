"""Schema-536 source provenance validator."""
from tools.package.source_hash_provenance_v535 import validate_v535 as _validate
def validate_v536(value,label="source_provenance_v536"):
    return [e.replace("535","536") for e in _validate(value)]
