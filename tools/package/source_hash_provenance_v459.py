"""Schema-459 source provenance validator."""
from tools.package.source_hash_provenance_v458 import validate_v458 as _validate
def validate_v459(value,label="source_provenance_v459"):
    return [e.replace("458","459") for e in _validate(value)]
