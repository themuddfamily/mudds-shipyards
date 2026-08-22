"""Schema-535 source provenance validator."""
from tools.package.source_hash_provenance_v534 import validate_v534 as _validate
def validate_v535(value,label="source_provenance_v535"):
    return [e.replace("534","535") for e in _validate(value)]
