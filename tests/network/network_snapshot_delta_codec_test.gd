extends SceneTree

const Codec := preload("res://scripts/network/network_snapshot_delta_codec.gd")
const Fragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")

func _init() -> void:
	var encoder := Codec.new()
	var decoder := Codec.new()
	var first := {"revision": 1, "server_tick": 1, "sections": {"movement": [{"id": "a"}]}}
	var full := encoder.encode(first)
	assert(full.kind == &"full")
	assert(full.packet == first and not full.has("packet_size"))
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
	_test_large_full(_large_packet())
	# Reuse the same contract with a captured production packet without making
	# this suite depend on a local capture or checking a binary into the repo.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--snapshot-dump="):
			var path := argument.trim_prefix("--snapshot-dump=")
			_test_large_full(FileAccess.open(path, FileAccess.READ).get_var(false))
	print("OK: network snapshot delta codec (small/full compression, fragmentation, rejection, delta/removal, recovery)")
	quit(0)


func _large_packet() -> Dictionary:
	var movement: Array = []
	var ownership: Array = []
	var respawn: Array = []
	for index in 9:
		var id := "craft-%d" % index
		movement.append({"id": id, "position": Vector3(index, index * 2, index * 3),
			"engine": &"ONLINE", "hull": 0.88 - index * 0.025,
			"display_facts": {"cockpit": ("%s engine ONLINE hull %.3f " % [id, 0.88 - index * 0.025]).repeat(20)}})
		ownership.append({"ship_id": id, "owner_peer_id": index, "generation": 1,
			"ledger_note": ("%s committed ownership " % id).repeat(15)})
		respawn.append({"ship_id": id, "destroyed": false, "hull": 0.88 - index * 0.025})
	return {"revision": 10, "server_tick": 123, "sections": {
		"movement": movement, "ownership": ownership, "respawn": respawn}}


func _test_large_full(packet: Dictionary) -> void:
	var plain := {"kind": &"full", "base_revision": 0, "revision": packet.revision, "packet": packet}
	var plain_bytes := Marshalls.variant_to_base64(plain).length()
	assert(plain_bytes > Fragmenter.MAX_PACKET_BYTES)
	assert(Fragmenter.new().fragment(plain, 1, packet.revision).is_empty())
	var encoder := Codec.new()
	var decoder := Codec.new()
	var full := encoder.encode(packet, true)
	assert(full.kind == &"full" and full.base_revision == 0 and full.revision == packet.revision)
	assert(full.packet is PackedByteArray)
	var packed_bytes := Marshalls.variant_to_base64(full).length()
	assert(packed_bytes <= Fragmenter.MAX_PACKET_BYTES)
	var reassembled := _transport(full)
	var accepted := decoder.decode(reassembled)
	assert(accepted.accepted and accepted.status == &"full_snapshot" and accepted.packet == packet)
	# A failed full must not poison the previously usable delta baseline.
	var baseline := decoder.get_snapshot()
	var bad_values: Array = ["wrong type", [], {}, PackedByteArray()]
	for value in bad_values:
		var bad := full.duplicate(true)
		bad.packet = value
		_assert_bad_full(decoder, bad, baseline)
	for size in [0, -1, Codec.MAX_INFLATED_PACKET_BYTES + 1, "wrong type", float(full.packet_size)]:
		var bad := full.duplicate(true)
		bad.packet_size = size
		_assert_bad_full(decoder, bad, baseline)
	var corrupt := full.duplicate(true)
	corrupt.packet[corrupt.packet.size() - 1] ^= 1
	_assert_bad_full(decoder, corrupt, baseline)
	var oversize := full.duplicate(true)
	oversize.packet.resize(Codec.MAX_COMPRESSED_PACKET_BYTES + 1)
	_assert_bad_full(decoder, oversize, baseline)
	var extra := full.duplicate(true)
	extra.extra = "x".repeat(Fragmenter.MAX_PACKET_BYTES)
	_assert_bad_full(decoder, extra, baseline)
	var mismatch := full.duplicate(true)
	mismatch.revision += 1
	_assert_bad_full(decoder, mismatch, baseline)
	for value in [[1, 2], "not a packet", Resource.new()]:
		var bytes := var_to_bytes_with_objects(value)
		var bad := full.duplicate(true)
		bad.packet = bytes.compress(FileAccess.COMPRESSION_ZSTD)
		bad.packet_size = bytes.size()
		bad.packet_digest = _digest(bad.packet)
		_assert_bad_full(decoder, bad, baseline)
	# Godot deliberately reports ERR_UNAUTHORIZED for a full Object nested in
	# an otherwise valid Dictionary. Silence only this expected diagnostic;
	# acceptance and baseline preservation are still asserted.
	var object_bytes := var_to_bytes_with_objects({"revision": packet.revision, "object": Resource.new()})
	var nested_object := full.duplicate(true)
	nested_object.packet = object_bytes.compress(FileAccess.COMPRESSION_ZSTD)
	nested_object.packet_size = object_bytes.size()
	nested_object.packet_digest = _digest(nested_object.packet)
	var print_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	_assert_bad_full(decoder, nested_object, baseline)
	Engine.print_error_messages = print_errors
	var malformed_bytes := var_to_bytes({"revision": packet.revision, "unfinished": "data"})
	malformed_bytes.resize(malformed_bytes.size() - 4)
	var malformed := full.duplicate(true)
	malformed.packet = malformed_bytes.compress(FileAccess.COMPRESSION_ZSTD)
	malformed.packet_size = malformed_bytes.size()
	malformed.packet_digest = _digest(malformed.packet)
	# The primitive scanner also deliberately reports ERR_FILE_EOF here.
	Engine.print_error_messages = false
	_assert_bad_full(decoder, malformed, baseline)
	Engine.print_error_messages = print_errors
	var trailing := var_to_bytes(packet)
	trailing.append(0)
	var bad_trailing := full.duplicate(true)
	bad_trailing.packet = trailing.compress(FileAccess.COMPRESSION_ZSTD)
	bad_trailing.packet_size = trailing.size()
	bad_trailing.packet_digest = _digest(bad_trailing.packet)
	_assert_bad_full(decoder, bad_trailing, baseline)
	var next := packet.duplicate(true)
	next.revision += 1
	next.server_tick += 1
	# Small movement change and removal must still reference the inflated full.
	var section_keys := (next.sections as Dictionary).keys()
	next.sections.erase(section_keys.back())
	var first_section: Array = next.sections[section_keys.front()]
	first_section[0]["budget_test_change"] = true
	var delta := encoder.encode(next)
	assert(delta.kind == &"delta" and delta.base_revision == packet.revision)
	assert(delta.section_removals == [section_keys.back()])
	var decoded := decoder.decode(_transport(delta))
	assert(decoded.accepted and decoded.status == &"delta_snapshot" and decoded.packet == next)
	assert(Codec.new().decode(delta).status == &"missing_delta_baseline")
	assert(decoder.decode(delta).status == &"stale_delta_baseline")
	# Periodic and forced recovery retain the original full status and cadence.
	for index in range(2, Codec.FULL_INTERVAL):
		next.revision += 1
		assert(encoder.encode(next).kind == &"delta")
	next.revision += 1
	var periodic := encoder.encode(next)
	assert(periodic.kind == &"full")
	decoder.reset()
	assert(decoder.decode(_transport(periodic)).packet == next)
	next.revision += 1
	assert(decoder.decode(_transport(encoder.encode(next, true))).packet == next)
	print("FULL_BUDGET plain=%d packed=%d headroom=%d exact_roundtrip=true" % [
		plain_bytes, packed_bytes, Fragmenter.MAX_PACKET_BYTES - packed_bytes])


func _transport(envelope: Dictionary) -> Dictionary:
	var fragments := Fragmenter.new().fragment(envelope, 1, envelope.revision)
	assert(not fragments.is_empty() and fragments.size() <= Fragmenter.MAX_FRAGMENTS)
	var receiver := Fragmenter.new()
	var result: Dictionary = {}
	fragments.reverse()
	for fragment in fragments:
		result = receiver.accept(fragment, 1)
	assert(result.accepted and result.status == &"reassembled")
	return result.packet


func _assert_bad_full(decoder: RefCounted, envelope: Dictionary, baseline: Dictionary) -> void:
	var result: Dictionary = decoder.decode(envelope)
	assert(not result.accepted and result.status == &"invalid_full_snapshot")
	assert(decoder.get_snapshot() == baseline)


func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish()
