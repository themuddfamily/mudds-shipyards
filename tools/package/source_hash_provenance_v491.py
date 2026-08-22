"""Schema-491 source provenance validator."""
from tools.package.source_hash_provenance_v490 import validate_v490 as _validate
def validate_v491(value,label="source_provenance_v491"):
    return [e.replace("490","491") for e in _validate(value)]
