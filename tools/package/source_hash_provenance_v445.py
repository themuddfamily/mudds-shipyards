"""Schema-445 source provenance validator."""
from tools.package.source_hash_provenance_v444 import validate_v444 as _validate
def validate_v445(value,label="source_provenance_v445"):
    return [e.replace("444","445") for e in _validate(value)]
