"""Schema-455 source provenance validator."""
from tools.package.source_hash_provenance_v454 import validate_v454 as _validate
def validate_v455(value,label="source_provenance_v455"):
    return [e.replace("454","455") for e in _validate(value)]
