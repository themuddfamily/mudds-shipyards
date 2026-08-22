"""Schema-574 source provenance validator."""
from tools.package.source_hash_provenance_v573 import validate_v573 as _validate
def validate_v574(value,label="source_provenance_v574"):
    return [e.replace("573","574") for e in _validate(value)]
