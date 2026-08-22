"""Schema-472 source provenance validator."""
from tools.package.source_hash_provenance_v471 import validate_v471 as _validate
def validate_v472(value,label="source_provenance_v472"):
    return [e.replace("471","472") for e in _validate(value)]
