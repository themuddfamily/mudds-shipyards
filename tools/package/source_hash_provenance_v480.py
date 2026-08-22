"""Schema-480 source provenance validator."""
from tools.package.source_hash_provenance_v479 import validate_v479 as _validate
def validate_v480(value,label="source_provenance_v480"):
    return [e.replace("479","480") for e in _validate(value)]
