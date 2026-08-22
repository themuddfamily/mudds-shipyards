"""Schema-435 source provenance validator."""
from tools.package.source_hash_provenance_v434 import validate_v434 as _validate
def validate_v435(value,label="source_provenance_v435"):
    return [e.replace("434","435") for e in _validate(value)]
