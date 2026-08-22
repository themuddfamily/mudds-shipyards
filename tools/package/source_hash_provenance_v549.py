"""Schema-549 source provenance validator."""
from tools.package.source_hash_provenance_v548 import validate_v548 as _validate
def validate_v549(value,label="source_provenance_v549"):
    return [e.replace("548","549") for e in _validate(value)]
