"""Schema-514 source provenance validator."""
from tools.package.source_hash_provenance_v513 import validate_v513 as _validate
def validate_v514(value,label="source_provenance_v514"):
    return [e.replace("513","514") for e in _validate(value)]
