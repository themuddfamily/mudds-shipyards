# Mudds Shipyards

**Mudds Shipyards** is a native Godot 4 fan-remake prototype inspired by ZolarKeth's 2009 Roblox game **Keth Shipyards**. Walk the station, board one of **nine flyable craft**, launch, fight, land, disembark, and recover after a crash in the same world. The guided Torrent sortie sits alongside the fleet sandbox, bounded nearby activities, and an Ember Moon expedition.

Repository: <https://github.com/themuddfamily/mudds-shipyards>

This is an unofficial, research-led project with original code and newly produced assets unless noted otherwise. The owner considers the creator-permission question settled following their direct contact with the original creator; the [research plan](ROADMAP.md#phase-1--research) records that account and the absence of a written grant. The repository has no project `LICENSE` file.

## Current prototype slice

Source capabilities reviewed on **2026-09-07**; this inventory is not a new test or package result.

- **Physical fleet loop:** independently reserved berths, automatic propulsion, guided combat and return, collision-backed station routes, landing assistance, destruction/recovery and craft regeneration. Cabin access and optional crew roles are craft-specific.
- **Nine flyable craft:** Torrent, Arrow, Jovian, Zenith, Halyard Crew Transport, Bulwark Heavy Gunship, Cinder Cargo Hauler, Cinder Long-Range Bomber and Cinder Light Interceptor. The [ship definitions](assets/ships) and [production flow](scripts/game/game_flow.gd) define the roster; the Fleet Dock expansion occupies Dock 04/05/06.
- **Controls and accessibility:** persisted keyboard/mouse and gamepad remapping with conflict handling and reset, adjustable deadzones, linear/squared curves and hold/toggle processing, active-device keyboard/Xbox/PlayStation glyph presentation, controller menu focus, UI scaling, colour-vision presets, reduced motion/flash and audio captions. Physical controller validation remains open.
- **Combat and crew:** bounded varied encounters, component damage and repair, gunner/engineer roles on supported craft, bomber payloads, and station-defence waves. These remain incomplete combat and multiplayer slices.
- **Networking:** production ENet session integration, server-owned command/seat/combat paths, moving-interior replication and bounded role/projectile presentation exist. The deterministic and multiprocess harnesses cover specific contracts; a current native-Windows two-client review and sustained soak remain open. See [Phase 7](ROADMAP.md#phase-7--multiplayer).
- **Nearby activities:** the streamed Cinder Reach cluster and Activity Board expose bounded race, patrol, cargo, mining/extraction, scan, beacon and defence routes with generation-bound progress and receipts. Package-level player validation remains open. See [Phase 8](ROADMAP.md#phase-8--nearby-world-and-activities).
- **Ember Moon:** the Destination Board exposes the bounded Ember journey, physical cruise/final approach, streamed landing/surface survey and return to the craft's home berth. The catalog does not make every listed world visitable. Full planetary breadth, uninterrupted human expedition review and representative hardware performance remain open. See [Phase 10](ROADMAP.md#4-visitable-planets-with-complete-atmosphere-to-surface-loops).

The historical evidence boundary is unchanged: Torrent's B5 link and Zenith's B7 link support bounded partial reconstructions, with recording/build provenance and continuity with 2009 unresolved. Zenith's Interceptor/Fighter naming conflict remains open. Arrow and Jovian have no name-to-model locks; their geometry and systems are modern candidates. Halyard, Bulwark and the three Cinder craft are original modern designs, not recovered historical ships. Station details, activities, audio and planetary content do not authenticate the original game. See the [research plan](ROADMAP.md#phase-1--research) and [asset record](ASSETS.md).

## Next milestone

Deliver a source-pinned stabilization candidate for normal-controls Windows feedback:

Regression discovery now includes nested suites and registered graphical harnesses; CI runs the eight-suite core on changes and broader suites on a schedule. Failed diagnostic saves retain their records and back off between retries. The planetary journey coordinator now lives outside `GameFlow` and remains attached across Ember return cycles. Equivalent audio validators share one implementation.

The current stabilization pass also repairs physical boarding, moving-cabin collision alignment, doorway face winding, Cinder streaming fades, startup cleanup and network HUD revision handling. Focused checks have passed; the complete matrix must pass on the merged source before release qualification.

1. Finish the merged full regression and export its exact source revision.
2. Exercise boarding, combat, landing, disembarking, crash recovery and the Ember expedition on Windows using normal controls. Tune camera comfort, landing clarity, prompts and audio from recorded observations.
3. Run the existing benchmark on representative minimum/target hardware before further visual expansion. Use the packaged Ember observations to choose its next visible improvement.

Current-source full regression, packaging and package parity evidence are **pending**. Current-candidate native-Windows human play, representative CPU/GPU benchmarks, real-controller focus and audible mix review are **`NOT_RUN`** until actually performed. Historical native startup/capture records do not substitute for those gates. The [complete roadmap](ROADMAP.md) retains every phase and open acceptance requirement.

## Run locally

Use Godot 4.7.1 and open `project.godot`. For a silent import check on a fresh checkout:

```bash
godot --headless --audio-driver Dummy --editor --path . --quit
```

Run the project from the editor for interactive play. Press `E` on the title screen to begin, `F1` for controls, and `Esc` for the pause menu, Settings and activity/destination interfaces.

## Runtime settings

Settings preview and persist through the retained `RuntimeSettings` / `UserDataStore` composition. The panel covers separate ship/on-foot sensitivity and invert-Y, FOV, audio groups, graphics/display modes, accessibility and input profiles. Accepted remaps update the live controls and glyph rows; reset restores and persists authored defaults. Invalid or unsupported stored data fails closed. See [production settings persistence](docs/RUNTIME_SETTINGS_PRODUCTION_PERSISTENCE.md).

### Accessibility presets

UI scale is capped to fit the viewport; colour-vision presets supplement text and shapes; reduced-motion/flash controls limit presentation; audio captions provide event text. The active device determines help glyphs. These source features still need current native display, controller and human accessibility review.

## Controls

The tables show defaults; the in-game remapping panel and controls overlay reflect the active profile.

On foot:

| Input | Action |
|---|---|
| `W A S D` | Move |
| Mouse | Look |
| `Shift` | Sprint |
| `Space` | Jump |
| `E` | Interact / board / operate station doors |
| `C` | Toggle first / third person. The choice persists through the settings store and is restored after leaving a seat. `V` controls the ship camera. |

In any current prototype craft:

Propulsion is automatic. The previous prototype mapped keyboard `Y` / gamepad D-pad Up to engine start and keyboard `X` / gamepad D-pad Down to engine stop (`Y` was creator-listed across documented builds; `X` carried a fixed-era meaning). Those four player-facing bindings and their actions are retired. Real flight or fire demand now powers the craft in the same physics tick, avoiding a separate start/stop chore and ensuring the waking input is responsive; neutral controls automatically take it offline after exactly `1.5` seconds of physics time.

| Input | Action |
|---|---|
| `W / S` | Throttle; non-neutral input automatically powers the engine |
| Mouse | Yaw / pitch attitude; captured look intent automatically powers the engine |
| `A / D` | Yaw left / right |
| `Up / Down` | Pitch up / down |
| `Q / R` | Roll left / right |
| `V` | Toggle chase / cockpit view |
| Mouse wheel | Adjust chase-camera distance |
| `Shift` | Boost |
| `Page Up` or right mouse | Brake |
| `H` | Hover (creator-listed in later original-era builds) |
| `F` or left mouse | Fire (`F` is creator-listed; mouse fire is new) |
| `G` | Barrel roll (fixed-era binding) |
| `L` | Landing assist (modern prototype binding); power is retained until touchdown |
| All flight controls neutral | After exactly `1.5` seconds of physics time outside landing/recovery, engine state, thrust visuals, and continuous audio settle `OFFLINE` |
| `E` | Leave the pilot seat once automatically offline: at a berth you step out onto the deck; away from one you step into the craft's own cabin, if it has a walkable one (only when that craft publishes a walkable cabin). Press `E` again at the cockpit to sit back down. |
| `Esc` | Pause; open **Settings** from the pause panel |
| `F1` | Toggle controls |
| `F2` | Save a screenshot to `user://screenshots` |
| `F3` | Toggle screenshot diagnostics: active actor and camera XYZ, facing, velocity, centre-view hit position, and rebase-stable absolute cell/offset coordinates for both the actor and hit point |

Default SDL-style gamepad bindings, on foot and while piloting (authored `0.18` deadzone, adjustable in settings):

| Input | Action |
|---|---|
| Left stick vertical / horizontal | Walk; throttle / yaw while piloting |
| Right stick vertical / horizontal | Pitch / roll |
| Left trigger / right trigger | Brake / fire |
| Left-stick press (`L3`) | Sprint on foot; boost while piloting |
| `A` | Jump on foot; hover while piloting |
| `B` | Barrel roll |
| `X` | Begin shift, interact, board, operate station doors, disembark |
| `Y` | Toggle chase / cockpit view |
| `LB` / `RB` | Chase-camera distance nearer / farther |
| D-pad Left | Landing assist |
| D-pad Right | Toggle first / third person on foot |
| Start | Pause; the pause panel and settings take controller focus |
| Back | Toggle the controls overlay |

Every input-requiring step of the core loop—begin shift, walk, board, apply thrust to power up and launch, fly, fire, return, land, disembark after automatic idle, pause, and read the controls overlay—is bound on the gamepad and is covered by a controller-only regression through the production scene. Runtime remapping, conflict replacement, defaults/reset, deadzone/curve and hold/toggle options, and active-device keyboard/Xbox/PlayStation glyph presentation are implemented. A real-controller hardware and focus review remains `NOT_RUN` for the current candidate. `F1` and `Back` share one `toggle_controls_overlay` action.

The historical bindings changed between builds. Movement handling, mouse flight, boost, brake, landing assist, weapon/damage values, and AI behaviour are current remake design rather than recovered simulation parameters.

## Validation and export

Every automated Godot invocation must include `--audio-driver Dummy`, including headless tests, rendered captures and package probes. Real audible testing requires explicit user authorization.

```bash
# Import/parse, then run focused core checks.
godot --headless --audio-driver Dummy --editor --path . --quit
godot --headless --audio-driver Dummy --path . --script res://tests/smoke_test.gd
godot --headless --audio-driver Dummy --path . --script res://tests/sandbox_loop_test.gd

# Headless regression; the runner reports graphical suites as NOT_RUN.
tools/release/run_test_matrix.sh --audio-driver Dummy --mode headless

# Complete roster, including graphical suites; requires a working display.
tools/release/run_test_matrix.sh --audio-driver Dummy --mode all

# Source-named Windows candidate from a clean exact commit; existing outputs are preserved.
tools/release/export_windows_candidate.sh
```

Use `--scope` on the matrix runner for focused suites, or `--list --mode all` to inspect its recursively discovered roster. Graphical harnesses require a rendering device/display; CI supplies Xvfb for its scheduled graphical job. Only an unfiltered `--mode all` run covers the complete roster for the release gate. Consult the runner's `--help` for selection and result paths. Compare structured `results-canonical.tsv` outcomes; raw logs remain the diagnostic record. A documented command is not evidence that its run passed.

The export wrapper runs on Linux/WSL using Linux `/proc` and GNU tools; its output is a Windows executable under ignored `builds/windows/`. Export, pack inventory and Linux startup checks do not establish native-Windows gameplay. The [release evidence tool](docs/RELEASE_EVIDENCE_TOOL.md) binds a clean source revision, matrix, package probes, inventory, PE/signing metadata and executable checksum; signing and publishing remain separate gates.

## Project status

The game has implemented slices across Phases 2–10, with research continuing in Phase 1. The full station, historically researched fleet, complete combat/multiplayer, planetary breadth and release polish remain unfinished. Checked roadmap items describe bounded implementation, not whole-phase completion or historical authentication.

Detailed old art passes, handoffs, matrix totals and package hashes are retained in the [dated documentation archive](docs/history/README.md). They refer to their original checkpoints and are not source-current acceptance evidence. Use [Next milestone](#next-milestone) and the [active roadmap](ROADMAP.md) for the current work.
