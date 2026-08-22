"""Schema-453 source provenance validator."""
from tools.package.source_hash_provenance_v452 import validate_v452 as _validate
def validate_v453(value,label="source_provenance_v453"):
    return [e.replace("452","453") for e in _validate(value)]
