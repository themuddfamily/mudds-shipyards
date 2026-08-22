"""Schema-485 source provenance validator."""
from tools.package.source_hash_provenance_v484 import validate_v484 as _validate
def validate_v485(value,label="source_provenance_v485"):
    return [e.replace("484","485") for e in _validate(value)]
