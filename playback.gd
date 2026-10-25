# playback.gd -- the alphabet book MAIN scene: plays Astrid's baked animation and leaf 01's baked page turn
# together from one clock (Blender frame numbers, 30 fps), and moves her follow camera + salon spots with her.
# First written by astrid_godot_export.py; from then on it is Orion's (the exporter only rewrites it with `-- main`).
# Keys (run window): Space play / pause, Left / Right one frame (Shift: 10), Home first frame, C switch camera.
# F = fly camera (fly_cam.gd, as in Parrots France): starts where the current camera is; hold RIGHT mouse to look,
# W A S D move, Q / E down / up, Shift 4x faster, Ctrl 4x slower, wheel = speed, R = back to the start. F again leaves it.
# L = Astrid's look: WOODCUT -> FLAT -> C4D -> WOODCUT (astrid_setup.gd `look`; the HUD shows it when not woodcut).
# H = shadow mode (hero_shadows.gd): ONE SUN (crisp Book Light + a fake soft book shadow on the table; default) ->
# SUN PAIR (soft Book Light + a crisp copy for Astrid) -> SOFT (the Book Light as saved). Run window only; the editor
# shows the plain Book Light.
@tool
extends Node3D

const HeroShadows := preload("res://hero_shadows.gd")

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
@export_enum("Book", "Astrid", "Fly") var view := 0:
	set(v):
		view = v
		_apply_camera()
## fly camera start speed, metres per second (the book is about 11.7 m across)
@export var fly_speed := 1.5
## play in the editor viewport too (off: the editor only follows `frame`)
@export var play_in_editor := false
@export var show_frame := true
## crisp Astrid shadows (hero_shadows.gd, run window only; H cycles): One Sun = crisp Book Light + fake soft book
## shadow (the light one), Sun Pair = soft Book Light + crisp copy for Astrid, Soft = the Book Light as saved
@export_enum("One Sun", "Sun Pair", "Soft") var shadow_mode := 0:
	set(v):
		shadow_mode = v
		if _hero:
			_hero.mode = v
			_hero.apply()
## sun size of the crisp shadows, in degrees (0 = plain filtered shadow, the cheapest)
@export_range(0.0, 10.0, 0.01) var hero_shadow_size := 0.0:
	set(v):
		hero_shadow_size = v
		if _hero:
			_hero.size = v
			_hero.apply()

var _ap: AnimationPlayer
var _clip := ""
var _root_motion: Node3D
var _book: Node
var _fly: Camera3D
var _look := "WOODCUT"
var _hero   # hero_shadows.gd, built in the run window only

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
	var sun := get_node_or_null("Book Light") as DirectionalLight3D
	if sun and not Engine.is_editor_hint():
		_hero = HeroShadows.new()
		_hero.mode = shadow_mode
		_hero.build(sun, _book, hero_shadow_size)

func _process(delta: float) -> void:
	if playing and (not Engine.is_editor_hint() or play_in_editor):
		var f := frame + delta * FPS * speed
		if f > LAST:
			f = FIRST if loop else LAST
		frame = f
	var lab := get_node_or_null("HUD/Frame") as Label
	if lab:
		lab.visible = show_frame and not Engine.is_editor_hint()
		lab.text = "frame %d%s%s%s" % [int(frame), "" if playing else "  (paused)",
				"" if _look == "WOODCUT" else "  look " + _look,
				"" if shadow_mode == 0 else "  shadows " + HeroShadows.MODE_NAMES[shadow_mode]]

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
	if view == 2:
		if Engine.is_editor_hint():
			return
		_start_fly()
		return
	var c := get_node_or_null("Book Camera" if view == 0 else "Astrid Follow/Astrid Camera") as Camera3D
	if c:
		c.current = true

# a fresh fly camera at the camera you were looking through (run window only, never saved into the scene)
func _start_fly() -> void:
	var from := get_viewport().get_camera_3d()
	if _fly:
		_fly.queue_free()
	_fly = Camera3D.new()
	_fly.name = "Fly Camera"
	if from:
		_fly.fov = from.fov
		_fly.near = from.near
		_fly.far = from.far
		_fly.cull_mask = from.cull_mask
		_fly.environment = from.environment
		_fly.attributes = from.attributes
		_fly.compositor = from.compositor
	_fly.set_script(load("res://fly_cam.gd"))
	_fly.set("speed", fly_speed)
	if from:   # placed BEFORE it enters the tree, so its _ready takes this as the start (R) and the look angles
		_fly.transform = global_transform.affine_inverse() * from.global_transform
	add_child(_fly)
	_fly.current = true

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
			view = 1 if view == 0 else 0
		KEY_F:
			view = 2 if view != 2 else 0
		KEY_H:
			shadow_mode = (shadow_mode + 1) % HeroShadows.MODE_NAMES.size()
		KEY_L:   # Astrid's look: WOODCUT -> FLAT -> C4D (astrid_setup.gd, 20 Oct 2026)
			var a := get_node_or_null("Astrid (import)")
			if a and a.has_method("next_look"):
				_look = a.next_look()
				print("look: ", _look)
