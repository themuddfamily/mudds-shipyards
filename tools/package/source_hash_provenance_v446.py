"""Schema-446 source provenance validator."""
from tools.package.source_hash_provenance_v445 import validate_v445 as _validate
def validate_v446(value,label="source_provenance_v446"):
    return [e.replace("445","446") for e in _validate(value)]
