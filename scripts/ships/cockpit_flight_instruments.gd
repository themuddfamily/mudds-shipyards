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
	_throttle.set_instance_shader_parameter(&"fill", clampf(absf(throttle), 0.0, 1.0))
	_throttle.set_instance_shader_parameter(&"ink", throttle_color)
	_hull.set_instance_shader_parameter(&"fill", clampf(hull_fraction, 0.0, 1.0))
	_hull.set_instance_shader_parameter(&"ink", hull_color)
	_throttle_text.modulate = throttle_color
	_hull_text.modulate = hull_color


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
