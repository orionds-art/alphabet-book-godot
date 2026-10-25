# split_test.gd -- SPLIT SCREEN TEST (25 Oct 2026): the bedroom + table + book + two fighters, two views side by side,
# each with its own follow camera. No gameplay rules.
# Fighter A = Astrid, PLAYED (player_control.gd, node "Player A": W A S D walk, Shift faster, Space jump, E page).
# Without a "Player A" node she plays the MAIN animation instead.
# Fighter B is a second Astrid (the dragon is not in Godot yet): same clip, half a clip later, standing on the table
# in front of the book (Blender y -100, on the table top 3.56 below her page floor), camera behind her.
# Test keys (number row): 1 split / single view, 2 camera A lock on / behind her, 3 look (WOODCUT -> FLAT -> C4D, both
#   fighters; starts on C4D, the book scan), 4 room on / off, 5 tail flakes on / off, 6 shadows on / off, 7 fighter B's own lights on / off,
#   9 reset Astrid and the page, 0 pause fighter B. The readout shows timings and the keys.
# Measuring (real renderer, never --headless):
#   Godot_console --position 3900,300 --resolution 960x540 --path "F:\WOODCUTS GODOT\alphabet book" res://split_test.tscn ++ measure <out folder>
# Each case: 120 frames warm up (shader compile), then 360 frames sampled; vsync off. Writes <out>/split_measure.json
# and a full-size still of each view setup per look (split_<look>.png = the two views at 1920x1080, as the player sees
# them, plus window_<look>.png = the run window itself).
extends Node

const FPS := 30.0
const FIRST := 1.0
const LAST := 1050.0
const LOOKS := ["WOODCUT", "FLAT", "C4D"]

## render size of the whole screen (both views together), whatever the window size
@export var render_size := Vector2i(1920, 1080)
@export var split := true:
	set(v):
		split = v
		if is_inside_tree():
			_layout()
@export var playing := true
## fighter B starts this many frames later in the same clip
@export var fighter_b_offset := 525.0
## follow cameras: distance behind the fighter and height, in meters
@export var camera_distance := 4.5
@export var camera_height := 1.6

@onready var _a: Node3D = $"World/Fighter A"
@onready var _b: Node3D = $"World/Fighter B"
@onready var _book: Node = $"World/Book"
@onready var _room: Node3D = $"World/Bedroom"
@onready var _lights_a: Node3D = $"World/Fighter A Lights"
@onready var _lights_b: Node3D = $"World/Fighter B Lights"
@onready var _sun: DirectionalLight3D = $"World/Book Light"
@onready var _left: SubViewportContainer = $"Screens/Left"
@onready var _right: SubViewportContainer = $"Screens/Right"
@onready var _view_a: SubViewport = $"Screens/Left/View A"
@onready var _view_b: SubViewport = $"Screens/Right/View B"
@onready var _cam_a: Camera3D = $"Screens/Left/View A/Camera A"
@onready var _cam_b: Camera3D = $"Screens/Right/View B/Camera B"
@onready var _hud: Label = $"HUD/Stats"
@onready var _player: Node = get_node_or_null("Player A")

var _frame_a := FIRST
var _frame_b := FIRST
var _ap_a: AnimationPlayer
var _ap_b: AnimationPlayer
var _clip_a := ""
var _clip_b := ""
var _root_a: Node3D
var _root_b: Node3D
var _look := 2   # starts on C4D (the book-scan look), Orion 25 Oct 2026
var _flakes := true
var _shadows := true
var _b_lights := true
var _last_us := 0
var _frame_ms: Array[float] = []

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_frame_b = fposmod(FIRST + fighter_b_offset - FIRST, LAST - FIRST) + FIRST
	for v in [_view_a, _view_b]:
		RenderingServer.viewport_set_measure_render_time(v.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_ap_a = _a.get_animation_player()
	_ap_b = _b.get_animation_player()
	_root_a = _a.get_root_motion_node()
	_root_b = _b.get_root_motion_node()
	_clip_a = _first_clip(_ap_a)
	_clip_b = _first_clip(_ap_b)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply()
	set_look(_look)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[0] == "measure":
		_measure.call_deferred(args[1])

func _first_clip(ap: AnimationPlayer) -> String:
	if ap == null:
		return ""
	for n in ap.get_animation_list():
		if n != "RESET":
			ap.play(n)
			ap.pause()
			return n
	return ""

# the two views at render_size in all, scaled down to fit the window (the container draws the view texture)
func _layout() -> void:
	var w := render_size.x / 2 if split else render_size.x
	_view_a.size = Vector2i(w, render_size.y)
	_view_b.size = Vector2i(w, render_size.y)
	_right.visible = split
	_view_b.render_target_update_mode = SubViewport.UPDATE_ALWAYS if split else SubViewport.UPDATE_DISABLED
	var win := Vector2(get_viewport().get_visible_rect().size)
	var k := minf(win.x / render_size.x, win.y / render_size.y)
	for c in [_left, _right]:
		c.stretch = false
		c.size = Vector2(w, render_size.y)
		c.scale = Vector2(k, k)
	_left.position = Vector2.ZERO
	_right.position = Vector2(w * k, 0)
	_cam_a.fov = 40.0 if split else 32.0
	_cam_b.fov = _cam_a.fov

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frame_ms.append((now - _last_us) / 1000.0)
		if _frame_ms.size() > 120:
			_frame_ms.pop_front()
	_last_us = now
	if playing:
		if _player == null:
			_frame_a = _wrap(_frame_a + delta * FPS)
		_frame_b = _wrap(_frame_b + delta * FPS)
	_apply()
	_hud.text = _stats_line()

func _wrap(f: float) -> float:
	return FIRST + fposmod(f - FIRST, LAST - FIRST)

func _apply() -> void:
	if _player == null:
		if _ap_a and _clip_a != "":
			_ap_a.seek((_frame_a - FIRST) / FPS, true)
		if _book.has_method("set_frame"):
			_book.set_frame(_frame_a)
	if _ap_b and _clip_b != "":
		_ap_b.seek((_frame_b - FIRST) / FPS, true)
	var pa := _root_a.global_position
	var pb := _root_b.global_position
	# her two salon spots follow her ROOT's x / z, at her floor height (as MAIN's Astrid Follow)
	_lights_a.global_position = Vector3(pa.x, _a.global_position.y, pa.z)
	_lights_b.global_position = Vector3(pb.x, _b.global_position.y, pb.z)
	if _player == null:
		_follow(_cam_a, pa, pb)
	_follow(_cam_b, pb, pa)

# behind `me`, on the far side from `other`, looking at the other fighter's middle
func _follow(cam: Camera3D, me: Vector3, other: Vector3) -> void:
	var d := Vector3(me.x - other.x, 0, me.z - other.z)
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	cam.global_position = me + d * camera_distance + Vector3(0, camera_height, 0)
	cam.look_at(other.lerp(me, 0.35) + Vector3(0, 0.8, 0), Vector3.UP)

func _gpu_ms() -> float:
	var g := RenderingServer.viewport_get_measured_render_time_gpu(_view_a.get_viewport_rid())
	if split:
		g += RenderingServer.viewport_get_measured_render_time_gpu(_view_b.get_viewport_rid())
	return g + RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())

func _cpu_ms() -> float:
	var c := RenderingServer.viewport_get_measured_render_time_cpu(_view_a.get_viewport_rid())
	if split:
		c += RenderingServer.viewport_get_measured_render_time_cpu(_view_b.get_viewport_rid())
	return c + RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()) \
		+ RenderingServer.get_frame_setup_time_cpu()

func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]

func _stats_line() -> String:
	var fm := _median(_frame_ms)
	return "%s  look %s  room %s  flakes %s  shadows %s  B lights %s  Astrid: %s\n%.1f fps  frame %.2f ms  GPU %.2f ms  render CPU %.2f ms  draw calls %d  triangles %dk  VRAM %d MB\nW A S D walk  Shift faster  Space jump  E page (hold = lift, tap = turn)  |  1 split  2 camera  3 look  4 room  5 flakes  6 shadows  7 B lights  9 reset  0 pause B" % [
		"SPLIT" if split else "SINGLE", LOOKS[_look], _on(_room.visible), _on(_flakes), _on(_shadows), _on(_b_lights),
		_player.state_name() if _player else "clip",
		1000.0 / maxf(fm, 0.001), fm, _gpu_ms(), _cpu_ms(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)]

func _on(b: bool) -> String:
	return "on" if b else "off"

# ------------------------------------------------------------------ switches
func set_look(i: int) -> void:
	_look = i
	for f in [_a, _b]:
		f.look = i

func set_room(on: bool) -> void:
	_room.visible = on

func set_flakes(on: bool) -> void:
	_flakes = on
	for f in [_a, _b]:
		var ts: Node = f.get_tail_shed() if f.has_method("get_tail_shed") else null
		if ts:
			ts.set("enabled", on)
			ts.visible = on

func set_shadows(on: bool) -> void:
	_shadows = on
	_sun.shadow_enabled = on
	for l in _lights_a.get_children() + _lights_b.get_children():
		(l as Light3D).shadow_enabled = on

func set_b_lights(on: bool) -> void:
	_b_lights = on
	_lights_b.visible = on

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_1:
			split = not split
		KEY_2:
			if _player:
				_player.camera_mode = 1 - _player.camera_mode
		KEY_3:
			set_look((_look + 1) % LOOKS.size())
		KEY_4:
			set_room(not _room.visible)
		KEY_5:
			set_flakes(not _flakes)
		KEY_6:
			set_shadows(not _shadows)
		KEY_7:
			set_b_lights(not _b_lights)
		KEY_9:
			if _player:
				_player.reset()
		KEY_0:
			playing = not playing

# ------------------------------------------------------------------ measuring
func _case(c: Dictionary) -> void:
	split = c.get("split", true)
	set_look(LOOKS.find(c.get("look", "WOODCUT")))
	set_room(c.get("room", true))
	set_flakes(c.get("flakes", true))
	set_shadows(c.get("shadows", true))
	set_b_lights(c.get("b_lights", true))

func _measure(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var cases := [
		{"name": "split, woodcut, room, flakes, shadows (the full test)"},
		{"name": "single, woodcut", "split": false},
		{"name": "split, flat", "look": "FLAT"},
		{"name": "split, c4d", "look": "C4D"},
		{"name": "single, flat", "split": false, "look": "FLAT"},
		{"name": "single, c4d", "split": false, "look": "C4D"},
		{"name": "split, woodcut, no room", "room": false},
		{"name": "single, woodcut, no room", "split": false, "room": false},
		{"name": "split, woodcut, flakes off", "flakes": false},
		{"name": "split, woodcut, shadows off", "shadows": false},
		{"name": "split, woodcut, fighter B lights off (3 lights)", "b_lights": false},
		{"name": "split, flat, shadows off, B lights off (cheapest)", "look": "FLAT", "shadows": false, "b_lights": false},
	]
	var rows := []
	for c in cases:
		_case(c)
		for i in 120:
			await get_tree().process_frame
		var fr := []
		var gpu := []
		var cpu := []
		var dc := []
		var tri := []
		var last := Time.get_ticks_usec()
		for i in 360:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			fr.append((now - last) / 1000.0)
			last = now
			gpu.append(_gpu_ms())
			cpu.append(_cpu_ms())
			dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			tri.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		fr.sort()
		var row := {"case": c["name"], "frame_ms_median": _median(fr), "frame_ms_95": fr[int(fr.size() * 0.95)],
			"frame_ms_max": fr.max(), "fps_median": 1000.0 / _median(fr), "gpu_ms_median": _median(gpu),
			"render_cpu_ms_median": _median(cpu), "draw_calls": _median(dc), "triangles": _median(tri),
			"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0}
		rows.append(row)
		print("[split] %-52s %6.1f fps  frame %6.2f ms (95%% %6.2f, max %6.2f)  GPU %6.2f ms  render CPU %5.2f ms  draws %5d  tris %7d  VRAM %4d MB" % [
			row["case"], row["fps_median"], row["frame_ms_median"], row["frame_ms_95"], row["frame_ms_max"],
			row["gpu_ms_median"], row["render_cpu_ms_median"], int(row["draw_calls"]), int(row["triangles"]),
			int(row["vram_mb"])])
	var f := FileAccess.open(out.path_join("split_measure.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"render_size": [render_size.x, render_size.y], "gpu": RenderingServer.get_video_adapter_name(),
		"rows": rows}, "  "))
	f.close()
	# stills: the split screen running, in each look (frame A 300 / B 825)
	for lk in LOOKS:
		_case({"look": lk})
		playing = false
		_frame_a = 300.0
		_frame_b = _wrap(300.0 + fighter_b_offset)
		for i in 60:
			await get_tree().process_frame
		var ia := _view_a.get_texture().get_image()
		var ib := _view_b.get_texture().get_image()
		var img := Image.create(render_size.x, render_size.y, false, ia.get_format())
		img.blit_rect(ia, Rect2i(Vector2i.ZERO, ia.get_size()), Vector2i.ZERO)
		img.blit_rect(ib, Rect2i(Vector2i.ZERO, ib.get_size()), Vector2i(ia.get_size().x, 0))
		img.save_png(out.path_join("split_%s.png" % lk.to_lower()))
		get_viewport().get_texture().get_image().save_png(out.path_join("window_%s.png" % lk.to_lower()))
		print("[split] wrote stills for ", lk)
		playing = true
	get_tree().quit()
