"""Schema-565 source provenance validator."""
from tools.package.source_hash_provenance_v564 import validate_v564 as _validate
def validate_v565(value,label="source_provenance_v565"):
    return [e.replace("564","565") for e in _validate(value)]
