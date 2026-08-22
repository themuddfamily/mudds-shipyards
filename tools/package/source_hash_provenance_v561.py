"""Schema-561 source provenance validator."""
from tools.package.source_hash_provenance_v560 import validate_v560 as _validate
def validate_v561(value,label="source_provenance_v561"):
    return [e.replace("560","561") for e in _validate(value)]
