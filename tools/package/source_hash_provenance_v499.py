"""Schema-499 source provenance validator."""
from tools.package.source_hash_provenance_v498 import validate_v498 as _validate
def validate_v499(value,label="source_provenance_v499"):
    return [e.replace("498","499") for e in _validate(value)]
