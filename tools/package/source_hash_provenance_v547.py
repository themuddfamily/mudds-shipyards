"""Schema-547 source provenance validator."""
from tools.package.source_hash_provenance_v546 import validate_v546 as _validate
def validate_v547(value,label="source_provenance_v547"):
    return [e.replace("546","547") for e in _validate(value)]
