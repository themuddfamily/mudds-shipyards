"""Schema-430 source provenance validator."""
from tools.package.source_hash_provenance_v429 import validate_v429 as _validate
def validate_v430(value,label="source_provenance_v430"):
    return [e.replace("429","430") for e in _validate(value)]
