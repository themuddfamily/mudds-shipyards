"""Schema-467 source provenance validator."""
from tools.package.source_hash_provenance_v466 import validate_v466 as _validate
def validate_v467(value,label="source_provenance_v467"):
    return [e.replace("466","467") for e in _validate(value)]
