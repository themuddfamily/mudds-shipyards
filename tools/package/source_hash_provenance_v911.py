"""Schema-911 source provenance validator."""


def validate_v911(value, label="source_provenance_v911"):
    """Return schema errors for a v911 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 911:
        return [f"{label}.schema_version must be 911"]
    return []
