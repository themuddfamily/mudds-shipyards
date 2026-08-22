"""Schema-559 source provenance validator."""
from tools.package.source_hash_provenance_v558 import validate_v558 as _validate
def validate_v559(value,label="source_provenance_v559"):
    return [e.replace("558","559") for e in _validate(value)]
