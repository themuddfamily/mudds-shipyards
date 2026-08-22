"""Schema-429 source provenance validator."""
from tools.package.source_hash_provenance_v428 import validate_v428 as _validate
def validate_v429(value,label="source_provenance_v429"):
    return [e.replace("428","429") for e in _validate(value)]
