"""Schema-489 source provenance validator."""
from tools.package.source_hash_provenance_v488 import validate_v488 as _validate
def validate_v489(value,label="source_provenance_v489"):
    return [e.replace("488","489") for e in _validate(value)]
