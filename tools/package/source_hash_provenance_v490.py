"""Schema-490 source provenance validator."""
from tools.package.source_hash_provenance_v489 import validate_v489 as _validate
def validate_v490(value,label="source_provenance_v490"):
    return [e.replace("489","490") for e in _validate(value)]
