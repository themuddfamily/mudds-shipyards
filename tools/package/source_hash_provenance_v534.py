"""Schema-534 source provenance validator."""
from tools.package.source_hash_provenance_v533 import validate_v533 as _validate
def validate_v534(value,label="source_provenance_v534"):
    return [e.replace("533","534") for e in _validate(value)]
