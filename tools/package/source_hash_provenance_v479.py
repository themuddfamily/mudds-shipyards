"""Schema-479 source provenance validator."""
from tools.package.source_hash_provenance_v478 import validate_v478 as _validate
def validate_v479(value,label="source_provenance_v479"):
    return [e.replace("478","479") for e in _validate(value)]
