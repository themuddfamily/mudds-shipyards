"""Schema-477 source provenance validator."""
from tools.package.source_hash_provenance_v476 import validate_v476 as _validate
def validate_v477(value,label="source_provenance_v477"):
    return [e.replace("476","477") for e in _validate(value)]
