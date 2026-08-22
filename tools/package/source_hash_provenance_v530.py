"""Schema-530 source provenance validator."""
from tools.package.source_hash_provenance_v529 import validate_v529 as _validate
def validate_v530(value,label="source_provenance_v530"):
    return [e.replace("529","530") for e in _validate(value)]
