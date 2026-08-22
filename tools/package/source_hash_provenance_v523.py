"""Schema-523 source provenance validator."""
from tools.package.source_hash_provenance_v522 import validate_v522 as _validate
def validate_v523(value,label="source_provenance_v523"):
    return [e.replace("522","523") for e in _validate(value)]
