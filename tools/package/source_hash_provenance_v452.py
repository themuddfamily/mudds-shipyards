"""Schema-452 source provenance validator."""
from tools.package.source_hash_provenance_v451 import validate_v451 as _validate
def validate_v452(value,label="source_provenance_v452"):
    return [e.replace("451","452") for e in _validate(value)]
