"""Schema-529 source provenance validator."""
from tools.package.source_hash_provenance_v528 import validate_v528 as _validate
def validate_v529(value,label="source_provenance_v529"):
    return [e.replace("528","529") for e in _validate(value)]
