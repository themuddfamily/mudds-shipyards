"""Schema-468 source provenance validator."""
from tools.package.source_hash_provenance_v467 import validate_v467 as _validate
def validate_v468(value,label="source_provenance_v468"):
    return [e.replace("467","468") for e in _validate(value)]
