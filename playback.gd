# playback.gd -- the alphabet book MAIN scene: plays Astrid's baked animation and leaf 01's baked page turn
# together from one clock (Blender frame numbers, 30 fps), and moves her follow camera + salon spots with her.
# First written by astrid_godot_export.py; from then on it is Orion's (the exporter only rewrites it with `-- main`).
# Keys (run window): Space play / pause, Left / Right one frame (Shift: 10), Home first frame, C switch camera.
@tool
extends Node3D

const FPS := 30.0
const FIRST := 1.0
const LAST := 1050.0

@export var playing := true
@export var loop := true
@export_range(0.0, 4.0, 0.05) var speed := 1.0
## the current frame (Blender numbering); drag it to scrub
@export_range(1.0, 1050.0, 0.01) var frame := 1.0:
	set(v):
		frame = clampf(v, FIRST, LAST)
		_apply()
@export_enum("Book", "Astrid") var view := 0:
	set(v):
		view = v
		_apply_camera()
## play in the editor viewport too (off: the editor only follows `frame`)
@export var play_in_editor := false
@export var show_frame := true

var _ap: AnimationPlayer
var _clip := ""
var _root_motion: Node3D
var _book: Node

func _ready() -> void:
	var astrid := get_node_or_null("Astrid (import)")
	_book = get_node_or_null("Book (import)")
	if astrid and astrid.has_method("get_animation_player"):
		_ap = astrid.get_animation_player()
		_root_motion = astrid.get_root_motion_node()
	if _ap:
		for n in _ap.get_animation_list():
			if n != "RESET":
				_clip = n
				break
		if _clip != "":
			_ap.play(_clip)
			_ap.pause()
	_apply_camera()
	_apply()

func _process(delta: float) -> void:
	if playing and (not Engine.is_editor_hint() or play_in_editor):
		var f := frame + delta * FPS * speed
		if f > LAST:
			f = FIRST if loop else LAST
		frame = f
	var lab := get_node_or_null("HUD/Frame") as Label
	if lab:
		lab.visible = show_frame and not Engine.is_editor_hint()
		lab.text = "frame %d%s" % [int(frame), "" if playing else "  (paused)"]

func _apply() -> void:
	if not is_inside_tree():
		return
	if _ap and _clip != "":
		_ap.seek((frame - FIRST) / FPS, true)
	if _book and _book.has_method("set_frame"):
		_book.set_frame(frame)
	var fol := get_node_or_null("Astrid Follow") as Node3D
	if fol and _root_motion:
		var p := _root_motion.global_position
		fol.global_position = Vector3(p.x, 0.0, p.z)

func _apply_camera() -> void:
	if not is_inside_tree():
		return
	var c := get_node_or_null("Book Camera" if view == 0 else "Astrid Follow/Astrid Camera") as Camera3D
	if c:
		c.current = true

func _unhandled_input(e: InputEvent) -> void:
	if Engine.is_editor_hint() or not (e is InputEventKey) or not e.pressed:
		return
	match e.keycode:
		KEY_SPACE:
			playing = not playing
		KEY_RIGHT:
			playing = false
			frame = frame + (10.0 if e.shift_pressed else 1.0)
		KEY_LEFT:
			playing = false
			frame = frame - (10.0 if e.shift_pressed else 1.0)
		KEY_HOME:
			frame = FIRST
		KEY_C:
			view = 1 - view
