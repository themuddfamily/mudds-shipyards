# Agent collaboration policy

## Parallel-agent policy

Use subagents deliberately when they materially shorten independent work. The
goal is faster implementation with useful verification, not maximum research
coverage.

- Before substantial work, decompose the task and use **1–3 subagents at most**
  for independent implementation, evidence gathering, or review.
- Default to one implementation agent. Add one independent reviewer for
  high-risk changes; use a third agent only for a genuinely separate workstream
  that can proceed concurrently.
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
