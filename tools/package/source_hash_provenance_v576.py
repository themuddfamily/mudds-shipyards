"""Schema-576 source provenance validator."""
from tools.package.source_hash_provenance_v575 import validate_v575 as _validate
def validate_v576(value,label="source_provenance_v576"):
    return [e.replace("575","576") for e in _validate(value)]
