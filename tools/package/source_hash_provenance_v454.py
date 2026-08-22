"""Schema-454 source provenance validator."""
from tools.package.source_hash_provenance_v453 import validate_v453 as _validate
def validate_v454(value,label="source_provenance_v454"):
    return [e.replace("453","454") for e in _validate(value)]
