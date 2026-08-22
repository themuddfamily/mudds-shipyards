"""Schema-442 source provenance validator."""
from tools.package.source_hash_provenance_v441 import validate_v441 as _validate
def validate_v442(value,label="source_provenance_v442"):
    return [e.replace("441","442") for e in _validate(value)]
