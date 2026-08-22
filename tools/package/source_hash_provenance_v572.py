"""Schema-572 source provenance validator."""
from tools.package.source_hash_provenance_v571 import validate_v571 as _validate
def validate_v572(value,label="source_provenance_v572"):
    return [e.replace("571","572") for e in _validate(value)]
