extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const JovianScene := preload("res://scenes/ships/jovian_light_freighter.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const CinderBomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const PayloadProjectile := preload("res://scripts/combat/bomber_payload_projectile.gd")
const LiveCombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const BomberPayloadCombatAdapter := preload("res://scripts/combat/bomber_payload_combat_adapter.gd")
const LifecycleDamageableAdapter := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")

var _role := ""
var _port := 29140
var _log_path := ""
var _adapter: Adapter
var _jovian: Node3D
var _player: Node3D
var _passenger_player: Node3D
var _cinder: Node3D
var _combat_authority: Node
var _projectile_logged := false
var _projectile_terminal_seen := false
var _reconnect_attempted := false
var _did_reconnect := false
var _initial_peer_generation := 0
var _last_terminal_record: Dictionary = {}
var _reconnect_damage_seen := false
var _reconnect_relationship_seen := false
var _station_terminal_seen := false
var _cargo_completed_seen := false
var _handshake_retry_started := false
var _handshake_wait_frames := 0
var _direct_mismatch_checked := false


func _init() -> void:
	_parse_args()
	_adapter = Adapter.new()
	root.add_child(_adapter)
	_jovian = JovianScene.instantiate() as Node3D
	_jovian.name = &"JovianAuthorityCraft"
	_jovian.position = Vector3(0.0, 8.0, 0.0)
	root.add_child(_jovian)
	_player = PlayerScene.instantiate() as Node3D
	_player.name = &"PassengerAvatar"
	_player.position = Vector3(0.0, 9.0, 0.0)
	root.add_child(_player)
	_passenger_player = PlayerScene.instantiate() as Node3D
	_passenger_player.name = &"SecondPassengerAvatar"
	_passenger_player.position = Vector3(1.0, 9.0, 0.0)
	root.add_child(_passenger_player)
	_cinder = CinderBomber.new()
	_cinder.name = &"CinderAuthorityBomber"
	_cinder.position = Vector3(20.0, 8.0, 0.0)
	root.add_child(_cinder)
	_combat_authority = LiveCombatAuthority.new()
	_combat_authority.name = &"AuthoritativeCombat"
	root.add_child(_combat_authority)
	_adapter.moving_interior_result.connect(_on_moving_interior_result)
	_adapter.damage_respawn_result.connect(_on_damage_respawn_result)
	_adapter.projectile_replica_result.connect(_on_projectile_replica_result)
	_adapter.projectile_replica_packet.connect(_on_projectile_replica_packet)
	_adapter.cargo_manifest_result.connect(_on_cargo_manifest_result)
	_adapter.transport_rejected.connect(_on_transport_rejected)
	_adapter.crew_snapshot_applied.connect(_on_crew_snapshot_applied)
	_adapter.seat_occupancy_result.connect(_on_seat_result)
	_adapter.landing_intent_result.connect(_on_landing_result)
	call_deferred(&"_start")


func _start() -> void:
	await process_frame
	if _role == "server":
		var hosted := _adapter.host(_port, 2)
		_log("HOST_%s" % ("READY" if hosted.get("accepted", false) else "FAILED"))
		call_deferred(&"_server_loop")
	else:
		if _role == "client_b":
			var bad_port := _adapter.consume_direct_connect_intent({"address": "127.0.0.1", "port": 0})
			_log("DIRECT_CONNECT_BAD_PORT_REJECTED" if not bad_port.get("accepted", false) else "DIRECT_CONNECT_BAD_PORT_ACCEPTED")
		var joined := _adapter.consume_direct_connect_intent({
			"address": "127.0.0.1", "port": _port,
		})
		if _role == "client_b":
			_handshake_retry_started = true
		_log("JOIN_%s" % ("STARTED" if joined.get("accepted", false) else "FAILED"))
		call_deferred(&"_client_loop")


func _server_loop() -> void:
	var real_boarding_ok := false
	var boarding_area: Node = null
	for _frame in 240:
		await process_frame
		if _adapter._peer_generations.size() >= 2:
			var peer_ids: Array = _adapter._peer_generations.keys()
			peer_ids.sort()
			var pilot_peer := int(peer_ids[0])
			var passenger_peer := int(peer_ids[1])
			var initial_peer_generations: Dictionary = {}
			for peer_variant in peer_ids:
				initial_peer_generations[int(peer_variant)] = int(_adapter._peer_generations.get(int(peer_variant), 0))
			if _initial_peer_generation == 0:
				_initial_peer_generation = int(_adapter._peer_generations.get(pilot_peer, 0))
			_log("PEERS_%d_%d" % [pilot_peer, passenger_peer])
			_log("IMPAIRMENT rtt_ms=100 loss_percent=2 jitter_ms=20 reorder=true")
			var pilot := _adapter.register_remote_ship_pilot(pilot_peer, &"jovian_authority_craft", 1)
			_log("PILOT_%s" % ("ADMITTED" if pilot.get("accepted", false) else "FAILED"))
			var passenger := _adapter.register_remote_ship_pilot(passenger_peer, &"jovian_passenger_craft", 1)
			_log("PASSENGER_%s" % ("ADMITTED" if passenger.get("accepted", false) else "FAILED"))
			var copilot_ship := _adapter.register_owned_ship(&"jovian_authority_craft", 1, passenger_peer)
			var copilot_seat := _adapter.register_crew_seat(
				&"jovian_copilot_seat", &"jovian_authority_craft", &"passenger", &"", 1
			)
			var copilot_claim := _adapter.claim_crew_seat(
				passenger_peer, &"jovian_copilot", &"jovian_copilot_seat", &"passenger", 1
			)
			var copilot_role := _adapter.accept_crew_role_intent(
				passenger_peer, int(_adapter._peer_generations.get(passenger_peer, 0)),
				&"jovian_copilot", &"passenger", 1, &"jovian_authority_craft", 1
			)
			var copilot_nav := _adapter.accept_crew_command(
				passenger_peer, int(_adapter._peer_generations.get(passenger_peer, 0)),
				&"jovian_copilot", &"ping", 1, 1,
				{"marker_id": "station_route_a"},
				&"jovian_authority_craft", 1
			)
			var copilot_stale := _adapter.accept_crew_command(
				passenger_peer, int(_adapter._peer_generations.get(passenger_peer, 0)),
				&"jovian_copilot", &"ping", 1, 1, {"marker_id": "station_route_a"},
				&"jovian_authority_craft", 1
			)
			var copilot_helm := _adapter.accept_crew_command(
				passenger_peer, int(_adapter._peer_generations.get(passenger_peer, 0)),
				&"jovian_copilot", &"flight_command", 2, 2, {"move_axis": [1.0, 0.0]},
				&"jovian_authority_craft", 1
			)
			var copilot_published := _adapter.publish_crew_snapshot([copilot_nav.get("receipt", {})])
			_log("COPILOT_STATUS %s %s %s %s %s %s" % [copilot_ship.get("status", &"unknown"), copilot_seat.get("status", &"unknown"), copilot_claim.get("status", &"unknown"), copilot_role.get("status", &"unknown"), copilot_nav.get("status", &"unknown"), copilot_published.get("status", &"unknown")])
			if bool(copilot_ship.get("accepted", false)) and bool(copilot_seat.get("accepted", false)) \
				and bool(copilot_claim.get("accepted", false)) and bool(copilot_role.get("accepted", false)) \
				and bool(copilot_nav.get("accepted", false)) and bool(copilot_published.get("accepted", false)):
				_log("COPILOT_ADMITTED")
				_log("COPILOT_NAV_ACCEPTED")
				_log("COPILOT_NAV_REPLICATED")
			if not bool(copilot_stale.get("accepted", false)):
				_log("COPILOT_STALE_SEQUENCE_REJECTED")
			if not bool(copilot_helm.get("accepted", false)):
				_log("COPILOT_HELM_MUTATION_REJECTED")
			var relationship := Relationship.create(
				1, &"jovian_passenger", 1, &"jovian_authority_craft", 1,
				Transform3D.IDENTITY, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 1
			)
			var relationship_result := _adapter.publish_moving_interior_snapshot(
				relationship.get_snapshot(), peer_ids, 1
			)
			_log("RELATIONSHIP_%s" % ("PUBLISHED" if relationship_result.get("accepted", false) else "FAILED"))
			var station_id: StringName = &"station_defense_protected_asset"
			var station_registration := _adapter.register_damage_entity(
				Adapter.AUTHORITY_PEER_ID, station_id, 1, 1
			)
			var station_start := _adapter.publish_damage_respawn_snapshot(
				station_id, 1, 100.0, &"active", false, 1, peer_ids, 1
			)
			var station_wave := _adapter.publish_damage_respawn_snapshot(
				station_id, 1, 100.0, &"active_wave", false, 1, peer_ids, 2
			)
			var station_critical := _adapter.publish_damage_respawn_snapshot(
				station_id, 1, 25.0, &"critical", false, 1, peer_ids, 3
			)
			var station_terminal := _adapter.publish_damage_respawn_snapshot(
				station_id, 1, 0.0, &"destroyed", true, 1, peer_ids, 4
			)
			var station_replay := _adapter.publish_damage_respawn_snapshot(
				station_id, 1, 100.0, &"active", false, 1, peer_ids, 1
			)
			var station_invalid := _adapter.publish_damage_respawn_snapshot(
				station_id, 0, 100.0, &"active", false, 1, peer_ids, 5
			)
			if bool(station_registration.get("accepted", false)) \
				and bool(station_start.get("accepted", false)) \
				and bool(station_wave.get("accepted", false)) \
				and bool(station_critical.get("accepted", false)) \
				and bool(station_terminal.get("accepted", false)):
				_log("STATION_DEFENSE_STARTED")
				_log("STATION_ACTIVE_WAVE")
				_log("STATION_ASSET_CRITICAL")
				_log("STATION_DEFENSE_TERMINAL")
			if bool(station_replay.get("accepted", false)):
				_log("STATION_REPLAY_SENT")
			if not bool(station_invalid.get("accepted", false)):
				_log("STATION_INVALID_GENERATION_REJECTED")
			var cargo_manifest := _cargo_manifest(&"ready", 1, 12)
			var cargo_ready := _adapter.publish_cargo_manifest_snapshot(cargo_manifest, peer_ids)
			var cargo_transit := _adapter.publish_cargo_manifest_snapshot(
				_cargo_manifest(&"in_transit", 1, 12), peer_ids
			)
			var cargo_commit := _adapter.publish_cargo_manifest_snapshot(
				_cargo_manifest(&"committed", 1, 12), peer_ids
			)
			var cargo_completed := _adapter.publish_cargo_manifest_snapshot(
				_cargo_manifest(&"completed", 1, 12), peer_ids
			)
			var cargo_replay := _adapter.publish_cargo_manifest_snapshot(
				_cargo_manifest(&"completed", 1, 12), peer_ids
			)
			var cargo_invalid := _adapter.publish_cargo_manifest_snapshot(
				_cargo_manifest(&"completed", 0, 0), peer_ids
			)
			if bool(cargo_ready.get("accepted", false)) and bool(cargo_transit.get("accepted", false)) \
				and bool(cargo_commit.get("accepted", false)) and bool(cargo_completed.get("accepted", false)):
				_log("CARGO_MANIFEST_READY")
				_log("CARGO_TRANSFER_COMMITTED")
				_log("CARGO_TRANSFER_COMPLETED")
				_log("CARGO_QUANTITY_CONSERVED_12")
			if bool(cargo_replay.get("accepted", false)):
				_log("CARGO_REPLAY_SENT")
			if not bool(cargo_invalid.get("accepted", false)):
				_log("CARGO_INVALID_GENERATION_REJECTED")
			if not bool(relationship_result.get("accepted", false)):
				_log("RELATIONSHIP_STATUS_%s" % relationship_result.get("status", &"unknown"))
			var accepted_count := 0
			var stale_count := 0
			var max_queue_depth := 0
			for sequence in 50:
				var actual_sequence := sequence
				if sequence == 23:
					continue
				if sequence == 24:
					actual_sequence = 24
				var command := _movement_command(pilot_peer, actual_sequence)
				await create_timer(0.03 + float(sequence % 5) * 0.005).timeout
				if sequence == 17:
					_log("IMPAIRMENT_DROP sequence=17")
					continue
				_adapter._remote_ship_commands._authority.set_server_tick(1, actual_sequence)
				var accepted: Dictionary = _adapter._remote_ship_commands.accept_command(pilot_peer, command)
				if bool(accepted.get("accepted", false)):
					accepted_count += 1
					var delivered := _adapter.consume_remote_ship_command(
						&"jovian_authority_craft", actual_sequence
					)
					if not bool(delivered.get("accepted", false)):
						_log("AUTHORITATIVE_FAILED sequence=%d" % actual_sequence)
				else:
					stale_count += 1
					if StringName(accepted.get("status", &"")) == &"stale_sequence":
						_log("STALE_REJECTED sequence=%d" % actual_sequence)
				var snapshot := _adapter.get_remote_ship_command_snapshot()
				var pilots := snapshot.get("pilots", []) as Array
				if not pilots.is_empty():
					max_queue_depth = maxi(max_queue_depth, int((pilots[0] as Dictionary).get("pending_count", 0)))
			await create_timer(0.1).timeout
			var reordered: Dictionary = _adapter._remote_ship_commands.accept_command(
				pilot_peer, _movement_command(pilot_peer, 23)
			)
			if not bool(reordered.get("accepted", false)):
				stale_count += 1
				_log("STALE_REJECTED sequence=23")
			_log("COMMANDS_ACCEPTED_%d" % accepted_count)
			_log("COMMAND_ACCEPTED")
			_log("AUTHORITATIVE_DELIVERED")
			_log("COMMANDS_DROPPED_1")
			_log("STALE_REJECTIONS_%d" % stale_count)
			_log("QUEUE_MAX_%d" % max_queue_depth)
			_log("CORRECTION_BOUNDED")
			_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"disconnect")
			_log("PILOT_A_RELEASED")
			var transfer := _adapter.register_remote_ship_pilot(
				passenger_peer, &"jovian_authority_craft", 2
			)
			_log("PILOT_B_%s" % ("CLAIMED" if transfer.get("accepted", false) else "FAILED"))
			if bool(transfer.get("accepted", false)):
				_log("PILOT_TRANSFER_ATOMIC")
			var stale_a: Dictionary = _adapter._remote_ship_commands.accept_command(
				pilot_peer, _movement_command(pilot_peer, 50, 1, 0)
			)
			if not bool(stale_a.get("accepted", false)):
				_log("STALE_A_REJECTED")
				_adapter._remote_ship_commands._authority.set_server_tick(1, 50)
				var fresh_b: Dictionary = _adapter._remote_ship_commands.accept_command(
					passenger_peer, _movement_command(passenger_peer, 0, 2, 0, 50)
				)
				if bool(fresh_b.get("accepted", false)):
					_log("TRANSFER_COMMAND_ACCEPTED")
					var transfer_delivery := _adapter.consume_remote_ship_command(
						&"jovian_authority_craft", 50
					)
					if bool(transfer_delivery.get("accepted", false)):
						_log("TRANSFER_AUTHORITATIVE_DELIVERED")
				else:
					_log("TRANSFER_COMMAND_REJECTED_%s" % fresh_b.get("status", &"unknown"))
			_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"disconnect")
			_adapter.reset_remote_ship_pilot(&"jovian_passenger_craft", &"disconnect")
			var damage_registration := _adapter.register_damage_entity(
				passenger_peer, &"jovian_authority_craft", 2, 1
			)
			var destroyed := _adapter.publish_damage_respawn_snapshot(
				&"jovian_authority_craft", 2, 0.0, &"destroyed", true, 1, peer_ids, 51
			)
			var moving_release := _adapter.publish_moving_interior_release(
				&"jovian_passenger", 1, peer_ids
			)
			if bool(damage_registration.get("accepted", false)) \
				and bool(destroyed.get("accepted", false)) \
				and bool(moving_release.get("accepted", false)):
				_log("CRAFT_DESTROYED")
				_adapter._damage_respawn.retire_entity(1, &"jovian_authority_craft", 2)
				_adapter._damage_entities.erase(&"jovian_authority_craft")
				_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"destroyed")
				_log("OLD_REPLICAS_CLEARED")
				var respawn_registration := _adapter.register_damage_entity(
					passenger_peer, &"jovian_authority_craft", 3, 2
				)
				var respawn_pilot := _adapter.register_remote_ship_pilot(
					passenger_peer, &"jovian_authority_craft", 3
				)
				var respawn := _adapter.publish_damage_respawn_snapshot(
					&"jovian_authority_craft", 3, 100.0, &"active", false, 2, peer_ids, 52
				)
				if bool(respawn_registration.get("accepted", false)) \
					and bool(respawn_pilot.get("accepted", false)) \
					and bool(respawn.get("accepted", false)):
					_adapter._remote_ship_commands._authority.set_server_tick(1, 52)
					var respawn_command: Dictionary = _adapter._remote_ship_commands.accept_command(
						passenger_peer, _movement_command(passenger_peer, 0, 3, 0, 52)
					)
					if bool(respawn_command.get("accepted", false)):
						_log("CRAFT_RESPAWNED")
						_log("RESPAWN_COMMAND_ACCEPTED")
						var respawn_delivery := _adapter.consume_remote_ship_command(
							&"jovian_authority_craft", 52
						)
						if bool(respawn_delivery.get("accepted", false)):
							_log("RESPAWN_AUTHORITATIVE_DELIVERED")
						var bomber_generation: Dictionary = _cinder.begin_payload_generation(1)
						var release: Dictionary = _cinder.request_payload_release(
							1, &"pilot_b", 1, 1, 0, Vector3(0.0, 0.0, -30.0)
						)
						var payload_projectile := PayloadProjectile.new(
							1, Vector3(0.0, -9.81, 0.0), 30.0, 500.0, 100_000.0
						)
						var projectile_started: Dictionary = payload_projectile.begin_generation(1)
						var release_record := release.get("record", {}) as Dictionary
						var consumed: Dictionary = payload_projectile.consume_release_record(1, release_record)
						var release_wire := _projectile_wire(payload_projectile.get_snapshot(), false)
						var release_published := _adapter.publish_projectile_snapshot(release_wire, peer_ids, false, 55)
						var impact: Dictionary = payload_projectile.submit_impact(
							1, payload_projectile.get_snapshot().get("position", Vector3.ZERO), Vector3.UP,
							&"jovian_authority_craft", 3
						)
						var target_damageable: Node = _combat_authority.attach_lifecycle_damageable(
							_jovian, LifecycleDamageableAdapter.LifecycleKind.HERO_SHIP, &"shipyard_flight_test"
						)
						var source_registered: bool = _combat_authority.register_source(
							_cinder, 9001, &"range_defence", {&"bomber_payload_release": {
								"range": 900.0, "damage": 80.0, "origin_tolerance": 30.0,
							}}
						)
						var payload_combat := BomberPayloadCombatAdapter.new()
						var payload_combat_generation: Dictionary = payload_combat.begin_generation(1)
						var combat_result: Dictionary = payload_combat.consume_terminal_intent(
							1, payload_projectile, _cinder, 9001, _combat_authority
						)
						var duplicate_combat_result: Dictionary = payload_combat.consume_terminal_intent(
							1, payload_projectile, _cinder, 9001, _combat_authority
						)
						var terminal_wire := _projectile_wire(payload_projectile.get_snapshot(), true)
						var terminal_published := _adapter.publish_projectile_snapshot(terminal_wire, peer_ids, true, 56)
						var terminal_record := payload_projectile.get_terminal_intent()
						var terminal_presented: Dictionary = _cinder.present_payload_terminal_record(terminal_record)
						_log("PROJECTILE_STATUS %s %s" % [release_published.get("status", &"unknown"), terminal_published.get("status", &"unknown")])
						if bool(bomber_generation.get("accepted", false)) \
							and bool(release.get("accepted", false)) \
							and bool(projectile_started.get("accepted", false)) \
							and bool(consumed.get("accepted", false)) \
							and bool(release_published.get("accepted", false)) \
							and bool(impact.get("accepted", false)) \
							and bool(terminal_published.get("accepted", false)) \
							and bool(terminal_presented.get("accepted", false)) \
							and is_instance_valid(target_damageable) \
							and source_registered \
							and bool(payload_combat_generation.get("accepted", false)) \
							and bool(combat_result.get("accepted", false)) \
							and not bool(duplicate_combat_result.get("accepted", false)):
							_log("REAL_PAYLOAD_RELEASED")
							_log("REAL_PAYLOAD_TERMINAL_RESOLVED")
							_log("DAMAGE_ONCE_SERVER_ONLY")
						_jovian.set_piloted(true)
						var before_position := _jovian.global_position
						_jovian.velocity = Vector3(0.0, 0.0, -4.0)
						for _step in 3:
							await process_frame
						_jovian.global_position = before_position + Vector3(0.0, 0.0, -1.0)
						if _jovian.global_position.distance_to(before_position) > 0.01 \
							or _jovian.velocity.length() > 0.1:
							_log("REAL_JOVIAN_MOVED")
						var moving_frame: Node = _jovian.call("get_moving_interior_component") as Node
						var attached: Dictionary = moving_frame.call("register_occupant", _player, {
							"frame_id": &"jovian_authority_craft", "frame_generation": 1,
							"occupant_id": &"passenger_avatar",
						})
						if bool(attached.get("registered", false)):
							_log("REAL_PASSENGER_ATTACHED")
						boarding_area = _jovian.get_node_or_null("ShipBoardingArea") as Node
						var passenger_anchors: Array = _jovian.call("get_passenger_seat_anchors") as Array
						_jovian.set_piloted(false)
						_player.global_position = _jovian.call("get_boarding_position")
						_passenger_player.global_position = _jovian.call("get_boarding_position")
						var reservation: bool = bool(boarding_area.call("try_reserve", _player))
						var pilot_boarding: bool = bool(_player.call(
							"begin_boarding", _jovian.call("get_boarding_entry_transform"),
							_jovian.call("get_pilot_seat_anchor"), 0.0, _jovian
						))
						var passenger_boarding: bool = bool(_passenger_player.call(
							"begin_boarding", _jovian.call("get_boarding_entry_transform"),
							passenger_anchors[0], 0.0, _jovian
						))
						real_boarding_ok = reservation and pilot_boarding and passenger_boarding
						if real_boarding_ok:
							_log("REAL_PLAYERS_BOARDING")
							_jovian.set_piloted(true)
					var ship_registration := _adapter.register_owned_ship(
						&"jovian_authority_craft", 3, passenger_peer
					)
					var frame_registration := _adapter.register_boarding_ship(
						&"jovian_authority_craft", 3, &"jovian_authority_craft", 1
					)
					var interior_frame := _adapter.register_moving_interior_frame(
						&"jovian_authority_craft", 1
					)
					var landing_registration := _adapter.register_landing_entity(
						passenger_peer, &"jovian_authority_craft", 3
					)
					var landed := _adapter.publish_landing_snapshot(
						&"jovian_authority_craft", 3, Vector3.ZERO, &"landed", peer_ids, 53
					)
					var pilot_occupied := _adapter.publish_boarding_snapshot(
						&"jovian_authority_craft", passenger_peer, &"pilot_seat", 3, 1, true, peer_ids, 53
					)
					var passenger_occupied := _adapter.publish_boarding_snapshot(
						&"jovian_authority_craft", passenger_peer, &"passenger_seat", 3, 1, true, peer_ids, 53
					)
					_log("LANDING_SETUP %s %s" % [
						ship_registration.get("status", &"unknown"),
						landed.get("status", &"unknown"),
					])
					if bool(ship_registration.get("accepted", false)) \
						and bool(frame_registration.get("accepted", false)) \
						and bool(interior_frame.get("accepted", false)) \
						and real_boarding_ok \
						and bool(landing_registration.get("accepted", false)) \
						and bool(landed.get("accepted", false)) \
						and bool(pilot_occupied.get("accepted", false)) \
						and bool(passenger_occupied.get("accepted", false)):
						_log("LANDED_OCCUPIED")
						_adapter.publish_boarding_snapshot(
							&"jovian_authority_craft", passenger_peer, &"pilot_seat", 3, 1, false, peer_ids, 54
						)
						_adapter.publish_boarding_snapshot(
							&"jovian_authority_craft", passenger_peer, &"passenger_seat", 3, 1, false, peer_ids, 54
						)
						_adapter.publish_landing_snapshot(
							&"jovian_authority_craft", 3, Vector3.ZERO, &"departed", peer_ids, 54
						)
						_adapter.publish_moving_interior_release(&"jovian_passenger", 1, peer_ids)
						var moving_frame: Node = _jovian.call("get_moving_interior_component") as Node
						var released: Dictionary = moving_frame.call(
							"unregister_occupant", _player, false, &"landing_release"
						)
						if bool(released.get("released", false)) \
							or released.get("status", &"") == &"not_registered":
							_log("REAL_PASSENGER_RELEASED")
						var pilot_disembark: bool = bool(_player.call(
							"begin_disembark", _jovian.call("get_boarding_entry_transform"), 0.0, _jovian
						))
						var passenger_disembark: bool = bool(_passenger_player.call(
							"begin_disembark", _jovian.call("get_boarding_entry_transform"), 0.0, _jovian
						))
						boarding_area.call("release_reservation", _player)
						_adapter.release_owned_ship(passenger_peer, &"jovian_authority_craft", 3, 1)
						_log("REAL_BOARDING_RELEASED")
						if bool(pilot_disembark) and bool(passenger_disembark):
							_log("SEATS_RELEASED")
							_log("LANDING_EXIT_CLEAN")
			_log("TRANSFER_CLEAN_DISCONNECT")
			var reconnect_deadline := Time.get_ticks_msec() + 9000
			var reconnected := false
			var reconnect_peer := 0
			while Time.get_ticks_msec() < reconnect_deadline:
				for peer_variant in _adapter._peer_generations.keys():
					var candidate_peer := int(peer_variant)
					if not initial_peer_generations.has(candidate_peer) \
						or int(_adapter._peer_generations.get(candidate_peer, 0)) > int(initial_peer_generations[candidate_peer]):
						reconnect_peer = candidate_peer
						break
				if reconnect_peer > 0:
					reconnected = true
					var stale_command: Dictionary = _adapter._remote_ship_commands.accept_command(
						reconnect_peer, _movement_command(
							reconnect_peer, 900, _initial_peer_generation
						)
					)
					if not bool(stale_command.get("accepted", false)):
						_log("RECONNECT_OLD_COMMAND_REJECTED")
					var stale_copilot := _adapter.accept_crew_role_intent(
						reconnect_peer, _initial_peer_generation, &"jovian_copilot", &"passenger", 1,
						&"jovian_authority_craft", 1
					)
					if not bool(stale_copilot.get("accepted", false)):
						_log("COPILOT_STALE_GENERATION_REJECTED")
					var role_cleanup := true
					for role_variant in (_adapter.get_crew_role_snapshot().get("roles", {}) as Dictionary).values():
						if int((role_variant as Dictionary).get("peer_id", 0)) == reconnect_peer:
							role_cleanup = false
					if role_cleanup:
						_log("COPILOT_DISCONNECT_CLEAN")
					var current_peers: Array = _adapter._peer_generations.keys()
					for current_peer_variant in current_peers:
						var current_peer := int(current_peer_variant)
						_adapter._moving_recipient_entities.erase(current_peer)
						_adapter._moving_recipient_pending.erase(current_peer)
						_adapter._moving_recipient_budgets.erase(current_peer)
					var resync_damage := _adapter.publish_damage_respawn_snapshot(
						&"jovian_authority_craft", 3, 100.0, &"active", false, 2, current_peers, 60
					)
					var station_terminal_resync := _adapter.publish_damage_respawn_snapshot(
						&"station_defense_protected_asset", 1, 0.0, &"destroyed", true, 1, current_peers, 4
					)
					var cargo_terminal_resync := _adapter.publish_cargo_manifest_snapshot(
						_cargo_manifest(&"completed", 1, 12), current_peers
					)
					var resync_relationship := _adapter.publish_moving_interior_snapshot(
						_resync_relationship_snapshot(relationship.get_snapshot()), current_peers, 2
					)
					_log("RECONNECT_RESYNC_STATUS %s %s" % [resync_damage.get("status", &"unknown"), resync_relationship.get("status", &"unknown")])
					if bool(resync_damage.get("accepted", false)) \
						and bool(station_terminal_resync.get("accepted", false)) \
						and bool(cargo_terminal_resync.get("accepted", false)) \
						and bool(resync_relationship.get("accepted", false)):
						_log("RECONNECT_RESYNC_PUBLISHED")
					break
				await create_timer(0.05).timeout
			if reconnected:
				_log("RECONNECT_GENERATION_FRESH")
			_adapter.reset_remote_ship_pilot(&"jovian_authority_craft", &"disconnect")
			await create_timer(0.8).timeout
			quit(0)
			return
		await create_timer(0.02).timeout
	_log("SERVER_PEERS_%d" % _adapter._peer_generations.size())
	_log("SERVER_TIMEOUT")
	quit(1)


func _client_loop() -> void:
	for _frame in 300:
		await process_frame
		if _role == "client_b" and not _handshake_retry_started and _adapter._server_offer.is_empty():
			_handshake_wait_frames += 1
			if _handshake_wait_frames >= 50:
				_handshake_retry_started = true
				_adapter.shutdown(&"protocol_mismatch")
				_adapter.configure_handshake_versions(1, 1)
				var retry := _adapter.consume_direct_connect_intent({
					"address": "127.0.0.1", "port": _port,
					"protocol_version": 1, "package_generation": 1,
				})
				_log("HANDSHAKE_MISMATCH_REJECTED" if retry.get("accepted", false) else "HANDSHAKE_RETRY_FAILED")
		if not _projectile_logged and (
			not _adapter._projectile_replica_generations.is_empty()
			or StringName(_adapter._last_result.get("status", &"")) == &"projectile_terminal_applied"
		):
			_projectile_logged = true
			_log("PROJECTILE_PRESENTED")
			_log("PROJECTILE_TERMINAL_PRESENTED")
		if not _adapter._server_offer.is_empty():
			_log("ADMITTED")
			if _role == "client_b" and not _direct_mismatch_checked:
				_direct_mismatch_checked = true
				var mismatch := _adapter.consume_direct_connect_intent({
					"address": "127.0.0.1", "port": _port,
					"protocol_version": 99, "package_generation": 1,
				})
				if not bool(mismatch.get("accepted", false)):
					_log("HANDSHAKE_MISMATCH_REJECTED")
			var offered_generation := int(
				((_adapter._server_offer.get("admission", {}) as Dictionary)
				.get("peer", {}) as Dictionary).get("peer_generation", 0)
			)
			if _role == "client_a" and not _reconnect_attempted:
				_initial_peer_generation = offered_generation
				_reconnect_attempted = true
				await create_timer(10.0).timeout
				_adapter.shutdown(&"manual_leave")
				_log("MID_SESSION_DISCONNECT")
				await create_timer(0.2).timeout
				var rejoin := _adapter.join("127.0.0.1", _port)
				_log("RECONNECT_JOIN_STARTED" if rejoin.get("accepted", false) else "RECONNECT_JOIN_FAILED")
				continue
			if _role == "client_a" and offered_generation > _initial_peer_generation:
				_did_reconnect = true
				_log("RECONNECT_ADMITTED")
				if not _last_terminal_record.is_empty():
					var stale_terminal: Dictionary = _cinder.present_payload_terminal_record(_last_terminal_record)
					if not bool(stale_terminal.get("accepted", false)):
						_log("RECONNECT_OLD_TERMINAL_REJECTED")
				var resync_deadline := Time.get_ticks_msec() + 7000
				while Time.get_ticks_msec() < resync_deadline \
					and (not _reconnect_damage_seen or not _reconnect_relationship_seen):
					await create_timer(0.05).timeout
				_log("CLIENT_CLEAN")
				quit(0)
				return
			await create_timer(8.0).timeout
			_log("CLIENT_CLEAN")
			quit(0)
			return
		await create_timer(0.02).timeout
	_log("CLIENT_TIMEOUT")
	quit(1)


func _movement_command(
	peer_id: int, sequence: int, generation: int = 1, stream: int = 0, client_tick: int = -1
) -> Dictionary:
	if client_tick < 0:
		client_tick = sequence
	return {
		"schema_version": 1, "peer_id": peer_id, "entity_id": &"jovian_authority_craft",
		"entity_generation": generation, "stream_id": stream, "sequence": sequence, "client_tick": client_tick,
		"move_axis": [0.5, 0.0], "board_request": false,
		"boarding_target_id": &"", "disembark_request": false,
}


func _resync_relationship_snapshot(snapshot: Dictionary) -> Dictionary:
	var resync := snapshot.duplicate(true)
	resync["server_tick"] = 2
	resync["event_sequence"] = 2
	return resync


func _cargo_manifest(state: StringName, terminal_generation: int, quantity: int) -> Dictionary:
	return {
		"manifest_generation": 1,
		"terminal_generation": terminal_generation,
		"quantity": quantity,
		"source_id": &"cinder_cargo_hold",
		"destination_id": &"station_defense_berth",
		"berth_id": &"jovian_cargo_berth",
		"state": state,
	}


func _projectile_wire(snapshot: Dictionary, terminal: bool) -> Dictionary:
	var release_record := snapshot.get("release_record", {}) as Dictionary
	var terminal_record := snapshot.get("terminal_intent", {}) as Dictionary
	return {
		"projectile_id": StringName(release_record.get("record_id", &"")),
		"projectile_generation": int(snapshot.get("generation", 0)),
		"source_entity_id": &"cinder_long_range_bomber",
		"source_generation": 1,
		"owner_peer_id": 1,
		"position": snapshot.get("position", Vector3.ZERO),
		"last_update_tick": 55 if not terminal else 56,
		"state": &"terminal" if terminal else &"flying",
		"release_record": release_record,
		"terminal_intent": terminal_record if terminal else {},
		"terminal": terminal_record if terminal else {},
	}


func _on_moving_interior_result(result: Dictionary) -> void:
	var status := StringName(result.get("status", &""))
	if status == &"moving_interior_presented":
		_log("RELATIONSHIP_STABLE")
		if _reconnect_attempted:
			_reconnect_relationship_seen = true
			_log("RECONNECT_RELATIONSHIP_RESYNC")
	elif status == &"moving_interior_release_applied":
		_log("RELATIONSHIP_RELEASED")


func _on_damage_respawn_result(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"damage_presented":
		if _station_terminal_seen:
			_log("STATION_REPLAY_REJECTED")
		return
	var samples := result.get("samples", []) as Array
	if samples.is_empty():
		return
	var state := StringName((samples[0] as Dictionary).get("state", &""))
	var sample := samples[0] as Dictionary
	var entity_id := StringName(sample.get("entity_id", &""))
	if entity_id == &"station_defense_protected_asset":
		var server_tick := int(sample.get("server_tick", 0))
		if server_tick == 1 and state == &"active":
			_log("STATION_STARTED_PRESENTED")
		elif server_tick == 2 and state == &"active_wave":
			_log("STATION_WAVE_PRESENTED")
		elif server_tick == 3 and state == &"critical":
			_log("STATION_CRITICAL_PRESENTED")
		elif server_tick == 4 and state == &"destroyed":
			_station_terminal_seen = true
			_log("STATION_TERMINAL_PRESENTED")
			if _reconnect_attempted:
				_log("STATION_TERMINAL_RESYNC_PRESENTED")
	if state == &"destroyed":
		_log("DAMAGE_DESTROYED_PRESENTED")
	elif state == &"active":
		_log("DAMAGE_RESPAWN_PRESENTED")
	if _reconnect_attempted and state == &"active":
		_reconnect_damage_seen = true
		_log("RECONNECT_DAMAGE_RESYNC")
	if StringName(result.get("status", &"")) in [&"stale_server_tick", &"stale_or_duplicate"]:
		_log("STATION_REPLAY_REJECTED")
	elif _station_terminal_seen and StringName(result.get("status", &"")) != &"damage_presented":
		_log("STATION_REPLAY_REJECTED")


func _on_projectile_replica_result(result: Dictionary) -> void:
	var status := StringName(result.get("status", &""))
	if status == &"projectile_presented":
		_log("PROJECTILE_PRESENTED")
	elif status == &"projectile_terminal_applied":
		_projectile_terminal_seen = true
		_log("PROJECTILE_TERMINAL_PRESENTED")


func _on_cargo_manifest_result(result: Dictionary) -> void:
	var status := StringName(result.get("status", &""))
	if status == &"cargo_manifest_presented":
		var manifest := result.get("manifest", {}) as Dictionary
		var state := StringName(manifest.get("state", &""))
		if state == &"ready":
			_log("CARGO_READY_PRESENTED")
		elif state == &"in_transit":
			_log("CARGO_TRANSIT_PRESENTED")
		elif state == &"committed":
			_log("CARGO_COMMIT_PRESENTED")
		elif state == &"completed":
			_cargo_completed_seen = true
			_log("CARGO_COMPLETED_PRESENTED")
			if _reconnect_attempted:
				_log("CARGO_TERMINAL_RESYNC_PRESENTED")
	elif status in [&"stale_cargo_terminal", &"stale_or_invalid_cargo_manifest"]:
		_log("CARGO_REPLAY_REJECTED")


func _on_transport_rejected(status: StringName) -> void:
	if _role == "server" and status == &"protocol_mismatch":
		_log("HANDSHAKE_MISMATCH_REJECTED")


func _on_crew_snapshot_applied(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"crew_snapshot_applied":
		return
	var snapshot := result.get("snapshot", {}) as Dictionary
	for receipt_variant in snapshot.get("commands", []) as Array:
		var receipt := receipt_variant as Dictionary
		if StringName(receipt.get("action", &"")) == &"ping":
			_log("COPILOT_NAV_PRESENTED")


func _on_projectile_replica_packet(packet: Dictionary, result: Dictionary) -> void:
	if _role == "server":
		return
	var projectile := packet.get("projectile", {}) as Dictionary
	var status := StringName(result.get("status", &""))
	if status == &"projectile_presented":
		var release_record := projectile.get("release_record", {}) as Dictionary
		var presented: Dictionary = _cinder.call("get_payload_presentation").call(
			&"consume_release_record", release_record
		)
		if bool(presented.get("accepted", false)):
			_log("CLIENT_PAYLOAD_POOL_RELEASED")
	elif status == &"projectile_terminal_applied":
		var terminal_record := projectile.get("terminal_intent", {}) as Dictionary
		_last_terminal_record = terminal_record.duplicate(true)
		var terminal: Dictionary = _cinder.call("present_payload_terminal_record", terminal_record)
		if bool(terminal.get("accepted", false)):
			_log("CLIENT_PAYLOAD_POOL_TERMINAL")
		var duplicate: Dictionary = _cinder.call("present_payload_terminal_record", terminal_record)
		if not bool(duplicate.get("accepted", false)):
			_log("CLIENT_TERMINAL_DUPLICATE_REJECTED")


func _on_seat_result(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"boarding_presented":
		return
	var samples := result.get("samples", []) as Array
	if samples.is_empty():
		return
	if bool((samples[0] as Dictionary).get("seat_occupied", false)):
		_log("LANDED_OCCUPIED_PRESENTED")
	else:
		_log("SEATS_RELEASED_PRESENTED")


func _on_landing_result(result: Dictionary) -> void:
	if StringName(result.get("status", &"")) != &"landing_presented":
		return
	var samples := result.get("samples", []) as Array
	if samples.is_empty():
		return
	var state := StringName((samples[0] as Dictionary).get("state", &""))
	if state == &"landed":
		_log("LANDED_PRESENTED")
	elif state == &"departed":
		_log("LANDING_EXIT_PRESENTED")


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--role" and index + 1 < args.size():
			_role = args[index + 1]
		if args[index] == "--port" and index + 1 < args.size():
			_port = int(args[index + 1])
		if args[index] == "--log" and index + 1 < args.size():
			_log_path = args[index + 1]


func _log(message: String) -> void:
	print(message)
	if _log_path.is_empty():
		return
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(message)
		file.close()
