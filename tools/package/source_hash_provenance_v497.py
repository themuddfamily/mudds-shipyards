"""Schema-497 source provenance validator."""
from tools.package.source_hash_provenance_v496 import validate_v496 as _validate
def validate_v497(value,label="source_provenance_v497"):
    return [e.replace("496","497") for e in _validate(value)]
