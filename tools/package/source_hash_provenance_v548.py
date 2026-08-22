"""Schema-548 source provenance validator."""
from tools.package.source_hash_provenance_v547 import validate_v547 as _validate
def validate_v548(value,label="source_provenance_v548"):
    return [e.replace("547","548") for e in _validate(value)]
