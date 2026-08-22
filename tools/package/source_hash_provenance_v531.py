"""Schema-531 source provenance validator."""
from tools.package.source_hash_provenance_v530 import validate_v530 as _validate
def validate_v531(value,label="source_provenance_v531"):
    return [e.replace("530","531") for e in _validate(value)]
