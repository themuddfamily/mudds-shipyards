"""Bake the original seamless fleet paint finish (requires numpy and Pillow).

Run from the repository root. These are analytic PBR channels, not image-derived
normal maps: millimetre-scale paint grain and broad roughness variation share
one height field. Hull seams and hardware belong to the model, not a tiled grid.
"""
from pathlib import Path
import numpy as np
from PIL import Image


def generate() -> None:
    size = 512
    rng = np.random.default_rng(81736)
    y, x = np.mgrid[:size, :size].astype(np.float64) / size
    coarse = np.zeros_like(x)
    grain = np.zeros_like(x)
    for field, low, high, count in [(coarse, 1, 7, 18), (grain, 35, 140, 64)]:
        for _ in range(count):
            fx, fy = rng.integers(low, high, 2)
            field += np.sin(np.pi * 2 * (fx * x + fy * y) + rng.uniform(0, np.pi * 2))
        field /= np.sqrt(count / 2)
    height = grain * 0.035
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    normal = np.stack((-dx, -dy, np.ones_like(x)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    albedo = np.clip(239 + coarse * 1.8 + grain * 0.65, 227, 247)
    roughness = np.clip(238 + coarse * 4.0 + grain * 3.0, 218, 253)
    target = Path("assets/materials")
    target.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.repeat(albedo[..., None], 3, axis=-1).astype(np.uint8)).save(target / "manufactured-paint-albedo.png")
    Image.fromarray(((normal * 0.5 + 0.5) * 255).astype(np.uint8)).save(target / "manufactured-paint-normal.png")
    Image.fromarray(roughness.astype(np.uint8)).save(target / "manufactured-paint-roughness.png")
    print("Generated three seamless 512px fleet paint channels.")


if __name__ == "__main__":
    generate()
