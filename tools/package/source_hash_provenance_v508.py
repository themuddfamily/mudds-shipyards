"""Schema-508 source provenance validator."""
from tools.package.source_hash_provenance_v507 import validate_v507 as _validate
def validate_v508(value,label="source_provenance_v508"):
    return [e.replace("507","508") for e in _validate(value)]
