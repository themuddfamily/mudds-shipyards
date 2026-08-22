"""Schema-511 source provenance validator."""
from tools.package.source_hash_provenance_v510 import validate_v510 as _validate
def validate_v511(value,label="source_provenance_v511"):
    return [e.replace("510","511") for e in _validate(value)]
