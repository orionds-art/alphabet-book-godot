# player_control.gd -- PLAYTEST controls for fighter A (Astrid) in split_test.tscn (25 Oct 2026). No gameplay rules yet.
#   W A S D (or arrows, or the left stick) walk, relative to her camera; Shift (or right shoulder) walks faster.
#   Space (or pad A) jumps: a made-up arc (there is no jump clip), steerable in the air, lands on whatever is below.
#   E (or pad X) near the right page's outer edge (where the MAIN animation grabs it):
#       HOLD = she crouches, takes the page edge and lifts it (her baked clip + the baked page turn, scrubbed forward
#              while held, up to frame 280 = the edge raised in front of her); RELEASE = it goes back down the same way.
#       TAP  = the whole baked turn plays (frames 193..1050: over her head, across, laid down on the left); she gets
#              control back where the clip ends, on the left cover. 9 resets her and the page.
# How she moves: her clip has no free walk, so the walk is a loop of clip frames 93..117 (two steps, 4.75 units at
# 30 fps = her own stride speed 5.94 units/s), played faster or slower with her ground speed so the feet don't skate
# much. Her position / facing are written over the clip's root motion every frame (the "Astrid" node under the
# 1/11 Scale). Standing = clip frame 1. While grabbing / turning, the clip's own root motion runs (it was made there).
# Floor height: worked out from the book's measured shapes, not ray casts (the page is a baked VAT, no collision):
# right page z 0, left page 1.80 lower with the joint's slope to the spine, cover boards -1.899, table -3.5596
# (Blender units; Blender x = Godot x, Blender y = -Godot z). Off the table edge she can't go.
extends Node

const FPS := 30.0
const WALK_A := 93.0                # walk loop: two steps of her clip (step boundaries every 12 frames)
const WALK_B := 117.0
const STAND := 1.0
const JUMP_POSE := 99.0             # mid-stride: legs apart for the leap
const STRIDE_SPEED := 5.94          # units / s her clip walks at
const GRAB_START := 193.0           # crouch + reach starts here (her root at GRAB_SPOT, facing +x)
const GRAB_TOP := 280.0             # the most a held E lifts (the edge raised in front of her)
const TURN_END := 1050.0
const VAT_LAST := 1004.0
const GRAB_SPOT := Vector2(28.019, -4.030)   # her root (local x, z) at frame 193
const GRAB_YAW := 90.61
const U := 11.0                     # Blender units per Godot meter

@export var fighter_path: NodePath = ^"../World/Fighter A"
@export var book_path: NodePath = ^"../World/Book"
@export var camera_path: NodePath = ^"../Screens/Left/View A/Camera A"
@export var opponent_path: NodePath = ^"../World/Fighter B"
## walk speed, units per second (her own stride speed is 5.94)
@export var walk_speed := 6.0
## with Shift / right shoulder
@export var fast_speed := 11.0
## how fast she turns to face where she walks (higher = snappier)
@export var turn_rate := 9.0
## jump height in meters
@export var jump_height := 0.65
## gravity in meters per second squared (cartoon-heavy)
@export var gravity := 22.0
## the highest step she walks up without jumping, in meters (the cover is 0.15 up from the table, the page block
## 0.16 up from the cover: both need a jump)
@export var step_height := 0.08
## how close (meters) to the page's grab point E works
@export var grab_reach := 1.1
## camera: "Lock on" looks past her at the other fighter; "Behind her" swings round behind her facing
@export_enum("Lock on", "Behind her") var camera_mode := 0
@export var camera_distance := 4.2
@export var camera_height := 2.2
@export var camera_smooth := 5.0

enum { WALK, APPROACH, GRAB, TURN }
var state := WALK
var pos := Vector3(0.415, 0.0, 9.181)       # her root, local units (the Scale space)
var yaw := deg_to_rad(171.63)
var vy := 0.0                               # units / s
var airborne := false
var clip_frame := STAND
var vat_frame := 1.0
var page_turned := false
var moving := false
var _settling := false
var _squash := 0.0
var _grab_held := 0.0
var _approach_t := 0.0
var _approach_from_pos := Vector3.ZERO
var _approach_from_yaw := 0.0
var _approach_released := false
var _fighter: Node3D
var _root: Node3D
var _ap: AnimationPlayer
var _clip := ""
var _book: Node
var _cam: Camera3D
var _opp: Node3D
var _cam_dir := Vector3(0, 0, 1)

func _ready() -> void:
	process_priority = -10
	_add_actions()
	_fighter = get_node(fighter_path)
	_book = get_node(book_path)
	_cam = get_node(camera_path)
	_opp = get_node_or_null(opponent_path)
	_ap = _fighter.get_animation_player()
	_root = _fighter.get_root_motion_node()
	for n in _ap.get_animation_list():
		if n != "RESET":
			_clip = n
	_ap.play(_clip)
	_ap.pause()
	reset()

## back to the start: her MAIN start spot, standing, the page flat on the right
func reset() -> void:
	state = WALK
	pos = Vector3(0.415, 0.0, 9.181)
	yaw = deg_to_rad(171.63)
	vy = 0.0
	airborne = false
	clip_frame = STAND
	vat_frame = 1.0
	page_turned = false
	_settling = false
	_squash = 0.0
	_apply()
	_cam_dir = Vector3(0, 0, 1)
	_place_camera(1.0)

func _add_actions() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "grab": [KEY_E], "walk_fast": [KEY_SHIFT]}
	for a in keys:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a, 0.2)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	var axes := {"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0]}
	for a in axes:
		var j := InputEventJoypadMotion.new()
		j.device = 0
		j.axis = axes[a][0]
		j.axis_value = axes[a][1]
		InputMap.action_add_event(a, j)
	for pair in [["jump", JOY_BUTTON_A], ["grab", JOY_BUTTON_X], ["walk_fast", JOY_BUTTON_RIGHT_SHOULDER]]:
		var b := InputEventJoypadButton.new()
		b.device = 0
		b.button_index = pair[1]
		InputMap.action_add_event(pair[0], b)

# ------------------------------------------------------------------ the floor under a point (local units)
static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## floor height (local y = Blender z) at local x, z; -INF off the table
static func floor_at(x: float, z: float) -> float:
	var bx := x
	var by := -z
	if by >= -39.59 and by <= 47.59:
		if bx >= -32.17 and bx <= 32.17:
			return 0.0                                          # right page
		if bx >= -96.51 and bx < -32.17:
			var xs := bx + 32.17                                # 0 at the spine, -64.34 at the left fore-edge
			return -1.80 + 1.80 * (1.0 - _smooth(-xs / 7.26))   # left page, the joint rising to the spine
	if bx >= -108.51 and bx <= 44.17 and by >= -51.59 and by <= 59.59:
		return -1.899                                           # cover boards
	if absf(bx) <= 203.5 and absf(by) <= 130.9:                 # table (4 units in from its edge: her feet)
		return -3.5596
	return -INF

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	match state:
		WALK:
			_walk(delta)
		APPROACH:
			_approach(delta)
		GRAB:
			_grab(delta)
		TURN:
			_turn(delta)
	_apply()
	_place_camera(delta)

func _input_dir() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if v.length() < 0.01:
		return Vector3.ZERO
	var f := -_cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var r := _cam.global_transform.basis.x
	r.y = 0.0
	r = r.normalized()
	var d := r * v.x + f * v.y
	return d.limit_length(1.0)

func _walk(delta: float) -> void:
	var d := _input_dir()
	var spd := (fast_speed if Input.is_action_pressed("walk_fast") else walk_speed) * d.length()
	if Input.is_action_just_pressed("grab") and not airborne and not page_turned and _near_grab():
		_start_approach()
		return
	if Input.is_action_just_pressed("jump") and not airborne:
		airborne = true
		vy = sqrt(2.0 * gravity * jump_height) * U
		clip_frame = JUMP_POSE
	if d.length() > 0.01:
		var want := atan2(d.x, d.z)
		yaw = lerp_angle(yaw, want, 1.0 - exp(-turn_rate * delta))
		_settling = false
	elif moving and not airborne:
		_settling = true                                   # finish the step before standing still
	var step := Vector3.ZERO
	if d.length() > 0.01:
		step = d.normalized() * spd * delta
	elif _settling:
		step = Vector3(sin(yaw), 0, cos(yaw)) * walk_speed * 0.6 * delta
	_move(step)
	# vertical
	var fl := floor_at(pos.x, pos.z)
	if airborne:
		vy -= gravity * U * delta
		pos.y += vy * delta
		if pos.y <= fl and vy <= 0.0:
			pos.y = fl
			airborne = false
			vy = 0.0
			_squash = 1.0
			clip_frame = WALK_A if d.length() > 0.01 else STAND
	elif fl < pos.y - 0.05:
		airborne = true                                     # walked off an edge: fall
		vy = 0.0
	else:
		pos.y = fl
	# animation
	moving = (d.length() > 0.01 or _settling) and not airborne
	if moving:
		if clip_frame < WALK_A or clip_frame > WALK_B:
			clip_frame = WALK_A
		var rate := (spd if d.length() > 0.01 else walk_speed * 0.6) / STRIDE_SPEED
		var before := clip_frame
		clip_frame += delta * FPS * rate
		if _settling and (floori((before - WALK_A) / 12.0) != floori((clip_frame - WALK_A) / 12.0)):
			_settling = false                              # reached a step boundary: stand
			moving = false
			clip_frame = STAND
		elif clip_frame >= WALK_B:
			clip_frame = WALK_A + fmod(clip_frame - WALK_A, WALK_B - WALK_A)
	elif not airborne:
		clip_frame = STAND
	_squash = maxf(0.0, _squash - delta / 0.18)
	vat_frame = VAT_LAST if page_turned else 1.0

# horizontal move with walls: higher floors than a step (or a jump top) block, per axis so she slides along edges
func _move(step: Vector3) -> void:
	if step.length() < 1e-6:
		return
	for s in [step, Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		var n: Vector3 = pos + s
		var fl := floor_at(n.x, n.z)
		if fl == -INF:
			continue
		var top := pos.y + (0.0 if airborne else step_height * U)
		if fl <= top + 0.001:
			pos.x = n.x
			pos.z = n.z
			return

func _near_grab() -> bool:
	return Vector2(pos.x, pos.z).distance_to(GRAB_SPOT) <= grab_reach * U and absf(pos.y) < 0.5

func _start_approach() -> void:
	state = APPROACH
	_approach_t = 0.0
	_approach_from_pos = pos
	_approach_from_yaw = yaw
	_approach_released = false

func _approach(delta: float) -> void:
	_approach_t += delta / 0.35
	if not Input.is_action_pressed("grab"):
		_approach_released = true
	var t := _smooth(_approach_t)
	pos = _approach_from_pos.lerp(Vector3(GRAB_SPOT.x, 0.0, GRAB_SPOT.y), t)
	yaw = lerp_angle(_approach_from_yaw, deg_to_rad(GRAB_YAW), t)
	moving = true
	clip_frame = WALK_A + fposmod(clip_frame - WALK_A + delta * FPS, WALK_B - WALK_A) if t < 0.95 else GRAB_START
	if _approach_t >= 1.0:
		clip_frame = GRAB_START
		_grab_held = 0.0
		state = TURN if _approach_released else GRAB

func _grab(delta: float) -> void:
	if Input.is_action_pressed("grab"):
		_grab_held += delta
		clip_frame = minf(clip_frame + delta * FPS, GRAB_TOP)
	else:
		if _grab_held < 0.25 and clip_frame < GRAB_START + 10.0:
			state = TURN                                      # a tap: the whole turn
			return
		clip_frame -= delta * FPS * 1.5                       # let it go back down
		if clip_frame <= GRAB_START:
			clip_frame = GRAB_START
			_back_to_walk()
	vat_frame = clip_frame

func _turn(delta: float) -> void:
	clip_frame = minf(clip_frame + delta * FPS, TURN_END)
	vat_frame = minf(clip_frame, VAT_LAST)
	if clip_frame >= TURN_END:
		page_turned = true
		_back_to_walk()

# hand control back where the clip has put her
func _back_to_walk() -> void:
	var t := _root.transform
	pos = t.origin
	pos.y = floor_at(pos.x, pos.z)
	var f := t.basis.z
	yaw = atan2(f.x, f.z)
	state = WALK
	clip_frame = STAND
	moving = false
	_settling = false

func _apply() -> void:
	_ap.seek((clip_frame - 1.0) / FPS, true)
	if state == WALK or state == APPROACH:
		var bob := _root.transform.origin.y if moving else 0.0      # the clip's walk bob (-0.25 at the dips)
		var sq := Vector3(1.0 + 0.08 * _squash, 1.0 - 0.14 * _squash, 1.0 + 0.08 * _squash)
		_root.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(sq), Vector3(pos.x, pos.y + bob, pos.z))
	if _book.has_method("set_frame"):
		_book.set_frame(vat_frame)

## her position in Godot meters (global)
func fighter_position() -> Vector3:
	return _root.global_position

# ------------------------------------------------------------------ camera
func _place_camera(delta: float) -> void:
	var me := _root.global_position
	var want := _cam_dir
	if camera_mode == 0 and _opp:
		var o: Node3D = _opp.get_root_motion_node() if _opp.has_method("get_root_motion_node") else _opp
		var d := me - o.global_position
		d.y = 0.0
		if d.length() > 2.0:                                  # too close: keep the last direction
			want = d.normalized()
	else:
		var f := _root.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.01:
			want = -f.normalized()
	var k := 1.0 - exp(-camera_smooth * 0.5 * delta) if delta < 1.0 else 1.0
	_cam_dir = _cam_dir.slerp(want, k).normalized() if _cam_dir.dot(want) > -0.99 else want
	# while she handles the page, rise and step back to look over it (the standing page fills a low view)
	var over := 1.0 if state == GRAB or state == TURN else 0.0
	var target := me + _cam_dir * camera_distance * (1.0 + 0.5 * over) + Vector3(0, camera_height + 3.0 * over, 0)
	# never below the floor under the camera + a margin, never under her head height
	var fl := floor_at(target.x * U, target.z * U)
	var low := maxf((fl if fl != -INF else -3.56) / U, me.y) + 1.4
	target.y = maxf(target.y, low)
	var kp := 1.0 - exp(-camera_smooth * delta) if delta < 1.0 else 1.0
	_cam.global_position = _cam.global_position.lerp(target, kp)
	_cam.look_at(me + Vector3(0, 0.9, 0) - _cam_dir * 1.0, Vector3.UP)

func state_name() -> String:
	return ["walk", "approach", "grab", "turn"][state] + (" (in the air)" if airborne else "")
