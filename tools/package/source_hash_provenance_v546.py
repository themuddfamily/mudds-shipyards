"""Schema-546 source provenance validator."""
from tools.package.source_hash_provenance_v545 import validate_v545 as _validate
def validate_v546(value,label="source_provenance_v546"):
    return [e.replace("545","546") for e in _validate(value)]
