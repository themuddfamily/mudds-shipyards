"""Schema-953 source provenance validator."""


def validate_v953(value, label="source_provenance_v953"):
    """Return schema errors for a v953 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 953:
        return [f"{label}.schema_version must be 953"]
    return []
