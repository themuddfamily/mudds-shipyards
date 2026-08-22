"""Schema-568 source provenance validator."""
from tools.package.source_hash_provenance_v567 import validate_v567 as _validate
def validate_v568(value,label="source_provenance_v568"):
    return [e.replace("567","568") for e in _validate(value)]
