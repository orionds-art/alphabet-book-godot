# look_cost.gd -- GPU time of each Astrid look (20 Oct 2026). Renders MAIN in an offscreen SubViewport (default
# 1920x1080) from the Astrid camera, paused on one frame, and prints the viewport's measured GPU render time per look,
# plus Astrid hidden (the book / table / paper alone) as the baseline. Real renderer only (not --headless):
#   Godot_console --position 3900,300 --resolution 960x540 --path "F:\WOODCUTS GODOT\alphabet book" -s res://tools/look_cost.gd ++ [frame 300] [1920x1080] [frames 240] [view 1]
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _median(a: Array) -> float:
	a.sort()
	return a[a.size() / 2]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var fr := float(args[0]) if args.size() > 0 else 300.0
	var res := args[1].split("x") if args.size() > 1 else PackedStringArray(["1920", "1080"])
	var n := int(args[2]) if args.size() > 2 else 240
	var view := int(args[3]) if args.size() > 3 else 1
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var sv := SubViewport.new()
	sv.size = Vector2i(int(res[0]), int(res[1]))
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var main: Node = (load("res://alphabet_book_MAIN.tscn") as PackedScene).instantiate()
	main.playing = false
	sv.add_child(main)
	var rid := sv.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var astrid := main.get_node_or_null("Astrid (import)") as Node3D
	for i in 30:
		await process_frame
	main.view = view
	main.frame = fr
	var rows := []
	for case in ["WOODCUT", "FLAT", "C4D", "HIDDEN", "WOODCUT"]:
		if case == "HIDDEN":
			astrid.visible = false
		else:
			astrid.visible = true
			astrid.look = ["WOODCUT", "FLAT", "C4D"].find(case)
		for i in 90:      # shader compile + warm up
			await process_frame
		var gpu := []
		var cpu := []
		for i in n:
			await process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		var g := _median(gpu)
		rows.append([case, g])
		print("[cost] %-8s GPU median %.3f ms (min %.3f, max %.3f), render CPU %.3f ms, %dx%d, frame %d, view %d"
			% [case, g, gpu.min(), gpu.max(), _median(cpu), sv.size.x, sv.size.y, int(fr), view])
	var base: float = rows[3][1]
	for r in rows:
		if r[0] != "HIDDEN":
			print("[cost] %-8s Astrid's share %.3f ms" % [r[0], r[1] - base])
	quit()
