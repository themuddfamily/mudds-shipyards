# Asset register

## Zenith B7 evidence and project-original runtime assets

The B7-observed Zenith implementation adds no source media or derived historical
asset to the repository. The exact inspected public rendition is registered only
by metadata and SHA-256
`c716c506d9fd7042ac98720e8815725cf083d24967bc8c9f842cdfa58e8ca144`
in [`docs/research/source_ledger.json`](docs/research/source_ledger.json); the
video and every extracted screenshot/frame remain untracked and must not be
bundled or shipped. Permission and redistribution rights are not recorded.

[`docs/ZENITH_B7_RECONSTRUCTION_SPEC.md`](docs/ZENITH_B7_RECONSTRUCTION_SPEC.md)
is the written evidence/art constraint, not an asset licence, source model,
texture, concept image or authentication record. Only the bounded pale wide-
delta/arrow macroform, raised central wedge/spine, long strakes, repeated simple
subdivisions and cautiously indexed pod-like forms may be claimed as B7-directed.
The upload date does not date the recording or game build, the A5/B7 Interceptor
versus A9 Fighter conflict remains unresolved, and exact construction, scale,
access, materials, systems, handling and berth placement remain modern or
unknown. On 2026-08-15 the runtime hull tint moved from `#e6e2d5` to `#bac8d6`
under the fleet readability palette recorded further down this register; that is
a modern swatch change inside the observed pale read, and it neither adds nor
weakens any B7 claim.

### `art_source/zenith/zenith_authored_v1.blend`

- Purpose: editable source for the accepted bounded B7-observed Zenith partial
  reconstruction, with the recognition-bearing `SourceCore` separable from the
  project-original `ModernSystems` hierarchy.
- Created with the deterministic project generator
  `tools/blender/generate_zenith_authored_v1.py` under Blender 4.0.2.
- Authorship: original script-assisted Blender work. No source pixels, source
  meshes, Roblox assets, or extracted third-party geometry are redistributed.
- Size: 4,303,884 bytes. SHA-256:
  `33a29154bb0028cd8494506ef874a2cb6d44e82fb8738cfc0c227ae0dec44712`.
- The metre envelope is a modern ergonomic normalization. Pod-like source-core
  forms retain unknown historical function; the cockpit, canopy, engine
  internals, exhaust, weapons, landing gear, boarding aids, docking hardware,
  materials, damage anchors and handling presentation are modern additions.

### `assets/models/zenith/zenith_authored_art.glb`

- Purpose: presentation-only imported Zenith art used through
  `scenes/ships/presentation/zenith_authored_presentation.tscn`.
- Size: 1,968,948 bytes. SHA-256:
  `d22f26152b275e6d295c9de36968c08af0f83f55af7942b93818924dca789476`.
- The close/far whole-ship levels contain 47,274 / 5,412 triangles. Runtime
  batching exposes 22 meshes and 22 surfaces across ten material roles. The GLB
  owns no gameplay or collision authority.

### `assets/models/zenith/zenith_authored_asset_manifest.json`

- Purpose: machine-readable authorship, evidence-scope, SourceCore/ModernSystems,
  mesh/material, anchor, whole-ship LOD, and non-authoritative collision-proposal
  record for `mudds.ship.zenith.b7_authored.v1`.
- SHA-256:
  `3264eee6c3e2af4c7494545d0cfeeb2806c465445e10a997eee6a1bf4e4c15fa`.
- It pins B7 frames `f373–f467`, excludes `f468+`, records that dimensions are
  modern normalization, and marks source pixels/geometry as not redistributed.
  The authoritative runtime instead owns an independently hard-coded 24-shape
  mixed collision contract; passing its art and gameplay audits does not
  authenticate historical geometry.

### Zenith definition and runtime wrappers

- `assets/ships/zenith_b7_observed.tres` defines the deliberately versioned
  `zenith_b7_observed` partial reconstruction and its modern agile-interceptor
  balance; those numeric values are not recovered B7 handling.
- `scenes/ships/zenith_interceptor.tscn` and
  `scripts/ships/zenith_interceptor.gd` own collision, flight, boarding, damage,
  weapons, audio and docking authority independently of the presentation GLB.
- `scenes/ships/presentation/zenith_authored_presentation.tscn` keeps imported
  authored art presentation-only. The world-owned Fleet Dock berth and its
  placement are modern and are not a historical class-to-berth claim.

## `art_source/station/central_berth_hero_v1.blend`

- Purpose: editable Blender source for the presentation-only central Torrent
  berth shell. It replaces the old runtime-primitive pad inset, fascia and
  trusses while the existing Godot walking floor, berth, clamps, utilities,
  lights and route collision remain authoritative.
- Created: 2026-08-13 with the deterministic project generator
  `tools/blender/generate_central_berth_hero_v1.py` under Blender 4.0.2.
- Authorship: original script-assisted Blender work. It is a modern design, not
  recovered Roblox geometry and not evidence of the historical station layout.
- Contract: 111 editable components grouped under the exact semantic roots
  `deck_panels`, `edge_fascia`, `primary_structure`, `secondary_structure`, and
  `service_channels`; five material roles; 8 runtime static batches/surfaces;
  5,976 vertices; 11,508 triangles; exact Godot-space bounds
  `(-12.75, -2.58, -27.75)` to `(12.75, 0.095, 7.75)`.
- Runtime: `assets/models/station/central_berth_hero_v1.glb`, mounted at identity
  by `CentralBerthHeroPresentation`. `DeckComposite` binds the registered
  shipyard-deck albedo/normal/roughness through authored UV0; triplanar mapping
  is disabled. Upward faces use a canonical non-mirrored 7 m tile basis; the
  live imported top has 190 non-degenerate samples, p95/max anisotropy
  `1.048`/`1.069`, and 2.93% maximum density deviation. The imported subtree
  contains no collision, body, area, camera, audio, navigation or
  walking-surface authority.
- Final SHA-256: generator
  `d27b0a615b645f0885a083e53320ab4c8f76ead19fcc592bc2c92fc52a3b74d1`;
  Blend `29b6a145ed8041b9018d3d4e0855e07ee86462617722f9772211cf322804e80b`;
  GLB `c4eb42c2b8e70f5f5e6d05542e823797705cdd8c94db9b3963a3148529014836`;
  manifest `9f6aab53f202e9eebc8487ce1b8753584d8a42a40c241b14f2237d1f5640e004`.


## `assets/effects/mudds-combat-vfx-atlas-v1.png`

- Purpose: project-original, tintable presentation atlas for the shared Mudds
  Shipyards pulse, muzzle and endpoint-impact renderer. The four equal cells are
  a forward pulse/head, an energetic impact, a reserved explosion study, and a
  shock ring. The current runtime uses only the pulse and impact cells; the
  explosion and ring cells are retained as visual development rather than
  claimed as integrated destruction effects.
- Created: 2026-08-13 with OpenAI's built-in image generation tool.
- SHA-256:
  `e748314a287112a11f809b417fa262b184199715f029b0915b63ca8ccecd3aac`.
- Project status: modern project-original imagegen output; not sourced from
  Roblox, the original Keth Shipyards, or third-party artwork. The neutral
  white/grey energy shapes are intentionally tinted by the runtime's cyan,
  amber and magenta style contract. This is a presentation texture, not
  historical evidence for any original weapon effect.
- Final prompt (verbatim):

> Use case: game-asset. Asset type: transparent-background, tintable grayscale 2x2 VFX sprite atlas for a Godot 4 real-time 3D game. Create exactly four equal square cells with no dividers and generous transparent padding: top-left a compact forward-stretched white energy pulse with a hard brilliant core and soft layered halo; top-right a radial white impact flash with a crisp centre, partial shock ring and eight tapered outward streaks; bottom-left a layered white energy explosion with bright core, irregular expanding front and wispy smoke-like outer breakup; bottom-right a clean expanding circular shock ring with a soft falloff. Neutral white and pale grey only so every cell can be multiplied by cyan, amber or magenta at runtime. Premium modern arcade science-fiction game VFX, readable at small screen size, strong silhouette, smooth antialiased alpha, physically plausible falloff but stylised and powerful. Orthographic sprite treatment, each effect centred in its cell except the top-left pulse which points exactly to the right. Transparent background; no black matte, no stars, no environment, no UI, no text, no letters, no numbers, no logos, no watermark, no colored pixels, no hard rectangular cell edges, no lens-flare photography, no copied franchise effects.

## `assets/concepts/torrent/torrent-hero-concept-multiview-v1.png`

- Purpose: project-original, four-view visual-development reference for the
  Blender close-range Torrent hero pass. It is a design target only: the image
  is not sampled into runtime materials, converted into geometry, or treated as
  an orthographic source of exact dimensions.
- Created: 2026-08-13 with OpenAI's built-in image generation tool.
- SHA-256:
  `673bf61d3c2875ec2358b622c1410d46fb766426303f7e34fcf83716b2e05318`.
- Project status: modern project-original concept art. It is not sourced from
  Roblox or the original Keth Shipyards and is not historical evidence for the
  B5-linked Torrent. Its panel layout, engine construction, cockpit shell,
  landing gear, boarding hardware, weapons, materials and surface detail are
  modern design proposals. Although the four views are visually coherent, the
  generated sheet is not a dimensionally exact turntable and must not be used
  as an authenticated reconstruction or a final production-art claim.
- Evidence-date note: B5 was uploaded in June 2011, but its recording date and
  live build revision are unverified. The `dated-2011` wording preserved only
  inside the verbatim generation prompt below was project shorthand, not a
  verified date; current public provenance uses `b5_observed_name_to_model`.
- Final prompt (verbatim):

> Use case: stylized-concept
> Asset type: project-original orthographic concept sheet for a hard-surface 3D modelling guide; reference-only, not a game texture
> Primary request: design a cohesive modern-studio reinterpretation of the compact dated-2011 Torrent interceptor described below, shown as the SAME spacecraft in four clearly separated views: front three-quarter, true side profile, true dorsal/top, and true aft. Maintain exact identity across views.
> Scene/backdrop: clean neutral warm-grey industrial design-sheet background, no environment, no stars, no dramatic scenery
> Subject: a compact 8.4 m long by 7.2 m wide single-seat arcade spacecraft with a pointed low faceted nose, raised central spine, blunt blocky aft, four stepped horizontal side-plane tiers, two subordinate round aft housings, and two tall dominant pale aft rails connected by a short crossbar. Central openable neutral-glass canopy around a visible crimson pilot seat. Modern interpretation adds credible recessed twin engine machinery, restrained pulse cannons, tricycle landing gear with visible load paths, docking receiver, RCS clusters, service panels, vents, reachable port boarding steps and handhold. Preserve broad clean colourful Keth-like silhouette; do not make it generic military sci-fi.
> Style/medium: polished high-end stylised hard-surface spacecraft concept, believable production modelling callout quality, clean readable forms, subtle bevels, weighted-normal broad panels, three scales of detail, 3D product-design render rather than painterly art
> Composition/framing: four evenly sized views on one 16:9 sheet, full craft visible and uncropped in every view, consistent orthographic scale, generous separation, no perspective ambiguity for profile/top/aft
> Lighting/mood: neutral studio lighting revealing form and material roughness, no dramatic bloom, no crushed blacks
> Color palette: at least 70% warm off-white hull, restrained dark graphite mechanical recesses, small cyan livery/status accents only, crimson pilot seat, small amber unknown-function forward panel
> Materials/textures: clean dielectric painted hull, graphite machinery, neutral canopy glass, rubber seals, exposed alloy; coherent panel seams and sparse decals; no image-projected faux relief
> Constraints: recognizable compact pointed wedge + raised spine + blocky aft + four stepped side planes + paired round housings + dominant U-like aft rails in all views; aft must have credible depth and machinery; landing gear must look mechanically supported; boarding hardware must be reachable; canopy and cockpit must be ergonomic; no text labels required; no watermark
> Avoid: broad blank slabs, giant featureless aft wall, separate-looking cyan shell, thick rectangular canopy cage, nested torus engines, primitive boxes/cylinders, excessive greebles, grey militarism, organic curves, wings like a modern jet, huge glowing spheres, copied franchise designs, logos, text, watermark

## `assets/models/torrent/textures/torrent-hero-trim-albedo-v1.png`

- Purpose: project-original visual source for an intentional UV trim atlas on the
  modern Torrent hero presentation. The 1254 x 1254 source is preserved exactly
  at SHA-256
  `21536687fe1b5b7ddba305f696d1e7a53f29bd14774db3ec1411af12b6622b76`.
- Created: 2026-08-13 with OpenAI's built-in image generation tool.
- Project status: modern project-original imagegen output; not sourced from
  Roblox or the original Keth Shipyards, and not historical evidence for the
  B5-linked Torrent. Its plate layout, livery, wear, cyan accents and material
  response are modern visual interpretation.
- Actual-output classification: despite the prompt's requested flat and seamless
  result, the image visibly contains bevel-like highlights, shadow/AO-like edge
  darkening and strong apparent relief. Its opposite edges have not been verified
  seamless. It is therefore used only as an intentionally mapped UV trim atlas,
  not as a repeating tile, neutral scan, or historical surface reconstruction.
- Final prompt (verbatim):

> Use case: stylized-concept
> Asset type: seamless square albedo texture for the hero spacecraft hull in a Godot game
> Primary request: create a production-quality, perfectly tileable painted spacecraft hull panel texture for the Keth Torrent hero craft, a modern interpretation of a colorful early-2010s arcade sci-fi vehicle
> Style/medium: orthographic PBR albedo texture sheet, clean stylized sci-fi, authored game texture, not a beauty render
> Composition/framing: straight-on flat square material swatch, edge-to-edge seamless tiling, medium-scale panel layout with broad ivory-white painted alloy plates, restrained graphite seams, sparse warm red identification bands and tiny cyan maintenance accents; no single central emblem
> Lighting/mood: pure flat albedo color only, completely unlit, no cast shadows, no highlights, no ambient occlusion baked into color
> Materials/textures: painted metal with subtle wear concentrated on panel edges, sparse micro-scratches and maintenance markings, coherent plate scale suitable for a compact fighter; readable but not noisy
> Constraints: seamless on all four edges; no words, letters, numbers, logos, watermarks, perspective, objects, spacecraft silhouette, bolts at tile boundaries, gradients caused by lighting, or photographic background; preserve a bright colorful arcade-readable palette; square image
> Avoid: dark military camouflage, photoreal studio lighting, grunge overload, text-like glyphs, UI, concept-art framing

## `assets/models/torrent/textures/torrent-hero-flat-albedo-study-v1.png`

- Purpose: project-original 1254 x 1254 material study created by editing the
  trim source toward flatter base colour. The source is preserved exactly at
  SHA-256
  `c480681c5c94ca7baa01668127f0084e61adbf86e8c3826dbe208b7f8c81f063`.
- Created: 2026-08-13 with OpenAI's built-in image generation tool.
- Project status: modern project-original imagegen output; not sourced from
  Roblox or the original Keth Shipyards, and not historical evidence. The study
  is not selected for the runtime hero material.
- Actual-output classification: it is flatter than the trim source but its seam
  status remains unverified, and the requested broad warm-red bands are absent.
  It remains a material study rather than a seamless or runtime-authoritative
  albedo.
- Final edit prompt (verbatim):

> Edit the generated spacecraft hull texture into a true flat PBR base-color/albedo map. Preserve the same broad ivory panel layout, restrained graphite seams, sparse warm red bands, and tiny cyan maintenance accents, but remove every bevel highlight, cast shadow, ambient-occlusion shadow, specular highlight, embossed depth illusion, and lighting gradient. Panels should read through clean flat color boundaries and very subtle pigment/wear variation only. Make the left and right edges and the top and bottom edges visually seamless for tiling; remove motifs cut awkwardly at boundaries or continue them perfectly across the opposite edge. Reduce small busy detail by about 30 percent. Keep it square, orthographic, edge-to-edge, bright and arcade-readable. No text, letters, numbers, logos, watermark, perspective, objects, or ship silhouette.

## Torrent hero runtime texture derivatives

`tools/generate_material_maps.gd` deterministically creates these 1024 x 1024
runtime assets on 2026-08-13 while preserving both 1254 x 1254 imagegen sources:

- `assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png`
  (`17ccc04b8e641b4890cbacb7842b2fb24e2bbbbd00a7628fc5d9fa86c1b74b12`)
- `assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png`
  (`c86817d88739b85835efd8626a2ce2c540620fa8a0af985e4bc5384d1599e357`)
- `assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png`
  (`57255d680fc060dd74a040f3bea27d55e9e93dba35f42985ada956f92bacfa42`)
- `assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png`
  (`8f754d93a36b12eb6a031c8c9675da6e54591844c5582fee1063d6d3b523b2cd`)
- `assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png`
  (`398be72d094af6a429d9f06ec7eeeb855850b9873648d2d2f70e6b85e47cbd69`)
- `assets/models/torrent/textures/torrent-hero-flat-albedo-study-runtime-v2.png`
  (`f2305695d1b6f924da73be35b4d3a9aec3e5702fb36b4346a920ae29f60fae6e`)

The trim albedo and flat study are deterministic Lanczos runtime-size copies.
The other four maps remain exactly pixel-registered to the resized trim atlas.
The tangent-space normal records restrained luminance-gradient cues already
visible in the source; it does not recover geometry. Roughness is a bounded
image-derived material proxy. The packed ORM stores neutral AO (`R = 1`), that
same registered roughness (`G`), and non-metal (`B = 0`) rather than inventing
occlusion or metalness from colour. The optional emissive map isolates only the
sparse cyan accents; it is a modern opt-in lighting interpretation, not evidence
that those marks emit light. Atlas-border sampling is clamped, never wrapped,
because the trim is deliberately classified non-tileable. None of these assets
is a high/low geometry bake, measured scan, recovered historical texture, or
final authored PBR material set.

## Symmetric station triplanar PBR set

`tools/generate_material_maps.gd` deterministically creates this 512 x 512
station-only material set:

- `assets/materials/procedural-panel-triplanar-albedo-v2.png`
  (`5477c96d6270815e87ddd7d394e15915d2848aa388615a6d595f0fc668e705c1`)
- `assets/materials/procedural-panel-triplanar-normal-v2.png`
  (`a55957b6ea2a90c5d2e82f7ed579dcd59b34ebc534714c41b262a18bbd2e9fcd`)
- `assets/materials/procedural-panel-triplanar-roughness-v2.png`
  (`b35de83ad27917dbb99c42decd828ac76569b09db797916c814a7ca114e6eb6f`)

Purpose: replace the directional Arrow ship atlas formerly projected onto the
Aft Junction, Habitat and Jovian freight-berth floors, walls and stairs. The
new scalar layout is exactly invariant under horizontal/vertical reflection and
90-degree rotation, repeats continuously at every border, and contains only
isotropic seams, concentric service rings and four-way fasteners. Its grayscale
albedo has no preferred lighting direction. Physical relief is carried by the
registered normal map, whose import sidecar performs the image-row-to-Godot
tangent-Y conversion; roughness is a bounded matched scalar map. Station
materials use continuous world triplanar projection while retaining their
existing physical scales and colours.

Coverage extension (2026-08-15, no new asset bytes): the same three registered
files are now also bound to the walked-on overlay surfaces that previously sat
unmapped on top of mapped station floors — the Aft Junction continuous stair
ramp and its nine operations-room floor pressure plates at the module's existing
0.30 scale, and the Habitat connector inset, corridor walking lane and
observation-common floor inset at the module's existing 0.28 scale. Only the
material bindings changed; no geometry, collision, walkable-surface roster,
route marker, module contract, texture byte, physical scale or albedo colour was
altered, and the identically coloured structural beams, frames, vents, trim,
glass and emissive accents stay deliberately unmapped. Live station coverage
therefore moves from 507 to 520 mapped surfaces (11 at 0.22, 265 at 0.28, 244 at
0.30), re-frozen in `tests/station_triplanar_material_test.gd`.

Authorship: project-original fixed-recipe procedural raster work created locally
on 2026-08-14. It uses no image-generation source, source-game pixels, recovered
historical texture, photographed scan, third-party artwork or ship atlas. It is
a modern station presentation material and does not authenticate historical
surface construction. Arrow, Jovian, Torrent and Zenith retain their separately
registered ship-specific material identities; this symmetric set is not bound
to those ships.

## `assets/materials/cockpit-anti-glare-composite-v1.png`

- Purpose: original low-contrast woven-composite albedo for the Torrent's modern
  anti-glare instrument hood and cockpit trim. It is intended to improve depth
  and legibility without baking lighting or interface graphics into the surface.
- Created: 2026-08-13 with OpenAI's built-in image generation tool.
- Project status: newly generated project asset; not sourced from Roblox or the
  original Keth Shipyards. The weave, finish, scale and cockpit application are
  modern interpretation rather than historical evidence.
- Final prompt:

> Use case: stylized-concept. Asset type: seamless square albedo texture for a
> Godot spacecraft cockpit interior. Create a seamless tileable top-down
> material texture for a high-end stylised science-fiction cockpit anti-glare
> composite panel, realistic-looking but clean and readable. Physically
> plausible PBR albedo source under completely neutral diffuse illumination,
> with no baked highlights, shadows, glow, vignette or directional lighting.
> Very dark desaturated navy-charcoal, subtle cool graphite fibres and sparse
> restrained warm-grey micro-speckle. Fine woven composite grain, subtle molded
> polymer variation, extremely restrained wear. Perfectly seamless on all four
> edges. No text, letters, numerals, symbols, logos, decals, UI, screens,
> fasteners, borders, watermark, military camouflage, heavy damage, bright cyan
> or amber glow.

## `assets/materials/jovian-hull-albedo-v1.png`

- Purpose: original warm pearl-grey cargo-spacecraft panel albedo used by the
  provisional Jovian light freighter. Its larger service hatches and restrained
  teal/amber inspection marks distinguish the freighter from the Arrow's small
  ceramic-composite pattern. The image itself is unchanged; since 2026-08-15 the
  runtime multiplies it by the warm clay-sand fleet readability tint recorded
  above, so the rendered freighter hull is warmer and deeper than this swatch
  alone.
- Created: 2026-08-12 with OpenAI's built-in image generation tool.
- Project status: newly generated project asset; not sourced from Roblox or the
  original Keth Shipyards. The material is a modern, provisional visual design.
- Final prompt:

> Use case: stylized-concept. Asset type: seamless tileable base-color texture
> for a realistic high-end Godot 4 light-freighter hull material. Create an
> original square orthographic material swatch for the provisional Jovian-class
> light freighter: large warm pearl-grey aerospace composite panels sized for a
> medium cargo spacecraft, with inset maintenance hatches, narrow dark structural
> seams, flush fasteners, subtle layered paint variation, restrained abrasion
> around service edges, and sparse muted teal and amber inspection markings.
> Realistic-stylised AAA hard-surface game material; physically plausible painted
> composite and metal construction; clean optimistic civilian shipyard aesthetic.
> Perfectly front-facing, edge-to-edge, visually seamless at every edge, neutral
> diffuse material-reference illumination, no baked directional shading. No text,
> letters, numbers, symbols, logos, watermark, objects, ship silhouette, horizon,
> dramatic lighting, reflection, battle damage, rust, heavy grime, black greeble
> clutter, obvious repeated medallions, or franchise styling.

## `assets/materials/shipyard-deck-albedo-v1.png`

- Purpose: original blue-grey operational deck and structural-cladding albedo
  used with its derived normal and roughness maps on the central Torrent hero
  berth's top skin. Wider station surfaces have not yet received this treatment.
- Created: 2026-08-12 with OpenAI's built-in image generation tool.
- Project status: newly generated project asset; not sourced from Roblox or the
  original Keth Shipyards. Its panel dimensions, wear, fasteners and safety
  inlays are modern/provisional rather than historical evidence.
- Final prompt:

> Use case: stylized-concept. Asset type: seamless tileable base-color texture
> for a realistic high-end Godot 4 orbital shipyard deck and structural cladding
> material. Create an original square orthographic swatch of medium blue-grey
> painted metal/composite deck plates with human-scale rectangular service
> panels, fine recessed seams, flush bolts, anti-slip microtexture, narrow
> maintenance channels, sparse edge scuffing, and restrained cyan and amber
> safety-inlay fragments. Realistic-stylised AAA hard-surface material with an
> optimistic, readable late-2000s science-fiction identity modernised for a
> current PC game. Perfectly front-facing, edge-to-edge, visually seamless,
> neutral diffuse material-reference lighting. No text, letters, numbers, arrows,
> symbols, logos, watermark, scenery, silhouettes, dramatic lighting, reflection,
> battle damage, rust, heavy grime, black greeble overload, or franchise styling.

## Registered derived material maps

The following maps are deterministic derivatives of their correspondingly named
project-original albedo swatches and remain exactly registered to those layouts:

- `assets/materials/torrent-hull-normal-v1.png`
- `assets/materials/torrent-hull-roughness-v1.png`
- `assets/materials/arrow-hull-normal-v1.png`
- `assets/materials/arrow-hull-roughness-v1.png`
- `assets/materials/jovian-hull-normal-v1.png`
- `assets/materials/jovian-hull-roughness-v1.png`
- `assets/materials/shipyard-deck-normal-v1.png`
- `assets/materials/shipyard-deck-roughness-v1.png`

They were originally generated locally by the v1 implementation of
`tools/generate_material_maps.gd` on 2026-08-12. The v2 hero-material pass
validates every existing derivative against its registered hash and leaves it
byte-identical. On a clean checkout it can reproduce a missing derivative with
the retained v1 recipe, but it refuses to overwrite a present mismatched file.
The normal maps encode shallow luminance-gradient relief, and the roughness maps
encode restrained local contrast around seams and hardware. They are an interim
procedural-prototype material aid, not high/low-poly bakes, measured material
scans, or final hand-authored ORM sets. The original v1 pass deliberately wrapped
its samples at every edge so those legacy derivatives preserve their source tile
boundaries; the non-tileable Torrent hero atlas instead uses clamped borders.

## Fleet readability palette (runtime scalar tints)

- Purpose: separate the four flyable craft by colour so at-a-glance
  identification does not rest on silhouette and scale alone. Before this pass
  all four shared one near-white body tone whose closest pair measured CIEDE2000
  0.82 in normal vision and 0.45 under simulated deuteranopia — below the
  just-noticeable difference — while the Arrow/Jovian/Zenith identification
  accents clustered in cyan-teal at 6.40 under simulated protanopia.
- Created: 2026-08-15. These are **hand-picked scalar `albedo_color` values
  chosen by numeric search against the CIEDE2000 and Viénot 1999 dichromat
  maths in `tests/fleet_colour_metrics.gd`**. They are not authored artwork, not
  baked, not scanned, not sampled from any source recording, and no new image
  asset was produced for them. No hull albedo, normal or roughness map changed;
  each craft's bound map is multiplied by the new tint at runtime.
- Project status: modern project-original visual design. It authenticates
  nothing and raises no `name_to_model_status`.

| Craft | Body tone before | Body tone after | Accent before | Accent after | Defined in |
| --- | --- | --- | --- | --- | --- |
| Torrent | `#e8e2cf` | `#e8e2cf` (unchanged) | `#f0b94d` | `#f0b94d` (unchanged) | `scenes/ships/presentation/torrent_hero_presentation.gd`, `scripts/ships/hero_ship.gd` |
| Zenith | `#e6e2d5` | `#bac8d6` | `#c9dee0` | `#2f5fbe` | `scenes/ships/presentation/zenith_authored_presentation.gd`, `scenes/ships/zenith_interceptor.tscn` |
| Arrow | `#e9eee9` | `#7891ab` | `#45dee6` | `#45dee6` (unchanged) | `scripts/ships/arrow_recon_ship.gd` |
| Jovian | `#e7e4d6` | `#e0ab74` | `#38bdb5` | `#b32620` | `scripts/ships/jovian_light_freighter.gd`, `scenes/ships/jovian_light_freighter.tscn` |

The subordinate hull tone of each changed craft moved with its primary so the
primary stays the brightest large surface: Arrow `CERAMIC` `#c7d2ce` →
`#66798d`, Jovian `HULL_COOL` `#bbc8c5` → `#bd9270`, Zenith
`PaleFacetSecondary` `#aeb1aa` → `#97a3ad`.

Evidence boundary observed for each craft, checked against
`docs/research/ship_evidence_matrix.json` and the two reconstruction
specifications rather than assumed:

- **Torrent — bounded, so unchanged.** `docs/TORRENT_2011_RECONSTRUCTION_SPEC.md`
  registers a source-observed exterior palette of "high-value low-saturation
  off-white/light grey across all silhouette-defining masses" and requires at
  least about 70% of the source-core exterior to stay pale and low-saturation.
  Its warm ivory and warm gold were therefore left exactly as they were, and the
  Torrent hero Blender asset and its baked derivatives are untouched.
- **Zenith — bounded, but only in relative value.** The B7 source core records a
  "pale width-dominant full-delta/arrow planform", and
  `docs/ZENITH_B7_RECONSTRUCTION_SPEC.md` states B7 "supports relative value,
  not an exact albedo swatch, paint system, reflectance or weathering level" and
  explicitly does not establish "exact colours, materials, PBR response". The
  new `#bac8d6` is a pale light-grey at L\* 79.96, so the observed pale read is
  preserved while the exact swatch — which no source establishes — moves off the
  fleet's shared warm ivory. Its identification accent is modern systems detail
  under the same specification.
- **Arrow — unbounded.** `docs/research/ship_evidence_matrix.json` records
  `name_to_model_status: unknown` for Arrow and lists "palette" among its
  unknowns; ROADMAP Phase 4 states no Arrow colours are authenticated. The
  palette is modern design and freely changeable.
- **Jovian — unbounded.** Same record: `name_to_model_status: unknown`, with
  "palette" among its unknowns, and ROADMAP Phase 4 states every current Jovian
  colour remains modern interpretation.

Achieved separation, measured from the running production Main scene under all
four vision models and frozen as floors in
`tests/fleet_role_differentiation_test.gd`:

| Vision model | Body-tone minimum CIEDE2000 | Accent minimum CIEDE2000 |
| --- | --- | --- |
| normal | 16.95 | 42.57 |
| protanopia | 16.62 | 37.38 |
| deuteranopia | 16.91 | 31.38 |
| tritanopia | 17.45 | 34.19 |

The frozen floors are 12.0 for body tones and 25.0 for accents. The body-tone
figure is capped by the evidence boundary, not by taste: with Torrent's warm
ivory fixed and Zenith required to stay pale, that pair cannot be separated
further without contradicting a registered source observation.

## `assets/materials/arrow-hull-albedo-v1.png`

- Purpose: original warm ceramic-composite panel albedo used by the provisional
  Arrow recon craft through triplanar PBR treatments. It is a ship-specific
  atlas and is no longer projected onto any station structure: the Aft Junction
  and Habitat pressure shells that once borrowed it moved to the symmetric
  station triplanar PBR set above, and
  `tests/station_triplanar_material_test.gd` asserts that no live station
  surface reuses this directional atlas. The image itself is unchanged; since
  2026-08-15 the runtime multiplies it by the slate-blue fleet readability tint
  recorded above, so the rendered recon hull is cooler and deeper than this
  swatch alone.
- Created: 2026-08-12 with OpenAI's built-in image generation tool.
- Project status: newly generated project asset; not sourced from Roblox or the
  original Keth Shipyards. Its panel layout is modern and provisional, just like
  the candidate craft geometry.
- Final prompt:

> Use case: stylized-concept. Asset type: seamless game-ready spaceship and
> station hull albedo texture for a Godot 4 PBR material. Create a square,
> orthographic, tileable-looking aerospace surface texture: pale warm off-white
> ceramic-composite hull panels with subtle cool grey seam lines, tiny recessed
> fasteners, restrained wear at panel edges, faint micro-scratches and
> manufacturing variation; realistic high-end hard-surface game material, clean
> but used, physically plausible scale. Perfectly front-facing flat material
> swatch filling the canvas evenly; no perspective, horizon, or objects. Neutral
> diffuse studio illumination with minimal baked shading. Warm off-white, light
> grey, very sparse muted graphite; no strong colors. Visually seamless at all
> four edges; no readable text, symbols, logos, decals, numbers, directional
> shadows, dramatic highlights, depth-of-field, or watermark. Avoid rust, heavy
> grime, battle damage, black sci-fi greeble overload, an obvious repeating
> central motif, or photographic perspective.

## `assets/materials/torrent-hull-albedo-v1.png`

- Purpose: original warm off-white panelled hull albedo for the hero spacecraft's
  more realistic aerospace/PBR surface treatment.
- Created: 2026-08-12 with OpenAI's built-in image generation tool.
- Project status: newly generated project asset; not sourced from Roblox or the
  original Keth Shipyards.
- Final prompt:

> Use case: stylized-concept. Asset type: seamless tileable base-color texture
> for a realistic Godot 4 spacecraft hull material. Create an original seamless
> warm off-white painted spacecraft hull surface with fine modern aerospace panel
> construction, subtle flush access panels, narrow precise seams, tiny fasteners,
> restrained edge grime, faint heat and maintenance variation, and believable
> painted composite/metal microtexture. Realistic high-end PC science-fiction
> game, orthographic flat texture scan, edge-to-edge, neutral diffuse illumination,
> no baked shadows or reflections. Warm off-white/light grey with restrained cyan
> and amber maintenance marks. Must tile on all edges; no text, logos, watermark,
> franchise markings, dramatic lighting, objects, ship silhouette, or background.

## `assets/keth-nebula.png`

- Purpose: project-original panoramic backdrop used at full strength for the
  title treatment. In the live world it is now only an `8%`-modulated sky cover
  over a near-black procedural sky; source evidence more strongly supports
  near-black, densely starred space and large simple colour bodies than a
  dominant teal nebula.
- Created: 2026-08-12 with OpenAI's built-in image generation tool (`gpt-image 2.0` provenance is retained in the PNG metadata).
- Project status: newly generated project asset; not sourced from Roblox or the original Keth Shipyards.
- Final prompt:

> Use case: stylized-concept. Asset type: panoramic deep-space background texture for a modern standalone arcade spaceflight game vertical slice. An original richly detailed starfield with a restrained luminous teal-and-amber nebula, deep navy-black space, distant dust clouds and tiny varied stars; evocative of optimistic colorful late-2000s science fiction rebuilt with modern polish. Polished hand-authored cinematic game-sky texture, realistic-stylized, no visible brush strokes. Very wide panoramic composition, visual interest mostly around the outer thirds, calmer dark central area for readable gameplay silhouettes. Awe-inspiring, adventurous, clean and colorful rather than grim military. Deep navy, cyan-teal, muted cobalt, small warm amber highlights. Environment only; no spacecraft, station, planets, text, logos, watermark, obvious constellations, photoreal NASA-photo mimicry, overbright central cloud, purple-heavy vaporwave, or UI.

## `assets/audio/combat/`

- Purpose: seven non-looping combat one-shots for accepted player/defender fire,
  three hull-impact weights, ship destruction, and restrained safed-trigger
  feedback.
- Format: checked-in mono 48 kHz signed 16-bit little-endian PCM WAV; Godot
  import sidecars preserve the PCM data rather than applying lossy compression.
- Editable source: `tools/audio/generate_combat_audio_v1.py`; the fixed-seed
  offline generator and per-cue hashes/measurements are pinned by
  `combat_audio_v1_asset_manifest.json`.
- Project status: original fixed-seed offline procedural synthesis authored for
  Mudds Shipyards; no recorded, sampled, or third-party source material. The
  checked-in PCM WAVs are the runtime assets and the generator is reproducible
  editable source. Byte-identical regeneration was verified on CPython 3.12.3
  under Linux; cross-libm byte identity, historical authenticity, real-output
  audibility, and final mix quality are not claimed.

All geometry, UI, effects, and audio in the current slice are original project
work. The Torrent, pilot, and central-berth packages preserve editable Blender
sources and deterministic import contracts; much of the remaining station and
fleet still uses code-authored Godot geometry. Registered project-original
raster textures, their locally derived material maps, and the original generated
PCM bank documented above are the explicit checked-in media. No original Roblox
assets or scripts are bundled.

## `assets/keth-icon.png`

- Purpose: Godot project and Windows application icon.
- Created: 2026-08-12 with OpenAI's built-in image generation tool (`gpt-image 2.0` provenance retained).
- Project status: newly generated project asset; not sourced from Roblox or the original Keth Shipyards.
- Final prompt:

> Use case: logo-brand. Asset type: square Windows PC game application icon and Godot project icon. An original emblem for Keth Shipyards: Reforged, centered on a clean broad arrowhead spacecraft silhouette inspired by the project's pale off-white Torrent-class interceptor, seen from a slightly raised front/top angle, framed by a precise orbital shipyard ring. Polished stylized 3D game icon, bold readable geometry, premium modern science-fiction finish, not photorealistic. Centered symmetrical emblem, generous safe margin, immediately readable at 32px and 64px, square 1:1. Optimistic adventurous deep-space glow. Deep navy-black background, warm off-white ship, luminous cyan-teal cockpit/ring, restrained amber-gold navigation accents. Clean painted hull, subtle metallic ring, glassy cyan canopy. No text, letters, logos, watermark, humans, Roblox styling, generic rockets, realistic NASA insignia, dark military aesthetic, clutter, tiny details, or purple vaporwave.
