# Multi-crew seat and role authority

`NetworkSeatAuthority` is the first bounded multiplayer contract for the
larger-vessel crew slice. It is a detached, server-owned ledger for stable seat
IDs and the four supported role names: `pilot`, `gunner`, `passenger`, and
`engineer`.

The server registers the vessel's seats with a seat generation and optional
moving-interior frame ID. A validated client intent is committed through
`claim()` only when the caller is the configured authority peer. Claims are
atomic: a seat can have one occupant, an avatar cannot claim two seats, and the
requested role must match the registered seat role. Per-occupant monotonic
request sequences reject replay and reordering. `release()` checks the seat
generation, and `release_peer()` is the server-only disconnect cleanup path.

`get_snapshot()` returns a deep-copied roster/assignment snapshot suitable for a
future network transport. No RPC, movement, boarding, ship simulation, damage,
landing, interpolation, or client replica setter is implemented here. The
focused regression is `tests/network/network_seat_authority_test.gd`; it does
not launch a multiplayer peer or production scene.
