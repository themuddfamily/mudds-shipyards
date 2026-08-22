"""Schema-460 source provenance validator."""
from tools.package.source_hash_provenance_v459 import validate_v459 as _validate
def validate_v460(value,label="source_provenance_v460"):
    return [e.replace("459","460") for e in _validate(value)]
