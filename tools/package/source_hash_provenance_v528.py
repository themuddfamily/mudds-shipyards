"""Schema-528 source provenance validator."""
from tools.package.source_hash_provenance_v527 import validate_v527 as _validate
def validate_v528(value,label="source_provenance_v528"):
    return [e.replace("527","528") for e in _validate(value)]
