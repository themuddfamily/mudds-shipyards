"""Schema-510 source provenance validator."""
from tools.package.source_hash_provenance_v509 import validate_v509 as _validate
def validate_v510(value,label="source_provenance_v510"):
    return [e.replace("509","510") for e in _validate(value)]
