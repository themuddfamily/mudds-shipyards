"""Schema-541 source provenance validator."""
from tools.package.source_hash_provenance_v540 import validate_v540 as _validate
def validate_v541(value,label="source_provenance_v541"):
    return [e.replace("540","541") for e in _validate(value)]
