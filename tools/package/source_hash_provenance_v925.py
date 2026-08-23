"""Schema-925 source provenance validator."""


def validate_v925(value, label="source_provenance_v925"):
    """Return schema errors for a v925 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 925:
        return [f"{label}.schema_version must be 925"]
    return []
