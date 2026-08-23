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
	print("OK: network snapshot delta codec (6 assertions)")
	quit(0)
