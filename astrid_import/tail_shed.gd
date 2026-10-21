# tail_shed.gd -- copied by astrid_godot_export.py (Blender repo, godot_export\tail_shed\). Re-export rewrites it.
# Astrid's tuft sheds little torn paper triangles (21 Oct 2026, Orion: "occasionally ... a little heavier if the
# character stomps, and when they land after jumping. Slight tuft losses while walking would be funny").
# Made at run time by astrid_setup.gd (never saved into a scene) when res://astrid_import/tail_shed_events.json exists.
#   * a BoneAttachment3D on TAIL_12 (the tuft) carries a pool of one-shot GPUParticles3D bursts;
#   * the events come from Blender (rig\tools\tail\tail_ik_build.py, text block 'TAIL SHED EVENTS', written per exported
#     action): [frame, strength, flakes]; strength 1 = a walk footfall (1 flake), 2 = stomp, 3 = landing;
#   * each frame it reads the clip time of her AnimationPlayer (playback.gd seeks it), fires the events it passed, and
#     runs the particles at the playback's speed (paused playback = paused flakes). Scrubbing back clears them.
#   * the flakes themselves: tail_flake.gdshader (closed-form paper fall, the same model as Blender's preview) +
#     tail_flake_draw.gdshader (her C4D paper).
# Game use: call burst(strength, flakes) from gameplay (footfall / stomp / landing) instead of the event list.
# Run window: T toggles the shedding.
extends Node3D

const EVENTS := "res://astrid_import/tail_shed_events.json"
const TONE := "res://astrid_import/tex/scan_tone_4k.png"
## shedding on / off (run window: T)
@export var enabled := true
## bursts alive at once (each a one-shot GPUParticles3D, flakes live <= 1.9 s); the oldest is reused
@export var pool := 4
## flakes per burst at most (the landing uses 16)
@export var max_burst := 24
@export var bone := "TAIL_12"

var _ap: AnimationPlayer
var _att: BoneAttachment3D
var _root_motion: Node3D
var _emit: Array[GPUParticles3D] = []
var _next := 0
var _events := []
var _model := {}
var _fps := 30.0
var _prev_frame := -1.0
var _prev_pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _u := 1.0 / 11.0
var _seed := 1
var fired := 0          # bursts fired (for the probes)
var _clock: Node

func _ready() -> void:
	var host := get_parent()
	_ap = host.get_animation_player() if host.has_method("get_animation_player") else null
	_root_motion = host.get_root_motion_node() if host.has_method("get_root_motion_node") else null
	var q := host.get_parent()
	while q:
		if "frame" in q and "playing" in q:
			_clock = q
			break
		q = q.get_parent()
	var sk := host.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty() or not FileAccess.file_exists(EVENTS):
		push_warning("tail_shed: no skeleton or no events")
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS))
	_events = data.get("events", [])
	_model = data.get("model", {})
	_fps = float(data.get("fps", 30.0))
	_att = BoneAttachment3D.new()
	_att.name = "Tail Shed (tuft)"
	_att.bone_name = bone
	(sk[0] as Skeleton3D).add_child(_att)
	var tri := _flake_mesh()
	var pm := ShaderMaterial.new()
	pm.shader = load("res://astrid_import/tail_flake.gdshader")
	for i in pool:
		var p := GPUParticles3D.new()
		p.name = "Burst %d" % i
		p.amount = max_burst
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 2.2      # longer than any flake's own life (tail_flake.gdshader ends each one itself)
		p.local_coords = false
		p.fixed_fps = 0
		p.interpolate = false
		p.emitting = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.layers = 1 | 2
		p.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))   # bone space, Blender units
		p.process_material = pm.duplicate()
		p.draw_pass_1 = tri
		_att.add_child(p)
		_emit.append(p)
	print("tail_shed: %d events, pool %d x %d flakes" % [_events.size(), pool, max_burst])

func _flake_mesh() -> ArrayMesh:
	# the Blender 'TAIL FLAKE' triangle, flat in XZ (normal +Y), unit size (the particle scales it)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vs := [Vector3(-0.5, 0, 0.38), Vector3(0.5, 0, 0.30), Vector3(0.06, 0, -0.62)]
	for v in vs:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.3 + v.x * 0.18, 0.4 - v.z * 0.18) * 20.0)
		st.add_vertex(v)
	var m := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://astrid_import/tail_flake_draw.gdshader")
	if ResourceLoader.exists(TONE):
		mat.set_shader_parameter("tone_tex", load(TONE))
	m.surface_set_material(0, mat)
	return m

func _frame() -> float:
	# the playback clock (playback.gd's `frame`, Blender numbering) when an ancestor has one, else her clip's time
	if _clock:
		return float(_clock.get("frame"))
	if _ap == null or _ap.assigned_animation == "":
		return -1.0
	return _ap.current_animation_position * _fps + 1.0

func _process(delta: float) -> void:
	if _att == null:
		return
	var f := _frame()
	var pos := _att.global_position
	var df := f - _prev_frame
	if _prev_frame >= 0.0 and df > 0.0:
		_vel = (pos - _prev_pos) / (df / _fps)
	# the flakes run at the playback's speed: paused playback, paused flakes
	var sp := 0.0
	if delta > 0.0 and df > 0.0 and df < 10.0:
		sp = (df / _fps) / delta
	for p in _emit:
		p.speed_scale = sp
	if _prev_frame >= 0.0:
		if df < 0.0 or df >= 10.0:
			clear()
		elif df > 0.0 and enabled:
			for e in _events:
				if float(e[0]) > _prev_frame and float(e[0]) <= f:
					burst(int(e[1]), int(e[2]))
	_prev_frame = f
	_prev_pos = pos

## one burst of `flakes` flakes, strength 1 (walk), 2 (stomp), 3 (landing)
func burst(strength: int, flakes: int) -> void:
	if _emit.is_empty():
		return
	var p := _emit[_next]
	_next = (_next + 1) % _emit.size()
	var m := p.process_material as ShaderMaterial
	_u = _att.global_basis.get_scale().x
	var u := _u
	var kick: Array = _model.get("kick", {}).get(str(strength), [0.5, 1.5])
	var inh := float(_model.get("inherit", 0.3))
	var vmax := float(_model.get("inherit_max", 6.0)) * u
	var vi := _vel * inh
	if vi.length() > vmax:
		vi = vi.normalized() * vmax
	var box: Array = _model.get("box", [[-0.12, 0.12], [-0.4, 1.4], [-0.8, 0.8]])
	_seed += 1
	m.set_shader_parameter("burst_seed", _seed)
	m.set_shader_parameter("inherit_vel", vi)
	m.set_shader_parameter("kick", Vector2(kick[0], kick[1]) * u)
	m.set_shader_parameter("spread", float(_model.get("spread", 1.6)) * u)
	m.set_shader_parameter("tau", float(_model.get("tau", 0.3)))
	m.set_shader_parameter("v_fall", float(_model.get("v_fall", 5.5)) * u)
	var lr: Array = _model.get("life", {}).get(str(strength), [1.0, 1.4])
	m.set_shader_parameter("life_range", Vector2(lr[0], lr[1]))
	m.set_shader_parameter("shrink", float(_model.get("shrink", 0.3)))
	m.set_shader_parameter("box_min", Vector3(box[0][0], box[1][0], box[2][0]))
	m.set_shader_parameter("box_max", Vector3(box[0][1], box[1][1], box[2][1]))
	var sz: Array = _model.get("size", [0.22, 0.5])
	var am: Array = _model.get("amp", [0.12, 0.35])
	m.set_shader_parameter("size_range", Vector2(sz[0], sz[1]) * u)
	m.set_shader_parameter("amp_range", Vector2(am[0], am[1]) * u)
	var om: Array = _model.get("omega", [5.0, 9.0])
	var spn: Array = _model.get("spin", [4.0, 11.0])
	m.set_shader_parameter("omega_range", Vector2(om[0], om[1]))
	m.set_shader_parameter("spin_range", Vector2(spn[0], spn[1]))
	m.set_shader_parameter("count", clampi(flakes, 0, max_burst))
	p.set_meta("flakes", clampi(flakes, 0, max_burst))
	p.restart()
	p.emitting = true
	fired += 1

## remove every flake (scrubbing back, or a jump in the playback)
func clear() -> void:
	for p in _emit:
		(p.process_material as ShaderMaterial).set_shader_parameter("count", 0)
		p.set_meta("flakes", 0)
		p.restart()
		p.emitting = false

## live flakes, roughly (bursts alive x their flakes), for the probes
func live_flakes() -> int:
	var n := 0
	for p in _emit:
		if p.emitting:
			n += int(p.get_meta("flakes", 0))
	return n

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_T:
		enabled = not enabled
		if not enabled:
			clear()
		print("tail shed: ", "on" if enabled else "off")
