"""Schema-473 source provenance validator."""
from tools.package.source_hash_provenance_v472 import validate_v472 as _validate
def validate_v473(value,label="source_provenance_v473"):
    return [e.replace("472","473") for e in _validate(value)]
