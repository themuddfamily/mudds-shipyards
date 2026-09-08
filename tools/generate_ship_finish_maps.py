"""Bake fleet coating channels (requires numpy and Pillow).

Run from the repository root. Fine paint grain uses analytic seamless fields;
ship coating wear adapts a registered scanned roughness source. Hull seams and
hardware belong to the model, not a tiled grid.
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

    # The scanned painted-steel roughness supplies actual scuffs and rubbed
    # patches. Normalize its useful range as a modulation of each ship's own
    # coating roughness; this is an artistic adaptation, not calibrated scan
    # reflectance. Keep the original 16-bit source intact under art_source.
    source = Path("art_source/materials/blue_metal_plate_rough_1k.png")
    scan = np.asarray(Image.open(source), dtype=np.float64) / 65535.0
    # Use the interior of one painted panel: the scan's actual plate joints
    # must not become miniature fictitious joints on every hull component.
    scan = scan[110:710, 330:750]
    # Remove the smooth boundary mismatch to make the cropped wear field
    # periodic without mirrored scratches or a blurred stripe at tile edges.
    boundary = np.zeros_like(scan)
    boundary[0, :] = scan[-1, :] - scan[0, :]
    boundary[-1, :] = -boundary[0, :]
    boundary[:, 0] += scan[:, -1] - scan[:, 0]
    boundary[:, -1] -= scan[:, -1] - scan[:, 0]
    fy = np.fft.fftfreq(scan.shape[0])[:, None]
    fx = np.fft.fftfreq(scan.shape[1])[None, :]
    laplacian = 2.0 * np.cos(2.0 * np.pi * fx) + 2.0 * np.cos(2.0 * np.pi * fy) - 4.0
    laplacian[0, 0] = 1.0
    smooth = np.fft.fft2(boundary) / laplacian
    smooth[0, 0] = 0.0
    scan -= np.fft.ifft2(smooth).real
    low, high = np.percentile(scan, [5, 95])
    # Retain satin paint between scuffs. The former 0.40 floor turned broad
    # rubbed patches into glossy streaks when multiplied by hull roughness.
    coating = 0.82 + 0.18 * np.clip((scan - low) / (high - low), 0.0, 1.0)
    Image.fromarray(np.rint(coating * 255.0).astype(np.uint8)).save(
        target / "coating-scuff-roughness.png"
    )
    print("Adapted scanned coating scuffs to a 420x600 linear roughness tile.")


if __name__ == "__main__":
    generate()
