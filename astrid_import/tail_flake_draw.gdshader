// tail_flake_draw.gdshader -- copied by astrid_godot_export.py (Blender repo, godot_export\tail_shed\). Re-export rewrites it.
// A shed tuft flake: her C4D paper (BODY C4D's colour + the baked page-edge scan tone), a random patch of the scan per
// flake (INSTANCE_CUSTOM.z from tail_flake.gdshader). Lambert, two-sided, no specular, one texture fetch.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 paper_color = vec3(0.87050, 0.85390, 0.80520);
uniform float light_gain : hint_range(0.0, 16.0) = 2.0;
uniform float fill : hint_range(0.0, 2.0) = 0.25;
uniform sampler2D tone_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float line_dark : hint_range(0.0, 1.0) = 0.12;
uniform float uv_scale = 0.05;
varying float v_off;

void vertex() {
	v_off = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 uv = UV * uv_scale + vec2(v_off, fract(v_off * 7.31));
	float t = texture(tone_tex, uv).r;
	vec3 c = paper_color * mix(line_dark, 1.0, t);
	ALBEDO = c;
	EMISSION = c * fill;
}

void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR * (light_gain / PI);
}
