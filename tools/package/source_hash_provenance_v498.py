"""Schema-498 source provenance validator."""
from tools.package.source_hash_provenance_v497 import validate_v497 as _validate
def validate_v498(value,label="source_provenance_v498"):
    return [e.replace("497","498") for e in _validate(value)]
