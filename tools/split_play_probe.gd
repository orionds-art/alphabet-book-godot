# split_play_probe.gd -- drives the split test's Player A with simulated input and takes stills (real renderer only):
#   Godot_console --position 3900,300 --resolution 960x540 --path "F:\WOODCUTS GODOT\alphabet book" -s res://tools/split_play_probe.gd ++ <out folder> [skip_turn]
# Walks her forward off the book onto the table, turns back (blocked by the cover's edge), jumps onto the cover and
# onto the page, walks to the page's grab point, holds E (lift) and lets go, then taps E (the whole turn).
# Prints her state / height through the run and the frame times per part; writes play_<n>_<what>.png (both views at
# 1920x1080) and window_<n>_<what>.png (the run window as seen, readout included).
extends SceneTree

var out := ""
var scene: Node
var player: Node
var n_still := 0
var times := {}
var part := "start"
var last_us := 0

func _init() -> void:
	_run.call_deferred()

func _ms_tick() -> void:
	var now := Time.get_ticks_usec()
	if last_us > 0:
		if not times.has(part):
			times[part] = []
		times[part].append((now - last_us) / 1000.0)
	last_us = now

func _wait(sec: float, fn: Callable = Callable()) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		if fn.is_valid():
			fn.call()
		await process_frame
		_ms_tick()

func _log(what: String) -> void:
	var p: Vector3 = player.pos
	print("[play] %-34s state %-16s local (%.1f, %.2f, %.1f) floor %.2f  clip %.0f  page %.0f" % [what,
		player.state_name(), p.x, p.y, p.z, player.floor_at(p.x, p.z), player.clip_frame, player.vat_frame])

func _still(what: String) -> void:
	n_still += 1
	var va: SubViewport = scene.get_node("Screens/Left/View A")
	var vb: SubViewport = scene.get_node("Screens/Right/View B")
	var ia := va.get_texture().get_image()
	var ib := vb.get_texture().get_image()
	var img := Image.create(ia.get_width() + ib.get_width(), ia.get_height(), false, ia.get_format())
	img.blit_rect(ia, Rect2i(Vector2i.ZERO, ia.get_size()), Vector2i.ZERO)
	img.blit_rect(ib, Rect2i(Vector2i.ZERO, ib.get_size()), Vector2i(ia.get_width(), 0))
	img.save_png(out.path_join("play_%02d_%s.png" % [n_still, what]))
	root.get_texture().get_image().save_png(out.path_join("window_%02d_%s.png" % [n_still, what]))
	_log("still " + what)
	last_us = 0                                          # the readback + PNG save is not a game frame

# wait until her walking stops making progress (pushing at an edge)
func _wait_blocked() -> void:
	var last_p: Vector3 = player.pos
	for i in 40:
		await _wait(0.1)
		if player.pos.distance_to(last_p) < 0.05:
			return
		last_p = player.pos

func _release_moves() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)

# press the move keys that walk her toward a local (Blender-unit) point, relative to her camera
func _steer(target: Vector3) -> float:
	var cam: Camera3D = scene.get_node("Screens/Left/View A/Camera A")
	var d: Vector3 = target - player.pos
	d.y = 0.0
	var dist := d.length()
	_release_moves()
	if dist < 1.5:
		return dist
	d = d.normalized()
	var f := -cam.global_transform.basis.z
	f.y = 0
	f = f.normalized()
	var r := cam.global_transform.basis.x
	r.y = 0
	r = r.normalized()
	var x := d.dot(r)
	var y := d.dot(f)
	if y > 0.38: Input.action_press("move_forward")
	if y < -0.38: Input.action_press("move_back")
	if x > 0.38: Input.action_press("move_right")
	if x < -0.38: Input.action_press("move_left")
	return dist

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://split_play"
	var skip_turn := args.size() > 1 and args[1] == "skip_turn"
	DirAccess.make_dir_recursive_absolute(out)
	scene = (load("res://split_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	player = scene.get_node("Player A")
	await _wait(2.0)                                     # shader compile
	_still("start")

	part = "walk off the book"
	Input.action_press("walk_fast")
	Input.action_press("move_forward")
	await _wait(1.6)
	_still("walking")
	await _wait(1.0, func(): pass)
	var was_air := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2200:
		if player.airborne and not was_air:
			_log("walked off an edge")
		was_air = player.airborne
		await process_frame
		_ms_tick()
	Input.action_release("move_forward")
	Input.action_release("walk_fast")
	await _wait(0.6)
	_still("on the table")

	part = "back to the book (blocked)"
	Input.action_press("move_back")
	await _wait(2.2)
	_log("pushing at the cover edge")
	_still("blocked at the cover")

	part = "jump onto the book"
	Input.action_press("jump")
	await process_frame
	Input.action_release("jump")
	await _wait(0.22)
	_still("jump")
	await _wait(0.6)
	_log("after jump 1")
	await _wait_blocked()
	_log("pushing at the page block")
	Input.action_press("jump")
	await process_frame
	Input.action_release("jump")
	await _wait(0.9)
	_log("after jump 2")
	Input.action_release("move_back")
	await _wait(0.5)
	_still("landed on the page")

	part = "walk to the page edge"
	var spot := Vector3(24.0, 0.0, -4.0)
	t0 = Time.get_ticks_msec()
	var last_p: Vector3 = player.pos
	var last_t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		if _steer(spot) < 2.0:
			break
		if Time.get_ticks_msec() - last_t > 300:            # stuck at an edge: jump
			if player.pos.distance_to(last_p) < 0.5 and not player.airborne:
				_log("stuck: jump")
				Input.action_press("jump")
				await process_frame
				Input.action_release("jump")
			last_p = player.pos
			last_t = Time.get_ticks_msec()
		await process_frame
		_ms_tick()
	_release_moves()
	await _wait(0.4)
	_log("at the page edge")
	_still("at the page edge")

	part = "hold E: lift the page"
	Input.action_press("grab")
	await _wait(1.6)
	_still("lifting")
	await _wait(1.9)
	_still("page lifted")
	Input.action_release("grab")
	part = "let go"
	await _wait(1.0)
	_still("letting go")
	await _wait(1.6)
	_still("page down again")

	if not skip_turn:
		part = "tap E: the whole turn"
		Input.action_press("grab")
		await process_frame
		await process_frame
		Input.action_release("grab")
		await _wait(9.0)
		_still("turn, over her head")
		await _wait(22.0)
		_still("turn done")
		part = "walk after the turn"
		Input.action_press("move_forward")
		await _wait(1.5)
		Input.action_release("move_forward")
		await _wait(0.5)
		_still("walking after the turn")

	for k in times:
		var a: Array = times[k]
		a.sort()
		print("[play] frame time  %-30s median %6.2f ms  95%% %6.2f ms  max %6.2f ms  (%d frames)" % [k, a[a.size() / 2],
			a[int(a.size() * 0.95)], a.max(), a.size()])
	quit()
