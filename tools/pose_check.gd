# pose_check.gd -- headless: Astrid's HEAD / HIPS / PAW.R positions (Godot metres, through the IMPORT scene's 1/11 scale)
# at chosen Blender frames, for each clip in the glb. Compare with astrid_godot_export's Blender numbers.
#   Godot_console --headless --path "<project>" -s res://tools/pose_check.gd ++ 300,990,1050
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := args[0].split(",") if args.size() > 0 else PackedStringArray(["300", "990", "1050"])
	var a: Node = (load("res://astrid_import/astrid_IMPORT.tscn") as PackedScene).instantiate()
	root.add_child(a)
	var ap: AnimationPlayer = a.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = a.find_children("*", "Skeleton3D", true, false)[0]
	for clip in ap.get_animation_list():
		ap.play(clip)
		ap.pause()
		for f in frames:
			ap.seek((float(f) - 1.0) / 30.0, true)
			await process_frame
			var line := "[pose] %s f%s" % [clip, f]
			for b in ["HIPS", "HEAD", "PAW.R"]:
				var i := sk.find_bone(b)
				var p := (sk.global_transform * sk.get_bone_global_pose(i)).origin
				line += "  %s (%.3f, %.3f, %.3f)" % [b, p.x, p.y, p.z]
			print(line)
	quit()
