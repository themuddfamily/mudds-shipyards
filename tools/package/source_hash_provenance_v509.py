"""Schema-509 source provenance validator."""
from tools.package.source_hash_provenance_v508 import validate_v508 as _validate
def validate_v509(value,label="source_provenance_v509"):
    return [e.replace("508","509") for e in _validate(value)]
