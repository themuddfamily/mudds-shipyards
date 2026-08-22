"""Schema-495 source provenance validator."""
from tools.package.source_hash_provenance_v494 import validate_v494 as _validate
def validate_v495(value,label="source_provenance_v495"):
    return [e.replace("494","495") for e in _validate(value)]
