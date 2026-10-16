# Git branch review — 16 October 2026

Reviewed the initial 1,220 local branches, 254 origin branches, and one orphan
remote-tracking ref against main.
The starting main was `f140ff2b0`; another session merged the feedback/capture
branch as `891cdf109` during the inventory. Recovered work builds on that merge.

## Decisions

Most divergent history was already cherry-picked: 1,031 refs were patch-equivalent
to main and 176 refs were ancestors. The remaining 269 refs (228 distinct tips)
received grouped runtime, content, recovery, and network review, including
simulated merges and explicit comparison with successor implementations.
Commit subjects alone were not used to authorize deletion.

The following useful changes were recovered selectively, preserving current
contracts instead of merging old candidate stacks:

- Aft watch-rack knob and roof-collar batching; Habitat collar batching.
- Shared bomber fin geometry and composite Operations notice sheets.
- Formed exterior ribs on the abandoned hulk.
- A steady hostile-approach chevron on the defense beacon.
- A guarded Salvage breaker overlook adapted to the current compact pad,
  adding 15 m² and two route markers.
- Canonical shared-craft pose coordinates, protection against host reboarding
  while Ember crew remain outside, and actual host-exit receipt waiting.
- Atmospheric/airless guidance handling for nested transition snapshots and
  generic airless worlds.
- Missing sprint-toggle re-entry coverage, isolated survey-lifecycle persistence,
  and safe refusal of linked capture-output trees before recursive cleanup.
- Dispatch-only workflow definitions supporting the existing GitHub CI hold.

Old diagnostic/prototype stacks were archived where their production outcomes
already exist. The unfinished Ember movement prototype was superseded by the
current physical flight and planetary lifecycle implementations. The old compact
fleet layout conflicts with the subsequent freight-apron/launch-lane restoration
and was not replayed. The VIP revert merges to an identical main tree.

`agent/zenith-finish` remains a unique optional satin-paint alternative. It is
preserved for an art decision rather than mixed into the recovered functional
changes. Locked and dirty linked-worktree branches are also preserved. Clean
worktrees whose branch was retired remain on the same commit with detached HEAD;
their files and ignored artifacts were not removed.

## Validation

Focused headless tests use Dummy audio throughout. Passing checks include:

- Aft, Habitat, bomber presentation (60 assertions), and hulk gameplay (76).
- Operations composite and full activity; defense lifecycle/content. The beacon
  cue also passed isolated Xvfb x11 Forward+ capture under llvmpipe.
- Shared station-frame independent peers (186 assertions), orbital rounding,
  host reboard refusal, and delayed-exit handling.
- Entry guidance (12) and its production Arrow caller (14).
- Seven feedback/UI suites. Survey lifecycle initially failed because it read
  existing saved rewards; the same failure reproduced on the original `f140`
  fixture. An isolated production store fixes the fixture; all 41 checks pass.
- Sprint-toggle GameFlow re-entry (6).
- Salvage gameplay (136), surface playability, route registry, and integrated
  walkable census: 84 surfaces, six ramps, 420/420 support samples, below 23%
  station expansion.
- Integrated triplanar/material checks (25). Counts reconcile the actual batches
  and restored Salvage ring; UV and material-recipe checks retain their strictness.
- Capture cleanup/routing probes reject intact and broken links and preserve
  outside/staged sentinel files. `git diff --check` passes.

No hosted CI was enabled or dispatched. Native GPU performance, real-controller
hardware, full canonical packaged multiplayer journeys, human visual/gameplay
review, and the complete project regression matrix remain **NOT_RUN**. Source
peer tests do not qualify mixed-version packages.

## Recovery and audit

The complete pre-cleanup branch history is preserved in the verified bundle:

`/root/.cache/mudds-shipyards/branches-before-review-20261016.bundle`

The persistent review directory contains the original ref/SHA inventory, per-ref
decisions, deletion records, reports and validation logs:

`/root/.cache/mudds-shipyards/branch-review-20261016/`

To inspect archived branch names, use `git bundle list-heads` on the bundle. To
restore a branch without changing the working tree, fetch its exact archived
`refs/heads/<name>` into a new local branch. Uncommitted work remains in its
original worktree and is not represented by the bundle.

## Completed cleanup and checkpoint

This review deleted **1,207 local branches and 252 origin branches**, plus the
superseded orphan `origin-local/main` tracking ref. The concurrent session deleted
the feedback branch locally and remotely after merging it. Origin now contains
only `main`. There are 12 local branches: main, nine locked worktree branches,
one dirty worktree branch, and the unique Zenith material alternative.

Recovered source is committed and pushed as `807851f919217e9fa4f2b167439a2bc416cc5ca5`.
The original untracked skills, marketing and handoff files remain untouched.

The clean-source Windows checkpoint is in `builds/windows/`:

- `MuddsShipyards-807851f.exe`
- `MuddsShipyards-807851f-checkpoint.zip`
- `MuddsShipyards-807851f-notes.txt`

The final ZIP passes integrity and embedded EXE hash checks. Its extracted native
Windows EXE passed silent headless startup from a temporary package and profile:
exit 0, exactly one `STARTUP_MENU_READY_OK`, no engine/script/leak diagnostics,
and a 180-second abort deadline. No graphical desktop was opened. This does not
qualify native GPU performance or the full Windows gameplay matrix. The actual
startup receipt is `windows-package-startup-final.json` in the review directory.

EXE SHA-256: `dcfa6d3d5ee1052b2fe26e128e44181d01015766b919a40cb1c87f30ecd74d96`.

ZIP SHA-256: `6cff0b770b72c7b0d511602a7fdbbf65d125ff0648e63e40ef12f90b89b838d3`.
