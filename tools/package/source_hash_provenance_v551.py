"""Schema-551 source provenance validator."""
from tools.package.source_hash_provenance_v550 import validate_v550 as _validate
def validate_v551(value,label="source_provenance_v551"):
    return [e.replace("550","551") for e in _validate(value)]
