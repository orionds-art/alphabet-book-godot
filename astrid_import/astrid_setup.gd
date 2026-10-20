# astrid_setup.gd -- written by astrid_godot_export.py (Blender repo, godot_export\). Re-export rewrites it.
# Puts Astrid's woodCUT materials on the imported mesh by Blender material name. A file in res://astrid_main/mat/
# named "<name> MAIN.tres" wins over the exporter's "<name> IMPORT.tres" (that folder is Orion's; the exporter never
# writes it). @tool: the editor shows the woodcut look too.
@tool
extends Node3D

const IMPORT_MAT := "res://astrid_import/mat/"
const MAIN_MAT := "res://astrid_main/mat/"
# Blender material name -> file name stem
const MATERIALS := {
	 "BODY": "BODY",
	 "DARK": "DARK",
	 "woodcut ver 2 Joan LOW SHIELD": "woodcut_ver_2_Joan_LOW_SHIELD",
	 "woodcut ver 2 Joan MID SHIELD": "woodcut_ver_2_Joan_MID_SHIELD",
	 "woodcut ver 2 Joan UPPER SHIELD": "woodcut_ver_2_Joan_UPPER_SHIELD"
	}
# render layer bit for every Astrid mesh (her salon spots light layer 1 only; the Book Light lights layer 2 only)
@export_flags_3d_render var layers := 1

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

func _material(stem: String) -> Material:
	var p := MAIN_MAT + stem + " MAIN.tres"
	if ResourceLoader.exists(p):
		return load(p)
	return load(IMPORT_MAT + stem + " IMPORT.tres")

## the imported AnimationPlayer (clip "ASTRID walk + page turn", 30 fps, Blender frame 1 = 0 s)
func get_animation_player() -> AnimationPlayer:
	var aps := find_children("*", "AnimationPlayer", true, false)
	return aps[0] if aps.size() > 0 else null

## the node that carries her ROOT motion (walks and turns with her)
func get_root_motion_node() -> Node3D:
	return find_child("Astrid", true, false) as Node3D
