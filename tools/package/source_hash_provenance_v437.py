"""Schema-437 source provenance validator."""
from tools.package.source_hash_provenance_v436 import validate_v436 as _validate
def validate_v437(value,label="source_provenance_v437"):
    return [e.replace("436","437") for e in _validate(value)]
