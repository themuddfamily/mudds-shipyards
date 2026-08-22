"""Schema-496 source provenance validator."""
from tools.package.source_hash_provenance_v495 import validate_v495 as _validate
def validate_v496(value,label="source_provenance_v496"):
    return [e.replace("495","496") for e in _validate(value)]
