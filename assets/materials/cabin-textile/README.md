# Cabin textile

The three unmodified 1024 × 1024 PNG maps are **Fabric069** by ambientCG
(Lennart Demes), created with **photometric stereo**, released 2022-08-28.

- Asset and technique: https://ambientcg.com/view?id=Fabric069
- Original download: https://ambientcg.com/get?file=Fabric069_1K-PNG.zip
- License: **Creative Commons CC0 1.0 Universal**.
- Provider license statement: https://docs.ambientcg.com/license/
- Full legal text: https://creativecommons.org/publicdomain/zero/1.0/legalcode
- Source and license checked 2026-09-08.

CC0 permits copying, modification and redistribution, including raw files in a
commercial game. Original filenames are retained for traceability. Only the
runtime color, OpenGL tangent normal and roughness maps are included; displacement,
DirectX normals and source-provider scene files are not required by this shader.

`CabinTextile.apply` supplies the editable material recipe. The original denim
color is balanced by its mean linear-light RGB in the material multiplier before the authored
ship dye, preserving the scan's thread variation. This does not alter the source
maps. The default tile covers 42 cm, giving approximately millimetre yarn detail;
the blanket uses 62 cm for a coarser twill. This is an authored physical scale,
not a measured sample size claimed by the provider. Object-local triplanar
projection keeps that scale across furniture batches without world-space swim.
Roughness, restrained dielectric specular and a faint grazing fiber rim separate
cloth from surrounding hard liners. No extra geometry or material passes.

All maps use mipmaps and high-quality GPU compression; the normal is imported as
a normal map. Anisotropic filtering retains the weave at grazing angles without
subpixel sparkle. Reapplying the helper retains the original dye metadata.
