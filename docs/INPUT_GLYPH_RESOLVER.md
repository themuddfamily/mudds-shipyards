# Input glyph resolver

`InputGlyphResolver` is a presentation-only adapter for the normalized binding
descriptors stored by `InputBindingProfile`. It does not read or mutate
`InputMap`, change a profile, dispatch input, or decide gameplay authority.

## Result contract

`resolve_binding()` and `resolve_action()` return a deep-copied dictionary with:

- `glyph_token`: a stable semantic token for a future icon atlas or text UI;
- `localization_key`: the corresponding translation key;
- `text` and `fallback_text`: translated text when the key is registered, or a
  deterministic English fallback;
- `device_family`: the family used to interpret the binding;
- `valid` and `fallback_used`: explicit resolution status; and
- `binding`: a deep copy of the normalized source descriptor.

Tokens describe meaning, not an asset path. Examples include `key.w`,
`mouse.wheel_up`, `gamepad.xbox.a`, `gamepad.playstation.cross`,
`gamepad.nintendo.b`, and `gamepad.generic.left_stick.up`. Unknown valid button
or axis indices keep deterministic generic tokens and readable text. Invalid or
unbound descriptors return `input.unknown`.

Keyboard resolution uses `physical_keycode`, matching the profile's physical-key
contract. Mouse resolution distinguishes ordinary, side, and directional wheel
buttons. Gamepad button numbers follow Godot/SDL positional semantics; family
mapping changes the displayed label without changing the stored binding.
Directional stick axes include their sign, and trigger axes use family labels.

## Preferred device family

A resolver instance begins with keyboard as its deterministic last-active
family. `observe_binding_activity()` or `observe_input_event()` may update that
family after accepted activity. Joy-axis magnitudes at or below the supplied
deadzone are ignored, so drift cannot switch prompts. Released buttons and
keyboard echo events are also ignored.

`set_explicit_device_family_override()` pins selection until cleared. Activity
is still remembered while pinned, but cannot replace the displayed family. If
an action has no binding for the preferred family, `resolve_action()` uses a
stable keyboard/mouse/gamepad fallback order and reports `selected_by_fallback`;
it does not change either preference state.

Supported families are `keyboard`, `mouse`, `gamepad_generic`, `gamepad_xbox`,
`gamepad_playstation`, and `gamepad_nintendo`.

## Device metadata boundary

Gamepad layout is accepted only from caller-provided metadata:

```gdscript
{"device_class": "gamepad", "layout": "playstation"}
```

Recognized layouts are `generic`, `xbox`, `playstation`/`ps`, and
`nintendo`/`switch`. Missing, conflicting, or unknown metadata resolves to the
generic family. The resolver does not inspect platform, controller names,
vendor IDs, or operating-system state, and therefore makes no autodetection
claim.

## Deterministic audit

`audit_profile()` sorts action names, resolves every copied binding, includes
copied action options, and hashes the canonical JSON action list with SHA-256.
The returned tree is detached from the profile and from subsequent audits, so
callers may serialize or mutate it without changing binding authority. The
fingerprint is a presentation audit aid, not a profile identity or save format.

## Integration limits

This slice intentionally provides no images, font glyphs, HUD wiring, remapping
UI, automatic device discovery, or localization catalogue. A later UI consumer
may map semantic tokens to available artwork and should always retain `text` as
the accessible fallback.
