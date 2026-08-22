"""Schema-470 source provenance validator."""
from tools.package.source_hash_provenance_v469 import validate_v469 as _validate
def validate_v470(value,label="source_provenance_v470"):
    return [e.replace("469","470") for e in _validate(value)]
