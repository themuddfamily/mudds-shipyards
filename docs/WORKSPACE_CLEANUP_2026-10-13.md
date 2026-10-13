# Workspace cleanup — 2026-10-13

Assessed all `/root/mudds-*` sibling directories, including the ten worktrees inside `mudds-shipyards-worktrees`. Preserved unfinished/unpublished work before removing 28 inactive linked worktrees and their empty container. Only the primary `/root/mudds-shipyards` directory remains. No forced removals or historical code merges were used.

Twenty recovery branches were pushed atomically and their exact tips verified against live GitHub refs. Six contain new historical WIP commits; thirteen preserve existing divergent tips; one saves the primary workspace. The nine remaining clean worktrees were already ancestors of pushed main `5266aa53b56cee1af236b6b5f6e76a860ea2581b`.

These branches preserve work for review. They are not current-source integration, runtime acceptance or roadmap completion. Existing installed-hulk, shared-arrival/cruise, Ember-generation/return and hulk-geometry work should be assessed against current production before any merge. Several chair/combat/regression changes already have patch-equivalent implementations on main.

## Preserved source

Recovery branches use `recovery/siblings-2026-10-13/` followed by the former directory path relative to `/root`. The table records exact saved commits.

| Former directory | Saved commit | Preservation |
| --- | --- | --- |
| `mudds-chair-floor-support` | `e60e426293844b16ed55dcb930e96a387e847204` | Existing tip, recovery branch |
| `mudds-chair-recovery` | `96de8ab3588d2288d4282e7a7717453a96c32676` | Existing tip, recovery branch |
| `mudds-chair-reseat-recovery` | `10eeb67b8c02c914b1c38f96044ddca8cf435e8a` | Already in pushed main |
| `mudds-chair-supported-residue` | `c54114453f019948511ff45a9b7e2e24f51a93b6` | Existing tip, recovery branch |
| `mudds-combat-capture` | `8688d790726f072a507728bb9c4520e82eeaa985` | Existing tip, recovery branch |
| `mudds-halyard-combined` | `154ddde1d567a0751d772685b52199c94acb220d` | Already in pushed main |
| `mudds-halyard-passenger` | `7edfaeba92b03c668acd673cacbe3cc715f58345` | Existing tip, recovery branch |
| `mudds-mining-installer` | `527bdde5c2da88bad08da2328c1f5a36d09f8f2c` | Existing tip, recovery branch |
| `mudds-mining-installer-fix` | `cc7c40d5fe01b15f736760c080166ae2fb1d633f` | Existing tip, recovery branch |
| `mudds-rebase-roster-cache` | `9d65526a7d8933c5758a9f1ab034611fa8aaf0f0` | Existing tip, recovery branch |
| `mudds-shared-arrival` | `0bfea191e96900fd5bfd7fc1cf0ef9fe9c2980a7` | WIP commit, recovery branch |
| `mudds-shared-arrival-snapshot-baseline` | `61f11e8a39af9cbbb0e9c5117b96e799ea46fc3f` | WIP commit, recovery branch |
| `mudds-shared-cruise` | `9bd1d4cd348a4811ac049e9e724ad5919e4359bc` | Existing tip, recovery branch |
| `mudds-shipyards-ember-generation` | `1d7175519922de7a85fe3b9b2e2ecf410b4ece82` | Existing tip, recovery branch |
| `mudds-shipyards-ember-return` | `f017ddc8cf3c5884d351980dae4cc1099b477532` | WIP commit, recovery branch |
| `mudds-shipyards-installed-hulk` | `e5dade1aac93f7298421b32c46576e8913993d38` | Existing tip, recovery branch |
| `mudds-shipyards-return-regressions-633f36c` | `633f36cd10dda8ddd664bc3e7ea1b6a928ff7958` | Existing tip, recovery branch |
| `mudds-shipyards-worktrees/full-matrix-a3c28e7d7` | `a3c28e7d76cb1d07cc25af72631e08b3ad1e6850` | Already in pushed main |
| `mudds-shipyards-worktrees/goal-export-fix` | `a266de0cbfed76253baf001f36da5b95fe850b6a` | Existing tip, recovery branch |
| `mudds-shipyards-worktrees/goal-integrated` | `531a70f9ff12eb136547305cb304f1ac237849d5` | Already in pushed main |
| `mudds-shipyards-worktrees/integration-fa31504ab` | `fa31504abb34d2b3b3bab6e89bfa897bf45f619f` | Already in pushed main |
| `mudds-shipyards-worktrees/matrix-79aff53f4` | `79aff53f4a2c91bb1f9c1a0d642898b49eba9d88` | Already in pushed main |
| `mudds-shipyards-worktrees/matrix-b49d86bed-20260926T121943Z` | `b49d86bedcc55dfe992e59aaf497826d19baabfc` | Already in pushed main |
| `mudds-shipyards-worktrees/mudds-aurora-visual-57ece81` | `71cf5106436cfd144e9debaf6fab708a149b6c8e` | WIP commit, recovery branch |
| `mudds-shipyards-worktrees/mudds-hulk-plate-geometry` | `4dcd4c98ecb761ec078d950aeb34854defbcf328` | WIP commit, recovery branch |
| `mudds-shipyards-worktrees/mudds-integrated-focused-bc38358` | `1af47a39d161ba64e1323f914f5acb70faa45fe4` | Already in pushed main |
| `mudds-shipyards-worktrees/mudds-stabilization-matrix-57ece813` | `ff33d00b108d083de356f8b8ef532d73ef78ef36` | Already in pushed main |
| `mudds-smoke-worktree` | `b8085250a01d7f1d62cbee418ac7b459c00d0353` | WIP commit, recovery branch |

## Primary workspace

The primary workspace is retained. Recovery branch `recovery/siblings-2026-10-13/main-workspace` saves commit `a7ed55d1d82870b56b16b008865e6d24795fe9cb`, parent `5266aa53b56cee1af236b6b5f6e76a860ea2581b`. It preserves the existing 62 historical build-metadata deletions and 1,762 nonignored local source files: 1,746 Godot skill/reference files, eight handoff documents, seven advert source/documentation files and `skills-lock.json`. Its commit was created with a temporary index; main's HEAD, index and local files were unchanged by preservation. The cleanup report itself is a separate main commit.

Ignored advert outputs, current builds, primary `.godot`, home game data and all `/tmp` and `.cache` worktrees remain in place. This cleanup does not qualify or merge the separately pushed cylinder-clearance candidate `6d55f01f836077fc6f149e483c0703eacf74c51e`; focused native and full Rime qualification still remain pending.

## Captures and audit records

Forty-six ignored captures/log/manifest files (8,107,977 bytes) were copied with SHA-256 verification to:

`/root/.cache/mudds-shipyards/sibling-cleanup-oct13/preserved-artifacts/`

Their original directory structure is retained. No nonempty ignored Windows build directory was found; `goal-integrated/builds/windows` was empty. Reproducible Godot caches, Python caches and generated PNG import sidecars in the removed worktrees were discarded. Primary ignored advert outputs remain local and were not added to the recovery branch.

The same cleanup directory contains `worktrees-before.json`, `worktrees-preserved-local.json`, `main-workspace-recovery.json`, `remote-preservation.json`, `remote-heads-before.json`, `remote-heads-after.json`, `preserved-artifacts.json`, `removed-worktrees.json`, `cleanup-result.json` and the actual push log. Original branch refs remain locally; recovery tips are available remotely.

## Validation

- All 28 worktrees had no active process working directory; readable open-file checks in the initial audit found no users. Unreadable process CWD entries were zombies, with no live unknown users.
- Every dirty worktree was committed on its own recovery branch and became clean. Tracked change rosters and diff checks were preserved; no gameplay tests or new quality claims were introduced.
- Live remote refs verified all twenty saved recovery tips before removal. Other removed commits were verified ancestors of pushed main.
- Preserved capture bytes matched both source and destination hashes before removal.
- Every removal used `git worktree remove` without force. No removed paths remain registered, and the empty container was removed with `rmdir`.
- The primary source/index/status remained unchanged during cleanup. Local branch history and unrelated worktrees were retained.

Independent final review verified every original folder, all live recovery refs, exact WIP parents/change rosters, main snapshot additions/deletions and retained capture hashes. A concurrent Bulwark handoff commit `44259b8023161d2bb367d50d0253da2e07f5eba1` subsequently advanced main above the cleanup baseline; it was retained. The original 1,762 local files and 62 deletions remained intact. About 20 GiB of filesystem space was available after cleanup.
