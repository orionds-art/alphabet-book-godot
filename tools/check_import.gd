# check_import.gd -- headless structural check of the exported alphabet book (19 Oct 2026). Safe headless:
#   Godot_console --headless --path "F:\WOODCUTS GODOT\alphabet book" -s res://tools/check_import.gd
# Prints: Astrid's mesh (skin, surfaces, CUSTOM0 rest positions == the rest vertices), the clip (length, tracks, root
# motion node), the leaf's VAT index range, and the VAT textures decoded against the exporter's samples.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var a: Node = (load("res://astrid_import/astrid_IMPORT.glb") as PackedScene).instantiate()
	root.add_child(a)
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		print("[check] astrid mesh %s: skin %s, %d surfaces, parent %s" % [mi.name, mi.skin != null, m.get_surface_count(), mi.get_parent().name])
		var worst := 0.0
		var nv := 0
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var c = arr[Mesh.ARRAY_CUSTOM0]
			nv += v.size()
			var mat := m.surface_get_material(s)
			if c == null:
				print("[check]   surface %d (%s/%s): NO CUSTOM0" % [s, mat.resource_name if mat else "?", m.surface_get_name(s)])
				continue
			var stride: int = c.size() / max(v.size(), 1)
			if s == 0:
				for i in [0, 1000, 50000]:
					print("[check]     v%d VERTEX %s CUSTOM0 %s %s %s %s" % [i, v[i], c[i * stride], c[i * stride + 1], c[i * stride + 2], c[i * stride + 3]])
			var w := 0.0
			for i in v.size():
				var r := Vector3(c[i * stride], c[i * stride + 1], c[i * stride + 2])
				w = maxf(w, (r - v[i]).length())
			worst = maxf(worst, w)
			print("[check]   surface %d (%s/%s): %d verts, CUSTOM0 stride %d, |CUSTOM0 - VERTEX| max %.5f" % [s, mat.resource_name if mat else "?", m.surface_get_name(s), v.size(), stride, w])
		print("[check]   %d verts in all, CUSTOM0 vs rest max %.5f" % [nv, worst])
	for sk in a.find_children("*", "Skeleton3D", true, false):
		print("[check] skeleton %s: %d bones, parent %s" % [sk.name, sk.get_bone_count(), sk.get_parent().name])
	for ap in a.find_children("*", "AnimationPlayer", true, false):
		for n in ap.get_animation_list():
			var an: Animation = ap.get_animation(n)
			var paths := {}
			for t in an.get_track_count():
				paths[String(an.track_get_path(t)).split(":")[0]] = true
			print("[check] clip '%s': %.3f s (%.1f frames at 30), %d tracks, nodes %s" % [n, an.length, an.length * 30.0, an.get_track_count(), paths.keys()])
	var b: Node = (load("res://book_import/book_IMPORT.glb") as PackedScene).instantiate()
	root.add_child(b)
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		var line := "[check] book mesh %s: %d surfaces" % [mi.name, m.get_surface_count()]
		if String(mi.name) == "Leaf 01":
			var kmin := 1 << 30
			var kmax := -1
			var nv := 0
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
				nv += uv2.size()
				for u in uv2:
					var k := int(round(u.x * 255.0)) + int(round(u.y * 255.0)) * 256
					kmin = mini(kmin, k)
					kmax = maxi(kmax, k)
			line += ", %d verts, VAT k %d..%d (vertex %d..%d), shadow mesh %s" % [nv, kmin, kmax, kmin / 2, kmax / 2, m.shadow_mesh != null if m is ArrayMesh else "?"]
		print(line)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://book_import/leaf01_vat.json"))
	var hi: Image = (load("res://book_import/leaf01_vat_hi.png") as Texture2D).get_image()
	var lo: Image = (load("res://book_import/leaf01_vat_lo.png") as Texture2D).get_image()
	print("[check] VAT textures %dx%d %s / %dx%d %s (json: %d x %d)" % [hi.get_width(), hi.get_height(), hi.get_format(), lo.get_width(), lo.get_height(), lo.get_format(), meta.vertices, meta.rows])
	var mn := Vector3(meta.min[0], meta.min[1], meta.min[2])
	var sz := Vector3(meta.size[0], meta.size[1], meta.size[2])
	var worst := 0.0
	for smp in meta.samples:
		var h := hi.get_pixel(int(smp.vertex), int(smp.row))
		var l := lo.get_pixel(int(smp.vertex), int(smp.row))
		var q := Vector3(round(h.r * 255.0) * 256.0 + round(l.r * 255.0), round(h.g * 255.0) * 256.0 + round(l.g * 255.0), round(h.b * 255.0) * 256.0 + round(l.b * 255.0)) / 65535.0
		var p := mn + q * sz
		worst = maxf(worst, (p - Vector3(smp.pos[0], smp.pos[1], smp.pos[2])).length())
	print("[check] VAT decode vs Blender samples: max error %.5f units over %d samples" % [worst, meta.samples.size()])
	quit()
