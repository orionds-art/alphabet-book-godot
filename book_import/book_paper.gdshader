// book_paper.gdshader -- written by astrid_godot_export.py (Blender repo, godot_export\). Re-export rewrites it.
// The book's plain look (no woodcut yet, as in Blender): a flat colour, a noise colour ramp (paper, cloth), wave
// bands / rings (table wood, page edges, endpapers), optionally times a page image -- all measured in the mesh's
// own Blender units and axes (Blender's Object texture coordinates). Colours are linear, like Blender's ramps.
// VAT: leaf 01's page turn baked by the exporter (two PNGs, see ALPHABET_BOOK_GODOT_HANDOFF.md). The vertex reads
// its Page Turn position + normal for `vat_frame` (Blender frame number, set per instance by book_setup.gd /
// playback.gd), between two stored frames linearly, and rebuilds the paper's two faces at +- half thickness.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

group_uniforms Look;
uniform int color_mode : hint_enum("Flat,Noise Ramp,Wave Bands,Wave Rings") = 0;
uniform vec3 base_color = vec3(0.8, 0.8, 0.8);
uniform vec3 ramp_a = vec3(0.6, 0.48, 0.29);
uniform vec3 ramp_b = vec3(0.78, 0.67, 0.46);
uniform float tex_scale = 1.0;
uniform float tex_detail = 2.0;
uniform float tex_distortion = 0.0;
uniform int wave_axis : hint_enum("X,Y,Z,Spherical") = 0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform bool use_page_tex = false;
uniform sampler2D page_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// u' = u * x + y (Page 02 is mirrored: -1, 1)
uniform vec2 page_u_map = vec2(1.0, 0.0);
group_uniforms;

group_uniforms VAT;
uniform bool use_vat = false;
uniform sampler2D vat_hi : filter_nearest, repeat_disable;
uniform sampler2D vat_lo : filter_nearest, repeat_disable;
uniform vec3 vat_min = vec3(0.0);
uniform vec3 vat_size = vec3(1.0);
uniform int vat_rows = 1;
uniform float vat_first_frame = 1.0;
uniform float vat_step = 1.0;
uniform float vat_half_thickness = 0.0311;
instance uniform float vat_frame = 1.0;
group_uniforms;

varying vec3 v_obj;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Blender-like fBM: detail + 1 octaves, roughness 0.5, lacunarity 2, normalised to 0..1
float fbm(vec3 p, float detail) {
	float sum = 0.0;
	float amp = 1.0;
	float norm = 0.0;
	int oct = int(clamp(detail, 0.0, 8.0)) + 1;
	for (int i = 0; i < oct; i++) {
		sum += vnoise(p) * amp;
		norm += amp;
		amp *= 0.5;
		p *= 2.0;
	}
	return sum / norm;
}

vec3 vat_pos(ivec2 t) {
	vec4 h = texelFetch(vat_hi, t, 0);
	vec4 l = texelFetch(vat_lo, t, 0);
	vec3 q = (round(h.rgb * 255.0) * 256.0 + round(l.rgb * 255.0)) / 65535.0;
	return vat_min + q * vat_size;
}

vec3 vat_nrm(ivec2 t) {
	vec2 e = vec2(texelFetch(vat_hi, t, 0).a, texelFetch(vat_lo, t, 0).a) * 2.0 - 1.0;
	vec3 n = vec3(e.x, e.y, 1.0 - abs(e.x) - abs(e.y));
	float k = max(-n.z, 0.0);
	n.x += n.x >= 0.0 ? -k : k;
	n.y += n.y >= 0.0 ? -k : k;
	return normalize(n);
}

void vertex() {
	// Blender object coordinates of the resting mesh (the paper look stays glued to the paper)
	v_obj = vec3(VERTEX.x, -VERTEX.z, VERTEX.y);
	if (use_vat) {
		int k = int(round(UV2.x * 255.0)) + int(round(UV2.y * 255.0)) * 256;
		int vid = k / 2;
		float side = (k - vid * 2) == 1 ? 1.0 : -1.0;
		float r = clamp((vat_frame - vat_first_frame) / vat_step, 0.0, float(vat_rows - 1));
		int r0 = int(floor(r));
		int r1 = min(r0 + 1, vat_rows - 1);
		float t = r - float(r0);
		vec3 p = mix(vat_pos(ivec2(vid, r0)), vat_pos(ivec2(vid, r1)), t);
		vec3 n = normalize(mix(vat_nrm(ivec2(vid, r0)), vat_nrm(ivec2(vid, r1)), t));
		VERTEX = p + n * (side * vat_half_thickness);
		NORMAL = n * side;
	}
}

void fragment() {
	vec3 c = base_color;
	vec3 p = v_obj * tex_scale;
	if (color_mode == 1) {
		c = mix(ramp_a, ramp_b, clamp(fbm(p, tex_detail), 0.0, 1.0));
	} else if (color_mode >= 2) {
		vec3 pr = wave_axis == 0 ? vec3(0.0, p.y, p.z) : wave_axis == 1 ? vec3(p.x, 0.0, p.z) : wave_axis == 2 ? vec3(p.x, p.y, 0.0) : p;
		float n = color_mode == 2 ? p[min(wave_axis, 2)] * 20.0 : length(pr) * 20.0;
		if (tex_distortion != 0.0) {
			n += tex_distortion * (fbm(p, tex_detail) * 2.0 - 1.0);
		}
		c = mix(ramp_a, ramp_b, 0.5 + 0.5 * sin(n - 1.5707963));
	}
	if (use_page_tex) {
		c *= texture(page_tex, vec2(UV.x * page_u_map.x + page_u_map.y, UV.y)).rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.5;
}
