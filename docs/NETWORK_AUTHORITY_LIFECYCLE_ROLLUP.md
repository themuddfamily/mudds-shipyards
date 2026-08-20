# Network authority, interest, and lifecycle rollup

`network_authority_lifecycle_rollup_validator.py` validates a small JSON
evidence rollup over the existing detached multiplayer ledgers. The fixture
must show these server-owned phases in order:

`admit` → `bind` → `interest` → `replicate` → `correct` → `cleanup`

Each phase identifies its existing policy version, an accepted receipt, the
server-owned source, and a strictly increasing event sequence. Correction must
leave `client_can_mutate_state` false; cleanup must leave `active_after` false.

This is a contract-composition gate only. It does not create a
`MultiplayerPeer`, run a production scene, capture transport counters, or
claim Windows/native playtest evidence. The focused regression is
`test_network_authority_lifecycle_rollup_validator.py`.

Run it with:

```sh
python3 -m unittest tools/network/test_network_authority_lifecycle_rollup_validator.py
python3 tools/network/network_authority_lifecycle_rollup_validator.py path/to/rollup.json
```
