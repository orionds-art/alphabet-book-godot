# render_probe.gd -- stills of alphabet_book_MAIN.tscn at chosen frames from both cameras, through an offscreen
# SubViewport (the window can stay small on the side monitor). Real renderer only (not --headless):
#   Godot_console --position 3900,300 --resolution 960x540 --path "F:\WOODCUTS GODOT\alphabet book" -s res://tools/render_probe.gd ++ <out dir> 1,300,500,990,1050 [1280x720] [spot energy multiplier] [looks]
# looks (20 Oct 2026): comma list of Astrid looks to render, e.g. WOODCUT,FLAT,C4D (astrid_setup.gd `look`); default
# WOODCUT only, with the old file names. Other looks write godot_<look>_<book|astrid>_f<frame>.png.
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
	var tag := "" if args.size() <= 3 or args[3] == "1" else "_x" + args[3]
	for l in main.find_children("*", "SpotLight3D", true, false):
		l.light_energy *= mul
	var looks := args[4].split(",") if args.size() > 4 else PackedStringArray(["WOODCUT"])
	var astrid := main.get_node_or_null("Astrid (import)")
	for i in 60:
		await process_frame
	for lk in looks:
		var lt := ""
		if astrid and "look" in astrid:
			astrid.look = ["WOODCUT", "FLAT", "C4D"].find(lk)
			lt = "" if lk == "WOODCUT" and looks.size() == 1 else "_" + lk.to_lower()
		for i in 30:
			await process_frame
		for v in [0, 1]:
			main.view = v
			for f in frames:
				main.frame = float(f)
				for i in 12:
					await process_frame
				var img := sv.get_texture().get_image()
				var p := "%s/godot%s%s_%s_f%04d.png" % [out, tag, lt, "book" if v == 0 else "astrid", int(f)]
				img.save_png(p)
				print("[probe] wrote ", p)
	quit()
