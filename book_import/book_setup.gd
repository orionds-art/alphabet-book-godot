# book_setup.gd -- written by astrid_godot_export.py (Blender repo, godot_export\). Re-export rewrites it.
# Puts the book / table materials on the imported meshes by Blender material name ("<name> MAIN.tres" in
# res://book_main/mat/ wins over the exporter's "<name> IMPORT.tres"), puts every mesh on render layer 2 (the
# Book Light lights layer 2 only, as Blender's light linking), and plays leaf 01's baked page turn: set `frame`
# (Blender frame number, 1..1050) -- playback.gd does that from Astrid's animation clock.
@tool
extends Node3D

const IMPORT_MAT := "res://book_import/mat/"
const MAIN_MAT := "res://book_main/mat/"
const MATERIALS := {
	 "Book Cloth": "Book_Cloth",
	 "Endpaper": "Endpaper",
	 "Page Edges": "Page_Edges",
	 "Page 03 (A picture)": "Page_03_A_picture",
	 "Page 01 (title)": "Page_01_title",
	 "Page 02 (A letter)": "Page_02_A_letter",
	 "Leaf Edge": "Leaf_Edge",
	 "Table Wood": "Table_Wood"
	}
const LEAF := "Leaf 01"
# the bake's bounding box (leaf mesh space, Blender units): the leaf's culling box, since the shader moves it
const VAT_AABB := AABB(Vector3(-64.34182739257812, -1.8057222366333008, -43.703651428222656), Vector3(128.6837158203125, 18.839421272277832, 87.44867706298828))

@export_flags_3d_render var layers := 2
@export_range(1.0, 1050.0, 0.01) var frame := 1.0:
	set(v):
		frame = v
		if is_inside_tree():
			_apply_frame()

var _leaf: GeometryInstance3D

func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.layers = layers
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var nm: String = m.resource_name if m and m.resource_name != "" else mesh.surface_get_name(i)
			if MATERIALS.has(nm):
				mi.set_surface_override_material(i, _material(MATERIALS[nm]))
		if String(mi.name) == LEAF:
			_leaf = mi
			mi.custom_aabb = VAT_AABB.grow(1.0)
			mi.lod_bias = 128.0
	_apply_frame()

func _material(stem: String) -> Material:
	var p := MAIN_MAT + stem + " MAIN.tres"
	if ResourceLoader.exists(p):
		return load(p)
	return load(IMPORT_MAT + stem + " IMPORT.tres")

func _apply_frame() -> void:
	if _leaf:
		_leaf.set_instance_shader_parameter("vat_frame", frame)

func set_frame(f: float) -> void:
	frame = f
