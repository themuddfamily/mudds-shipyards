"""Schema-466 source provenance validator."""
from tools.package.source_hash_provenance_v465 import validate_v465 as _validate
def validate_v466(value,label="source_provenance_v466"):
    return [e.replace("465","466") for e in _validate(value)]
