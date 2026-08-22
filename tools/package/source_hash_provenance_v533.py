"""Schema-533 source provenance validator."""
from tools.package.source_hash_provenance_v532 import validate_v532 as _validate
def validate_v533(value,label="source_provenance_v533"):
    return [e.replace("532","533") for e in _validate(value)]
