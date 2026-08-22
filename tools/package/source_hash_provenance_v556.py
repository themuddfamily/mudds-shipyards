"""Schema-556 source provenance validator."""
from tools.package.source_hash_provenance_v555 import validate_v555 as _validate
def validate_v556(value,label="source_provenance_v556"):
    return [e.replace("555","556") for e in _validate(value)]
