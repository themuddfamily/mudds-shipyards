"""Schema-462 source provenance validator."""
from tools.package.source_hash_provenance_v461 import validate_v461 as _validate
def validate_v462(value,label="source_provenance_v462"):
    return [e.replace("461","462") for e in _validate(value)]
