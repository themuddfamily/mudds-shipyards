"""Schema-817 source provenance validator."""


def validate_v817(value, label="source_provenance_v817"):
    """Return schema errors for a v817 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 817:
        return [f"{label}.schema_version must be 817"]
    return []
