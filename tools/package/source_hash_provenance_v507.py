"""Schema-507 source provenance validator."""
from tools.package.source_hash_provenance_v506 import validate_v506 as _validate
def validate_v507(value,label="source_provenance_v507"):
    return [e.replace("506","507") for e in _validate(value)]
