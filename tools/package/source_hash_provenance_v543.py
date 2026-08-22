"""Schema-543 source provenance validator."""
from tools.package.source_hash_provenance_v542 import validate_v542 as _validate
def validate_v543(value,label="source_provenance_v543"):
    return [e.replace("542","543") for e in _validate(value)]
