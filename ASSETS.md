# Asset register

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
  is disabled. The imported subtree contains no collision, body, area, camera,
  audio, navigation or walking-surface authority.
- Final SHA-256: generator
  `68a78fcdd9f1370be7d92a633ce6e7ad7a77fb5908c49baa4442912c704fa625`;
  Blend `30ae770d8d31d89dceab7334be1fa373ca4caf20469ae4944c00f62773cf8b14`;
  GLB `6d35d3c61dba7ba841ba062be65e6ef8cb56286953fb48551a7cfcfcd8423a7e`;
  manifest `dbf354f26f5333d3b4e831eee00998527cfef49297808b21bb8704d99b396459`.


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
  dated-2011 Torrent. Its panel layout, engine construction, cockpit shell,
  landing gear, boarding hardware, weapons, materials and surface detail are
  modern design proposals. Although the four views are visually coherent, the
  generated sheet is not a dimensionally exact turntable and must not be used
  as an authenticated reconstruction or a final production-art claim.
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
  dated 2011 Torrent. Its plate layout, livery, wear, cyan accents and material
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
  ceramic-composite pattern.
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

## `assets/materials/arrow-hull-albedo-v1.png`

- Purpose: original warm ceramic-composite panel albedo used by the provisional
  Arrow recon craft and the Aft/Habitat pressure shells through triplanar PBR
  treatments.
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

- Purpose: original panoramic space backdrop used outside the vertical-slice hangar and behind the title screen.
- Created: 2026-08-12 with OpenAI's built-in image generation tool (`gpt-image 2.0` provenance is retained in the PNG metadata).
- Project status: newly generated project asset; not sourced from Roblox or the original Keth Shipyards.
- Final prompt:

> Use case: stylized-concept. Asset type: panoramic deep-space background texture for a modern standalone arcade spaceflight game vertical slice. An original richly detailed starfield with a restrained luminous teal-and-amber nebula, deep navy-black space, distant dust clouds and tiny varied stars; evocative of optimistic colorful late-2000s science fiction rebuilt with modern polish. Polished hand-authored cinematic game-sky texture, realistic-stylized, no visible brush strokes. Very wide panoramic composition, visual interest mostly around the outer thirds, calmer dark central area for readable gameplay silhouettes. Awe-inspiring, adventurous, clean and colorful rather than grim military. Deep navy, cyan-teal, muted cobalt, small warm amber highlights. Environment only; no spacecraft, station, planets, text, logos, watermark, obvious constellations, photoreal NASA-photo mimicry, overbright central cloud, purple-heavy vaporwave, or UI.

All geometry, UI, effects, and audio in the current slice are original project
work. The Torrent, pilot, and central-berth packages preserve editable Blender
sources and deterministic import contracts; much of the remaining station and
fleet still uses code-authored Godot geometry. Registered project-original
raster textures and their locally derived material maps are documented above.
No original Roblox assets or scripts are bundled.

## `assets/keth-icon.png`

- Purpose: Godot project and Windows application icon.
- Created: 2026-08-12 with OpenAI's built-in image generation tool (`gpt-image 2.0` provenance retained).
- Project status: newly generated project asset; not sourced from Roblox or the original Keth Shipyards.
- Final prompt:

> Use case: logo-brand. Asset type: square Windows PC game application icon and Godot project icon. An original emblem for Keth Shipyards: Reforged, centered on a clean broad arrowhead spacecraft silhouette inspired by the project's pale off-white Torrent-class interceptor, seen from a slightly raised front/top angle, framed by a precise orbital shipyard ring. Polished stylized 3D game icon, bold readable geometry, premium modern science-fiction finish, not photorealistic. Centered symmetrical emblem, generous safe margin, immediately readable at 32px and 64px, square 1:1. Optimistic adventurous deep-space glow. Deep navy-black background, warm off-white ship, luminous cyan-teal cockpit/ring, restrained amber-gold navigation accents. Clean painted hull, subtle metallic ring, glassy cyan canopy. No text, letters, logos, watermark, humans, Roblox styling, generic rockets, realistic NASA insignia, dark military aesthetic, clutter, tiny details, or purple vaporwave.
