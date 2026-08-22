"""Schema-550 source provenance validator."""
from tools.package.source_hash_provenance_v549 import validate_v549 as _validate
def validate_v550(value,label="source_provenance_v550"):
    return [e.replace("549","550") for e in _validate(value)]
