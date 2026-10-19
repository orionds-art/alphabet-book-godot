# fly_cam.gd -- a free-look camera for F6 / F5 runs (Orion, 2 Oct 2026). Attach it to a Camera3D.
#
#   Hold RIGHT mouse        look around (the cursor hides while held)
#   W A S D                 forward / left / back / right (while right mouse is held, or any time)
#   Q / E                   down / up
#   Shift                   4x faster        Ctrl   4x slower
#   Mouse wheel             change the base speed
#   R                       back to where the camera started
#   SPACEMOUSE              push/pull/slide the puck to move, tilt/twist it to look (axis directions as the
#                           spacemouse_editor plugin; needs addons/spacemouse_native). Added 9 Oct 2026.
#
# Runs only in the game, never in the editor, so the scene's saved camera is left alone.
extends Camera3D

@export var speed := 0.6               # metres per second (Joan is 1.68 m tall)
@export var look_sensitivity := 0.25   # degrees per pixel of mouse motion
@export_group("SpaceMouse")
@export var spacemouse := true
@export var sm_move_gain := 1.0        # puck push -> fraction of `speed` (full push ~ speed)
@export var sm_look_gain := 1.0        # puck tilt -> turn rate
@export_range(0.0, 0.99) var sm_damping := 0.8
@export var sm_deadzone := 0.02
@export var sm_full_scale := 350.0     # raw puck value treated as "full push"
@export_group("")

var _yaw := 0.0
var _pitch := 0.0
var _looking := false
var _start: Transform3D
var _sm: Object = null
var _vt := Vector3.ZERO
var _vr := Vector3.ZERO

func _ready() -> void:
	_start = global_transform
	_take_angles()
	if spacemouse and not Engine.is_editor_hint():
		var ext := "res://addons/spacemouse_native/spacemouse_native.gdextension"
		if ResourceLoader.exists(ext):
			ResourceLoader.load(ext)
		if ClassDB.class_exists("SpaceMouseDevice"):
			_sm = ClassDB.instantiate("SpaceMouseDevice")
			if _sm and not _sm.open_first():
				push_warning("fly_cam: SpaceMouse not detected")
		else:
			push_warning("fly_cam: SpaceMouse driver not loaded (addons/spacemouse_native)")

func _exit_tree() -> void:
	if _sm:
		_sm.close()
		_sm = null

func _take_angles() -> void:
	var e := global_basis.get_euler()
	_pitch = rad_to_deg(e.x)
	_yaw = rad_to_deg(e.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed *= 1.25
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed /= 1.25
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clamp(_pitch - event.relative.y * look_sensitivity, -89.0, 89.0)
		rotation = Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		global_transform = _start
		_take_angles()

func _spacemouse(delta: float) -> void:
	if _sm == null:
		return
	var st: Dictionary = _sm.get_state()
	if not st.get("connected", false):
		return
	var t: Vector3 = st.get("t", Vector3.ZERO) / sm_full_scale
	var r: Vector3 = st.get("r", Vector3.ZERO) / sm_full_scale
	_vt = _vt * sm_damping + t * (1.0 - sm_damping)
	_vr = _vr * sm_damping + r * (1.0 - sm_damping)
	var s := speed
	if Input.is_key_pressed(KEY_SHIFT): s *= 4.0
	if Input.is_key_pressed(KEY_CTRL): s *= 0.25
	var fwd := -_vt.y
	if abs(fwd) < sm_deadzone: fwd = 0.0
	var move := Vector3(_vt.x, -_vt.z, -fwd)
	if move.length() > sm_deadzone:
		global_position += global_basis * move * s * sm_move_gain * delta
	if _vr.length() > sm_deadzone:
		_yaw += rad_to_deg(-_vr.z * sm_look_gain * 2.0 * delta)
		_pitch = clamp(_pitch + rad_to_deg(_vr.x * sm_look_gain * 2.0 * delta), -89.0, 89.0)
		rotation = Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)

func _process(delta: float) -> void:
	_spacemouse(delta)
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): d.z -= 1.0
	if Input.is_key_pressed(KEY_S): d.z += 1.0
	if Input.is_key_pressed(KEY_A): d.x -= 1.0
	if Input.is_key_pressed(KEY_D): d.x += 1.0
	if Input.is_key_pressed(KEY_Q): d.y -= 1.0
	if Input.is_key_pressed(KEY_E): d.y += 1.0
	if d == Vector3.ZERO:
		return
	var s := speed
	if Input.is_key_pressed(KEY_SHIFT): s *= 4.0
	if Input.is_key_pressed(KEY_CTRL): s *= 0.25
	# forward / sideways follow where the camera looks; Q / E stay straight up and down
	var move := global_basis * Vector3(d.x, 0.0, d.z)
	global_position += (move.normalized() * Vector2(d.x, d.z).length() + Vector3(0.0, d.y, 0.0)) * s * delta
