"""Schema-580 source provenance validator."""
from tools.package.source_hash_provenance_v579 import validate_v579 as _validate
def validate_v580(value,label="source_provenance_v580"):
    return [e.replace("579","580") for e in _validate(value)]
