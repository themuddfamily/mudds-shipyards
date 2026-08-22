"""Schema-545 source provenance validator."""
from tools.package.source_hash_provenance_v544 import validate_v544 as _validate
def validate_v545(value,label="source_provenance_v545"):
    return [e.replace("544","545") for e in _validate(value)]
