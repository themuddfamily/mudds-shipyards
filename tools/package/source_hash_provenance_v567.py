"""Schema-567 source provenance validator."""
from tools.package.source_hash_provenance_v566 import validate_v566 as _validate
def validate_v567(value,label="source_provenance_v567"):
    return [e.replace("566","567") for e in _validate(value)]
