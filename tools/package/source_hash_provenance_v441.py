"""Schema-441 source provenance validator."""
from tools.package.source_hash_provenance_v440 import validate_v440 as _validate
def validate_v441(value,label="source_provenance_v441"):
    return [e.replace("440","441") for e in _validate(value)]
