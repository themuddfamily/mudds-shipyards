"""Schema-458 source provenance validator."""
from tools.package.source_hash_provenance_v457 import validate_v457 as _validate
def validate_v458(value,label="source_provenance_v458"):
    return [e.replace("457","458") for e in _validate(value)]
