"""Schema-457 source provenance validator."""
from tools.package.source_hash_provenance_v456 import validate_v456 as _validate
def validate_v457(value,label="source_provenance_v457"):
    return [e.replace("456","457") for e in _validate(value)]
