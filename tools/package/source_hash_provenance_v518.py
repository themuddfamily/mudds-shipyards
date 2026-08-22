"""Schema-518 source provenance validator."""
from tools.package.source_hash_provenance_v517 import validate_v517 as _validate
def validate_v518(value,label="source_provenance_v518"):
    return [e.replace("517","518") for e in _validate(value)]
