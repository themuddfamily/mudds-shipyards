# Caption production integration

Production `Main` owns exactly one `CaptionPresentationService` for its
lifetime. `GameFlow` is the only code that constructs typed caption events or
advances their caller-supplied physics duration. The service is retained while
the whole `Main` subtree is detached, so its active/pending queue and remaining
physics time freeze and resume on re-entry rather than restarting.

`GameHUD` owns exactly one `CaptionPresenter` scene instance. Its existing
`caption_cue()` and `show_caption()` methods are request adapters: they submit a
detached display descriptor to the bound `GameFlow` callback, then receive only
the service's validated presentation snapshot dictionary. The HUD stores no
caption queue, timer, replay ID, history, or second visible-caption panel.

## Accessibility and layout

- `captions_enabled` is applied to both the HUD request gate and service
  presentation flag. Disabling it hides the component without changing gameplay
  or audio.
- The existing `reduced_motion` preference supplies the service's
  `reduced_flash` flag. The presenter remains full-opacity and unanimated.
- The presenter's exact UI scale range is 0.75–1.6, matching
  `RuntimeSettings`/`GameHUD`; valid endpoint settings are never rejected or
  silently clamped by the component.
- The host reserves `272 × effective UI scale` physical pixels at the bottom
  and excludes the existing left/right HUD gutters. Ordinary caption cues sit
  above interaction/telemetry and between objective/control columns. Presenter
  top/side safe margins, wrapping and content-height checks remain unchanged.

## Retained and retired behavior

Retained: every authored audio cue mapping, unknown/footstep filtering, the
captions toggle, reduced-motion accessibility behavior, UI scaling, combat
readouts, damage cues, objectives, interaction prompts, and the always-visible
toast channel. Toasts are already text and remain independent; they are not
duplicated into the optional caption queue.

Retired: the HUD-local three-line caption history, idle-frame hold timer, and
`CaptionPanel`. `get_caption_log()` remains a read-only compatibility projection
of the one active service presentation; it no longer invents a second history.

No caption component owns audio playback, gameplay, combat, activity, reward,
ship, berth, save, or network authority.

Focused validation:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/caption_presentation_service_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/caption_presenter_layout_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/caption_production_integration_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/accessibility_presets_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/accessibility_reentry_integration_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/hud_panel_layout_test.gd
```

The one normal-resolution production frame is written to
`/tmp/caption-production-forward-plus.png` by
`tests/caption_production_forward_render.gd`. It is visual evidence only and
makes no GPU-time or performance claim.
