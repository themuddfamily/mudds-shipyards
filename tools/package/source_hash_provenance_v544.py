"""Schema-544 source provenance validator."""
from tools.package.source_hash_provenance_v543 import validate_v543 as _validate
def validate_v544(value,label="source_provenance_v544"):
    return [e.replace("543","544") for e in _validate(value)]
