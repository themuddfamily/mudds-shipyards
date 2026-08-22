"""Schema-527 source provenance validator."""
from tools.package.source_hash_provenance_v526 import validate_v526 as _validate
def validate_v527(value,label="source_provenance_v527"):
    return [e.replace("526","527") for e in _validate(value)]
