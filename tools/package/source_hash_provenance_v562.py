"""Schema-562 source provenance validator."""
from tools.package.source_hash_provenance_v561 import validate_v561 as _validate
def validate_v562(value,label="source_provenance_v562"):
    return [e.replace("561","562") for e in _validate(value)]
