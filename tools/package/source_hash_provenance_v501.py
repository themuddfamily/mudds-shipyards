"""Schema-501 source provenance validator."""
from tools.package.source_hash_provenance_v500 import validate_v500 as _validate
def validate_v501(value,label="source_provenance_v501"):
    return [e.replace("500","501") for e in _validate(value)]
