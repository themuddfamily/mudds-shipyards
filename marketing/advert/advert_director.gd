extends SceneTree

## Scripted in-engine trailer for Mudds Shipyards.
##
## Loads the production main scene, parks the live game (UI hidden, ship logic
## disabled) and drives a cinematic camera, ship motion and title cards through a
## fixed shot list. Two modes:
##
##   ADVERT_MODE=stills  -> one PNG per shot into marketing/advert/stills/
##   (default)           -> real-time playback; run with Godot's Movie Maker
##                          (--write-movie <file>.avi --fixed-fps 30) to record.
##
## Always run on an isolated display with --audio-driver Dummy; see
## marketing/advert/render_advert.sh.

const MAIN_SCENE := "res://scenes/main.tscn"
const EMBER_SCENE := "res://scenes/world/planets/ember_moon.tscn"
const AURORA_SCENE := "res://scenes/world/planets/aurora_temperate_world.tscn"
const RESOLUTION := Vector2i(1920, 1080)
const PAD_Y := 120000.0
const STILLS_DIR := "res://marketing/advert/stills"

var _game: Node3D
var _world: Node3D
var _env_node: WorldEnvironment
var _camera: Camera3D
var _ember: Node3D
var _aurora: Node3D
var _ember_sun: DirectionalLight3D
var _ships := {}
var _ship_home := {}
var _fx_root: Node3D
var _bolts: Array[MeshInstance3D] = []
var _blast: MeshInstance3D
var _puffs: Array[MeshInstance3D] = []
var _blast_light: OmniLight3D

var _overlay: CanvasLayer
var _fade: ColorRect
var _title: Label
var _subtitle: Label
var _small: Label

var _shots: Array[Dictionary] = []
var _time := 0.0
var _total := 0.0
var _stage := ""
var _stills := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_stills = OS.get_environment("ADVERT_MODE") == "stills"
	DisplayServer.window_set_size(RESOLUTION)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = RESOLUTION

	_game = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_game)
	await _settle(20)
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		(candidate as CanvasLayer).visible = false
		candidate.process_mode = Node.PROCESS_MODE_DISABLED
	_world = _game.get_node(^"ShipyardWorld") as Node3D
	for candidate in _game.find_children("*", "WorldEnvironment", true, false):
		_env_node = candidate as WorldEnvironment
		break
	for ship_name in ["TorrentInterceptor", "ArrowReconShip", "JovianLightFreighter", "ZenithInterceptor",
			"HalyardCrewTransport", "BulwarkHeavyGunship"]:
		_register_ship(ship_name, _game.get_node_or_null(NodePath(ship_name)) as Node3D)
	var expansion := _world.get_node_or_null(^"FleetExpansionProductionBinding")
	if expansion:
		for ship_name in ["cinder_cargo_hauler", "cinder_long_range_bomber", "cinder_light_interceptor"]:
			_register_ship(ship_name, expansion.get_node_or_null(NodePath(ship_name)) as Node3D)
	for key in _ships:
		print("ADVERT_SHIP ", key, " ", (_ships[key] as Node3D).global_transform)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.near = 0.1
	_camera.far = 400000.0
	root.add_child(_camera)
	_camera.make_current()

	_build_fx()
	_build_overlay()
	_build_shots()
	await _settle(4)

	if _stills:
		await _render_stills()
		quit(0)
		return
	var director := Node.new()
	director.name = "AdvertClock"
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	director.set_script(_clock_script())
	director.set("tree", self)
	root.add_child(director)


func _register_ship(key: String, ship: Node3D) -> void:
	if ship == null:
		push_warning("ADVERT: missing ship %s" % key)
		return
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	_ships[key] = ship
	_ship_home[key] = ship.global_transform


# --- time line -------------------------------------------------------------

func _clock_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar tree\nfunc _process(delta: float) -> void:\n\ttree.advance(delta)\n"
	s.reload()
	return s


var _started := false


func advance(delta: float) -> void:
	if not _started:
		# Movie Maker records the load/setup frames too; the mux trims to here.
		_started = true
		print("ADVERT_START_FRAME ", Engine.get_frames_drawn())
		_apply_time(0.0)
		return
	_time += delta
	if _time >= _total:
		print("ADVERT_DONE ", _total)
		quit(0)
		return
	_apply_time(_time)


func _apply_time(t: float) -> void:
	var start := 0.0
	for shot in _shots:
		var dur: float = shot.dur
		if t < start + dur:
			var local := t - start
			var u := local / dur
			if shot.get("stage", "") != _stage:
				_enter_stage(shot.get("stage", ""))
			(shot.run as Callable).call(u)
			_camera.make_current()
			_apply_card(shot, local, dur)
			# Short dip to black between shots keeps cuts clean.
			var edge := minf(local, dur - local)
			var dip: float = shot.get("dip", 0.18)
			_fade.color.a = clampf(1.0 - edge / dip, 0.0, 1.0) if dip > 0.0 else 0.0
			var dim: float = shot.get("dim", 0.0) * clampf((local - 0.6) / 1.2, 0.0, 1.0)
			_fade.color.a = maxf(_fade.color.a, dim)
			if shot.has("flash"):
				var flash := (shot.flash as Callable).call(local / dur) as float
				_fade.color = Color(1, 0.9, 0.75, flash) if flash > _fade.color.a else Color(0, 0, 0, _fade.color.a)
			else:
				_fade.color = Color(0, 0, 0, _fade.color.a)
			if shot.has("fade_in") and local < float(shot.fade_in):
				_fade.color.a = maxf(_fade.color.a, 1.0 - local / float(shot.fade_in))
			if shot.has("fade_out") and dur - local < float(shot.fade_out):
				_fade.color.a = maxf(_fade.color.a, 1.0 - (dur - local) / float(shot.fade_out))
			return
		start += dur


func _render_stills() -> void:
	var stills_dir := OS.get_environment("ADVERT_STILLS_DIR")
	if stills_dir.is_empty():
		stills_dir = ProjectSettings.globalize_path(STILLS_DIR)
	DirAccess.make_dir_recursive_absolute(stills_dir)
	var start := 0.0
	var index := 0
	var only := OS.get_environment("ADVERT_ONLY")
	for shot in _shots:
		var dur: float = shot.dur
		if only.is_empty() or str(index) in only.split(","):
			for u in shot.get("still_u", [0.5]):
				_apply_time(start + dur * float(u))
				_fade.color.a = 0.0
				await _settle(8)
				var image := root.get_texture().get_image()
				var path := "%s/%02d_%s_%02d.png" % [stills_dir, index, shot.name, int(float(u) * 100)]
				image.save_png(path)
				print("ADVERT_STILL ", path)
		start += dur
		index += 1


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


# --- stages ----------------------------------------------------------------

func _enter_stage(stage: String) -> void:
	_stage = stage
	_reset_ships()
	_fx_root.visible = false
	_world.visible = stage == "station"
	if _ember:
		_ember.visible = stage == "ember"
	if _ember_sun:
		_ember_sun.visible = stage == "ember"
	if _aurora:
		_aurora.visible = stage == "aurora"
	for key in _ships:
		(_ships[key] as Node3D).visible = stage == "station"
	if stage == "ember":
		if _ember == null:
			_ember = (load(EMBER_SCENE) as PackedScene).instantiate() as Node3D
			root.add_child(_ember)
			_ember_sun = DirectionalLight3D.new()
			_ember_sun.light_energy = 2.2
			_ember_sun.shadow_enabled = true
			_ember_sun.directional_shadow_max_distance = 400.0
			_ember_sun.rotation_degrees = Vector3(-18.0, -130.0, 0.0)
			_ember_sun.light_color = Color(1.0, 0.93, 0.85)
			root.add_child(_ember_sun)
		_ensure_env(_env_node)
	elif stage == "aurora":
		if _aurora == null:
			_aurora = (load(AURORA_SCENE) as PackedScene).instantiate() as Node3D
			root.add_child(_aurora)
		# Aurora supplies its own sky; the station's space environment must leave.
		if _env_node and _env_node.is_inside_tree():
			_env_node.get_parent().remove_child(_env_node)
			_env_parent_holder = _game
	else:
		_ensure_env(_env_node)


var _env_parent_holder: Node


func _ensure_env(env: WorldEnvironment) -> void:
	if env and not env.is_inside_tree() and _env_parent_holder:
		_env_parent_holder.add_child(env)
	if _aurora and _stage != "aurora":
		_aurora.visible = false


func _reset_ships() -> void:
	for key in _ships:
		(_ships[key] as Node3D).global_transform = _ship_home[key]


func _ship(key: String) -> Node3D:
	return _ships[key] as Node3D


# --- effects ---------------------------------------------------------------

func _build_fx() -> void:
	_fx_root = Node3D.new()
	root.add_child(_fx_root)
	var bolt_mesh := CapsuleMesh.new()
	bolt_mesh.radius = 0.16
	bolt_mesh.height = 4.5
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mat.albedo_color = Color(0.55, 0.95, 1.0)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.4, 0.9, 1.0)
	bolt_mat.emission_energy_multiplier = 6.0
	bolt_mesh.material = bolt_mat
	for _i in 8:
		var bolt := MeshInstance3D.new()
		bolt.mesh = bolt_mesh
		_fx_root.add_child(bolt)
		_bolts.append(bolt)
	_blast = _additive_sphere()
	for _i in 7:
		_puffs.append(_additive_sphere())
	_blast_light = OmniLight3D.new()
	_blast_light.light_color = Color(1.0, 0.6, 0.3)
	_blast_light.omni_range = 60.0
	_fx_root.add_child(_blast_light)
	_fx_root.visible = false


func _additive_sphere() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	sphere.material = mat
	var node := MeshInstance3D.new()
	node.mesh = sphere
	_fx_root.add_child(node)
	return node


# --- overlay ---------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	root.add_child(_overlay)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.size = Vector2(RESOLUTION)
	_overlay.add_child(_fade)
	# Letterbox bars sit above the fade so the kill flash stays inside the frame.
	var bar_h := 96
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(RESOLUTION.x, bar_h)
		bar.position = Vector2(0, 0 if top else RESOLUTION.y - bar_h)
		_overlay.add_child(bar)

	var base := SystemFont.new()
	base.font_names = PackedStringArray(["DejaVu Sans"])
	base.font_weight = 700
	var wide := FontVariation.new()
	wide.base_font = base
	wide.spacing_glyph = 10
	var light := SystemFont.new()
	light.font_names = PackedStringArray(["DejaVu Sans"])
	light.font_weight = 300
	var light_wide := FontVariation.new()
	light_wide.base_font = light
	light_wide.spacing_glyph = 5

	_title = _make_label(wide, 104, Color(1, 1, 1))
	_subtitle = _make_label(light_wide, 40, Color(0.78, 0.92, 1.0))
	_small = _make_label(light_wide, 26, Color(0.75, 0.8, 0.88))


func _make_label(font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = size
	settings.font_color = colour
	settings.outline_size = maxi(4, size / 10)
	settings.outline_color = Color(0, 0, 0, 0.55)
	settings.shadow_size = 12
	settings.shadow_color = Color(0, 0, 0, 0.45)
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(RESOLUTION.x, size * 1.6)
	label.modulate.a = 0.0
	_overlay.add_child(label)
	return label


## Cards: {title, subtitle, small, at (0..1 vertical centre), in, out}
func _apply_card(shot: Dictionary, local: float, dur: float) -> void:
	var card: Dictionary = shot.get("card", {})
	var t_in: float = card.get("in", 0.5)
	var t_out: float = card.get("out", dur - 0.35)
	var alpha := 0.0
	if not card.is_empty():
		alpha = clampf((local - t_in) / 0.45, 0.0, 1.0) * clampf((t_out - local) / 0.35 + 1.0, 0.0, 1.0)
		alpha = clampf(alpha, 0.0, 1.0)
	var centre: float = card.get("at", 0.5) * RESOLUTION.y
	var rise := (1.0 - clampf((local - t_in) / 0.9, 0.0, 1.0)) * 14.0
	_title.text = card.get("title", "")
	_subtitle.text = card.get("subtitle", "")
	_small.text = card.get("small", "")
	_title.position = Vector2(0, centre - _title.size.y * 0.5 - 30 + rise)
	_subtitle.position = Vector2(0, centre + 48 + rise)
	_small.position = Vector2(0, centre + 120 + rise)
	for label in [_title, _subtitle, _small]:
		(label as Label).modulate.a = alpha


# --- camera helpers ----------------------------------------------------------

static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func _look(eye: Vector3, target: Vector3, fov: float = 55.0) -> void:
	_camera.fov = fov
	_camera.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func _orbit(centre: Vector3, radius: float, height: float, deg_from: float, deg_to: float, u: float,
		fov: float = 50.0, look_offset := Vector3.ZERO) -> void:
	var a := deg_to_rad(lerpf(deg_from, deg_to, u))
	var eye := centre + Vector3(sin(a) * radius, height, cos(a) * radius)
	_look(eye, centre + look_offset, fov)


func _place_ship(key: String, origin: Vector3, yaw_deg: float, pitch_deg := 0.0, roll_deg := 0.0) -> void:
	# Every ship model noses toward its local -Z; yaw 0 points it down world -Z.
	var ship := _ship(key)
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), deg_to_rad(roll_deg)))
	ship.global_transform = Transform3D(basis, origin)
	ship.visible = true


# --- shot list ---------------------------------------------------------------

func _build_shots() -> void:
	var torrent_home: Vector3 = (_ship_home.get("TorrentInterceptor", Transform3D()) as Transform3D).origin

	_shots.append({
		"name": "cold_open", "stage": "station", "dur": 6.0, "fade_in": 1.2, "dip": 0.0, "dim": 0.25,
		"card": {"title": "MUDDS SHIPYARDS", "subtitle": "AN ORBITAL SHIPYARD, OPEN FOR FLIGHT", "in": 1.6, "at": 0.46},
		"still_u": [0.1, 0.7],
		"run": func(u: float) -> void:
			var e := _ease(u)
			_look(Vector3(lerpf(-70, -38, e), lerpf(46, 26, e), lerpf(-150, -95, e)),
				Vector3(0, 2, lerpf(-10, 5, e)), 50.0),
	})
	_shots.append({
		"name": "torrent_hero", "stage": "station", "dur": 5.0,
		"card": {"title": "BOARD", "subtitle": "WALK THE STATION. CLAIM A BERTH.", "at": 0.78, "in": 0.7},
		"run": func(u: float) -> void:
			_orbit(torrent_home, 13.0, 3.2, 200.0, 250.0, _ease(u), 42.0, Vector3(0, 0.6, 0)),
	})
	_shots.append({
		"name": "fleet_dock", "stage": "station", "dur": 6.0,
		"card": {"title": "NINE FLYABLE CRAFT", "subtitle": "INTERCEPTORS  ·  FREIGHTERS  ·  GUNSHIPS  ·  BOMBERS", "at": 0.78, "in": 0.8},
		"still_u": [0.1, 0.5, 0.9],
		"run": func(u: float) -> void:
			var e := _ease(u)
			var x := lerpf(10.0, 50.0, e)
			_look(Vector3(x, 17.0, 22.0), Vector3(x + 8.0, 5.0, 55.0), 46.0),
	})
	_shots.append({
		"name": "cinder_line", "stage": "station", "dur": 4.5,
		"still_u": [0.2, 0.8],
		"run": func(u: float) -> void:
			var e := _ease(u)
			var target := (_ship_home["cinder_light_interceptor"] as Transform3D).origin
			_orbit(target, 15.0, 5.5, 205.0, 250.0, e, 45.0, Vector3(0, 0.3, 0)),
	})
	_shots.append({
		"name": "bomber", "stage": "station", "dur": 4.0,
		"run": func(u: float) -> void:
			var target := (_ship_home["cinder_long_range_bomber"] as Transform3D).origin
			_orbit(target, 17.0, 5.0, -40.0, 10.0, _ease(u), 48.0, Vector3(0, 0.5, 0)),
	})
	_shots.append({
		"name": "launch", "stage": "station", "dur": 6.0,
		"card": {"title": "LAUNCH", "at": 0.78, "in": 1.2},
		"still_u": [0.2, 0.6, 0.95],
		"run": func(u: float) -> void:
			# Lift off the pad, then accelerate out through the launch gate (-Z).
			var lift := clampf(u / 0.3, 0.0, 1.0)
			var go := clampf((u - 0.25) / 0.75, 0.0, 1.0)
			var pos := torrent_home + Vector3(0, _ease(lift) * 5.0 + go * go * 10.0, -go * go * 150.0)
			_place_ship("TorrentInterceptor", pos, 0.0, go * 6.0, sin(u * 6.0) * 2.0)
			var cam := Vector3(-10.0, 9.0, -36.0) if u < 0.55 else Vector3(-8.0, 9.0, -95.0)
			_look(cam, pos + Vector3(0, 1, 0), 48.0),
	})
	_shots.append({
		"name": "dogfight", "stage": "station", "dur": 6.5,
		"card": {"title": "FIGHT", "subtitle": "GUNNERS, ENGINEERS, COMPONENT DAMAGE", "at": 0.2, "in": 0.6},
		"still_u": [0.3, 0.6, 0.73, 0.85],
		"flash": func(u: float) -> float:
			return 0.35 * clampf(1.0 - absf(u - 0.705) / 0.03, 0.0, 1.0),
		"run": func(u: float) -> void:
			_run_dogfight(u),
	})
	_shots.append({
		"name": "ember", "stage": "ember", "dur": 6.5,
		"card": {"title": "LAND ON EMBER MOON", "subtitle": "FLY THE APPROACH. WALK THE CALDERA.", "at": 0.78, "in": 0.8},
		"still_u": [0.15, 0.6, 0.95],
		"run": func(u: float) -> void:
			var pad := Vector3(0, PAD_Y, 0)
			var descend := 1.0 - _ease(clampf(u / 0.85, 0.0, 1.0))
			var pos := pad + Vector3(0, 1.15 + descend * 26.0, descend * 55.0)
			_place_ship("TorrentInterceptor", pos, 180.0, -descend * 8.0, 0.0)
			var e := _ease(u)
			_look(pad + Vector3(lerpf(-34, -22, e), lerpf(6, 4, e), lerpf(-8, 10, e)), pos + Vector3(0, 1, 0), 50.0),
	})
	_shots.append({
		"name": "aurora", "stage": "aurora", "dur": 6.5, "dip": 0.4,
		"card": {"title": "EXPLORE AURORA", "subtitle": "A COASTAL WORLD, A TRAIL TO SURVEY", "at": 0.22, "in": 0.8},
		"still_u": [0.1, 0.6, 0.95],
		"run": func(u: float) -> void:
			var pad := Vector3(0, PAD_Y, 0)
			_place_ship("HalyardCrewTransport", pad + Vector3(0, 1.3, 0), 150.0)
			var e := _ease(u)
			_look(pad + Vector3(lerpf(38, 22, e), lerpf(9, 4, e), lerpf(-36, -20, e)), pad + Vector3(4, 2, 0), 52.0),
	})
	_shots.append({
		"name": "cabin", "stage": "station", "dur": 5.0,
		"card": {"title": "LIVE ABOARD", "subtitle": "WALK THE HALYARD'S CABIN. SLEEP IN ITS BUNKS.", "at": 0.78, "in": 0.6},
		"run": func(u: float) -> void:
			var home := (_ship_home["HalyardCrewTransport"] as Transform3D).origin
			var e := _ease(u)
			_look(home + Vector3(0.0, 2.35, lerpf(-4.2, 0.2, e)), home + Vector3(0, 1.4, 7.0), 70.0),
	})
	_shots.append({
		"name": "end_card", "stage": "station", "dur": 7.0, "fade_out": 1.4, "dip": 0.0, "dim": 0.55,
		"card": {"title": "MUDDS SHIPYARDS", "subtitle": "PLAYABLE PROTOTYPE  ·  WINDOWS",
			"small": "An unofficial fan remake inspired by Keth Shipyards", "at": 0.44, "in": 0.9, "out": 99.0},
		"still_u": [0.8],
		"run": func(u: float) -> void:
			var e := _ease(u)
			_look(Vector3(lerpf(30, 60, e), lerpf(22, 42, e), lerpf(-70, -120, e)), Vector3(10, 0, 20), 50.0),
	})
	_total = 0.0
	for shot in _shots:
		_total += float(shot.dur)
	print("ADVERT_TOTAL_SECONDS ", _total)


func _dogfight_hunter(t: float) -> Vector3:
	return Vector3(sin(t * 0.7) * 4.0, 34.0 + sin(t * 0.9) * 2.0, -150.0 - t * 42.0)


func _dogfight_weave(t: float) -> Vector3:
	return Vector3(sin(t * 1.6) * 9.0, 2.5 + sin(t * 1.1) * 3.5, -42.0 + sin(t * 0.8) * 4.0)


func _run_dogfight(u: float) -> void:
	# Chase camera: the Torrent runs down a weaving Cinder interceptor in open
	# space off the launch lane and lands the finishing burst.
	_fx_root.visible = true
	var hit := 0.7
	var t := u * 6.5
	var hunter_pos := _dogfight_hunter(t)
	var weave := _dogfight_weave(t)
	var prey_pos := hunter_pos + weave
	_place_ship("cinder_light_interceptor", prey_pos, sin(t * 1.6) * -12.0, 0.0, -cos(t * 1.6) * 38.0)
	_place_ship("TorrentInterceptor", hunter_pos, weave.x * -0.6, 2.0, -weave.x * 2.0)
	_ship("cinder_light_interceptor").visible = u < hit
	# Twin streams of pulse bolts, only while the trigger is held.
	var firing := u > 0.12 and u < hit
	for i in _bolts.size():
		var bolt := _bolts[i]
		var phase := fmod(u * 12.0 + float(i) / _bolts.size(), 1.0)
		var side := -1.4 if i % 2 == 0 else 1.4
		var from := hunter_pos + Vector3(side, 0.3, -3.0)
		var to := prey_pos + Vector3(side * 0.5, 0.3, 0.0)
		bolt.visible = firing
		bolt.global_transform = Transform3D(
			Basis.looking_at(to - from, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2), from.lerp(to, phase))
	var boom := clampf((u - hit) / 0.3, 0.0, 1.0)
	var fade := (1.0 - boom) * (1.0 - boom)
	var t_hit := hit * 6.5
	var blast_at := _dogfight_hunter(t_hit) + _dogfight_weave(t_hit)
	_blast.visible = u >= hit and boom < 1.0
	_blast.global_position = blast_at
	_blast.scale = Vector3.ONE * (1.5 + boom * 6.0)
	((_blast.mesh as SphereMesh).material as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.8) * fade
	for i in _puffs.size():
		var puff := _puffs[i]
		var dir := Vector3(sin(i * 2.4), cos(i * 1.7) * 0.7, sin(i * 3.1 + 1.0)).normalized()
		puff.visible = _blast.visible
		puff.global_position = blast_at + dir * boom * (6.0 + i * 1.5)
		puff.scale = Vector3.ONE * (1.0 + boom * (5.0 + (i % 3) * 2.0))
		var warm := Color(1.0, 0.55 - 0.05 * (i % 3), 0.15) if i % 2 == 0 else Color(1.0, 0.8, 0.35)
		((puff.mesh as SphereMesh).material as StandardMaterial3D).albedo_color = warm * fade * 0.7
	_blast_light.visible = u >= hit
	_blast_light.global_position = blast_at
	_blast_light.light_energy = 16.0 * fade
	var cam := hunter_pos + Vector3(5.0, 6.0, 21.0)
	_look(cam, hunter_pos + Vector3(weave.x * 0.45, 1.5, -26.0), 56.0)
