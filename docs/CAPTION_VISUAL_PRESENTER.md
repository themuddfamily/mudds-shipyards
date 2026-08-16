# Caption visual presenter

`scenes/ui/caption_presenter.tscn` is a reusable, presentation-only Control. It
accepts only detached dictionaries from
`CaptionPresentationService.get_presentation_snapshot()`. It does not retain the
service, caption events, Nodes, Resources or Callables, and this slice does not
edit GameHUD, GameFlow or an audio director.

The component renders three independent textual channels: a bracketed category
such as `[ RADIO ]`, the speaker, and wrapped caption text. Category meaning is
therefore not colour-dependent. All text and the panel border exceed a 7:1
contrast ratio against the dark panel, and outline strokes protect text over
bright world imagery.

## Frozen layout contract

| Quantity | Exact value |
| --- | ---: |
| UI scale | 0.8–1.5 |
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
1920×1200 (16:10) and 3440×1440 (ultrawide) at 0.8, 1.0 and 1.5 scale with an
exact 512-character caption.

Hidden snapshots clear stale text, set the component invisible, and every
Control in the subtree uses `MOUSE_FILTER_IGNORE`. Reduced-flash snapshots are
immediate, full-opacity and steady; the scene contains no AnimationPlayer and
creates no Tween. State, presentation and audit snapshots remain deeply
detached.

The deterministic audit denies gameplay, activity, reward, audio, ship, berth,
save and network authority. Production wiring remains intentionally deferred to
the separate timed-race HUD/GameFlow integration owner.

Run only the focused layout suite:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/caption_presenter_layout_test.gd
```

The single 1600×900 Forward+ review frame is produced with:

```sh
xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
  --display-driver x11 --rendering-driver vulkan \
  --script res://tests/caption_presenter_forward_render.gd
```

It writes exactly one file: `/tmp/caption-presenter-forward-plus.png`.
