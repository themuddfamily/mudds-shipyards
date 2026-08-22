"""Schema-566 source provenance validator."""
from tools.package.source_hash_provenance_v565 import validate_v565 as _validate
def validate_v566(value,label="source_provenance_v566"):
    return [e.replace("565","566") for e in _validate(value)]
