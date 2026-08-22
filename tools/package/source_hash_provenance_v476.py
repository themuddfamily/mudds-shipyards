"""Schema-476 source provenance validator."""
from tools.package.source_hash_provenance_v475 import validate_v475 as _validate
def validate_v476(value,label="source_provenance_v476"):
    return [e.replace("475","476") for e in _validate(value)]
