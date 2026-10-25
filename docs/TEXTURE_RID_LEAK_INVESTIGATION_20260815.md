# Investigation — the seven leaked `Texture` RIDs at engine finalize

**Date:** 2026-08-15
**Trigger:** [`docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md`](PACKAGE_BUILD_RECORD_20260815_EF5450C.md),
which recorded that the native-Windows run of `gateE-20260815-ef5450c` on an RTX 5070 Ti
exits `0` but always ends with:

```
WARNING: 7 RIDs of type "Texture" were leaked.
   at: finalize (servers/rendering/rendering_device.cpp:8900)
```

**Verdict: engine-side, not ours.** A single stock `ReflectionProbe` node leaks exactly
seven `RenderingDevice` texture RIDs at shutdown. It reproduces in a ~70-line empty
project containing nothing but a camera, a box mesh and one `ReflectionProbe`. No
application-side change can prevent it, and no code change was made.

The leak is **bounded and fixed** — seven RIDs, once, at process teardown — so the
long-standing "benign" characterisation is correct in its conclusion. Its stated
*reason* was wrong, and that mattered (see "Was the ROADMAP characterisation correct?").

## Reproduction

The headless matrix structurally cannot see this: `--headless` creates no rendering
device, so no texture RIDs exist to leak. Everything below runs under X11 + Vulkan.

The environment here is WSL2 with no `/dev/dri`, so Vulkan resolves to **lavapipe**
(`llvmpipe`, Vulkan 1.4.318) rather than the RTX 5070 Ti's Vulkan 1.4.341. The count is
identical on both, which is itself part of the evidence.

Closest analogue to the native Windows run — the real game, real main scene:

```
xvfb-run -a -s "-screen 0 1920x1080x24" godot \
  --path <worktree> --display-driver x11 --rendering-driver vulkan \
  --audio-driver Dummy --quit-after 300
```

→ `WARNING: 7 RIDs of type "Texture" were leaked.` — matching the Windows record exactly.

### Which harnesses leak, and why

| Harness | Leaked RIDs | Loads `scenes/main.tscn`? |
| --- | --- | --- |
| `--quit-after 300` (main scene, no harness) | **7** | yes (as main scene) |
| `--quit-after 900` (main scene, no harness) | **7** | yes (as main scene) |
| `tests/capture_zenith_visuals.gd` | **7** | yes |
| `tests/capture_berth_feedback.gd` | **7** | yes |
| `tests/capture_player_motion.gd` | 0 | no — `scenes/player/player.tscn` only |
| `tests/capture_jovian_freighter.gd` | 0 | no — builds an ad-hoc evidence world |

The split is exactly "does this harness render `ShipyardWorld`", which is the first
narrowing step.

## Bisection

A temporary `SceneTree` probe instantiated one scene, stepped N frames and quit. Note
the confound found early: **a probe with no `Camera3D` renders no 3D at all**, so an
uncontrolled bisection produces false negatives. Results with a camera added:

| Subject | Leaked RIDs |
| --- | --- |
| nothing (bare `SceneTree`) | 0 |
| `scenes/main.tscn`, `load()` only, never instantiated | 0 |
| `scenes/main.tscn`, instantiated + stepped | **7** |
| `scenes/world/shipyard_world.tscn` + camera | **7** |
| `scenes/ships/torrent_interceptor.tscn` + camera | 0 |
| `scenes/ships/zenith_interceptor.tscn` + camera | 0 |
| `scenes/ui/hud.tscn` | 0 |
| `scenes/player/player.tscn` | 0 |
| `scenes/effects/pulse_weapon_presentation.tscn` | 0 |

`Node.print_orphan_nodes()` at `_finalize` printed **nothing** in every run — there are no
leaked `Node`s. The repo also has **no** `static var`s, **no** runtime `ImageTexture` /
`NoiseTexture2D` / `GradientTexture` construction in `scripts/`, **no** `SubViewport` or
`ViewportTexture` anywhere in `scripts/` or `scenes/` (only in evidence harnesses under
`tests/`, and the harness that uses one — `capture_jovian_freighter.gd` — leaks nothing),
and exactly one `RenderingServer` call in the whole codebase
(`scripts/rendering/visual_quality_controller.gd:119`, a read-only
`get_current_rendering_method()`). Every candidate named in the original brief —
procedural material maps, the HUD, the star shell, `ShipBerthFeedback`, the pulse-weapon
pool — was ruled out. (`tools/generate_material_maps.gd` in particular is an offline
`SceneTree` script that writes PNGs to disk and never runs in the shipped game; `tools/**`
is excluded from the export by `export_presets.cfg` in any case.)

The codebase's one script-level texture cache — `scripts/effects/pulse_weapon_presentation.gd:39`,
`const VFX_ATLAS: Texture2D = preload(...)` — is the exact "`const` cache outliving
shutdown" pattern worth suspecting, and it is **not** the cause. Two independent results
clear it: instantiating `pulse_weapon_presentation.tscn` on its own leaks 0, and the
frame-1 probe-strip run below leaks 0 while `PulseWeaponPresentation` is still fully
present and initialised inside `main.tscn`.

### The owner

`ShipyardWorld` builds one `ReflectionProbe` at runtime:

- `scripts/world/shipyard_world.gd:2638` — `_build_central_reflection_probe()`
- called from `scripts/world/shipyard_world.gd:2356`, reached from `_ready()`

It is named `CentralBerthReflectionProbe`, `update_mode = UPDATE_ONCE`. It is the only
`ReflectionProbe` in the project.

Removing that one node before it ever renders takes the **real project** from 7 to 0:

| Real project, `scenes/main.tscn`, 30 frames | Leaked RIDs |
| --- | --- |
| unmodified | **7** |
| `ReflectionProbe` freed on frame 1 (1 node found) | **0** |

## Proof that it is engine-side

A trivial project — one `project.godot`, one `SceneTree` script, no imported assets:

| Empty-project scene content | Leaked RIDs |
| --- | --- |
| nothing | 0 |
| camera + box mesh | 0 |
| + `WorldEnvironment`, `BG_SKY`, `ProceduralSkyMaterial` | 0 |
| + glow (`glow_enabled`, intensity 0.45, bloom 0.08) | 0 |
| + `DirectionalLight3D` with `shadow_enabled` | 0 |
| **+ one stock `ReflectionProbe`, nothing else** | **7** |
| **four `ReflectionProbe`s** | **7** |
| one `ReflectionProbe`, freed at frame 10, 10 more frames rendered | **7** |

Three facts settle it:

1. **A single default-constructed `ReflectionProbe` in an otherwise empty project leaks
   all seven.** No project content is involved. The environment, sky, glow and shadow
   settings that `shipyard_world.gd` configures are all innocent — each was tested
   individually and leaks nothing.
2. **One probe and four probes both leak exactly seven.** The count does not scale with
   probe count, so this is a single shared reflection atlas allocated on first use, not
   a per-probe resource. That also explains why the count is a stable "7" across
   completely different scenes, harnesses, GPUs and drivers.
3. **Freeing the probe does not help.** Removing and `free()`-ing it ten frames before
   shutdown, then rendering ten more frames, still leaks seven. The application gave the
   engine every opportunity to release the atlas and it did not. There is therefore no
   teardown any game code could add that would clear this.

It is not driver-specific (llvmpipe/Vulkan 1.4.318 and RTX 5070 Ti/Vulkan 1.4.341 both
give 7) and not renderer-specific (**Forward+ and Forward Mobile both give 7**), which
points at the shared `RendererRD` reflection-atlas teardown path rather than anything
above it.

This matches a known upstream class of defect — RD-level RIDs surviving
`RenderingDevice::finalize()` in empty projects, e.g. godotengine/godot
[#89182](https://github.com/godotengine/godot/issues/89182) and
[#73577](https://github.com/godotengine/godot/issues/73577). No upstream issue naming
`ReflectionProbe` specifically was located; reporting one is a reasonable follow-up.

## Was the ROADMAP "known benign" characterisation correct?

**Conclusion right, reasoning wrong, and it was never actually attributed.**

`ROADMAP.md:313` calls it "the known seven-Texture-RID **llvmpipe** shutdown warning" and
`ROADMAP.md:314` "the known seven-Texture-RID **capture** warning". Both framings are
incorrect and both encouraged dismissal:

- It is **not an llvmpipe artifact.** It occurs identically on an RTX 5070 Ti under a
  real NVIDIA Vulkan driver. Attributing it to the software rasteriser implied it would
  vanish on real hardware; it did not, which is exactly why it resurfaced as an unowned
  finding in the package build record.
- It is **not a capture-harness artifact.** It occurs in the shipped game running its own
  main scene with no harness at all. It is a property of the product, not of the
  evidence tooling.

The severity call — benign — holds. It is seven RIDs, once, at `finalize()`, immediately
before the process exits and the OS reclaims everything. It does not grow with frame
count (300 vs 900 vs 20 all give 7), does not grow with probe count, and cannot reach a
long-running session because it only occurs during teardown. It is a cosmetic shutdown
diagnostic.

## No code change was made

Deliberately. The only way to remove the warning from our side would be to delete
`CentralBerthReflectionProbe` — a real visual regression to the central berth's hero
lighting in exchange for suppressing a cosmetic engine message — or to suppress the
warning outright. Both are the "papering over" this investigation was told to avoid, and
the third fact above proves no legitimate teardown would work anyway.

## What this does not establish

- **The exact seven RD textures were not individually named.** Godot 4.7.1 stable
  reports only a count; per-RID allocation tracking is a debug-build feature
  (`RID_HANDLE_ALLOC_TRACKING_DEBUG`) not compiled into the stable binary used here.
  "A shared reflection atlas" is inferred from the count's invariance to probe count,
  not read out of the engine. Confirming the precise allocations would need a
  tracking-enabled custom engine build.
- **Not re-verified on the Windows host.** The before/after counts above are Linux
  X11/Vulkan under lavapipe. The unmodified count (7) matches the recorded Windows count
  exactly, on both Forward+ and Mobile, but the "0 after removing the probe" figure was
  not re-measured natively on the RTX 5070 Ti.
- **No upstream fix or issue number** is claimed for `ReflectionProbe` specifically.

## Reproducing

The temporary bisection probe (`tests/zz_leak_probe.gd`) and the empty comparison project
were deliberately **not** committed — they are throwaway diagnostics, and `tests/` is
matrix-scanned. To rebuild the decisive experiment, create an empty Godot 4.7.1 project
whose `SceneTree` script adds a `Camera3D`, a `MeshInstance3D`, and one
`ReflectionProbe`, render ~20 frames, then quit:

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path <empty project> \
  --display-driver x11 --rendering-driver vulkan --audio-driver Dummy --script probe.gd
```

Add and remove the `ReflectionProbe` line to toggle the warning between 7 and 0.


## Guarded Linux engine build — 2026-10-15

The investigation above records the August baseline. [Upstream issue #122498](https://github.com/godotengine/godot/issues/122498) now identifies the same 4.7.1 build and missing reflection-atlas colour allocations. The [proposed upstream patch](https://github.com/godotengine/godot/commit/a2917e57c09a4341fed99d829495453ac6b8f9e9) is not treated as an officially released fix. Our [guarded derivative](../tools/release/patches/godot-4.7.1-reflection-atlas.patch) frees face framebuffers, face texture views and then the colour cube, checking RD ownership before each added free and clearing each stored handle. Independent source review confirmed that order and the ownership predicates. Inherited depth cleanup is unchanged; comprehensive allocation-failure recovery is not claimed.

[build_godot_reflection_fix.py](../tools/release/build_godot_reflection_fix.py) pins the official 4.7.1 source archive, SCons wheel and patch. Its default invocation prints a plan without writes or downloads. Run `python3 tools/release/build_godot_reflection_fix.py --build --jobs 4` for an isolated custom Linux editor; it uses one cache and private build tools, supports bounded cancellation/child cleanup, and never installs itself. An explicit release-template target is described below. Existing checks can select the printed binary through `GODOT_BIN`. Inputs and options are pinned; host compiler binaries are not, so byte-identical builds across hosts are not promised.

The actual build exited 0 in 932.533 seconds and reported `4.7.1.stable.mudds_reflection_atlas_a2917e5_guarded.a13da4feb`. Binary SHA256: `98d63f0184645244c2c7474871c5ef8bff057b60ccf793144edc5f0c3d8231f0`. All 37 installed-engine/template/preset pins remained unchanged and build actors closed. Cancellation and residual-child cleanup were also exercised with inert Linux children.

The first station attempt failed Vulkan initialization because private XDG search directories hid the installed driver manifest; its OpenGL fallback was rejected and the run was closed. A loader-only comparison reported no surface extension without an override, and the required extensions with explicit `VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.json`. The changed attempt retained private authenticated Xvfb, explicit X11, Forward+/Vulkan, Dummy audio and the original 900-second cap. It passed all 89 existing station checks on frozen game source `89ff44a9461137bb1f9b3b1fe940036b0a2cbcd5`, actual exit 0 in 313.472 seconds, one completion marker, zero errors and zero Texture-RID/resource-leak/invalid-ID diagnostics. The only warning was the standard superuser warning. Source/index/cache, binary and driver-manifest guards matched; all owned actors closed. The original `f399` traversal's seven leaked textures and the failed first attempt remain retained.

This qualifies the tested custom Linux editor's station shutdown under software Vulkan. It does not qualify native GPU performance, human visual review, Windows or exported runtime templates, and it does not waive the warning on unchanged official engines. Published checkpoints and default engines remain unchanged; final combined-source and distributed-build acceptance remain open.

## Private Linux release template and actual package — 2026-10-15

Release tooling committed in `a753ab08c` adds explicit `--target template_release`; the default remains the editor. The actual command `python3 tools/release/build_godot_reflection_fix.py --build --target template_release --jobs 4 --timeout 3600` succeeds in 605.258 seconds. Separate release logs/results preserve the original editor binary and receipts. The 91,156,904-byte release template and its conventional private-cache copy both have SHA256 `88e531f7b5a74759c25280d8f2fbb9a6dd8789b8cbdef3b40f60b835585732e0`. Installed templates remain unchanged.

The exporter accepts `GODOT_EXPORT_TEMPLATES_DIR` and `GODOT_EXPECTED_LINUX_TEMPLATE_SHA256`, checks the selected release template before and after export, and rejects a custom release override when pinned. Release export no longer requires an unused debug template. Twenty-six focused release-tool tests pass. The actual clean-source export exits 0 in 20.491 seconds. Independent read-only inspection checks all 1,513 embedded payload entries, the patched runtime code/data sections and safe archive contents. The executable SHA256 is `a119a146959206098dd53a0375de362f7b72c60afe2791394880e0f83f7204ab`; archive SHA256 is `6e0c93d3974470cf79def7c0962ece94d8a05ffdf10c64a80964c3bf314ee5de`. Export changes 215 import/editor cache paths, from 394 to 607 files; this normal transition is recorded rather than claimed unchanged.

Actual direct and archive headless startup pass in 9.373 and 9.281 seconds, each with exit 0 and exactly one `STARTUP_MENU_READY_OK`. Private desktop install/uninstall also passes under paths with spaces, with correct metadata/modes, saved data preserved and the entry removed. Installation checks do not launch the game.

The single cold rendered package startup uses authenticated private Xvfb, explicit X11/Forward+/Vulkan, lavapipe and Dummy audio. It reaches `Shipyard ready` at 287.418 seconds, then hits the original 300-second watchdog without menu readiness. This **fails rendered startup acceptance**; forced termination cannot qualify orderly reflection cleanup. The missing later `Opening title menu` marker narrows investigation to texture cleanup, loading-screen updates and the intervening process-frame await. It does not establish a shader or gameplay defect. No longer deadline, unchanged retry, graphics downgrade or publication is accepted.

Post-run source/index, the new 607-file cache, installed-engine/template/preset and staged/published artifact guards pass, and all recorded owned actors close. Failure receipt: `linux-export-a753ab0/native-qualification/linux-qualification.json` under the private engine cache (SHA256 `c15ec3cb030fb73c7e7e052a416589d23e64ee0e4185f919216138e7c888fed0`). Independent installation receipt SHA256: `489dd9d82af4ce26b9245cf632781f0e5600be5ef63968cadab891e2b582884f`. The package stays staged; published `3362f6f09` checkpoints remain unchanged. Rendered package acceptance, native GPU/Windows and human review remain open.


## Reconstructing a missing editor on a data volume — 2026-10-25

The previously recorded editor/build receipt is absent in the current environment;
its historical validation is retained, not treated as a live binary. The existing
builder now accepts `--cache-root` for reflection modes as well as RPC mode. A
canonical absolute owned non-symlink directory can place source/objects/private
profiles on a volume with room for compilation. The default remains unchanged;
RPC still requires its explicit root and separate platform directory. No HOME
replacement, global editor/template install, new patch or quality change.

```sh
python3 tools/release/build_godot_reflection_fix.py --build --jobs 4 --timeout 3600   --cache-root /srv/mudds-work/combat-reflection-capture-20261025/toolchain-build
```

The explicit-cache capability in `342ace33a` passes the existing 27 focused tests
(0.503 s supervised). The actual editor build exits 0 in 2,203.899 s, including
2,171.643 s SCons and the headless/Dummy version check. Archive, wheel, guarded
patch, patched target and editor-only options match the pinned contract. The
177,083,960-byte editor SHA256 is
`7b46e60fa1d4ddc979d35698a96d6cb16f79d03019ee5c84aaf24c98434c5f7d`.
It reports `4.7.1.stable.mudds_reflection_atlas_a2917e5_guarded.a13da4feb`.
The compiler emits the optional missing-msgfmt/.po fallback warning; no compiler
failure occurs. Host compiler binaries remain unpinned, so the historical binary
hash is not required to match. Independent receipt review GO.

ONE unchanged `capture_combat_visuals.gd` run uses its original 300 s limit,
Forward+/Vulkan/2560x1440, private authenticated Xvfb, explicit x11/Dummy and pinned
lavapipe. It **fails exit 124 after 300.846699 s**, zero images and zero completion
markers. Last checkpoint: Main instantiation. Code next attaches Main, settles
render frames, awaits physics and reconfigures the viewport before the next
logged check. The log cannot distinguish where time was spent or establish a
shader/gameplay cause. The only matched diagnostic is the supervisor timeout.
Forced termination does not qualify reflection shutdown, prove the RID warning
resolved, or permit pixel inspection. No retry, longer cap or quality downgrade.
Reopening requires an identified startup/render-delay cause, actionable correction
and independent/cumulative review. The old seven-frame evidence/warning remains.

Before/after source/index/cache match; capture cache has 651 entries unchanged.
Driver manifest and actual Vulkan library hashes also match. All three detached
owners are terminal and absent, with 2/10,548/5 observed descendant identities
absent for focused checks/build/capture. The accepted build capability is separate
from the failed capture; default editor and Linux template pins remain unchanged.
No default engine/template is installed or checkpoint regenerated.

The reusable editor, original receipt/build log and qualification limits are
intentionally retained in
`/srv/mudds-work/toolchains/godot-4.7.1-reflection-atlas-7b46e60/` (`godot`).
Original receipt paths describe the build location, subsequently removed.
Raw logs, frozen source/cache records, commands and results are byte-verified in
`/srv/mudds-work/combat-reflection-capture-20261025/records.tar.gz`;
source/object/private-profile scratch is removed. [Closeout](history/ROADMAP_DELIVERIES.md#reflection-editor-cache-and-combat-stop-20261025).
Published stock checkpoints, native GPU/Windows/human and full combined-source
acceptance do not inherit a custom-editor build result.
