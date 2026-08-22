"""Schema-461 source provenance validator."""
from tools.package.source_hash_provenance_v460 import validate_v460 as _validate
def validate_v461(value,label="source_provenance_v461"):
    return [e.replace("460","461") for e in _validate(value)]
