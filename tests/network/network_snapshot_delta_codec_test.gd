extends SceneTree

const Codec := preload("res://scripts/network/network_snapshot_delta_codec.gd")

func _init() -> void:
	var encoder := Codec.new()
	var decoder := Codec.new()
	var first := {"revision": 1, "server_tick": 1, "sections": {"movement": [{"id": "a"}]}}
	var full := encoder.encode(first)
	assert(full.kind == &"full")
	assert(decoder.decode(full).accepted)
	var second := {"revision": 2, "server_tick": 2, "sections": {"movement": [{"id": "b"}]}}
	var delta := encoder.encode(second)
	assert(delta.kind == &"delta")
	assert(decoder.decode(delta).packet.sections.movement[0].id == "b")
	var missing := Codec.new().decode(delta)
	assert(missing.status == &"missing_delta_baseline")
	# An unchanged section rides the delta only by reference to the baseline:
	# the static ownership ledger must not be re-sent on every tick.
	var ledger := [{"ship_id": "halyard", "owner_peer_id": 0}]
	var third := {"revision": 3, "server_tick": 3, "sections": {"movement": [{"id": "c"}], "ownership": ledger}}
	assert(decoder.decode(encoder.encode(third)).accepted)
	var fourth := {"revision": 4, "server_tick": 4, "sections": {"movement": [{"id": "d"}], "ownership": ledger}}
	var slim := encoder.encode(fourth)
	assert(slim.kind == &"delta")
	assert(not slim.changes.has("sections"))
	assert(slim.section_changes.keys() == ["movement"])
	var rebuilt: Dictionary = decoder.decode(slim).packet
	assert(rebuilt == fourth)
	var fifth := {"revision": 5, "server_tick": 5, "sections": {"movement": [{"id": "d"}]}}
	var dropped := encoder.encode(fifth)
	assert(not dropped.has("section_changes") and dropped.section_removals == ["ownership"])
	assert(decoder.decode(dropped).packet == fifth)
	print("OK: network snapshot delta codec (13 assertions)")
	quit(0)
