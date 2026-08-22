"""Schema-538 source provenance validator."""
from tools.package.source_hash_provenance_v537 import validate_v537 as _validate
def validate_v538(value,label="source_provenance_v538"):
    return [e.replace("537","538") for e in _validate(value)]
