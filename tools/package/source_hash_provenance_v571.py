"""Schema-571 source provenance validator."""
from tools.package.source_hash_provenance_v570 import validate_v570 as _validate
def validate_v571(value,label="source_provenance_v571"):
    return [e.replace("570","571") for e in _validate(value)]
