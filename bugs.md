# Bug ledger

This ledger contains only unresolved or explicitly accepted issues. Fixed and closed records are removed once their fixes are verified.

## RENDER-001 — Seven `Texture` RIDs leak at `RenderingDevice::finalize()` on every rendered run — **ACCEPTED_RISK**

- Status: `ACCEPTED_RISK`. Severity: **P3**. Disposition: **accepted, engine-side, no code
  change** — see "Rationale for accepting" below.
- Reporter: package-build agent, 2026-08-15, from the native-Windows execution recorded in
  [`docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md`](docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md).
  Investigated and adjudicated 2026-08-15; recorded here 2026-08-16.
- Owner: **none required on this side.** Owned upstream (godotengine/godot). The one
  follow-up that would belong to a person here is filing an upstream issue naming
  `ReflectionProbe`, which the investigation notes was not located and is optional.
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
unprompted in today's `tests/capture_hero_cell.gd` verification runs for CAPTURE-001 below
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
[#73577](https://github.com/godotengine/godot/issues/73577). No upstream issue naming
`ReflectionProbe` specifically was located.

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

## CAPTURE-001 — `tests/capture_hero_cell.gd` cannot pass on this software-rendered environment — **PARTIALLY FIXED**

- Status: `PARTIALLY_FIXED`, **adjudicated 2026-08-16; collateral fixes reconciled
  2026-08-23**. The record no longer holds an
  unadjudicated hypothesis: the decisive experiment it named was run, the hypothesis was
  upheld in substance and wrong about which emitter, and that **gate-design defect is now
  fixed** in the harness with no threshold moved. The uncontrolled backdrop assertion was
  subsequently replaced with a controlled ship-material reference at the same threshold.
  One real-GPU adjudication remains. See "Adjudication" below. Severity: **P2**.
  Disposition: **still open for renderer qualification only**.
- Reporter: housekeeping agent, 2026-08-16. Independently reproduced here from a clean
  checkout before recording; a sibling agent had reported it first (stash-and-rerun on
  unmodified `main`) and this record does **not** rest on that report. Adjudicated the same
  day on `fcfa58e` by the capture-harness agent, from five completed rendered runs (A–D and
  a confirming F; one run aborted on X-display contention with a sibling worktree and is not
  counted).
- Owner: **needed.** Whoever calibrated `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION`,
  or the current owner of the hero-cell evidence path.
- Affected loop beat: **none in the shipped game.** This is developer tooling. It does not
  gate the matrix — `capture_hero_cell.gd` is not a `tests/*_test.gd` file, so
  `tools/release/run_test_matrix.sh` never runs it — and no player-facing behaviour is
  implicated. It is recorded because a harness that cannot pass on unmodified `main` is a
  trap: the next person to run it reads a red as their own regression.
- First affected source: unknown — no bisection was run, and the harness is only invoked
  by hand. Last confirmed affected source: `e57d207`, today, working tree clean apart from
  the two unrelated test-wait conversions in this same commit (neither is on the
  hero-cell path). Harness SHA-256
  `e6fd564acaa9651b58d96df2f45f9394e810eac535b6e615d897db7726636d34`.
- Affected artifact hashes: **none produced.** See "The harness publishes nothing on
  failure" below — that is part of the defect's cost.

### Environment

Single configuration; the second configuration this record would need to be a
`NOT_REPRODUCED`-grade adjudication is precisely the real-GPU box it was calibrated on,
which is not available here.

| | |
| --- | --- |
| OS | WSL2 Linux `6.18.33.2-microsoft-standard-WSL2` on Windows 11 |
| CPU | Intel Core i9-14900, 32 threads |
| RAM | 94 GiB usable |
| GPU / driver | **no `/dev/dri`** — Vulkan resolves to lavapipe, `llvmpipe (LLVM 20.1.2, 256 bits)`, Vulkan 1.4.318 |
| Renderer profile | `forward_plus` (as the documented invocation requires) |
| Display driver | `x11` under `xvfb-run -a -s "-screen 0 2560x1440x24"` |
| Audio | `Dummy` |
| Input | none — the harness scripts every state |
| Resolution | 2560×1440 (`--resolution 2560x1440`, `CAPTURE_RESOLUTION`) |
| User data | clean |
| Godot | 4.7.1.stable.official.a13da4feb |

### Steps

1. `godot --headless --path . --editor --quit` (a fresh worktree has no `.godot/`).
2. Run the invocation documented at `README.md:352`, with `--audio-driver Dummy` added so
   it is headless-safe:
   `xvfb-run -a -s '-screen 0 2560x1440x24' godot --path . --resolution 2560x1440
   --rendering-method forward_plus --audio-driver Dummy --script res://tests/capture_hero_cell.gd`
3. Read `$?` and the `HERO_CELL_FAIL` lines.

### Expected / actual

- **Expected:** `HERO_CELL_CAPTURE_OK: 18 HUD-off source-frozen Forward+ frames at
  2560x1440`, exit `0`, and 18 published PNGs plus both manifests in `artifacts/hero_cell/`.
- **Actual:** `HERO_CELL_CAPTURE_FAILED`, exit `1`, nothing published.

### Failure frequency — 3/3 here, 4/4 including the sibling's run

Every gated metric, across the three runs performed for this record:

| Metric | Gate | Run 1 | Run 2 | Run 3 | Sibling |
| --- | --- | --- | --- | --- | --- |
| `ship_luminance_p5` | `> 0.04` | n/c | 0.0440 ✅ | 0.0445 ✅ | **0.0339** ❌ |
| `ship_luminance_p95` | `< 0.95` | n/c | 0.7546 ✅ | 0.7546 ✅ | — |
| `graphite_background_delta` | `>= 0.08` | **0.0781** ❌ | **0.0781** ❌ | **0.0766** ❌ | **0.0620** ❌ |
| ship-mask clipped luminance | `< 0.005` | n/c | 0.0026 ✅ | 0.0029 ✅ | — |
| cockpit OFFLINE/ONLINE exterior | `<= 0.005` | n/c | 0.0044 ✅ | 0.0045 ✅ | — |
| cockpit ONLINE/CRITICAL exterior | `<= 0.005` | **0.4148** ❌ | **0.0511** ❌ | **0.3808** ❌ | **0.1485** ❌ |

`n/c` = not captured. Run 1's stdout was truncated before the per-metric `PASS` lines were
read; its two failing values are recovered from the aggregate `HERO_CELL_CAPTURE_FAILED`
line, which enumerates every failure, so run 1 is known to have failed on exactly those
two and no others. Runs 2 and 3 were captured in full. The sibling column is that agent's
reported figures, retained for comparison but not relied on.

Exit `1` in 3/3. Every other assertion in the suite passes, including the complete
recursive source-freeze roster (471-file class, byte-identical before and after the
capture) and all 18 frame captures.

### These are two different problems, not one

> Retained as recorded on `e57d207`. **Superseded by "Adjudication" below**, which measured
> all four metrics again after the station lighting scheme landed and found three
> independent causes, not two. The split below was right about the *shape* of the
> ONLINE/CRITICAL failure and wrong about the emitter behind it.

The "thresholds were calibrated on real GPU hardware and this box is llvmpipe" reading
covers **one** of the two failures and not the other. Both halves are recorded because
recalibrating the numbers would close only the first and leave the harness red.

1. **`graphite_background_delta` — consistent with a calibration mismatch.** Stable across
   runs (0.0766–0.0781, a 1.9% spread) and only ~4% short of the `0.08` gate. This is the
   shape of a threshold that was set with real headroom on a different rasteriser and has
   none here. `ship_luminance_p5` belongs to the same family: it sits *on* its gate
   (0.0440/0.0445 against `> 0.04`, ~10% headroom) and the sibling's 0.0339 shows it
   flipping. Recalibration is a plausible repair for both — but only an owner can decide
   whether to widen the gate or accept that these two are unmeasurable without a GPU.
2. **cockpit ONLINE/CRITICAL exterior — *not* a calibration mismatch.** It ranges
   **0.0511 → 0.4148 across three runs of identical input**, i.e. 10× to 83× over a gate
   of `0.005`, with an 8× run-to-run spread. No single threshold value fits that. Its
   sibling comparison, cockpit OFFLINE/ONLINE, uses the **same gate and the same code path**
   and passes stably at 0.0044/0.0044/0.0045. So the gate itself is satisfiable here; the
   ONLINE→CRITICAL pair specifically is not.

**Leading hypothesis for (2), stated as a hypothesis and not adjudicated:** the CRITICAL
frame is produced by `_torrent.apply_damage(_torrent.maximum_hull * 0.76)`
(`tests/capture_hero_cell.gd:588`), which drives the live production damage presentation.
If that presentation puts anything stochastic outside the hull — sparks, smoke, a particle
system — those pixels are exterior/world pixels by the mask's own definition, they change
between the two frames by design, and their count varies per run. The harness's own
recorded limitation says the raw all-pixels-outside metric is deliberately *not* gated
"because live warning/practical lights intentionally change opaque cockpit surfaces", and
carves the gate down to triangle-unoccluded exterior/world pixels; the same reasoning may
simply not have been extended to damage VFX, which are outside the hull rather than on it.
That would make this a **gate-design defect rather than an environment defect**, and it
would fail on real hardware too. Confirming or refuting it needs one run with the damage
presentation suppressed, which was not performed here.

### Adjudication — 2026-08-16, on `fcfa58e`

The decisive experiment was run. Everything above was measured on `e57d207`, which predates
the station lighting scheme (`1ff7df2`, merged `6cca05d`), so all four metrics were
re-measured first. **The lighting pass moved three of them, one of them by 40×**, which by
itself retires the "these numbers just need widening" reading: the graphite figure the
record calls "stable and ~4% short" is no longer 0.0766–0.0781 on `main`.

Re-measurement on `fcfa58e`, same box, same documented invocation:

Run A is unmodified `main` from a pristine copy (harness SHA-256 identical to the one this
record was filed against). Runs B–D carry the instrumentation and then the repair.

| Metric | Gate | on `e57d207` | run A (unmodified) | run B | run D (repaired) |
| --- | --- | --- | --- | --- | --- |
| `ship_luminance_p5` | `> 0.04` | 0.0440–0.0445 | **0.0829** ✅ | 0.0830 ✅ | 0.0830 ✅ |
| `ship_luminance_p95` | `< 0.95` | 0.7546 | 0.7593 ✅ | 0.7593 ✅ | 0.7593 ✅ |
| `graphite_background_delta` | `>= 0.08` | 0.0766–0.0781 ❌ | **0.0019** ❌ | **0.0006** ❌ | **0.0019** ❌ |
| ship-mask clipped luminance | `< 0.005` | 0.0026–0.0029 | 0.0011 ✅ | 0.0011 ✅ | 0.0011 ✅ |
| cockpit OFFLINE/ONLINE exterior | `<= 0.005` | 0.0044–0.0045 ✅ | **0.0074** ❌ | 0.0050 ✅ | **0.0074** ❌ |
| cockpit ONLINE/CRITICAL exterior | `<= 0.005` | 0.0511–0.4148 ❌ | **0.4534** ❌ | **0.2748** ❌ | **0.0052** ❌ |

`ship_luminance_p5` is no longer marginal: the lighting pass roughly doubled it and it now
clears its gate by 2×. That half of finding (1) is closed by the lighting pass, not by any
harness change.

Note what the last two rows do after the repair. ONLINE/CRITICAL drops from 0.4534 to
0.0052 and becomes **indistinguishable from its stable sibling** — the outlier that no
threshold could fit is gone, and what is left on both rows is one shared, different problem
described under "The remaining two failures".

**Verdict on the ONLINE/CRITICAL hypothesis: upheld in substance, wrong in its named
emitter.** The cause is the live production damage presentation, and it is a gate-design
defect that fails on real hardware too — but it is not the stochastic particles. Three
readbacks of the same frozen scene, with each candidate quiesced in turn, separate them:

| Readback of the identical frozen CRITICAL scene | exterior changed fraction |
| --- | --- |
| fully live production damage presentation | 0.2748 |
| `DamageSparks`/`EngineFailureSparks`/`EngineSmoke` hidden, damage lights still live | **0.3127** |
| every transient damage emitter quiesced (particles **and** the two damage lights) | **0.0051** |

Hiding the stochastic particles did not reduce the metric at all — it read *higher* than the
live frame, because the lights kept moving between readbacks. Quiescing the lights collapsed
it to the renderer's own noise floor. The emitters are
`HeroDamagePresentation.DamageWarningLight` and `EngineFailureLight`
(`scripts/effects/hero_damage_presentation.gd:419`), whose energies are
`(1.4 + pulse) * urgency` with `pulse = sin(elapsed * 13)`, and
`2.8 * clampf(0.48 + 0.28 * sin(elapsed * 29) + 0.18 * sin(elapsed * 61), 0.12, 0.88)`.
Both are pure functions of accumulated presentation time, so the energy at readback is
whatever phase the frame timing happens to land on — a 3.4× swing on the warning light
alone. That is exactly the shape of the 0.0511 → 0.4534 spread across runs of identical
input, and it reproduces on any GPU: the sinusoids do not care about the rasteriser.

The particles are real and do reach exterior pixels — `local_coords = false`, `spread`
165°/48°, `randomness` 0.58–0.72, and they are `CPUParticles3D`, which
`_cockpit_occluder_mesh_records()` cannot classify because it only collects
`MeshInstance3D` — but their contribution is inside the noise of the light pulse.

**Fixed, in the harness, without moving a threshold.** The exterior comparison exists to
prove the fixed camera, the craft pose and the frozen world are identical between the two
frames, so that the physical-display ROI change is attributable to the readout. Pulsing
damage illumination is neither the world nor the pose, so the gated comparison now uses the
deterministic half of the critical state: after the fully live
`18_cockpit_critical_fixed.png` is staged, the transient damage emitters are made invisible,
the fixed-camera contract is re-validated, and one extra unpublished frame is read back for
the control (`_capture_cockpit_critical_exterior_control`). This is the same carve-out the
harness already documents for the raw outside-ROI metric — "live warning/practical lights
intentionally change opaque cockpit surfaces" — carried the rest of the way, because those
lights do not stop at the cockpit surfaces. `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION`
is **unchanged at 0.005**, the published critical frame is **unchanged and fully live**, and
the live exterior number is still measured and recorded as
`cockpit_online_critical_live_damage_exterior_world_non_gated` so nothing is hidden.

Measured on the repaired harness, three runs: live 0.4705 / 0.2765 / 0.4312 (recorded,
non-gated), transient emitters quiesced **0.0026 / 0.0052 / 0.0053** against the same
unchanged 0.005 gate — the live figure still swings by 1.7×, the gated one no longer moves
in the third decimal. That separation is the whole result. The
metric that ranged over an 8× spread across runs of identical input now lands inside the
renderer's own noise band, alongside the sibling comparison that was always stable. Run D
still trips the gate at 0.0052 — but for the reason the sibling trips it at 0.0074, not for
the reason this comparison used to.

### The remaining two failures, and why neither was "fixed" here

**(1) `graphite_background_delta` was not recalibrated, deliberately.** The gate is
`abs(graphite_median - background_median) >= 0.08`, where `background` is every mask sample
that did *not* hit the ship — i.e. whatever the station happens to put behind it. On
`fcfa58e` those two medians are `graphite 0.153652` and `background 0.153013`: the backdrop
has drifted onto the same luminance as the material, and the delta is 0.0006. Nothing about
the graphite material changed; the station lighting scheme did. The same run measures
`ivory_luminance_median 0.575780` against that graphite, so the ship's own material
separation is 0.42 and in excellent health — the material contrast this gate is presumably
meant to protect is not in trouble at all.

So the gate fails the "is it measuring the right thing" test: it benchmarks a ship material
against an uncontrolled backdrop, which makes it a property of the scenery, not of the
craft. Widening it to 0.0006 — or to anything — would be recalibrating to match a broken
measurement, which is worse than leaving it red. The repair is to give it a controlled
reference (the ivory/graphite separation is the obvious candidate, and is robust), but that
changes what the harness asserts and is an owner call.

**Resolved in the harness after adjudication, without changing a threshold.**
`graphite_background_delta` is now diagnostic-only. The acceptance check is
`ivory_graphite_delta >= 0.08`, computed from the same triangle-masked opaque
`WarmIvoryHull`/`IvorySecondary` and `GraphiteMachinery` samples already required by the
crop contract. This preserves the material-separation intent while removing the station
lighting/backdrop from the result. The 0.08 floor, ship-luminance thresholds, and cockpit ROI
thresholds were not moved. If a graphical renderer is unavailable, the harness now exits
failed before it enters its frame-post-draw readback path rather than waiting indefinitely.

**(2) The cockpit exterior gate has no headroom over this box's renderer noise floor.** This
now covers *both* exterior rows. The repaired harness measures the floor every run and
prints it: two readbacks of a single **unchanged** ONLINE state — zero scene difference,
zero state change — compared through the same exterior mask.

| Run | settle frames | measured noise floor | OFFLINE/ONLINE, same run | ONLINE/CRITICAL quiesced, same run |
| --- | --- | --- | --- | --- |
| B | 8 | 0.0044 | 0.0050 | 0.0051 (diagnostic) |
| C | 48 | 0.0124 | 0.0115 | 0.0026 |
| D | 8 | 0.0120 | 0.0074 | 0.0052 |
| F | 8 | 0.0121 | 0.0072 | 0.0053 |

The floor is **0.0044–0.0124 against a gate of 0.005**, and every gated exterior figure now
sits inside that band. Runs D and F are the same shipped harness and reproduce each other to
three decimals on every one of these figures, so what is left is stable and measurable — it
is simply larger than the gate. That settles what these comparisons are measuring on this box:
**renderer noise, and nothing else.** TAA is enabled on the capture viewport
(`_configure_native_capture` sets `root.use_taa = true`) and never stops jittering, so a
deliberately frozen scene is simply not reproducible below the gate here.

Settling longer was tried as a candidate repair and bought nothing — 8 frames gave 0.0044
and 0.0120 on two runs, 48 frames gave 0.0124 on one, so the floor is unstable run to run
and independent of the settle length, while 48 frames cost roughly three times the harness
runtime. `COCKPIT_DIFFERENTIAL_SETTLE_FRAMES` therefore stays at the original 8, with the
measurement recorded in the constant's comment so the next person does not repeat the
experiment. The floor is recorded, never gated: the harness does not get to pass by
declaring its own noise acceptable.

This one **is** genuinely environment-shaped — a real GPU with a stable TAA history would
plausibly sit far below 0.005 — but it cannot be adjudicated from one rasteriser, and the
gate value was not touched.

### The harness publishes nothing on failure and cleans its staging

The capture is transactional. All 18 PNGs are written to
`artifacts/hero_cell/.capture_transaction/` and promoted only after every check passes. A
new failing run publishes no frames and cannot authenticate frames from an older run: it
invalidates `source_manifest.sha256` and `evidence_manifest.json` before renderer setup,
then removes transaction staging before its terminal result. Previously published PNGs may
remain for diagnosis, but without those manifests they are not current evidence.

Two consequences are now explicit:

- There is no authenticated `log/image path + hash` evidence to cite for a failed run, which
  is why the metric table above is the durable anchor. (`artifacts/` is gitignored in any
  case; the package build record uses the same hashes-as-anchor convention.)
- Successful bounded cleanup prevents a rerun from inheriting stale transaction files. If
  cleanup cannot complete, that failure joins the terminal failure list and the process
  exits `1`; it never turns a failed or interrupted capture green.

The earlier metrics repair remains in place: the harness prints every measurement it took,
on both paths, as `HERO_CELL_METRICS:` lines carrying the full JSON of
`ship_mask_lighting` and every pair comparison, including non-gated diagnostics.

### Linked reproducer / regression

The reproducer is the three numbered steps above. **No regression was added**, deliberately:
a `tests/*_test.gd` asserting that the hero-cell harness currently fails would land inside
the matrix glob and turn a tooling defect into a gate, and it would go red the moment the
harness is repaired. The correct regression is the harness itself, once an owner has
decided what it should assert on a GPU-less box. That reasoning is unchanged by the
adjudication: the ONLINE/CRITICAL repair is a change to `tests/capture_hero_cell.gd` and its
regression is the harness's own `HERO_CELL_CAPTURE_OK` line, which the matrix structurally
cannot run and should not be made to.

### What would close this record

1. `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION` adjudicated against a real GPU, where the
   printed noise floor can be compared with this box's 0.0044–0.0124. If the floor there is
   an order of magnitude below the gate, the gate is right and this box is simply not a
   valid platform for it — which is a documentation change, not a threshold change.

The ONLINE/CRITICAL **gate-design** defect is closed and needs nothing further; what remains
on that row is item 2 above, shared with its sibling. `graphite_background_delta` is now
diagnostic-only, while the controlled `ivory_graphite_delta >= 0.08` material-separation
gate remains. The harness can still exit `1` on this box when either exterior comparison
exceeds `0.005`; real-GPU renderer qualification is the only open item in this record.
