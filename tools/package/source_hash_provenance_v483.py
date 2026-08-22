"""Schema-483 source provenance validator."""
from tools.package.source_hash_provenance_v482 import validate_v482 as _validate
def validate_v483(value,label="source_provenance_v483"):
    return [e.replace("482","483") for e in _validate(value)]
