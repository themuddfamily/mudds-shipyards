"""Schema-484 source provenance validator."""
from tools.package.source_hash_provenance_v483 import validate_v483 as _validate
def validate_v484(value,label="source_provenance_v484"):
    return [e.replace("483","484") for e in _validate(value)]
