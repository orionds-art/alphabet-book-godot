# hero_shadows.gd -- crisp shadows for the fighters under a big soft sun (25 Oct 2026).
# The soft sun (Book Light) keeps its sun size for the book and table but stops casting the fighters' shadows.
# A copy of it with a small sun size casts ONLY the fighters, and a negative copy with no shadow cancels the copy's
# extra light, so all the pair adds is a crisp fighter shadow. Same receivers (cull mask) as the soft sun.
# Built in the run window only (never in the editor), so nothing is saved into the scene.
# Used by playback.gd (MAIN, key H) and split_test.gd (key 8).
extends RefCounted

const HERO_LAYER := 1   # Astrid's render layer (astrid_setup.gd layers = 1; tail flakes 1 | 2)
const ALL_LAYERS := 0xFFFFF

var sun: DirectionalLight3D
var hero_sun: DirectionalLight3D
var cancel: DirectionalLight3D
var enabled := true

func build(soft_sun: DirectionalLight3D, size_degrees: float) -> void:
	sun = soft_sun
	hero_sun = soft_sun.duplicate() as DirectionalLight3D
	hero_sun.name = "Hero Shadow Sun"
	hero_sun.light_angular_distance = size_degrees
	hero_sun.shadow_caster_mask = HERO_LAYER
	cancel = soft_sun.duplicate() as DirectionalLight3D
	cancel.name = "Hero Shadow Cancel"
	cancel.light_negative = true
	cancel.shadow_enabled = false
	soft_sun.add_sibling(hero_sun)
	soft_sun.add_sibling(cancel)
	apply()

func set_size(size_degrees: float) -> void:
	hero_sun.light_angular_distance = size_degrees

# call after changing the soft sun's energy, color or shadow switch
func apply() -> void:
	var on := enabled and sun.shadow_enabled and sun.visible
	sun.shadow_caster_mask = ALL_LAYERS & ~HERO_LAYER if on else ALL_LAYERS
	hero_sun.visible = on
	cancel.visible = on
	for l in [hero_sun, cancel]:
		l.global_transform = sun.global_transform
		l.light_energy = sun.light_energy
		l.light_color = sun.light_color
		l.light_cull_mask = sun.light_cull_mask
