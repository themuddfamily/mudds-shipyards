"""Bake the original seamless fleet paint finish (requires numpy and Pillow).

Run from the repository root. These are analytic PBR channels, not image-derived
normal maps: fine paint grain and broad roughness variation are deterministic
seamless fields. Hull seams and hardware belong to the model, not a tiled grid.
"""
from pathlib import Path
import numpy as np
from PIL import Image


def generate() -> None:
    size = 512
    rng = np.random.default_rng(81736)
    # Filter white noise in frequency space, with the same radial response in
    # every direction. Positive-only sinusoid frequencies produced diagonal
    # striations that shimmered on oblique plates and read as brushed plastic.
    frequencies = np.fft.fftfreq(size) * size
    fy, fx = np.meshgrid(frequencies, frequencies, indexing="ij")
    radius = np.hypot(fx, fy)

    def noise(low: float, high: float) -> np.ndarray:
        spectrum = np.fft.fft2(rng.standard_normal((size, size)))
        envelope = np.exp(-0.5 * (radius / high) ** 4)
        envelope *= 1.0 - np.exp(-0.5 * (radius / low) ** 4)
        field = np.fft.ifft2(spectrum * envelope).real
        return field / field.std()

    coarse = noise(1.0, 5.0)
    grain = noise(55.0, 170.0)
    # Small, isotropic orange-peel relief. Broad variation belongs in the
    # roughness channel, not displacement or fictitious repeating hull seams.
    height = grain * 0.018
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    normal = np.stack((-dx, -dy, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    albedo = np.clip(244 + coarse * 1.5 + grain * 0.45, 237, 250)
    # Godot multiplies this linear channel by the caller's scalar roughness.
    # Keep it near white so authored paint and metal finish separation survives.
    roughness = np.clip(234 + coarse * 10.0 + grain * 2.0, 211, 254)
    target = Path("assets/materials")
    target.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.repeat(albedo[..., None], 3, axis=-1).astype(np.uint8)).save(target / "manufactured-paint-albedo.png")
    Image.fromarray(((normal * 0.5 + 0.5) * 255).astype(np.uint8)).save(target / "manufactured-paint-normal.png")
    Image.fromarray(roughness.astype(np.uint8)).save(target / "manufactured-paint-roughness.png")
    print("Generated three seamless 512px fleet paint channels.")


if __name__ == "__main__":
    generate()
