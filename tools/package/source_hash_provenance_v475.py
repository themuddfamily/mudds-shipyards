"""Schema-475 source provenance validator."""
from tools.package.source_hash_provenance_v474 import validate_v474 as _validate
def validate_v475(value,label="source_provenance_v475"):
    return [e.replace("474","475") for e in _validate(value)]
