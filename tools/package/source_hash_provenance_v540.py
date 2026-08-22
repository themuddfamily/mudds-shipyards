"""Schema-540 source provenance validator."""
from tools.package.source_hash_provenance_v539 import validate_v539 as _validate
def validate_v540(value,label="source_provenance_v540"):
    return [e.replace("539","540") for e in _validate(value)]
