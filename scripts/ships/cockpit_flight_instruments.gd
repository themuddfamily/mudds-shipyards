extends Node3D

## Physical instruments only: HeroShip supplies already-owned flight state.
## One retained child of FlightDataReadout follows cockpit adoption, visibility,
## detach and destruction. All craft share the two dial meshes and material;
## changing a reading updates instance uniforms, never allocates resources.
const CYAN := Color("8de8e4")
const AMBER := Color("ffb85c")
const RED := Color("ff6b5f")
const DIAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
instance uniform float fill = 0.0;
instance uniform vec4 ink : source_color = vec4(0.55, 0.91, 0.89, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float aa = max(fwidth(radius), 0.008);
	// A 270-degree instrument sweep, with the break at the bottom.
	float angle = mod(atan(p.x, -p.y) + 2.35619449, 6.28318531);
	float fraction = angle / 4.71238898;
	float sweep = 1.0 - step(1.0, fraction);
	float ring = smoothstep(0.69-aa, 0.69+aa, radius)
		* (1.0-smoothstep(0.83-aa, 0.83+aa, radius)) * sweep;
	float ticks = smoothstep(0.88-aa, 0.88+aa, radius)
		* (1.0-smoothstep(0.97-aa, 0.97+aa, radius))
		* (1.0-smoothstep(0.07, 0.16, abs(fract(fraction * 10.0 + 0.5)-0.5))) * sweep;
	float lit = step(fraction, fill) * step(0.001, fill);
	ALBEDO = mix(vec3(0.10, 0.23, 0.27), ink.rgb, lit);
	ALBEDO = mix(ALBEDO, ink.rgb * 0.60, ticks);
	ALPHA = max(ring, ticks);
}
"""

# The existing opaque face owns this finish: no overlay, texture viewport or
# moving scanlines. Model-space bounds keep Zenith's batched touch keys plain.
const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec2 face_size = vec2(0.72, 0.32);
uniform vec2 face_center = vec2(0.0);
uniform bool wide_face = false;
varying vec3 stock_position;
varying vec3 stock_normal;
void vertex() {
	stock_position = VERTEX;
	stock_normal = NORMAL;
}
void fragment() {
	vec2 p = (stock_position.xy - face_center) / face_size + 0.5;
	p.y = 1.0 - p.y;
	vec2 aa = max(fwidth(p), vec2(0.0005));
	float face = step(0.99, stock_normal.z)
		* step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	vec2 edge = min(p, 1.0-p);
	float inset = smoothstep(0.018, 0.018 + aa.x, edge.x)
		* smoothstep(0.038, 0.038 + aa.y, edge.y);
	float center = wide_face ? step(0.28, p.x) * step(p.x, 0.72) : 1.0;
	float header = (1.0-smoothstep(0.385, 0.385 + aa.y, p.y)) * center;
	// Quiet luminous glass, a recessed black perimeter and a speed/status rule.
	vec3 glass = mix(vec3(0.025, 0.070, 0.090), vec3(0.035, 0.115, 0.140), header);
	glass *= 0.80 + 0.20 * (1.0-p.y);
	float rule = (1.0-smoothstep(0.002, 0.002+aa.y, abs(p.y-0.39))) * center;
	float columns = wide_face ? (1.0-smoothstep(0.0015, 0.0015+aa.x,
		min(abs(p.x-0.28), abs(p.x-0.72)))) : 0.0;
	glass = mix(glass, vec3(0.065, 0.18, 0.20), max(rule, columns));
	ALBEDO = mix(vec3(0.003, 0.007, 0.009), glass, face * inset);
}
"""

static var _screen_materials: Dictionary = {}


static func screen_material(wide_face: bool = false) -> ShaderMaterial:
	if not _screen_materials.has(wide_face):
		var material := ShaderMaterial.new()
		if _screen_materials.is_empty():
			var shader := Shader.new()
			shader.code = SCREEN_SHADER
			material.shader = shader
		else:
			material.shader = (_screen_materials.values()[0] as ShaderMaterial).shader
		material.set_shader_parameter(&"wide_face", wide_face)
		if wide_face:
			material.set_shader_parameter(&"face_size", Vector2(1.27, 0.31))
			material.set_shader_parameter(&"face_center", Vector2(0.0, 0.06))
		_screen_materials[wide_face] = material
	return _screen_materials[wide_face]


static var _instance_count := 0
static var _dial_mesh: QuadMesh
static var _dial_material: ShaderMaterial

var _compact := false
var _speed: Label3D
var _dials: Node3D
var _throttle: MeshInstance3D
var _hull: MeshInstance3D
var _throttle_text: Label3D
var _hull_text: Label3D
# These belong to this cockpit, even though its mesh and material are shared.
var _readings_submitted := false
var _submitted_throttle_fill := 0.0
var _submitted_hull_fill := 0.0
var _submitted_throttle_color := Color()
var _submitted_hull_color := Color()


func _init() -> void:
	_instance_count += 1
	name = "LiveFlightInstruments"
	set_meta("presentation_only", true)
	_speed = _label("SpeedReadout", 72, 0.0009)
	_speed.position = Vector3(0.0, 0.125, 0.002)
	_speed.text = "SPD 000"
	add_child(_speed)
	_dials = Node3D.new()
	_dials.name = "LiveStatusRepeaters"
	add_child(_dials)
	if _dial_mesh == null:
		_dial_mesh = QuadMesh.new()
		_dial_mesh.size = Vector2(0.245, 0.245)
		var shader := Shader.new()
		shader.code = DIAL_SHADER
		_dial_material = ShaderMaterial.new()
		_dial_material.shader = shader
	_throttle = _dial("ThrottleGauge", -0.57)
	_hull = _dial("HullGauge", 0.57)
	_throttle_text = _label("ThrottleReadout", 44, 0.00084)
	_hull_text = _label("HullReadout", 44, 0.00084)
	_throttle_text.position = Vector3(-0.57, 0.065, 0.003)
	_hull_text.position = Vector3(0.57, 0.065, 0.003)
	_dials.add_child(_throttle_text)
	_dials.add_child(_hull_text)
	update_readings(0.0, 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_instance_count -= 1
		if _instance_count == 0:
			# Keep resources across detach/re-entry, but release the shared cache
			# when its last cockpit dies, before the rendering server shuts down.
			_dial_mesh = null
			_dial_material = null
			_screen_materials.clear()


func set_compact(compact: bool) -> void:
	_compact = compact
	# Torrent's imported art owns its face and has no matching round apertures.
	_dials.visible = not compact
	_speed.position.y = 0.085 if compact else 0.125
	_speed.pixel_size = 0.00072 if compact else 0.0009


func update_readings(speed: float, throttle: float, hull_fraction: float) -> void:
	_speed.text = (
		"SPD %03d   THR %+03d" % [roundi(speed), roundi(throttle * 100.0)]
		if _compact else "SPD %03d" % roundi(speed)
	)
	_throttle_text.text = "%+03d\nTHR %%" % roundi(throttle * 100.0)
	_hull_text.text = "%03d\nHULL %%" % roundi(hull_fraction * 100.0)
	var throttle_color := AMBER if throttle < 0.0 else CYAN
	var hull_color := RED if hull_fraction <= 0.30 else CYAN
	var throttle_fill := clampf(absf(throttle), 0.0, 1.0)
	var hull_fill := clampf(hull_fraction, 0.0, 1.0)
	# The engine setter dirties instance buffers even when the value is unchanged.
	# Compare exact derived values so every live change still reaches the dial.
	if not _readings_submitted or throttle_fill != _submitted_throttle_fill:
		_submit_dial_parameter(_throttle, &"fill", throttle_fill)
		_submitted_throttle_fill = throttle_fill
	if not _readings_submitted or throttle_color != _submitted_throttle_color:
		_submit_dial_parameter(_throttle, &"ink", throttle_color)
		_submitted_throttle_color = throttle_color
	if not _readings_submitted or hull_fill != _submitted_hull_fill:
		_submit_dial_parameter(_hull, &"fill", hull_fill)
		_submitted_hull_fill = hull_fill
	if not _readings_submitted or hull_color != _submitted_hull_color:
		_submit_dial_parameter(_hull, &"ink", hull_color)
		_submitted_hull_color = hull_color
	_readings_submitted = true
	_throttle_text.modulate = throttle_color
	_hull_text.modulate = hull_color


func _submit_dial_parameter(dial: MeshInstance3D, parameter: StringName, value: Variant) -> void:
	dial.set_instance_shader_parameter(parameter, value)


func _label(node_name: String, size: int, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.font_size = size
	label.pixel_size = pixels
	label.modulate = CYAN
	label.outline_modulate = Color("07111d")
	label.outline_size = 4
	label.no_depth_test = false
	label.set_meta("presentation_only", true)
	return label


func _dial(node_name: String, x: float) -> MeshInstance3D:
	var dial := MeshInstance3D.new()
	dial.name = node_name
	dial.mesh = _dial_mesh
	dial.material_override = _dial_material
	dial.position = Vector3(x, 0.065, 0.001)
	dial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dial.set_meta("presentation_only", true)
	_dials.add_child(dial)
	return dial
