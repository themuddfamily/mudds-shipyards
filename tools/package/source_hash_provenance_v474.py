"""Schema-474 source provenance validator."""
from tools.package.source_hash_provenance_v473 import validate_v473 as _validate
def validate_v474(value,label="source_provenance_v474"):
    return [e.replace("473","474") for e in _validate(value)]
