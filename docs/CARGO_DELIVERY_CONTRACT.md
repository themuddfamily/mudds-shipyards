# Cargo delivery contract foundation

## Outcome and boundary

This foundation makes one cargo delivery objective expressible and testable
without adding it to the live game. A contract binds one current source manifest
handle, one current destination manifest handle, one item and integer quantity,
an optional ordered phase list, and a positive physics deadline.

`CargoTransferAuthority` remains the only inventory authority. The delivery
activity calls its public `transfer()` API and never stores a parallel inventory
or edits a manifest. It observes the committed-receipt signal only to fail closed
when another caller consumes its reserved transfer ID; the mutable public signal
is never completion evidence. This slice adds no HUD, `GameFlow`, world, reward,
ship, berth, combat, save, persistence, or network integration.

## Types

- `CargoDeliveryContract` is a `RefCounted` definition with no public mutator.
  Constructor inputs and every public snapshot are deeply detached. IDs use the cargo
  authority's lowercase stable-ID grammar. Handles retain all four authority
  identity fields: entity ID/generation and manifest ID/generation.
- `CargoDeliveryActivity` is a generation-safe `RefCounted` objective. It owns
  only `IDLE`, `ACTIVE`, `COMPLETED`, `FAILED`, or `EXPIRED` state, phase index,
  caller-supplied physics elapsed time, failure reason, and the accepted receipt.
  It snapshots the complete contract when bound, so later caller-owned mutation
  cannot redirect a live objective.

Starting a run derives an expected transfer ID from the stable contract ID and
new activity generation (`<contract_id>_g<generation>`) and reserves that ID for
the supplied transfer authority. A second activity cannot start with the same
live reservation, and a previously committed ID cannot be reserved again. Reset
advances the activity generation and returns to `IDLE`; it does not restore cargo
and cannot make an old manifest handle current. Starting after reset advances
generation again, matching the existing activity lifecycle convention.

`start()` accepts only exact `IDLE`; `COMPLETED`, `FAILED`, and `EXPIRED`
return `reset_required`. Reset is the explicit generation boundary and is
accepted from a live or terminal run, not from an already-IDLE activity. This
prevents a duplicate activity from skipping generations to evade an existing
transfer-ID reservation.

## Completion proof

The activity completes only from the detached Dictionary returned directly by
the real authority's `transfer()` call made inside `submit_transfer()`. The
activity guards that complete synchronous call, including authority signal
dispatch, against reentry. This is deliberately stricter than trusting the
public signal Dictionary: Godot signal listeners share a mutable Dictionary, so
an earlier observer could rewrite signal fields. The authority returns a
separate deep copy after signal delivery, and that direct receipt must prove all
of the following:

1. `accepted == true` and `reason == committed`;
2. exact generation-specific transfer ID;
3. exact item and quantity;
4. exact source and destination handles in the bound direction;
5. positive receipt ID paired with that transfer ID in the authority's committed
   ledger, which the authority writes before signalling;
6. source/destination after-quantities equal the current authority snapshots;
7. every ordered phase has already been accepted in order.

An unrelated transfer is ignored. A real ledger-backed transfer from another
caller that consumes the exact ID fails the objective closed; it never completes
from the public signal, regardless of item, quantity, direction, or signal-field
mutation. Phase-incomplete consumption reports that ordering failure explicitly.
A transfer rejected by the authority emits no receipt, does not complete the
objective, and does not burn its transfer ID.

## Time, reset, and signals

The activity has no process callback or wall clock. Its positive finite deadline
advances only through `advance_physics(delta, expected_generation)`. A zero delta
is a deterministic pause; invalid, stale, overflowing, or terminal steps do not
mutate state. Crossing the deadline commits `EXPIRED` exactly once.

Every mutator requires the current generation. Start, phase, completion,
failure, expiry, and reset signals expose detached post-state snapshots.
Mutators reject `reentrant_call` during every activity signal, matching the cargo
authority's dispatch rule. The guard also spans the call into the authority, so
an authority-signal observer connected earlier cannot reset or fail the activity
after cargo commits but before the direct receipt returns. Observer mutation
therefore cannot alter retained state or use either signal route to reset, fail,
progress, or submit twice.

## Focused evidence

`tests/cargo_delivery_contract_test.gd` composes the production
`CargoTransferAuthority` with generic in-tree owner nodes. It covers exact
completion, deterministic phase/signal ordering, physics-only expiry, reset and
stale activity generations, stale and detached manifest handles, wrong item,
partial quantity, reversed direction, replay, a rejected authority transfer, an
early transfer, a forged signal lacking ledger evidence, deep-copy isolation,
mutable ledger-backed signal forgery, duplicate activity reservation, and both
activity- and authority-signal reentry. This is a foundation test only; no
player-facing integration or package claim is made.
