"""Schema-439 source provenance validator."""
from tools.package.source_hash_provenance_v438 import validate_v438 as _validate
def validate_v439(value,label="source_provenance_v439"):
    return [e.replace("438","439") for e in _validate(value)]
