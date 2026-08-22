"""Schema-492 source provenance validator."""
from tools.package.source_hash_provenance_v491 import validate_v491 as _validate
def validate_v492(value,label="source_provenance_v492"):
    return [e.replace("491","492") for e in _validate(value)]
