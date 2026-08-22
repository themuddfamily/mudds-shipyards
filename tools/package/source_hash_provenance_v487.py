"""Schema-487 source provenance validator."""
from tools.package.source_hash_provenance_v486 import validate_v486 as _validate
def validate_v487(value,label="source_provenance_v487"):
    return [e.replace("486","487") for e in _validate(value)]
