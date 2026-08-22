"""Schema-502 source provenance validator."""
from tools.package.source_hash_provenance_v501 import validate_v501 as _validate
def validate_v502(value,label="source_provenance_v502"):
    return [e.replace("501","502") for e in _validate(value)]
