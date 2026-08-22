"""Schema-488 source provenance validator."""
from tools.package.source_hash_provenance_v487 import validate_v487 as _validate
def validate_v488(value,label="source_provenance_v488"):
    return [e.replace("487","488") for e in _validate(value)]
