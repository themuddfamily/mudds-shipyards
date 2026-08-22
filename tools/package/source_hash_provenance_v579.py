"""Schema-579 source provenance validator."""
from tools.package.source_hash_provenance_v578 import validate_v578 as _validate
def validate_v579(value,label="source_provenance_v579"):
    return [e.replace("578","579") for e in _validate(value)]
