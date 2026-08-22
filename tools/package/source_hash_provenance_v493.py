"""Schema-493 source provenance validator."""
from tools.package.source_hash_provenance_v492 import validate_v492 as _validate
def validate_v493(value,label="source_provenance_v493"):
    return [e.replace("492","493") for e in _validate(value)]
