# Review candidates

These items were found during a conservative audit but are not confirmed defects, so no behavioural code was changed.

- `scripts/ui/hud.gd:66`: F1 toggles the help panel while the pause overlay is visible. This may be intentional, but it can change the resumed HUD state from the pause menu.
- `scripts/combat/live_combat_authority.gd:116`: deferred-presentation receipt IDs encode `source_id << 32`. The public source-ID API has no upper bound, so IDs at or above `2^31` can become negative and be treated as non-deferred. Production source IDs are small; add a bound or a non-negative encoding only if large IDs are supported.
