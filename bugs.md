# Bug ledger

This ledger contains only unresolved or explicitly accepted issues. Fixed and closed records are removed once their fixes are verified.

## INPUT-RECOVERY — Begin can board a saved on-foot player — **VERIFYING**

- Severity: **P1**; owner/reporter: root, 2026-10-16. Observed on source `2625eb246` and the published `eadc150` PCK; fixed `1461227` PCK passes the focused recovery regression.
- Reproduction: persist an on-foot home-berth context with reduced motion enabled, restart, then press and release the ordinary Interact binding once to Begin. Expected: restore controllable on-foot play. Actual: the same press emits a gameplay interaction and boards the nearby Torrent. The rendered run changes from saved `on_foot`, unseated/INTRO to seated/piloting/START_ENGINES. A separate cold-load regression reproduces the extra interaction before any fix.
- Cause: HUD handles Begin, but newly enabled Player input independently polls its global just-pressed Interact edge. On-foot recovery places the player beside the craft; only a saved `pilot` context should initiate automatic boarding.
- Environment: WSL2 Linux 6.18.40.1, Intel i9-14900, 94.1 GiB RAM, experimental Dozen/Microsoft Direct3D12 RTX 5070 Ti, pinned editor `6fdc84b5f6f178bd454c77ebaf5d3dd51e62c0ffd9b919d6ab8ea66c1c7c1fca`, private 3200×1800 X11 screen (application viewport not captured), Dummy audio and isolated saved profile. Native Windows/device qualification is not implied.
- Witness: `/root/.cache/mudds-shipyards/roadmap-validation/aurora-client-hud-retirement/stable-custom-full/settings-reentry-reader-walk-trace/settings-reentry-input-route.log`, SHA-256 `6416d846eb0591cba88e0ccac4a546d5e47765341ee9e2fa89539e1e03ae2389`. The on-foot context and resulting pilot state are logged immediately before/after Begin; all integrity and cleanup guards pass. Focused regression output: `begin-recovery-input-red/` beside that run.
- Fix candidate: Player fences an inherited Interact edge when controls become enabled, observes physical releases before GUI routing, and accepts a fresh release/repress even before the next physics tick. The cold-load regression fails on both keyboard and gamepad with reduced motion before the fix; all four keyboard/gamepad × motion cases pass after it. The default camera suite includes the regression; it and station-interaction/sleep checks pass (129 assertions across four commands), with source/cache/user-data guards unchanged. Results: `begin-recovery-input-red/` and `begin-recovery-input-green/` beside the witness.
- Package acceptance: the old published `eadc150` PCK reproduces the four expected reduced-motion keyboard/gamepad assertions; all four cold-recovery cases pass on the matching `1461227` PCK (40 assertions, exit 0, zero diagnostics). Both runs use the Linux editor, preserve all source/package/cache/user-data guards and leave no owned actors. Logs: `begin-input-published-eadc150-red/` and `begin-input-published-1461227-green/` beside the witness. Matching Windows/Linux checkpoints are published with identical 1,513 game payloads; only the Player script differs from the old content.
- Rendered recovery on packaged `0355c19`: the existing real profile resumes from saved `on_foot`, unseated/INTRO to controllable `on_foot`, unseated/APPROACH_SHIP after one native keyboard Begin press. Preferences and all desktop/gamepad on-foot controls pass. The separate Arrow approach subsequently fails against cargo-transfer machinery; the overall reader remains FAIL. All source/PCK/cache/user-data guards pass and owned actors close. Witness: `settings-reentry-supported-arrow-0355/settings-reentry-input-route.log` beside the earlier runs, SHA-256 `40026c054c44da028f2dc8a2696234d99483eb1b95b462c2f8c7ab3617c8a902`. Its successful settings writer ran on older source; this does not qualify the complete current Settings journey.
- Latest packaged `07305ea0e` diagnostic again restores on-foot controls and physically walks the supported Arrow route in 556/705 ticks, then boards normally. The old failed fixture had crossed machinery and the raised registry deck side; the corrected route uses existing clearances and Arrow ground waypoints. The whole reader still fails its mouse assertion; a later diagnostic establishes a test observation error: all four consumed motions rotate both hull axes, followed by neutral commands before the assertion polls. The corrected observation and complete Settings replay remain pending; the successful writer ran on older source.
- Remaining: full current-source regression and complete core-journey acceptance. No movement tuning, saved location or binding was changed to obtain the Begin-fix results.

## RENDER-002 — Pending reflection captures outlive a retained scenario — **VERIFYING**

- Severity: **P2**; owner: root. Reported 2026-10-15 during the current five-feature integration, based on `814fc5e7d`.
- Reproduction: run `tests/caption_production_integration_test.gd` with Dummy audio, X11 and Forward+ on an isolated display. Its existing whole-Main detach/re-entry scenario removes Main while reflection captures are pending, then reattaches it.
- Expected: detached probes retire their queued work and capture again after re-entry without renderer diagnostics. Actual: exit 0 and 35 assertions, but two `Parameter "scenario" is null` errors from `renderer_scene_cull.cpp:3780`. The headless equivalent passes all 35 checks without diagnostics; this does not qualify rendered re-entry.
- Confirmed environment: WSL, experimental Dozen/Microsoft Direct3D12 RTX 5070 Ti, pinned mesh-revision editor SHA-256 `ddfdd7a08c4d2a9b4cc546537a2adc92e70414339b49f880bd9c0c366a472d32`, private X11 display, Dummy audio and isolated user profile. No physical controller, audible or native Windows qualification is implied.
- Preserved log: `/root/.cache/mudds-shipyards/roadmap-validation/aurora-client-hud-retirement/stable-custom-full/parallel-five-ui-reviewed/caption_production_integration_test.log`, SHA-256 `c8a4d234d8f5c0ab3deff9e7b8fc2f2f66ea14cf44b4f6f4fd20d3026d61bab8`.
- Cause: the engine's scenario-removal reflection-probe branch releases its atlas entry but leaves its pending update linked; subsequent rendering consumes that entry after the scenario is cleared. Instance destruction already removes it, so retained detach needs equivalent cleanup.
- Fix: `673efcc93` adds the native queue unlink and an opt-in `--retained-probe-lifecycle` build mode. All 14 recipe checks pass. The separate editor built successfully (SHA-256 `6fdc84b5f6f178bd454c77ebaf5d3dd51e62c0ffd9b919d6ab8ea66c1c7c1fca`); existing engines/templates remain unchanged.
- Editor acceptance on `eadc15034`, 2026-10-16: the original rendered lifecycle passes 35 assertions, exit 0 and zero errors in 103.437 seconds. A separate diagnostic run passes 37 assertions, exit 0 and zero errors in 147.938 seconds: its detached interval contains one GPU report with no reflection work, followed by fresh capture Steps 1–7 after re-entry. Only that diagnostic fixture raises timestamp-query capacity to 4096; the original lifecycle remains unmodified. Both runs preserve source, package, cache, engine, driver and user-data guards and leave no owned actors. Logs and receipts: `/root/.cache/mudds-shipyards/reflection-reentry-profile-review/eadc-rendered-lifecycle/` and `eadc-rendered-profile-capacity/`. The earlier 256-query profiler overflow remains a failed diagnostic run.
- Release template built separately on 2026-10-16 (SHA-256 `802689d78eb21db34e02e7c5631154121eacfa46c62471cc604c06a03dae066c`). The distinct `4fa5006-probe-fix` Linux candidate passes direct and archive-extracted strict startup (exit 0, one menu-ready marker, zero errors). Its native code sections match the template and all 1,513 packaged payloads match the earlier `eadc15034` content. Receipts: `/root/.cache/mudds-shipyards/roadmap-validation/shared-visit-restoration/linux-4fa5006-probe-fix-headless/`. This establishes native headless package startup, not rendered template lifecycle acceptance.
- Release acceptance on `07305ea0e`, 2026-10-16: the actual Linux executable passes the private packaged `--reflection-reentry-check` in 160.725 seconds, exit 0, one success marker and zero errors. The same Main, five probes and production settings owner survive pending-capture cancellation and re-entry; two quiet GPU reports contain no reflection work, followed by 34 fresh reports with Steps 1–7. All 24 guards pass and no owned actors remain. Only the diagnostic timestamp-query capacity is raised to 4096. Receipts: `/root/.cache/mudds-shipyards/reflection-reentry-profile-review/07305ea-native-release/`.
- Remaining acceptance: full current-source regression and applicable target-hardware qualification. Windows runtime is unchanged and native Windows execution remains unperformed. This bounded Linux lifecycle result and the clean editor station capture do not establish a causal link to the earlier colour corruption.

## RENDER-001 — Seven `Texture` RIDs leak at `RenderingDevice::finalize()` on every rendered run — **ACCEPTED_RISK**

- Status: `ACCEPTED_RISK`. Severity: **P3**. Disposition: **accepted, engine-side, no code
  change** — see "Rationale for accepting" below.
- Reporter: package-build agent, 2026-08-15, from the native-Windows execution recorded in
  [`docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md`](docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md).
  Investigated and adjudicated 2026-08-15; recorded here 2026-08-16.
- Owner: **none required on this side.** Tracked upstream in
  [godotengine/godot#122498](https://github.com/godotengine/godot/issues/122498).
- Affected loop beat: **none.** It occurs only during process teardown, after every beat
  (begin shift, walk, board, start, launch, fly, fire, return, land, shut down, disembark)
  has already completed. No player-observable behaviour is involved at any beat.
- First affected source: unknown — the warning predates the records that name it, and both
  earlier ROADMAP mentions misattributed it (see below), so no first-bad commit was
  bisected. Last confirmed affected source: `e57d207` (this worktree's `main`), reproduced
  today. The package-build observation was on `ef5450c`.
- Affected artifact hashes: Windows GUI EXE `gateE-20260815-ef5450c`, SHA-256
  `2325f175e336c70bda247ccba3d4617867fad19c962772d09928e7f9fb929583`, 153,713,144 bytes,
  PE version `0.12.0.0`, embedded PCK sorted-path manifest SHA-256
  `dc0800edfdf7a553d98e8b398d493461ef7e9eaa7dd1f309debb9466fde34684`.
- Nearest owning source in this repo (**not** the defect):
  `scripts/world/shipyard_world.gd` (SHA-256
  `76b58bde7e53ff670b7ffdb5883fa808be344524e2253ee069cb7c720d6b3821`),
  `_build_central_reflection_probe()` at `:2638`, called from `:2356` via `_ready()`.
  It builds `CentralBerthReflectionProbe`, `update_mode = UPDATE_ONCE`, the only
  `ReflectionProbe` in the project.

### Current verification — 2026-09-06

Still reproduced on Godot `4.7.1.stable.official.a13da4feb` at source
`eb7416a8f`: a temporary empty project containing a camera, box mesh, and stock
`ReflectionProbe` rendered for 30 frames using Forward+ on llvmpipe, exited `0`,
and reported seven leaked Texture RIDs. The identical project with the probe
removed exited `0` without the warning. This remains an engine-side accepted
risk, not a confirmed fix. The completed native Windows RTX 5070 Ti and
Linux llvmpipe hero-cell captures also reported the same seven shutdown RIDs.

The dated source descriptions in this record are historical: the current world builds the
central probe plus four module probes. The default scene is now `scenes/boot.tscn`;
a default-scene run must enter the shipyard before it exercises these probes.

### Upstream repair candidate — checked 2026-09-06

[godotengine/godot#122498](https://github.com/godotengine/godot/issues/122498),
opened 2026-08-17, now reports this exact seven-Texture-RID leak on the same
`4.7.1.stable.official.a13da4feb` engine. It identifies missing cleanup of the
reflection atlas's six color views and color buffer and proposes freeing them
and their framebuffers in `LightStorage::_reflection_atlas_clear()`.

The official `4.7.1-stable` source was inspected independently: these resources
are allocated but omitted from that cleanup function. The issue is still open,
with no linked pull request or milestone; no released repair was found in the
bounded upstream review. The proposed patch is **not build- or runtime-verified
here** and does not close this record.

Using that patch locally would require building and qualifying a custom Godot
editor and matching Windows export templates. Selecting a patched editor with
`GODOT_BIN` alone would not fix the shipped executable: the current export
preset still selects the stock templates.

**User decision — 2026-09-06: keep official Godot.** Continue using official
Godot releases and matching official Windows export templates. Retain
`RENDER-001` as an accepted risk until a fixed official release is qualified.
This resolves the dependency choice for the bug review: this entry is an
explicitly accepted exception, not a verified fix, and remains in the ledger.

### Environment — two documented configurations, identical result

| | Configuration A (native Windows) | Configuration B (this box) |
| --- | --- | --- |
| OS | Windows 11 `10.0.26200.9168` | WSL2 Linux `6.18.33.2-microsoft-standard-WSL2` |
| CPU | Intel Core i9-14900 (32 threads) | same host, 32 threads |
| RAM | 94 GiB usable, 24 GiB swap | 94 GiB usable |
| GPU / driver | NVIDIA GeForce RTX 5070 Ti, Vulkan 1.4.341 | no `/dev/dri`; lavapipe `llvmpipe (LLVM 20.1.2, 256 bits)`, Vulkan 1.4.318 |
| Renderer profile | Forward+ | Forward+ **and** Forward Mobile, both tested |
| Display driver | as recorded: `--headless --quit-after 300` (see note) | `x11` under `xvfb-run` |
| Audio | `Dummy` | `Dummy` |
| Input | none (headless) | none (headless / scripted) |
| Resolution | default | 1280×720, 1920×1080 and 2560×1440 all tested |
| User data | clean | clean |
| Godot | 4.7.1.stable.official.a13da4feb | 4.7.1.stable.official.a13da4feb |

The count is **7 on both**, which is itself load-bearing evidence: it is neither an
llvmpipe artifact nor GPU-specific.

**Note on configuration A, unresolved:** the recorded native-Windows invocation passes
`--headless`, yet its banner reads `Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA -
NVIDIA GeForce RTX 5070 Ti` and it leaks 7. On Linux, `--headless` creates no rendering
device and leaks 0, which is the whole reason the matrix cannot see this. Whether the
exported Windows template treats the flag differently, or the flag was ineffective in that
interop invocation, was **not** determined. It does not affect the verdict — configuration
B reproduces the leak with an unambiguously real rendering device — but it should not be
read as "`--headless` opens a rendering device", because that is not established.

### Steps

1. Ensure `.godot/` exists: `godot --headless --path . --editor --quit`.
2. Run the shipped main scene with a real rendering device and no harness:
   `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --display-driver x11
   --rendering-driver vulkan --audio-driver Dummy --quit-after 300`.
3. Read the last two lines of stderr.
4. Repeat with `--quit-after 900`, and with `--rendering-method mobile`.

### Expected / actual

- **Expected:** the process exits `0` with no `Leaked` diagnostic. The playable-prototype
  gate in [`ROADMAP.md`](ROADMAP.md) names "resource-leak" diagnostics explicitly.
- **Actual:** exit `0`, and always:

  ```
  WARNING: 7 RIDs of type "Texture" were leaked.
     at: finalize (servers/rendering/rendering_device.cpp:8900)
  ```

### Failure frequency

Deterministic — but stated precisely rather than as a "10/10", because no single scenario
was run ten times. **Every** rendered run in the investigation's tables and every rendered
run performed for this record produced exactly 7, and no rendered run has ever produced a
different non-zero count: 7 at 20, 300 and 900 frames; 7 on Forward+ and on Forward
Mobile; 7 on llvmpipe and on the RTX 5070 Ti; 7 with one `ReflectionProbe` and 7 with
four; 7 from four different capture harnesses that load `ShipyardWorld`. Runs that never
render `ShipyardWorld`, and every `--headless` Linux run, produce 0. It was observed again
unprompted in today's `tests/capture_hero_cell.gd` verification runs for the now-closed CAPTURE-001
— an independent sighting on `e57d207`.

### Root cause — engine-side, proven by an empty-project reproduction

Full investigation, including the bisection table and the ruled-out candidates:
[`docs/TEXTURE_RID_LEAK_INVESTIGATION_20260815.md`](docs/TEXTURE_RID_LEAK_INVESTIGATION_20260815.md)
(SHA-256 `d130a8229157344a6ff1604fd887763b98cb8a1b1e69a40d82530464c94fc344`).

A ~70-line project containing only a `Camera3D`, a `MeshInstance3D` and **one stock
`ReflectionProbe`** leaks all seven. Three facts settle the attribution:

1. **No project content is involved.** `WorldEnvironment`, `BG_SKY`,
   `ProceduralSkyMaterial`, glow, and a shadow-casting `DirectionalLight3D` were each
   tested individually in that empty project and leak **0**. Adding the probe alone takes
   it to 7.
2. **The count does not scale with probe count.** One probe and four probes both leak
   exactly 7, so this is a single shared reflection atlas allocated on first use, not a
   per-probe resource. That also explains the stable "7" across unrelated scenes,
   harnesses, GPUs and drivers.
3. **Freeing the probe does not clear it.** Removing and `free()`-ing the probe ten frames
   before shutdown and rendering ten more frames still leaks 7. There is therefore no
   teardown any game code could add.

`Node.print_orphan_nodes()` printed nothing in every run — no `Node`s leak. The repo has
no `static var`s, no runtime `ImageTexture`/`NoiseTexture2D`/`GradientTexture`
construction in `scripts/`, no `SubViewport`/`ViewportTexture` outside `tests/`, and one
read-only `RenderingServer` call
(`scripts/rendering/visual_quality_controller.gd:119`). The one `const Texture2D`
cache — `scripts/effects/pulse_weapon_presentation.gd:39` — was suspected and cleared
twice independently.

Upstream references for the same class (RD-level RIDs surviving
`RenderingDevice::finalize()` in trivial projects): godotengine/godot
[#89182](https://github.com/godotengine/godot/issues/89182),
[#73577](https://github.com/godotengine/godot/issues/73577). At the original investigation date, no upstream issue naming
`ReflectionProbe` specifically was located. The matching issue found on
2026-09-06 is linked above.

### Rationale for accepting

- It is **bounded and fixed**: seven RIDs, once, at `finalize()`, immediately before the
  process exits and the OS reclaims everything. It does not grow with frame count, does
  not grow with probe count, and cannot reach a long-running session because it happens
  only during teardown.
- **No application-side repair exists.** Fact 3 above rules out teardown ordering. The
  only remaining levers are deleting `CentralBerthReflectionProbe` — a real visual
  regression to the central berth's hero lighting, traded for suppressing a cosmetic
  engine message — or suppressing the warning. Both are papering over.
- Two earlier characterisations were **wrong in their reasoning** and are corrected here:
  `ROADMAP.md` called it "the known seven-Texture-RID **llvmpipe** shutdown warning" and
  "the known seven-Texture-RID **capture** warning". It occurs identically on an RTX
  5070 Ti under a real NVIDIA driver, and it occurs in the shipped game running its own
  main scene with no harness. The severity call was right; the attribution was not, which
  is exactly why it kept resurfacing as an unowned finding.

### Known limits of this record

- The seven RD textures were **not individually named.** Godot 4.7.1 stable reports only a
  count; per-RID tracking is `RID_HANDLE_ALLOC_TRACKING_DEBUG`, a debug-build feature not
  compiled into the stable binary used here. "A shared reflection atlas" is inferred from
  the count's invariance to probe count, not read out of the engine.
- The **"0 after removing the probe" figure was measured only under lavapipe**, not
  re-measured natively on the RTX 5070 Ti. The unmodified count (7) does match the Windows
  record exactly.
- This collides with the literal wording of the playable-prototype gate ("no ...
  resource-leak ... diagnostics"). That gate wording needs an explicit carve-out for this
  shutdown warning, or every future rendered candidate run will re-open the same
  adjudication. Recorded, not silently absorbed.

### Linked reproducer / regression

**None, deliberately.** The bisection probe (`tests/zz_leak_probe.gd`) and the empty
comparison project were not committed: `tests/` is matrix-scanned and a permanent
regression asserting "the engine still leaks 7" would fail the moment upstream fixes it,
which is the wrong direction for a gate. The reproduction is the four numbered steps
above plus the empty-project recipe at the end of the investigation document. The headless
matrix structurally cannot see this — `--headless` creates no rendering device — which is
why `tools/release/run_test_matrix.sh` stays clean and is not a regression on it.
