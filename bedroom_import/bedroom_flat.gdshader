// bedroom_flat.gdshader -- written by props\bedroom_godot_export.py (Blender repo). Re-export rewrites it.
// The bedroom's flat stylized look: no lights, no shadows. Color x a fixed two-tone "light" by the surface's facing,
// the same formula as the Blender material: shade = low + (high - low) * (n . light * 0.5 + 0.5).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform vec3 color : source_color = vec3(0.35, 0.37, 0.45);
// Blender (0.35, -0.55, 0.76) in Godot axes
uniform vec3 light_direction = vec3(0.35, 0.76, 0.55);
uniform float shade_low : hint_range(0.0, 1.0) = 0.72;
uniform float shade_high : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = dot(n, normalize(light_direction)) * 0.5 + 0.5;
	ALBEDO = color * mix(shade_low, shade_high, d);
}
