"""Schema-519 source provenance validator."""
from tools.package.source_hash_provenance_v518 import validate_v518 as _validate
def validate_v519(value,label="source_provenance_v519"):
    return [e.replace("518","519") for e in _validate(value)]
