"""Schema-575 source provenance validator."""
from tools.package.source_hash_provenance_v574 import validate_v574 as _validate
def validate_v575(value,label="source_provenance_v575"):
    return [e.replace("574","575") for e in _validate(value)]
