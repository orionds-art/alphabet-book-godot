# render_probe.gd -- stills of alphabet_book_MAIN.tscn at chosen frames from both cameras, through an offscreen
# SubViewport (the window can stay small on the side monitor). Real renderer only (not --headless):
#   Godot_console --position 3900,300 --resolution 960x540 --path "F:\WOODCUTS GODOT\alphabet book" -s res://tools/render_probe.gd ++ <out dir> 1,300,500,990,1050 [1280x720] [spot energy multiplier]
# Writes <out>/godot_<book|astrid>_f<frame>.png
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var frames := args[1].split(",") if args.size() > 1 else PackedStringArray(["1", "300", "500", "990", "1050"])
	var res := args[2].split("x") if args.size() > 2 else PackedStringArray(["1280", "720"])
	DirAccess.make_dir_recursive_absolute(out)
	var sv := SubViewport.new()
	sv.size = Vector2i(int(res[0]), int(res[1]))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var main: Node = (load("res://alphabet_book_MAIN.tscn") as PackedScene).instantiate()
	main.playing = false
	sv.add_child(main)
	# optional 4th argument: multiply her spot lights' energy (calibration tests)
	var mul := float(args[3]) if args.size() > 3 else 1.0
	var tag := "" if args.size() <= 3 else "_x" + args[3]
	for l in main.find_children("*", "SpotLight3D", true, false):
		l.light_energy *= mul
	for i in 60:
		await process_frame
	for v in [0, 1]:
		main.view = v
		for f in frames:
			main.frame = float(f)
			for i in 12:
				await process_frame
			var img := sv.get_texture().get_image()
			var p := "%s/godot%s_%s_f%04d.png" % [out, tag, "book" if v == 0 else "astrid", int(f)]
			img.save_png(p)
			print("[probe] wrote ", p)
	quit()
