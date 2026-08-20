# Planetary surface audio playback foundation

This is a standalone, presentation-only foundation for the two opaque profile
IDs produced by `PlanetarySurfaceAudioPolicy`. It deliberately has no
production `Main` integration, no listener/context sampling, no world or
profile selection, no streaming lifecycle ownership, and no `AudioDirector`
dependency. A future caller must supply accepted policy results and all
attachment freshness identities.

## Authored assets and catalog

`assets/audio/planetary/` contains two original, fixed-seed, offline-rendered
eight-second mono PCM16 loops and a checked-in manifest. The generator is
offline tooling only; the game never synthesizes these sounds at runtime.

| Policy profile ID | Role | Asset |
| --- | --- | --- |
| `temperate_exterior` | non-positional exterior wind / moving air | `temperate_exterior_wind_air_v1.wav` |
| `temperate_interior` | restrained interior/cabin air | `temperate_interior_cabin_air_v1.wav` |

The `PlanetarySurfaceAudioCatalog` resource freezes that exact two-entry map,
including imported PCM identity, format, forward-loop metadata, and the
`Ambience` route. It resolves only these already-imported resources and fails
closed if either resource or catalog identity drifts. It loads nothing on
demand and owns neither playback nor mixer authority.

## Binding boundary

`planetary_surface_audio_playback_binding.tscn` owns exactly two direct-child,
non-positional `AudioStreamPlayer` voices: `ExteriorVoice` and `InteriorVoice`.
Both are authored on the `Ambience` bus with one voice of polyphony. The binding
does not mutate AudioServer buses or effects; it only assigns its own voices'
streams, local volume, pause state, and play/stop state.

After a one-time catalog configuration, a caller attaches an opaque atmosphere
profile ID plus root, frame, location, and attachment generations. The caller
then presents one accepted, detached policy result and its physics delta. The
binding validates the full policy schema and route/gain contract, retains a
0.75-second equal-power local fade, and immediately detaches on caller-reported
lifecycle loss. It has no process loop and no wall-clock ownership.

The content is explicitly `NEW` modern sound design with no historical source
claim. Automated checks establish file, catalog, hierarchy, and contract
integrity; native listening and production integration remain outstanding.

## Focused checks

Run after Godot imports are available:

```bash
godot --headless --path . --script res://tests/planetary_surface_audio_foundation_test.gd
```

The focused test checks the raw assets and manifest, strict immutable catalog,
two-voice non-positional scene contract, detached caller-driven attachment, and
the absence of `Main` or `AudioDirector` integration.
