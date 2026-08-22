"""Schema-537 source provenance validator."""
from tools.package.source_hash_provenance_v536 import validate_v536 as _validate
def validate_v537(value,label="source_provenance_v537"):
    return [e.replace("536","537") for e in _validate(value)]
