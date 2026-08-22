"""Schema-553 source provenance validator."""
from tools.package.source_hash_provenance_v552 import validate_v552 as _validate
def validate_v553(value,label="source_provenance_v553"):
    return [e.replace("552","553") for e in _validate(value)]
