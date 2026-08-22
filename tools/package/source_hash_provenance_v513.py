"""Schema-513 source provenance validator."""
from tools.package.source_hash_provenance_v512 import validate_v512 as _validate
def validate_v513(value,label="source_provenance_v513"):
    return [e.replace("512","513") for e in _validate(value)]
