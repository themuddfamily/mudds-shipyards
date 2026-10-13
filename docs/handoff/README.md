# Handoff briefs: index (2026-09-27)

These briefs cover the work still outstanding at the end of the 2026-09-27 session. Each brief stands alone and is meant for a different fresh agent with no prior context. All seven were checked against `main` at `92a30f7ff`. **Testing has deliberately NOT started, on the user's instruction.** Agents write or update the focused tests their brief names, but they do not run Godot or any suite until the user says testing may start. Each brief lists the suites to run later, with their success markers.

## Briefs

| # | Title | Priority | Roadmap item | Prior partial work at handoff | Files touched |
|---|---|---|---|---|---|
| [01](01-remote-helm-stream-restart.md) | Remote helm stream restart is refused as stale | P1 | Phase 7 multiplayer, remote piloting | Committed on a side branch: `db19b78bf` on `worktree-wf_bde904a0-40e-1` | `scripts/game/game_flow.gd` (helm vars, `_advance_network_remote_helm_stream`), `scripts/network/network_remote_pilot_command_source.gd` (`build_helm_intent`), `tests/network_remote_pilot_helm_test.gd` (section D2) |
| [02](02-host-seat-exit-window.md) | Host releases its pilot seat before it has left it | P2 | Phase 7 multiplayer, host seat occupancy | Committed on a side branch: `effab5d97` on `worktree-wf_bde904a0-40e-1` | `game_flow.gd` (`_network_host_desired_pilot_ship`), helm test (start of section A) |
| [03](03-observed-actor-follows-remote-craft.md) | Host's observed actor follows a crewmate's craft | P2 | Phase 7 multiplayer, remote piloting (Cinder/Ember streaming, minimap) | Committed on a side branch: `24c908d75` on `worktree-wf_bde904a0-40e-1`. It **depends on 04's `c36821ba9`**, and it has no test or audit yet | `game_flow.gd` (`_get_debug_actor`, new `_active_ship_flown_from_here`, `_capture_cinder_actor_sample`), `scripts/world/cinder_streaming_production_binding.gd`, possibly `scripts/game/planetary_journey_coordinator.gd` |
| [04](04-remote-helm-captures-host-input.md) | Remote helm binding takes over the host's mouse and input | P2 | Phase 7 multiplayer, remote piloting | Committed on a side branch: `c36821ba9` on `worktree-wf_bde904a0-40e-1`. One guard is missing | `scripts/ships/hero_ship.gd`, `game_flow.gd` (`_bind_network_remote_pilot`, `_unbind_network_remote_pilot`), helm test (asserts in sections A and E) |
| [05](05-torpedo-aims-at-boarding-sphere.md) | Seeker torpedo aims and fuses on the boarding sphere, not the hull | P2 | Torpedo boat opponent / Torpedo Run sortie | Committed on a side branch: `b0cb8d684` on `worktree-wf_bde904a0-40e-2`. The aim is fixed; the near-miss presentation and its test remain | `scripts/combat/seeker_torpedo_projectile.gd`, `scripts/combat/torpedo_run_audio.gd`, `tests/seeker_torpedo_projectile_test.gd`, `tests/torpedo_run_audio_test.gd` |
| [06](06-host-hauler-slug-replication.md) | Host's own Cinder hauler slugs reach clients | P3 | Phase 7 multiplayer, replicated combat presentation | None | `game_flow.gd` (`_ensure_player_bolt_pool`, a new observe helper, possibly `_advance_network_remote_projectiles`), a new focused test |
| [07](07-station-wayfinding-signage.md) | Station wayfinding signage (registry-driven sign panels) | P2 | Phase 10 section 3, whole-game visual improvement (navigation/readability) | Uncommitted, in worktree `.claude/worktrees/wf_bfd4b06c-966-1`. That agent was stopped on 2026-09-27; the worktree is frozen | `scripts/world/station_wayfinding_*.gd`, `scripts/world/shipyard_world.gd` (small hunk), `tools/signage/**`, `assets/signage/**`, `tests/station_wayfinding_test.gd`, `ASSETS.md`, `scripts/ui/credits_catalog.gd` |

Side-branch state at the time of writing:
- `worktree-wf_bde904a0-40e-1` holds, in order, `db19b78bf` (01), `effab5d97` (02), `c36821ba9` (04) and `24c908d75` (03).
- `worktree-wf_bde904a0-40e-2` holds `b0cb8d684` (05).
- The 07 worktree is uncommitted and frozen (its agent was stopped). It includes an `ASSETS.md` section for the sign atlas, now recorded in brief 07; copy it rather than editing the worktree.
- Never edit, reset or commit in any of these worktrees. Reuse the work by cherry-picking (or, for 07, copying files) onto a new branch created from `main`.

## File-collision matrix

"X" means both briefs edit the file. For `game_flow.gd`, every pair edits disjoint functions.

| File | 01 | 02 | 03 | 04 | 05 | 06 | 07 |
|---|---|---|---|---|---|---|---|
| `scripts/game/game_flow.gd` | X | X | X | X | | X | |
| `tests/network_remote_pilot_helm_test.gd` | X (D2) | X (A) | (maybe) | X (A, E) | | | |
| `scripts/ships/hero_ship.gd` | | | reads `is_remote_piloted()` | X (owner) | | | |
| `scripts/network/network_remote_pilot_command_source.gd` | X | | | | | | |
| `scripts/world/cinder_streaming_production_binding.gd` | | | X | | | | |
| `scripts/network/network_remote_projectile_replicator.gd` | | | | | read only | read only | |
| `scripts/combat/seeker_torpedo_projectile.gd`, `torpedo_run_audio.gd` | | | | | X | | |
| `scripts/world/shipyard_world.gd`, `ASSETS.md`, `credits_catalog.gd` | | | | | | | X |

Other dependencies and overlaps:
- **Hard dependency:** 03 calls `HeroShip.is_remote_piloted()`, which 04 adds. 03 must merge after 04.
- **Helm test:** 01, 02 and 04 add separate hunks to the helm test. 04's section A hunk was written on top of 02's hunk. Expect small conflicts only.
- **`hero_ship.gd`:** only 04 edits it.
- **Independent of the rest:** 05 and 07 share no files with any other brief. 06 shares only `game_flow.gd`, in a disjoint region (bolt pool and projectile observation).

## Recommended assignment plan

**Option A (preferred): four agents in parallel.**
- **Agent 1** takes 01, 02, 04 and 03 in that order. All four are cherry-picks from the same side branch. They touch neighbouring remote-pilot regions of `game_flow.gd`, and they share the helm test and the 04→03 dependency. One agent avoids conflicts inside the chain, and can restore 04's missing guard before 03 builds on it.
- **Agent 2** takes 05.
- **Agent 3** takes 06.
- **Agent 4** takes 07.

**Option B: one agent per brief (seven agents), as the briefs are written.**
- All seven can be *written* in parallel on separate branches from `main`.
- The one exception is 03. Either start it after 04 has merged, or cherry-pick `c36821ba9 24c908d75` and rebase once 04 lands. Tell the integrator about the duplicate `c36821ba9`.
- The integrator then resolves the small helm-test conflicts between 01, 02 and 04.

### Recommended merge order onto `main`

1. **07** (independent, visible in the next checkpoint build).
2. **05** (independent, visible combat fix).
3. **01**, then **02**, then **04**, then **03**, which is the remote-pilot chain in side-branch order.
4. **06**.

05, 06 and 07 have no ordering constraint among themselves or against the chain. The only fixed order is 01 → 02 → 04 → 03.

## Integration procedure (for whoever merges)

1. Work on `main` in `/root/mudds-shipyards`, or in a fresh integration worktree created with `git -C /root/mudds-shipyards worktree add -b <branch> <path> main`. Never use `reset --hard`, and do not push.
2. Cherry-pick each agent's commits in the merge order above: `git -C <repo> cherry-pick <sha>...`. Resolve helm-test conflicts by keeping every section's hunk. If 03's agent carried a copy of `c36821ba9`, skip that duplicate.
3. Run the import once:
   `godot --headless --audio-driver Dummy --path . --import`
4. Run `git status` and look for untracked `*.gd.uid` sidecars. Commit them with the scripts they belong to, or in one follow-up commit.
5. Parse-check each changed script:
   `godot --headless --audio-driver Dummy --path . --check-only --script res://<path>.gd`
6. Wait for the user's go-ahead before running any test suite.
7. Project rules apply throughout (see AGENTS.md):
   - every Godot invocation includes `--audio-driver Dummy`;
   - rendered runs happen only headless, or under Xvfb with `--display-driver x11` and `DISPLAY`/`WAYLAND_DISPLAY` unset;
   - no evidence validators and no schema bumps;
   - do not edit `ROADMAP.md`.

## Deferred testing phase

- `/root/.cache/mudds-shipyards/finish-game/suites.txt` has the aggregated list of suites to run once testing may start.
- `/root/.cache/mudds-shipyards/finish-game/*.output` holds the per-workstream agent reports.
- `/root/.cache/mudds-shipyards/finish-game/ledger.txt` maps each workstream to its report file, and records which workstreams were already merged.
- Each brief's own "Testing" section lists the focused suites for that item, with their success markers.
