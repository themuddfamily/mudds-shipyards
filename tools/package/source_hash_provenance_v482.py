"""Schema-482 source provenance validator."""
from tools.package.source_hash_provenance_v481 import validate_v481 as _validate
def validate_v482(value,label="source_provenance_v482"):
    return [e.replace("481","482") for e in _validate(value)]
