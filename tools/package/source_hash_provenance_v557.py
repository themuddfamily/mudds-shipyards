"""Schema-557 source provenance validator."""
from tools.package.source_hash_provenance_v556 import validate_v556 as _validate
def validate_v557(value,label="source_provenance_v557"):
    return [e.replace("556","557") for e in _validate(value)]
