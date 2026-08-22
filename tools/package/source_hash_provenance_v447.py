"""Schema-447 source provenance validator."""
from tools.package.source_hash_provenance_v446 import validate_v446 as _validate
def validate_v447(value,label="source_provenance_v447"):
    return [e.replace("446","447") for e in _validate(value)]
