# hero_shadows.gd -- crisp fighter shadows without a big soft sun (25 Oct 2026). Three modes:
#   ONE SUN (default, the light one): the Book Light alone, with a small sun size, so every shadow is crisp. The book's
#     soft shadow on the table is faked: a black soft-edged Decal on the table top under the book, offset away from
#     the sun (no extra light, no extra shadow map; the book never moves).
#   SUN PAIR (the first try): the Book Light stays soft but casts no fighter shadows; a small-sun copy casts only the
#     fighters and a negative copy with no shadow cancels its light. Three lights, two shadow maps.
#   SOFT: the Book Light exactly as saved in the scene (soft everything, blurry fighter shadows).
# Built in the run window only (never in the editor), so nothing is saved into the scene.
# Used by playback.gd (MAIN, key H) and split_test.gd (key 8); both cycle the modes.
extends RefCounted

enum Mode { ONE_SUN, SUN_PAIR, SOFT }
const MODE_NAMES := ["one sun", "sun pair", "soft"]
const HERO_LAYER := 1   # Astrid's render layer (astrid_setup.gd layers = 1; tail flakes 1 | 2)
const ALL_LAYERS := 0xFFFFF

var mode := Mode.ONE_SUN
## sun size of the crisp shadows, degrees (0 = plain filtered shadow, the cheapest; above 0 = soft-sun filter)
var size := 0.0
## the fake book shadow: darkness, and how far its edge fades out, in meters
var book_shadow_strength := 1.0
var book_shadow_blur := 0.35

var sun: DirectionalLight3D
var hero_sun: DirectionalLight3D
var cancel: DirectionalLight3D
var book_shadow: Decal
var _soft_size := 0.0
var _soft_mask := ALL_LAYERS

# soft_sun = the scene's Book Light; book = the book instance (has BOOK and Table Top meshes under it)
func build(soft_sun: DirectionalLight3D, book: Node, size_degrees: float) -> void:
	sun = soft_sun
	size = size_degrees
	_soft_size = sun.light_angular_distance
	_soft_mask = sun.shadow_caster_mask
	hero_sun = sun.duplicate() as DirectionalLight3D
	hero_sun.name = "Hero Shadow Sun"
	hero_sun.shadow_caster_mask = HERO_LAYER
	cancel = sun.duplicate() as DirectionalLight3D
	cancel.name = "Hero Shadow Cancel"
	cancel.light_negative = true
	cancel.shadow_enabled = false
	sun.add_sibling(hero_sun)
	sun.add_sibling(cancel)
	if book:
		book_shadow = _make_book_shadow(book)
	apply()

func next_mode() -> String:
	mode = (mode + 1) % Mode.size()
	apply()
	return MODE_NAMES[mode]

func mode_name() -> String:
	return MODE_NAMES[mode]

# call after changing the Book Light's energy, color or shadow switch
func apply() -> void:
	var shadows := sun.shadow_enabled and sun.visible
	sun.light_angular_distance = size if mode == Mode.ONE_SUN else _soft_size
	sun.shadow_caster_mask = ALL_LAYERS & ~HERO_LAYER if mode == Mode.SUN_PAIR and shadows else _soft_mask
	hero_sun.visible = mode == Mode.SUN_PAIR and shadows
	cancel.visible = hero_sun.visible
	hero_sun.light_angular_distance = size
	for l in [hero_sun, cancel]:
		l.global_transform = sun.global_transform
		l.light_energy = sun.light_energy
		l.light_color = sun.light_color
		l.light_cull_mask = sun.light_cull_mask
	if book_shadow:
		book_shadow.visible = mode == Mode.ONE_SUN and shadows
		book_shadow.modulate.a = book_shadow_strength

# a soft black rectangle on the table top, the book's footprint pushed away from the sun by the book's height
func _make_book_shadow(book: Node) -> Decal:
	var body := book.find_child("BOOK", true, false)
	var table := book.find_child("Table Top", true, false) as VisualInstance3D
	if body == null or table == null:
		push_warning("hero_shadows: no BOOK / Table Top under %s, no book shadow" % book.name)
		return null
	var box := AABB()
	var first := true
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var top := (table.global_transform * table.get_aabb()).end.y
	var height := box.end.y - top
	var dir := -sun.global_transform.basis.z   # the way the light travels
	var reach := Vector2(dir.x, dir.z) / maxf(-dir.y, 0.2) * height   # where the top edge's shadow lands
	var push := reach * 0.5
	var blur := book_shadow_blur
	var d := Decal.new()
	d.name = "Book Shadow (fake)"
	d.size = Vector3(box.size.x + absf(reach.x) + blur * 2.0, 0.06, box.size.z + absf(reach.y) + blur * 2.0)
	d.texture_albedo = _soft_rect(256, blur / d.size.x, blur / d.size.z)
	d.modulate = Color(0, 0, 0, book_shadow_strength)
	d.albedo_mix = 1.0
	d.normal_fade = 0.5   # only the flat table top, not the book's side faces
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = 2       # book + table layer (the room is on 3, Astrid on 1)
	sun.add_sibling(d)
	d.global_position = Vector3(box.get_center().x + push.x, top, box.get_center().z + push.y)
	return d

# white rectangle with soft edges in the alpha (fade = edge width as a fraction of each side)
static func _soft_rect(n: int, fade_x: float, fade_y: float) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var ax := smoothstep(0.0, fade_x * 2.0, minf(u, 1.0 - u))
			var ay := smoothstep(0.0, fade_y * 2.0, minf(v, 1.0 - v))
			img.set_pixel(x, y, Color(1, 1, 1, ax * ay))
	return ImageTexture.create_from_image(img)
