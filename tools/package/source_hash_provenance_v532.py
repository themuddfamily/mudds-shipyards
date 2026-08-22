"""Schema-532 source provenance validator."""
from tools.package.source_hash_provenance_v531 import validate_v531 as _validate
def validate_v532(value,label="source_provenance_v532"):
    return [e.replace("531","532") for e in _validate(value)]
