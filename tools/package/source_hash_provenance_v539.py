"""Schema-539 source provenance validator."""
from tools.package.source_hash_provenance_v538 import validate_v538 as _validate
def validate_v539(value,label="source_provenance_v539"):
    return [e.replace("538","539") for e in _validate(value)]
