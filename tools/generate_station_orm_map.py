"""Pack the station ORM map from the registered manufactured-paint channels.

Requires numpy and Pillow. Run from the repository root:

    python3 tools/generate_station_orm_map.py

Reads only the three registered maps written by
`tools/generate_ship_finish_maps.py` and writes
`assets/materials/manufactured-paint-orm.png`:

* R, occlusion: a cavity term from the normal map's tilt. The relief is a
  fine isotropic orange peel, so this stays within a few percent of white; it
  gives the grain depth under direct light without painting fictitious seams.
* G, roughness: the registered roughness map, verbatim.
* B, metal mask: near white, falling where the grain is rougher than its mean,
  so bare/clear-coated metal loses a little metalness exactly where it is
  scuffed. Godot multiplies this by each material's own scalar metalness.

No new source image is introduced; the result is deterministic.
"""
from pathlib import Path

import numpy as np
from PIL import Image

MATERIALS = Path("assets/materials")


def generate() -> None:
    normal = np.asarray(Image.open(MATERIALS / "manufactured-paint-normal.png").convert("RGB"), dtype=np.float64) / 255.0
    roughness = np.asarray(Image.open(MATERIALS / "manufactured-paint-roughness.png").convert("L"), dtype=np.float64)

    # The stored Z channel is quantised flat at this relief, so the tilt is read
    # from X/Y about their mean (the 8-bit midpoint is not exactly zero).
    nx = (normal[..., 0] - normal[..., 0].mean()) * 2.0
    ny = (normal[..., 1] - normal[..., 1].mean()) * 2.0
    tilt = np.hypot(nx, ny)
    occlusion = np.clip(1.0 - tilt * 1.6, 0.86, 1.0)

    deviation = (roughness - roughness.mean()) / 255.0
    metal = np.clip(1.0 - deviation * 1.8, 0.84, 1.0)

    packed = np.stack(
        (occlusion * 255.0, roughness, metal * 255.0), axis=-1
    ).round().astype(np.uint8)
    target = MATERIALS / "manufactured-paint-orm.png"
    Image.fromarray(packed, "RGB").save(target)
    print(
        "Packed %s: AO %.3f-%.3f, metal %.3f-%.3f"
        % (target, occlusion.min(), occlusion.max(), metal.min(), metal.max())
    )


if __name__ == "__main__":
    generate()
