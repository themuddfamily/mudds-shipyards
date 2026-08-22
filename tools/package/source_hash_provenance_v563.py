"""Schema-563 source provenance validator."""
from tools.package.source_hash_provenance_v562 import validate_v562 as _validate
def validate_v563(value,label="source_provenance_v563"):
    return [e.replace("562","563") for e in _validate(value)]
