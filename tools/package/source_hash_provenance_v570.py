"""Schema-570 source provenance validator."""
from tools.package.source_hash_provenance_v569 import validate_v569 as _validate
def validate_v570(value,label="source_provenance_v570"):
    return [e.replace("569","570") for e in _validate(value)]
