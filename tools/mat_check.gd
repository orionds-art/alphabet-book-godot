# mat_check.gd -- headless: print each Astrid Body surface's mesh material name and the override in use.
extends SceneTree
func _initialize() -> void:
	var main: Node = load("res://alphabet_book_MAIN.tscn").instantiate()
	root.add_child(main)
	var mi := main.find_child("Astrid Body", true, false) as MeshInstance3D
	for i in mi.mesh.get_surface_count():
		var o := mi.get_surface_override_material(i)
		print("[mat] surface %d  mesh=%s  override=%s" % [i, mi.mesh.surface_get_name(i), o.resource_path if o else "none"])
	quit()
