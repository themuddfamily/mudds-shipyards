"""Schema-522 source provenance validator."""
from tools.package.source_hash_provenance_v521 import validate_v521 as _validate
def validate_v522(value,label="source_provenance_v522"):
    return [e.replace("521","522") for e in _validate(value)]
