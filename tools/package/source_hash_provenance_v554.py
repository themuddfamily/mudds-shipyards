"""Schema-554 source provenance validator."""
from tools.package.source_hash_provenance_v553 import validate_v553 as _validate
def validate_v554(value,label="source_provenance_v554"):
    return [e.replace("553","554") for e in _validate(value)]
