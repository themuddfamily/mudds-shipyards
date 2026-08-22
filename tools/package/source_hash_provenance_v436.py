"""Schema-436 source provenance validator."""
from tools.package.source_hash_provenance_v435 import validate_v435 as _validate
def validate_v436(value,label="source_provenance_v436"):
    return [e.replace("435","436") for e in _validate(value)]
