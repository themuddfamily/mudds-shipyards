"""Schema-500 source provenance validator."""
from tools.package.source_hash_provenance_v499 import validate_v499 as _validate
def validate_v500(value,label="source_provenance_v500"):
    return [e.replace("499","500") for e in _validate(value)]
