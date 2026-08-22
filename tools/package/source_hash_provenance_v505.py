"""Schema-505 source provenance validator."""
from tools.package.source_hash_provenance_v504 import validate_v504 as _validate
def validate_v505(value,label="source_provenance_v505"):
    return [e.replace("504","505") for e in _validate(value)]
