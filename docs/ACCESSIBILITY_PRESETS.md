# Accessibility presets

`ROADMAP.md` Phase 9 ("broader accessibility presets") and playbook item 3
("reticle/colour alternatives, camera shake, motion/flash reduction"). This
document covers the two HUD presentation settings added on top of the existing
colour-vision, reduced-motion, reduced-flash, caption and UI-scale presets:
the **high-contrast HUD** and the **reticle style**. Both are presentation
only. Neither changes flight handling, targeting, damage, audio or networking.

## Settings

| Key | Type | Default | Where it lives |
| --- | --- | --- | --- |
| `high_contrast_hud` | `bool` | `false` | `RuntimeSettings.high_contrast_hud`; `[accessibility] high_contrast_hud` in `settings.cfg`; `values.high_contrast_hud` in the user-data payload |
| `reticle_style` | `StringName`: `standard`, `bold`, `large` | `standard` | `RuntimeSettings.reticle_style`; `[accessibility] reticle_style` (plain string); `values.reticle_style` (plain string) |

Both keys are part of `RuntimeSettings.to_dictionary()`,
`get_accessibility_descriptor()`, `reset_to_defaults()` and the user-data
payload. The typed payload schema moved from 10 to **11**; a schema-10 document
migrates with both defaults supplied and every stored value preserved, a
schema-10 document that already carries either key is rejected as malformed,
and a schema-12+ document is still rejected as `newer_schema` so an older build
never overwrites it. `docs/RUNTIME_SETTINGS_PRODUCTION_PERSISTENCE.md` records
the persistence contract. `GameFlow` only lists the two keys in
`RUNTIME_SETTING_KEYS` and in the HUD-refresh dispatch, so a change reaches the
retained HUD through the same `set_accessibility()` descriptor path as the
colour-vision preset.

The pause **SHIP SYSTEM SETTINGS** page exposes them under ACCESSIBILITY,
directly after the colour-vision preset: a "High-contrast HUD" toggle with an
inline description and a "Reticle style" selector. Both are in the controller
focus chain, carry a live tooltip (`High-contrast HUD: ON/OFF …`,
`Reticle style: Standard/Bold/Large …`), preview immediately on the HUD, mark
the page dirty like every other control, and are covered by Reset Defaults and
the unsaved-changes prompt because they flow through the generic settings
snapshot. The reticle selector reports a stable ID (never an index) to the
settings owner. `RuntimeAccessibilityPresentation` confirms both as text rows
("HIGH-CONTRAST HUD // ON", "RETICLE STYLE // LARGE WITH CENTRE DOT") and now
reconciles `high_contrast_hud` into `AccessibilityVisualPreset.ContrastMode.HIGH`,
which was previously unreachable from settings.

## High-contrast HUD

`HudPalette.get_palette(mode_id, high_contrast := true)` returns a variant of
every colour-vision palette. Each variant keeps its base preset's hue
assignment, so a colour a player has learned keeps its meaning when the variant
is toggled, and is verified against a new opaque panel colour
`HudPalette.PANEL_BACKGROUND_HIGH_CONTRAST` (`#05090f`, darker than the
authored `#0c1724` so the chromatic roles can clear the floor without
bleaching into one another).

While the variant is on, `GameHUD`:

- resolves every registered palette target through the variant (labels,
  rects, bar fills, borders, minimap);
- replaces every registered panel backing's fill (the translucent objective,
  help, telemetry, interaction, toast, status, enemy and pause-page boxes)
  with the opaque high-contrast panel colour, without touching border widths
  or content margins, so no layout moves;
- adds a 3 px `#020509` outline to every palette-tinted body `Label` that does
  not author its own outline (the wordmark and titles keep theirs).

Turning it off restores the authored fills, colours and outline state exactly.
`tests/accessibility_presets_test.gd` asserts that `none` + off is bit-identical
to the authored HUD before and after a toggle, which is what lets the ultrawide
and composition suites keep freezing the authored layout.

### Derived contrast and separation numbers

Re-derived on every run of `tests/accessibility_presets_test.gd` from the
constants in `scripts/ui/hud_palette.gd`, using the same WCAG relative-
luminance contrast, Machado dichromacy simulation and CIEDE2000 metric the
base presets are judged on. Gates: every one of the six roles at or above
**7.0:1** (WCAG AAA) against `#05090f`; state-role separation at least
**24.0** ΔE00 after simulating the target deficiency and at least **20.0**
with normal vision. The test fails if any colour is edited into a confusable
pair or below the floor.

| Mode | Variant roles (nominal / caution / danger / muted) | Simulated min ΔE00 (pair) | Normal-vision min ΔE00 | Weakest role contrast |
| --- | --- | --- | --- | --- |
| `none` | `62e6ef` / `ffb85c` / `ff7f78` / `a3a3a3` | not colour-safe by design: 11.3 (caution/danger) under deuteranopia, 13.2 under protanopia, 12.9 under tritanopia — printed, not gated | 25.3 (danger/muted) | 7.91:1 (muted) |
| `deuteranopia` | `8aa4ff` / `ffff00` / `e0846b` / `e4e7e5` | 24.8 (danger/muted) | 29.2 | 7.30:1 (danger) |
| `protanopia` | `2aa8ff` / `faf575` / `ff7434` / `b4bcb4` | 25.8 (danger/muted) | 27.2 | 7.41:1 (danger) |
| `tritanopia` | `85f2f2` / `f9e03e` / `ff7551` / `a0a2b2` | 26.3 (caution/muted) | 29.7 | 7.52:1 (danger) |

`primary` (`edfaff`, 18.7:1) and `nominal_soft` (11.7–17.3:1) clear the floor in
every variant. The base presets, for comparison, put their weakest state role
at 5.5–6.5:1 against the authored panel; the high-contrast variants strictly
raise that in every targeted mode.

Two margins are deliberately thin and are the reason the numbers are gated
rather than described: under deuteranopia a danger orange that clears 7.0:1 on
a dark panel is also the colour that converges on a light muted grey once
red-green vision is simulated (24.8 against a 24.0 gate), and the danger role
sits at 7.30–7.52:1 against a 7.0:1 floor. The deuteranopia and protanopia
variants also lift `muted` to a light grey (12–16:1); the muted role stays
distinguishable from `primary` text by weight and size rather than by
lightness alone in those two variants.

## Reticle style

`GameHUD.SENSOR_RETICLE_STYLE_LAYOUTS` authors three styles. All keep the
four-bar silhouette, the nominal/degraded/critical/failed damage staging, the
target-lock label and the palette tinting; only the geometry changes.

| Style | Footprint | Bar thickness | Bar length nominal / degraded / critical | Centre dot |
| --- | --- | --- | --- | --- |
| `standard` | 44 px (authored; bit-identical to `SENSOR_RETICLE_MARK_LAYOUT`) | 4 px | 12 / 8 / 6 | none |
| `bold` | 44 px | 6 px | 12 / 8 / 6 | none |
| `large` | 72 px (1.64×) | 6 px | 20 / 14 / 10 | 6 px, hidden only when the sensor has failed |

The reticle is centre-anchored and sized through symmetric offsets, so a
style change during play keeps it on the viewport centre (the first rendered
capture caught a `position`-based rebuild parking it in the corner). The state
label always sits 4 px below the footprint, so it cannot overlap a bar in any
style; `tests/accessibility_presets_test.gd` and
`tests/hud_ultrawide_safe_area_test.gd` measure that.
`get_sensor_reticle_component_snapshot()` reports `style`, `mark_count`,
`footprint`, `mark_thickness`, `centre_dot_visible` and, as before, the visible
mark count and bar length. The reticle stays excluded from UI scaling.

## Verification

Headless suites (all pass; run with
`tools/run_affected_suites.sh --jobs 3 <names>`):

- `accessibility_presets_test` — palette mode × contrast matrix re-derived and
  gated; HUD contrast application and exact restoration; reticle styles, mark
  counts, footprint, centring and label clearance.
- `runtime_settings_test` — defaults, config round trip, typed payload round
  trip, schema-10 migration, stale/newer/invalid rejection, reset.
- `runtime_accessibility_presentation_test`, `accessibility_visual_preset_test`
  — status rows and the HIGH contrast mode reaching the visual preset.
- `hud_ultrawide_safe_area_test` — every case now runs twice, authored and
  high-contrast + large reticle, at 16:9, 16:10, 21:9 and 32:9 × three scales.
- `ultrawide_layout_test` — a fourth preset (`high_contrast_large_reticle`)
  drives every HUD state at 4:3, 16:9, 1440p, 21:9 and 32:9 in production Main.
- `hud_accessibility_descriptions_test`, `settings_ui_test`,
  `accessibility_reentry_integration_test`,
  `game_flow_runtime_settings_repair_test`, `help_overlay_accessibility_test`,
  every `runtime_settings*` and `user_data*` suite, `display_stretch_policy_test`,
  `smoke_test`, and the hero reticle/heat/hull HUD suites.

Rendered evidence (Xvfb, x11 display driver, Mesa d3d12, 1280×720):

```sh
env -u DISPLAY -u WAYLAND_DISPLAY GALLIUM_DRIVER=d3d12 MESA_LOADER_DRIVER_OVERRIDE=d3d12 \
  ACCESSIBILITY_CAPTURE_DIR=/root/.cache/mudds-shipyards/agent-accessibility/captures \
  ACCESSIBILITY_CAPTURE_SET=presentation ACCESSIBILITY_CAPTURE_SIZE=1280x720 \
  xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --display-driver x11 \
  --resolution 1280x720 --path . --script res://tests/capture_accessibility_presets.gd
```

writes `hud_piloting_standard_none.png` and
`hud_piloting_high_contrast_large.png`, each checked for a blank frame on a
64×36 sampling grid (73 and 86 distinct colours respectively; the script exits
non-zero on a uniform frame).

## Not verified

- No human review of the rendered frames for readability; the captures were
  inspected only by the agent that produced them and by the blank-frame check.
- No native display, GPU or Windows package run; Xvfb + Mesa d3d12 establishes
  composition, not native rendering or performance.
- Contrast is verified against the HUD's own opaque panel. Text drawn over the
  3D scene outside a panel (the reticle label, the wordmark) is not measured
  against scene content; the outline is the mitigation, not a measurement.
- The high-contrast variants are gated on the same severity-1.0 dichromacy
  simulation as the base presets; anomalous trichromacy and low-vision
  conditions are not modelled.
- Camera shake reduction (playbook item 3) is not part of this change.
