"""Schema-481 source provenance validator."""
from tools.package.source_hash_provenance_v480 import validate_v480 as _validate
def validate_v481(value,label="source_provenance_v481"):
    return [e.replace("480","481") for e in _validate(value)]
