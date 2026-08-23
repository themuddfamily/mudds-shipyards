"""Schema-862 source provenance validator."""


def validate_v862(value, label="source_provenance_v862"):
    """Return schema errors for a v862 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 862:
        return [f"{label}.schema_version must be 862"]
    return []
