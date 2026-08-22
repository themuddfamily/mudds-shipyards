"""Schema-560 source provenance validator."""
from tools.package.source_hash_provenance_v559 import validate_v559 as _validate
def validate_v560(value,label="source_provenance_v560"):
    return [e.replace("559","560") for e in _validate(value)]
