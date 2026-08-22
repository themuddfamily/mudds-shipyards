"""Schema-448 source provenance validator."""
from tools.package.source_hash_provenance_v447 import validate_v447 as _validate
def validate_v448(value,label="source_provenance_v448"):
    return [e.replace("447","448") for e in _validate(value)]
