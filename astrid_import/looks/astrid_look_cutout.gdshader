// astrid_look_cutout.gdshader -- written by astrid_godot_export.py (Blender repo, godot_export\). Re-export rewrites it.
// Astrid's alternative LOOKS (20 Oct 2026), next to the woodcut: FLAT (plain lit gray) and C4D (Orion's Cinema 4D /
// Octane look: one scan of a book's page edges, its light / dark split baked into tone_tex by
// tools\looks\bake_tone.py, sampled through each piece's Octane UV Transform = the mesh's UV2).
// Cheap on purpose: one texture fetch (C4D), Lambert, no specular. Two-sided like her woodcut.
// This copy: the shield fleur-de-lis cutout (red of cutout_tex, read on UV).
// Colours are LINEAR (Blender / Octane values), not sRGB.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#define CUTOUT
uniform vec3 paper_color = vec3(0.55);
// her salon spots are set for the woodcut, which prints light hard; a plain diffuse needs more of it
uniform float light_gain : hint_range(0.0, 16.0) = 4.0;
// unlit fill, as a fraction of the colour (Blender stills: white world at 0.35)
uniform float fill : hint_range(0.0, 2.0) = 0.35;
uniform bool use_tone = false;
uniform sampler2D tone_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// which baked split: R body (Power 2.8, Gamma 5.73), G shields (6.0, 5.36), B body main section, A throat
uniform vec4 tone_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float line_dark : hint_range(0.0, 1.0) = 0.12;
uniform float line_mix : hint_range(0.0, 1.0) = 1.0;
#ifdef CUTOUT
uniform sampler2D cutout_tex : hint_default_white, filter_linear;
uniform float cutout_threshold : hint_range(0.0, 1.0) = 0.5;
#endif

void fragment() {
	vec3 c = paper_color;
	if (use_tone) {
		float t = dot(texture(tone_tex, UV2), tone_channel);
		c *= mix(1.0, mix(line_dark, 1.0, t), line_mix);
	}
	ALBEDO = c;
	EMISSION = c * fill;
#ifdef CUTOUT
	ALPHA = texture(cutout_tex, UV).r;
	ALPHA_SCISSOR_THRESHOLD = cutout_threshold;
#endif
}

void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR * (light_gain / PI);
}
