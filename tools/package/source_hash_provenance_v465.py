"""Schema-465 source provenance validator."""
from tools.package.source_hash_provenance_v464 import validate_v464 as _validate
def validate_v465(value,label="source_provenance_v465"):
    return [e.replace("464","465") for e in _validate(value)]
