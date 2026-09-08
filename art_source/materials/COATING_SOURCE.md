# Painted-metal roughness

`blue_metal_plate_rough_1k.png` is the unmodified 1K, 16-bit linear roughness
channel from **Blue Metal Plate**, by Rob Tuytel / Poly Haven.

- Asset: https://polyhaven.com/a/blue_metal_plate
- Original file: https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/blue_metal_plate/blue_metal_plate_rough_1k.png
- License: CC0 1.0, https://polyhaven.com/license
- Retrieved: 2026-09-08

`tools/generate_ship_finish_maps.py` crops pixels x=330–749, y=110–709 inside one
panel, then subtracts the smooth boundary mismatch to make a periodic tile
without mirrored scratches. It maps the resulting 5th–95th percentile range
to 0.82–1.00 and writes the 420×600, 8-bit runtime channel
`assets/materials/coating-scuff-roughness.png`. It modulates each ship's existing
coating roughness. The restrained range retains satin paint between scuffs;
the former 0.40 floor produced broad polished streaks on the hulls. This is an
artistic adaptation of the scan, not a claim of calibrated reflectance. Colour,
small paint grain, hull joints and damage remain separate from this surface-wear
channel.
