"""Schema-427 source provenance validator."""
from tools.package.source_hash_provenance_v426 import validate_v426 as _validate
def validate_v427(value,label="source_provenance_v427"):
    return [e.replace("426","427") for e in _validate(value)]
