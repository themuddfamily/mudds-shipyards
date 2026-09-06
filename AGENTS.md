# Agent collaboration policy

## Automated test audio

- Every automated Godot invocation must include `--audio-driver Dummy`, including
  headless tests, rendered captures, and exported-game probes. `--headless` alone
  does not disable audio and can play loud engine tones through the user's headphones.
- Use real audio output only when the user explicitly authorizes an audible test.

## Parallel-agent policy

Use subagents deliberately when they materially shorten independent work. The
goal is faster implementation with useful verification, not maximum research
coverage.

- Before substantial work, decompose the task and use **1–7 subagents at most**
  for independent implementation, evidence gathering, or review.
- Default to one implementation agent. Add one independent reviewer for
  high-risk changes; use additional agents only for genuinely separate
  workstreams that can proceed concurrently.
- Prefer breadth across the roadmap over a committee on one item: assign one
  implementation-oriented agent to each of up to 7 independent `ROADMAP.md` points,
  each in its own worktree with disjoint file ownership. Run those points in
  parallel when they have no ordering dependency. Keep dependent points
  sequential, and do not spend the available agents on overlapping research of
  one point unless that point is explicitly high-risk and needs one reviewer.
- Start independent agents concurrently, then continue useful coordination work
  in the main thread while they run.
- Give each agent a concrete, bounded deliverable.
- Prefer parallel agents for repository mapping, documentation research,
  reproducing bugs, test execution, and reviewing the proposed implementation.
- For implementation, assign agents non-overlapping files or components.
- Keep integration and final decisions in the main thread.
- Wait for all required agents and incorporate their findings.
- Skip delegation only when the task is genuinely sequential, trivial, or would
  cause agents to edit the same files. State the reason briefly when skipping.
- Do not let subagents recursively spawn more agents unless the root assignment
  explicitly authorizes that specific nested workstream.
- Time-box research by evidence, not curiosity: stop exploring once file
  ownership, the implementation seam, and acceptance checks are known. Do not
  keep enumerating hypothetical edge cases after the requested contract is
  demonstrated.
- Prefer implementation and direct validation over multiple overlapping audits.
  One concrete implementer plus one bounded reviewer is normally enough.

## Production progress and evidence policy

Evidence exists to verify product work; it is not a substitute for product
work. Optimize for named `ROADMAP.md` outcomes that change the running game,
player-facing content, production integration, or the actual build/release
pipeline.

- Do **not** create serial numbered validators, schema/version bumps, provenance
  chains, rollups, attestations, reconciliation layers, or near-duplicate tests
  merely to generate more evidence or commits.
- Do **not** advance an existing `vNNN` evidence family unless a named roadmap
  requirement or real consumer requires that exact format change. A new version
  must replace or migrate an existing contract, not sit beside it as another
  equivalent layer.
- A validator is justified only when it protects a concrete production
  behavior, artifact, external handoff, or regression that is not already
  covered. Prefer extending or consolidating an existing check over adding a
  parallel one.
- Every implementation assignment should deliver a production behavior,
  player-visible/content change, or executable build/release capability. Add
  the smallest focused test needed to prove that behavior.
- If a proposed task would modify only evidence/validator files under `tools/`
  and their tests, stop and redirect to the underlying runtime, content, UI,
  networking, packaging, or gameplay gap unless the user explicitly requested
  an evidence-only artifact.
- Do not count evidence-only commits, test-count growth, schema versions, or
  internal batch numbers as project percentage progress. Report progress using
  named roadmap deliverables and visible/runtime outcomes.
- Preserve native-hardware and human-review gates as `NOT_RUN` until actually
  performed; never manufacture additional evidence layers to make an external
  gate appear closer to completion.
- For short visible-delivery sprints, prioritize changes that can be exercised
  in the next packaged build and state the exact in-game result the user should
  notice.

## Dynamic reasoning-effort policy

Choose each new subagent's reasoning effort deliberately from the shape and risk
of its bounded task. Do not use one effort level for every agent.

- **Low:** deterministic commands, censuses, test execution, file inventories,
  and other mechanical evidence gathering with an objective result.
- **Medium:** bounded implementation or refactoring backed by strong existing
  tests and clear file ownership. This is the default when no tier clearly fits
  better.
- **High:** semantic rebases, physics or lifecycle changes, cross-component
  integration, and reviews where subtle behavior can regress.
- **Xhigh or max:** reserve for architecture decisions and adversarial final
  reviews where a missed issue is unusually expensive. Use these only when the
  extra latency is justified by a likely quality gain.

Set the effort when spawning the agent. Do not interrupt and restart a
near-complete agent solely to change its effort; apply the new tier on its next
bounded assignment. When an effort or model override requires a bounded context
fork, pass the smallest recent context that fully explains the task.

Reasoning effort does not replace scope control. Every delegation must still
state exact ownership, acceptance evidence, forbidden expansion, and a stopping
condition. Prefer a lower-effort agent with a precise task over a higher-effort
agent with an open-ended mandate.

Evaluate the policy by outcomes: correctness, required evidence, latency, and
cost. Raise an effort tier only when representative work shows a material
quality improvement; lower it when the same acceptance bar is met reliably.
