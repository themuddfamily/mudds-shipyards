"""Schema-512 source provenance validator."""
from tools.package.source_hash_provenance_v511 import validate_v511 as _validate
def validate_v512(value,label="source_provenance_v512"):
    return [e.replace("511","512") for e in _validate(value)]
