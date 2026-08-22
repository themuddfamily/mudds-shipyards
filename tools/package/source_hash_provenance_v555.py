"""Schema-555 source provenance validator."""
from tools.package.source_hash_provenance_v554 import validate_v554 as _validate
def validate_v555(value,label="source_provenance_v555"):
    return [e.replace("554","555") for e in _validate(value)]
