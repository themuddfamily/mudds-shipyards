"""Schema-996 source provenance validator."""


def validate_v996(value, label="source_provenance_v996"):
    """Return schema errors for a v996 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 996:
        return [f"{label}.schema_version must be 996"]
    return []
