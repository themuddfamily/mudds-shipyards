"""Schema-432 source provenance validator."""
from tools.package.source_hash_provenance_v431 import validate_v431 as _validate
def validate_v432(value,label="source_provenance_v432"):
    return [e.replace("431","432") for e in _validate(value)]
