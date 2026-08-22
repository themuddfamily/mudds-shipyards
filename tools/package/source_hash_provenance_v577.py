"""Schema-577 source provenance validator."""
from tools.package.source_hash_provenance_v576 import validate_v576 as _validate
def validate_v577(value,label="source_provenance_v577"):
    return [e.replace("576","577") for e in _validate(value)]
