# Review candidates

These items were found during a conservative audit but are not confirmed defects, so no behavioural code was changed.

- `scripts/combat/live_combat_authority.gd:107-110`: deferred-presentation receipt IDs pack `source_id` and only the low 32 bits of an unbounded sequence. A sequence separated by `2^32` aliases the same receipt, and source IDs at or above `2^31` produce a negative receipt that disables deferred presentation. Production sources and sessions are far below those limits; use a collision-free ID allocator or enforce bounds if such sessions/IDs are supported.
- `scripts/audio/station_machinery_ambience.gd:123-147`: `play_cue()` documents that `true` means the audio backend accepted playback, but returns `true` immediately after `AudioStreamPlayer3D.play()` without checking `playing`. Dummy mode correctly returns `false`; confirm real-backend rejection behaviour before changing the API contract or implementation.
