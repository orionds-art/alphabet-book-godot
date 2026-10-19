# fly_check.gd -- headless: switch the MAIN scene to the fly camera (F) and check it starts at the Book Camera.
#   godot --headless --path "alphabet book" -s res://tools/fly_check.gd
extends SceneTree

var main: Node3D
var n := 0

func _initialize() -> void:
	main = load("res://alphabet_book_MAIN.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	n += 1
	if n == 3:
		var ev := InputEventKey.new()
		ev.keycode = KEY_F
		ev.pressed = true
		main._unhandled_input(ev)
	if n == 6:
		var cam := root.get_viewport().get_camera_3d()
		var book := main.get_node("Book Camera") as Camera3D
		var d := cam.global_position.distance_to(book.global_position)
		print("[fly] view=%d current=%s script=%s offset_from_book_cam=%.5f speed=%s" % [main.view, cam.name, cam.get_script().resource_path if cam.get_script() else "none", d, cam.get("speed")])
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_F
		ev2.pressed = true
		main._unhandled_input(ev2)
	if n == 8:
		print("[fly] after F again: view=%d current=%s" % [main.view, root.get_viewport().get_camera_3d().name])
		return true
	return false
