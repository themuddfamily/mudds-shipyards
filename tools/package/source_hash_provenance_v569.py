"""Schema-569 source provenance validator."""
from tools.package.source_hash_provenance_v568 import validate_v568 as _validate
def validate_v569(value,label="source_provenance_v569"):
    return [e.replace("568","569") for e in _validate(value)]
