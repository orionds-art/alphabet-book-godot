# astrid_setup.gd -- written by astrid_godot_export.py (Blender repo, godot_export\). Re-export rewrites it.
# Puts Astrid's woodCUT materials on the imported mesh by Blender material name. A file in res://astrid_main/mat/
# named "<name> MAIN.tres" wins over the exporter's "<name> IMPORT.tres" (that folder is Orion's; the exporter never
# writes it). @tool: the editor shows the woodcut look too.
@tool
extends Node3D

const IMPORT_MAT := "res://astrid_import/mat/"
const MAIN_MAT := "res://astrid_main/mat/"
# alternative looks (20 Oct 2026): res://astrid_import/mat/looks/<FLAT|C4D>/<stem> LOOK.tres (a file in
# res://astrid_main/mat/looks/<LOOK>/<stem> MAIN.tres wins). A look without a file for a surface keeps the woodcut.
const LOOKS := ["WOODCUT", "FLAT", "C4D"]
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
## Woodcut (default) / Flat (plain lit gray) / C4D (Orion's Cinema 4D page-edge scan look). Run window: L cycles.
@export_enum("Woodcut", "Flat", "C4D") var look := 0:
	set(v):
		look = clampi(v, 0, LOOKS.size() - 1)
		if is_inside_tree():
			_apply_look()

func _ready() -> void:
	_apply_look()
	# tuft shedding (21 Oct 2026): run window / game only, never in the editor, never saved into a scene
	if not Engine.is_editor_hint() and FileAccess.file_exists("res://astrid_import/tail_shed_events.json") \
			and ResourceLoader.exists("res://astrid_import/tail_shed.gd"):
		var ts := Node3D.new()
		ts.name = "Tail Shed"
		ts.set_script(load("res://astrid_import/tail_shed.gd"))
		add_child(ts)

## the tuft shedding node (null when off): tail_shed.gd, burst(strength, flakes) for gameplay
func get_tail_shed() -> Node:
	return get_node_or_null("Tail Shed")

func _apply_look() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.layers = layers
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var nm: String = m.resource_name if m and m.resource_name != "" else mesh.surface_get_name(i)
			if not MATERIALS.has(nm):
				# a surface already on an override keeps its Blender name in the mesh's own material
				continue
			mi.set_surface_override_material(i, _material(MATERIALS[nm]))

func _material(stem: String) -> Material:
	if look > 0:
		var lk: String = LOOKS[look]
		var pm := MAIN_MAT + "looks/" + lk + "/" + stem + " MAIN.tres"
		if ResourceLoader.exists(pm):
			return load(pm)
		var pl := IMPORT_MAT + "looks/" + lk + "/" + stem + " LOOK.tres"
		if ResourceLoader.exists(pl):
			return load(pl)
	var p := MAIN_MAT + stem + " MAIN.tres"
	if ResourceLoader.exists(p):
		return load(p)
	return load(IMPORT_MAT + stem + " IMPORT.tres")

## the next look (WOODCUT -> FLAT -> C4D -> WOODCUT); returns its name
func next_look() -> String:
	look = (look + 1) % LOOKS.size()
	return LOOKS[look]

func look_name() -> String:
	return LOOKS[look]

## the imported AnimationPlayer (clip "ASTRID walk + page turn", 30 fps, Blender frame 1 = 0 s)
func get_animation_player() -> AnimationPlayer:
	var aps := find_children("*", "AnimationPlayer", true, false)
	return aps[0] if aps.size() > 0 else null

## the node that carries her ROOT motion (walks and turns with her)
func get_root_motion_node() -> Node3D:
	return find_child("Astrid", true, false) as Node3D
