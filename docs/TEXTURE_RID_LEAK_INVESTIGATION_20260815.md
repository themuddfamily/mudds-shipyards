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
