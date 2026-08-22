"""Schema-578 source provenance validator."""
from tools.package.source_hash_provenance_v577 import validate_v577 as _validate
def validate_v578(value,label="source_provenance_v578"):
    return [e.replace("577","578") for e in _validate(value)]
