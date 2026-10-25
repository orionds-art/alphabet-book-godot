# root_dump.gd -- prints Astrid's root-motion node (local, Blender units in the Scale space) at chosen frames and the
# animation's tracks on it (headless OK). Used to set up player_control.gd's walk loop and grab hand-off.
#   Godot_console --headless --path "F:\WOODCUTS GODOT\alphabet book" -s res://tools/root_dump.gd ++ 1,9,21,33,45,57,69,81,193,227,1050
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := args[0].split(",") if args.size() > 0 else PackedStringArray(["1", "45", "69", "193"])
	var a: Node3D = (load("res://astrid_import/astrid_IMPORT.tscn") as PackedScene).instantiate()
	root.add_child(a)
	await process_frame
	var ap: AnimationPlayer = a.get_animation_player()
	var rm: Node3D = a.get_root_motion_node()
	var clip := ""
	for n in ap.get_animation_list():
		if n != "RESET":
			clip = n
	var an := ap.get_animation(clip)
	print("[root] clip ", clip, " length ", an.length, " tracks ", an.get_track_count())
	for t in an.get_track_count():
		var p := String(an.track_get_path(t))
		if not p.contains(":") or p.begins_with("Astrid:") or p == "Astrid" or not p.contains("Skeleton"):
			print("[root] track ", t, " ", p, " type ", an.track_get_type(t), " keys ", an.track_get_key_count(t))
	ap.play(clip)
	ap.pause()
	for f in frames:
		ap.seek((float(f) - 1.0) / 30.0, true)
		var t := rm.transform
		var fwd := t.basis.z
		print("[root] f %4d pos (%.3f, %.3f, %.3f) yaw %.2f deg  basis.z (%.3f, %.3f, %.3f)  scale (%.3f)" % [
			int(f), t.origin.x, t.origin.y, t.origin.z, rad_to_deg(t.basis.get_euler().y), fwd.x, fwd.y, fwd.z, t.basis.get_scale().x])
	quit()
