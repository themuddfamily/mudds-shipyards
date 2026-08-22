"""Schema-456 source provenance validator."""
from tools.package.source_hash_provenance_v455 import validate_v455 as _validate
def validate_v456(value,label="source_provenance_v456"):
    return [e.replace("455","456") for e in _validate(value)]
