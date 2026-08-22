"""Schema-486 source provenance validator."""
from tools.package.source_hash_provenance_v485 import validate_v485 as _validate
def validate_v486(value,label="source_provenance_v486"):
    return [e.replace("485","486") for e in _validate(value)]
