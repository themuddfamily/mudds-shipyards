"""Schema-520 source provenance validator."""
from tools.package.source_hash_provenance_v519 import validate_v519 as _validate
def validate_v520(value,label="source_provenance_v520"):
    return [e.replace("519","520") for e in _validate(value)]
