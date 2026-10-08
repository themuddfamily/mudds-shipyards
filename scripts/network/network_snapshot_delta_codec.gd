class_name NetworkSnapshotDeltaCodec
extends RefCounted

## Bounded delta envelope for authoritative snapshots. The lifecycle adapter
## remains the schema/generation authority; this codec only reconstructs a
## detached full packet before lifecycle validation.

const FULL_INTERVAL := 8
const Fragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")
## Compression changes only oversized full envelopes, never the reconstructed
## snapshot or transport ceiling. Bound allocation before untrusted inflation.
const MAX_INFLATED_PACKET_BYTES := 64_000
const MAX_COMPRESSED_PACKET_BYTES := Fragmenter.MAX_PACKET_BYTES * 3 / 4
## The one nested key diffed per entry rather than as a whole: a delta carries
## only the sections that changed (`section_changes`) and the ones that went
## away (`section_removals`).
const SECTIONS_KEY := "sections"

var _baseline: Dictionary = {}
var _baseline_revision := 0
var _packets_since_full := 0


func reset() -> Dictionary:
	_baseline.clear()
	_baseline_revision = 0
	_packets_since_full = 0
	return {"accepted": true, "status": &"reset"}


func encode(packet: Dictionary, force_full: bool = false) -> Dictionary:
	var revision := int(packet.get("revision", 0))
	var full := force_full or _baseline.is_empty() or _packets_since_full >= FULL_INTERVAL
	if full:
		_baseline = packet.duplicate(true)
		_baseline_revision = revision
		_packets_since_full = 1
		return _full_envelope(packet, revision)
	var previous_revision := _baseline_revision
	var changes: Dictionary = {}
	var section_changes: Dictionary = {}
	var section_removals: Array = []
	for key in packet:
		if key == "revision":
			continue
		if key == SECTIONS_KEY and packet[key] is Dictionary and _baseline.get(key) is Dictionary:
			# Sections are diffed one by one. Movement changes every tick, but
			# the ownership, boarding and landing ledgers usually do not, and
			# re-sending all of them on every 60 Hz tick multiplied the
			# reliable stream to every peer several times over.
			var sections := packet[key] as Dictionary
			var baseline_sections := _baseline[key] as Dictionary
			for section in sections:
				if not baseline_sections.has(section) or baseline_sections[section] != sections[section]:
					section_changes[section] = _detached(sections[section])
			for section in baseline_sections:
				if not sections.has(section):
					section_removals.append(section)
			continue
		if not _baseline.has(key) or _baseline[key] != packet[key]:
			changes[key] = _detached(packet[key])
	_baseline = packet.duplicate(true)
	_baseline_revision = revision
	_packets_since_full += 1
	var envelope := {
		"kind": &"delta",
		"base_revision": previous_revision,
		"revision": revision,
		"changes": changes,
	}
	if not section_changes.is_empty():
		envelope["section_changes"] = section_changes
	if not section_removals.is_empty():
		envelope["section_removals"] = section_removals
	return envelope


func decode(envelope: Dictionary) -> Dictionary:
	var kind := StringName(envelope.get("kind", &""))
	var revision := int(envelope.get("revision", 0))
	if revision <= 0:
		return {"accepted": false, "status": &"invalid_delta_revision"}
	if kind == &"full":
		var packet := _full_packet(envelope)
		if packet.is_empty() or int(packet.get("revision", 0)) != revision:
			return {"accepted": false, "status": &"invalid_full_snapshot"}
		_baseline = packet.duplicate(true)
		_baseline_revision = revision
		_packets_since_full = 1
		return {"accepted": true, "status": &"full_snapshot", "packet": packet.duplicate(true)}
	if kind != &"delta" or _baseline.is_empty():
		return {"accepted": false, "status": &"missing_delta_baseline"}
	if int(envelope.get("base_revision", 0)) != _baseline_revision:
		return {"accepted": false, "status": &"stale_delta_baseline"}
	var merged := _baseline.duplicate(true)
	for key in envelope.get("changes", {}):
		merged[key] = _detached(envelope.changes[key])
	var section_changes: Variant = envelope.get("section_changes", {})
	var section_removals: Variant = envelope.get("section_removals", [])
	if not (section_changes is Dictionary and section_removals is Array):
		return {"accepted": false, "status": &"invalid_section_delta"}
	if not (section_changes as Dictionary).is_empty() or not (section_removals as Array).is_empty():
		if not merged.get(SECTIONS_KEY) is Dictionary:
			return {"accepted": false, "status": &"missing_section_baseline"}
		var sections := merged[SECTIONS_KEY] as Dictionary
		for section in section_changes as Dictionary:
			sections[section] = _detached((section_changes as Dictionary)[section])
		for section in section_removals as Array:
			sections.erase(section)
	merged["revision"] = revision
	_baseline = merged.duplicate(true)
	_baseline_revision = revision
	_packets_since_full += 1
	return {"accepted": true, "status": &"delta_snapshot", "packet": merged}


static func _full_envelope(packet: Dictionary, revision: int) -> Dictionary:
	var envelope := {"kind": &"full", "base_revision": 0, "revision": revision, "packet": packet.duplicate(true)}
	if Marshalls.variant_to_base64(envelope).length() <= Fragmenter.MAX_PACKET_BYTES:
		return envelope
	var bytes := var_to_bytes(packet)
	if bytes.size() > MAX_INFLATED_PACKET_BYTES:
		return envelope
	var compressed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty() or compressed.size() > MAX_COMPRESSED_PACKET_BYTES:
		return envelope
	var packed := {"kind": &"full", "base_revision": 0, "revision": revision,
		"packet": compressed, "packet_size": bytes.size(), "packet_digest": _digest(compressed)}
	if Marshalls.variant_to_base64(packed).length() > Fragmenter.MAX_PACKET_BYTES:
		return envelope
	return packed


static func _full_packet(envelope: Dictionary) -> Dictionary:
	var value: Variant = envelope.get("packet")
	if value is Dictionary:
		# Refuse an ambiguous packed/plain full envelope.
		if envelope.has("packet_size") or envelope.has("packet_digest"):
			return {}
		return value
	if not value is PackedByteArray or not envelope.get("packet_size") is int \
		or not envelope.get("packet_digest") is PackedByteArray:
		return {}
	var size: int = envelope.packet_size
	var compressed := value as PackedByteArray
	var digest := envelope.packet_digest as PackedByteArray
	if size <= 0 or size > MAX_INFLATED_PACKET_BYTES or compressed.is_empty() \
		or compressed.size() > MAX_COMPRESSED_PACKET_BYTES or digest.size() != 32:
		return {}
	if Marshalls.variant_to_base64(envelope).length() > Fragmenter.MAX_PACKET_BYTES \
		or _digest(compressed) != digest:
		return {}
	# Fixed-size ZSTD decompression is supported; the dynamic API is not.
	var bytes := compressed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	# Godot's primitive Variant header stores the base type in its low 16 bits.
	# Reject non-packets before invoking the decoder (including top-level Objects).
	if bytes.size() != size or size < 4 or (bytes.decode_u32(0) & 0xffff) != TYPE_DICTIONARY:
		return {}
	if not bytes.has_encoded_var(0, false):
		return {}
	if bytes.decode_var_size(0, false) != size:
		return {}
	var parsed: Variant = bytes.decode_var(0, false)
	return parsed as Dictionary if parsed is Dictionary else {}


static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish()


static func _detached(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func get_snapshot() -> Dictionary:
	return {"baseline_revision": _baseline_revision, "packets_since_full": _packets_since_full, "has_baseline": not _baseline.is_empty()}
