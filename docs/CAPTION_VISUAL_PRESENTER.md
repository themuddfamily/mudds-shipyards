# Caption visual presenter

`scenes/ui/caption_presenter.tscn` is a reusable, presentation-only Control. It
accepts only detached dictionaries from
`CaptionPresentationService.get_presentation_snapshot()`. It does not retain the
service, caption events, Nodes, Resources or Callables. Production GameFlow owns
the service and GameHUD hosts this authored presenter; the component retains no
gameplay or queue authority.

The component renders three independent textual channels: a bracketed category
such as `[ RADIO ]`, the speaker, and wrapped caption text. Category meaning is
therefore not colour-dependent. All text and the panel border exceed a 7:1
contrast ratio against the dark panel, and outline strokes protect text over
bright world imagery.

## Frozen layout contract

| Quantity | Exact value |
| --- | ---: |
| UI scale | 0.75–1.6 |
| Base panel width | 560–960 px |
| Base minimum height | 104 px |
| Horizontal safe margin | 32 px per side |
| Top safe margin | 24 px |
| Bottom safe margin | 42 px |
| Maximum caption text | 512 characters |

Dimensions and safe margins scale with UI scale. The panel is bottom-centred,
uses at most the scaled 960 px width, and yields to the safe width at narrow or
high-scale viewports. Height is derived from the real wrapped RichTextLabel
content metric, then constrained between the scaled 104 px minimum and the
deterministic maximum `viewport height - scaled top margin - scaled bottom
margin`. The focused suite measures 1280×720, 1920×1080 (16:9),
1920×1200 (16:10) and 3440×1440 (ultrawide) at 0.75, 0.8, 1.0, 1.5 and 1.6
scale with an exact 512-character caption.

A composing HUD may reserve a larger physical-pixel bottom band through
`set_host_bottom_safe_margin()`. This moves the panel above existing interaction
and telemetry controls without changing its wrapping, size bounds, or top/side
safe margins. The standalone default remains the scaled 42 px bottom margin.

Hidden snapshots clear stale text, set the component invisible, and every
Control in the subtree uses `MOUSE_FILTER_IGNORE`. Reduced-flash snapshots are
immediate, full-opacity and steady; the scene contains no AnimationPlayer and
creates no Tween. State, presentation and audit snapshots remain deeply
detached.

The deterministic audit denies gameplay, activity, reward, audio, ship, berth,
save and network authority. Production wiring belongs to GameFlow and the request-only GameHUD integration.
A component layout check does not establish ordinary gameplay or device acceptance.

Run only the focused layout suite:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/caption_presenter_layout_test.gd
```

The single 1600×900 Forward+ review frame is produced with:

```sh
xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
  --display-driver x11 --audio-driver Dummy --rendering-driver vulkan \
  --script res://tests/caption_presenter_forward_render.gd
```

It writes exactly one file, `caption-presenter-forward-plus.png`, inside
`MUDDS_CAPTION_CAPTURE_DIR` when supplied, otherwise in the application user-data
`captures/` directory. Automated callers must supply their owned private profile
and output directory.


## Open maximum-payload overflow policy

One actual GameHUD composition at1280×720/requested scale1.6 exposes an unresolved
valid-payload overflow. Effective scale1.043478 yields a530.783px host,464px panel
width and411.130435px safe height. A real service-accepted64-character source plus
512-character body has650px intrinsic height; the body alone needs512px. Original
16/19/23px fonts, margins and normal bottom reservation are intact. Layout token
and geometry converge, but PanelContainer minimum size grows the panel upward to
y−213.826px. `text_clipped=false` on the expanded body does not establish viewport
or safe-area containment.

This is a failed headless actual-HUD layout check, not a rendered image/Main or
ordinary-play qualification. The failed diagnostic is retained; no runtime repair
or altered font/scale/width/safe-area rule is delivered. An owner choice between
current-caption pagination, scrolling, or a wider/recomposed HUD is pending.
Chosen timing/input/full-text/reservation behavior must be fixed before its
bounded implementation and regression. Do not silently truncate/shrink text or
substitute transcript history for current-caption acceptance. Existing standalone
512-character/full-width and long-source/short-body results remain accepted only
for their recorded cases. [Exact case and records](history/ROADMAP_DELIVERIES.md#caption-combined-hud-overflow-measured-20261025).
