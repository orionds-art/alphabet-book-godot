# bedroom_setup.gd -- written by props\bedroom_godot_export.py (Blender repo). Re-export rewrites it.
# The child's bedroom around the book (background only, characters never touch it). Puts the flat stylized material
# on every surface by Blender material name: "<name> MAIN.tres" in res://bedroom_main/mat/ wins (Orion's folder),
# otherwise a ShaderMaterial on bedroom_flat.gdshader with the color below. Every mesh on render layer 3 only and
# casting no shadow (the room must not shade the book from the Book Light). @tool: the editor shows it too.
# The sleeping boy and dog are their own nodes: get_boy(), get_dog() (wake animations later).
@tool
extends Node3D

const SHADER := "res://bedroom_import/bedroom_flat.gdshader"
const MAIN_MAT := "res://bedroom_main/mat/"
# Blender material name -> color (sRGB 0..1)
const COLORS := {
	 "Bedroom Flat Book Spine": [
	  0.2588,
	  0.2745,
	  0.3529
	 ],
	 "Bedroom Flat Ceiling": [
	  0.2824,
	  0.3059,
	  0.3765
	 ],
	 "Bedroom Flat Curtain": [
	  0.3059,
	  0.3294,
	  0.4157
	 ],
	 "Bedroom Flat Dog": [
	  0.251,
	  0.2667,
	  0.3373
	 ],
	 "Bedroom Flat Dog Dark": [
	  0.1647,
	  0.1725,
	  0.2196
	 ],
	 "Bedroom Flat Door": [
	  0.2745,
	  0.298,
	  0.3686
	 ],
	 "Bedroom Flat Floor": [
	  0.2039,
	  0.2196,
	  0.2745
	 ],
	 "Bedroom Flat Hair": [
	  0.1569,
	  0.1647,
	  0.2118
	 ],
	 "Bedroom Flat Moon Pane": [
	  0.1804,
	  0.2275,
	  0.3608
	 ],
	 "Bedroom Flat Night": [
	  0.102,
	  0.1333,
	  0.2353
	 ],
	 "Bedroom Flat Pillow": [
	  0.549,
	  0.5804,
	  0.6588
	 ],
	 "Bedroom Flat Quilt": [
	  0.3922,
	  0.4235,
	  0.5176
	 ],
	 "Bedroom Flat Rug": [
	  0.2902,
	  0.3137,
	  0.3922
	 ],
	 "Bedroom Flat Sheet": [
	  0.4863,
	  0.5176,
	  0.5961
	 ],
	 "Bedroom Flat Skin": [
	  0.5176,
	  0.5255,
	  0.5882
	 ],
	 "Bedroom Flat Trim": [
	  0.2353,
	  0.2549,
	  0.3137
	 ],
	 "Bedroom Flat Wall": [
	  0.3451,
	  0.3725,
	  0.4471
	 ],
	 "Bedroom Flat Wood": [
	  0.1882,
	  0.2039,
	  0.251
	 ]
	}
## render layer bits for every room mesh (default layer 3; the book is on 2, Astrid on 1)
@export_flags_3d_render var layers := 4
## the shade of the side facing away from the fixed light (1 = no shading at all)
@export_range(0.0, 1.0) var shade_low := 0.72:
	set(v):
		shade_low = v
		if is_inside_tree():
			_apply()

var _cache := {}

func _ready() -> void:
	_apply()

func _apply() -> void:
	_cache.clear()
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.layers = layers
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var nm: String = m.resource_name if m and m.resource_name != "" else mesh.surface_get_name(i)
			if COLORS.has(nm):
				mi.set_surface_override_material(i, _material(nm))

func _material(nm: String) -> Material:
	if _cache.has(nm):
		return _cache[nm]
	var p := MAIN_MAT + nm + " MAIN.tres"
	var mat: Material
	if ResourceLoader.exists(p):
		mat = load(p)
	else:
		var sm := ShaderMaterial.new()
		sm.shader = load(SHADER)
		var c: Array = COLORS[nm]
		sm.set_shader_parameter("color", Color(c[0], c[1], c[2]))
		sm.set_shader_parameter("shade_low", shade_low)
		mat = sm
	_cache[nm] = mat
	return mat

func get_boy() -> Node3D:
	return find_child("Boy (sleeping)", true, false) as Node3D

func get_dog() -> Node3D:
	return find_child("Dog (sleeping)", true, false) as Node3D
