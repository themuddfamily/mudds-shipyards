"""Schema-542 source provenance validator."""
from tools.package.source_hash_provenance_v541 import validate_v541 as _validate
def validate_v542(value,label="source_provenance_v542"):
    return [e.replace("541","542") for e in _validate(value)]
