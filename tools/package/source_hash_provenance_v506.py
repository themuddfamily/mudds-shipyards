"""Schema-506 source provenance validator."""
from tools.package.source_hash_provenance_v505 import validate_v505 as _validate
def validate_v506(value,label="source_provenance_v506"):
    return [e.replace("505","506") for e in _validate(value)]
