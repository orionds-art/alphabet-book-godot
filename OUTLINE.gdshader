// =============================================================
//  INVERTED HULL OUTLINE  -  v3  (alpha erosion)
// =============================================================
//  CHANGELOG
//  v4  - REGISTRATION (8 Oct 2026, Canard; Orion: the outline reads as
//        a dotted line, wants "randomized, organic, like stamp
//        registration marks"). use_registration, off by default = v3
//        exactly. Replaces the tiled-texture erosion (a 64^3 noise
//        texture repeating every 1/chip_scale = the even dashes) with
//        procedural, non-repeating noise:
//          - line WEIGHT swells and thins along the contour
//            (reg_width_var / reg_width_scale)
//          - the whole print shifts off-register on screen
//            (reg_offset, view metres): heavy on one side, thin or
//            gone on the other
//          - GAPS of uneven length from domain-warped low-frequency
//            noise (reg_gap / reg_gap_scale / reg_warp), plus a fine
//            ragged BITE (reg_bite / reg_bite_scale)
//        reg_seed moves every pattern.
//  v3  - FACING ALPHA (30 Sept 2026, from the Blender port's
//        `block cut hair outline`): use_facing_alpha + width / soft /
//        cut. Off by default = v2 exactly.
//  v3  - DEPTH CUT (30 Sept 2026, Orion: the hull should not exist
//        until the halfway point of the object from the camera).
//        Off by default = v2 exactly. Hull pixels nearer the camera
//        than the object's middle are discarded, so interior
//        contours (the nose over the cheek) never print; only the
//        rim that lies behind the middle survives.
//  v2  - silhouette irregularity moved from the vertex stage to
//        the fragment stage. The hull is now a smooth, constant
//        thickness shell; the ragged edge comes from discarding
//        pixels. This needs NO extra geometry and NO UVs - v1
//        could only displace at existing vertices, so a low-poly
//        Cinema limb just got uniformly fatter.
//  v1  - vertex displacement along normals.
//
//  SETUP
//  1. Duplicate the MeshInstance3D, child it to the original.
//     Leave the Mesh slot on the SAME resource - no Make Unique.
//  2. Uncheck Cast Shadow on the duplicate.
//  3. Assign a ShaderMaterial with this shader.
//  4. noise_tex -> New NoiseTexture3D -> Noise -> New
//     FastNoiseLite. All FastNoiseLite options are on that
//     resource: Noise Type, Seed, Frequency, Fractal Type /
//     Octaves / Lacunarity / Gain, Cellular Distance Function,
//     Cellular Jitter, Domain Warp.
//     Turn SEAMLESS on. 64^3 is plenty.
//
//  TUNING ORDER
//  a. erode = 0, set thickness until the line weight is right.
//  b. chip_scale until the cells are the size of bark chips.
//     Model space: relative to the mesh's own units. If nothing
//     changes, move it by 10x, not 10%.
//  c. raise erode until the line starts breaking up.
//  d. contrast to sharpen the break from ragged to chipped.
//
//  NOTE ON SPACE
//  Model: chips are glued to the tree, no crawl when the camera
//  orbits, but they shrink with distance like real geometry.
//  Screen: chips stay a constant size in pixels - closer to how
//  a printing block behaves - but they do not travel with the
//  object, so a moving tree swims through the pattern. Model is
//  the safe default; Screen suits static set dressing.
// =============================================================

shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, depth_draw_opaque;

// ---- noise source ------------------------------------------
uniform sampler3D noise_tex : repeat_enable, filter_linear;

// ---- outline -----------------------------------------------
uniform vec3 ink : source_color = vec3(0.0, 0.0, 0.0);
uniform float thickness = 0.02;

// off: world-constant weight, thins with distance
// on:  constant printed weight at any distance
uniform bool constant_screen_width = false;
uniform float reference_depth = 5.0;

// ---- erosion -----------------------------------------------
// 0.0 = solid unbroken outline
// higher = more of the line eaten away
uniform float erode : hint_range(0.0, 1.0) = 0.35;
uniform float chip_scale = 20.0;
uniform float contrast : hint_range(0.5, 8.0) = 2.0;
uniform vec3 chip_offset = vec3(0.0);

// 0 = Model space, 1 = Screen space
uniform int chip_space : hint_enum("Model", "Screen") = 0;

// ---- hard-edge fix -----------------------------------------
// If the mesh has split normals the hull tears open at the
// seams. Either shade-smooth it, or bake a smoothed normal into
// vertex color (remapped -1..1 to 0..1) and enable this.
uniform bool use_vertex_color_normal = false;

// ---- depth cut (v3) ----------------------------------------
// depth_cut_center: the object's middle in MODEL space (the setup
// script passes the mesh's AABB centre). depth_cut: extra distance
// behind that middle before the hull appears, in view units
// (negative lets it start in front of the middle).
uniform bool use_depth_cut = false;
uniform vec3 depth_cut_center = vec3(0.0);
uniform float depth_cut = 0.0;

// ---- facing alpha (v3, from the Blender port) ---------------
// Opaque where the hull is EDGE-ON to the camera (|N.V| small), gone
// where it faces the camera. For a hull whose far side is not hidden
// by its object (a hair mass of lock tubes) this turns the hull back
// into a rim. alpha = 1 - smoothstep(width - soft, width + soft, |N.V|),
// then cut at facing_alpha_cut (the port's Alpha Cutout threshold).
uniform bool use_facing_alpha = false;
uniform float facing_alpha_width : hint_range(0.0, 1.0) = 0.35;
uniform float facing_alpha_soft : hint_range(0.0, 0.5) = 0.1;
uniform float facing_alpha_cut : hint_range(0.0, 1.0) = 0.5;

// ---- registration (v4) --------------------------------------
uniform bool use_registration = false;
uniform float reg_width_var : hint_range(0.0, 1.5) = 0.8;   // 0 = even line, 1 = swells 0..2x
uniform float reg_width_scale = 0.6;                         // model-space frequency of the swelling
uniform vec2 reg_offset = vec2(0.004, -0.003);               // off-register shift, view metres
uniform float reg_gap : hint_range(0.0, 1.0) = 0.3;          // share of the line lost to long breaks
uniform float reg_gap_scale = 0.9;
uniform float reg_warp : hint_range(0.0, 3.0) = 1.2;          // bends the breaks so they don't repeat
uniform float reg_bite : hint_range(0.0, 1.0) = 0.25;         // fine ragged bite
uniform float reg_bite_scale = 9.0;
uniform float reg_seed = 0.0;

varying vec3 model_pos;
varying float v_depth;
varying float v_center_depth;

// procedural value noise (no texture, never repeats at these scales)
float reg_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float reg_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(reg_hash(i + vec3(0, 0, 0)), reg_hash(i + vec3(1, 0, 0)), f.x),
	               mix(reg_hash(i + vec3(0, 1, 0)), reg_hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(reg_hash(i + vec3(0, 0, 1)), reg_hash(i + vec3(1, 0, 1)), f.x),
	               mix(reg_hash(i + vec3(0, 1, 1)), reg_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float reg_fbm(vec3 p) {
	float a = 0.5, s = 0.0;
	for (int k = 0; k < 4; k++) {
		s += a * reg_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s / 0.9375;
}


void vertex() {
	model_pos = VERTEX;

	vec3 dir = use_vertex_color_normal
		? normalize(COLOR.rgb * 2.0 - 1.0)
		: normalize(NORMAL);

	float t = thickness;

	if (constant_screen_width) {
		float depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
		t *= max(depth, 0.001) / max(reference_depth, 0.001);
	}

	if (use_registration) {
		// swelling line weight: slow fbm along the surface, pushed to the extremes so the
		// line goes from hairline to fat rather than wobbling round a mean
		float w = reg_fbm(VERTEX * reg_width_scale + vec3(reg_seed * 7.13));
		w = clamp((w - 0.5) * 2.2, -1.0, 1.0);
		t *= max(0.0, 1.0 + reg_width_var * w);
	}

	VERTEX += dir * t;

	v_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	v_center_depth = -(MODELVIEW_MATRIX * vec4(depth_cut_center, 1.0)).z;

	if (use_registration) {
		// off-register: the whole print slides on screen (depth kept, so the object still
		// hides the hull's far side and only the rim shows -- heavier on one side)
		vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vp.xy += reg_offset;
		POSITION = PROJECTION_MATRIX * vp;
	}
}


void fragment() {
	if (use_depth_cut && v_depth < v_center_depth + depth_cut) {
		discard;
	}
	if (use_facing_alpha) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float fa = 1.0 - smoothstep(facing_alpha_width - facing_alpha_soft,
		                            facing_alpha_width + facing_alpha_soft, facing);
		if (fa < facing_alpha_cut) {
			discard;
		}
	}

	if (use_registration) {
		vec3 q = model_pos + vec3(reg_seed * 3.71, reg_seed * 1.37, 0.0);
		// long breaks: domain-warped low-frequency noise -> gaps of uneven length
		vec3 warp = vec3(reg_noise(q * 0.5), reg_noise(q * 0.5 + 5.2), reg_noise(q * 0.5 + 9.7)) - 0.5;
		float g = reg_fbm(q * reg_gap_scale + warp * reg_warp * 2.0);
		if (g < reg_gap * 0.9 + 0.05 * step(0.001, reg_gap)) {
			discard;
		}
		// fine bite: ragged, ink-starved edge
		float b = reg_noise(q * reg_bite_scale + vec3(11.0));
		if (b < reg_bite * 0.75) {
			discard;
		}
		ALBEDO = ink;
	} else {
	vec3 p;

	if (chip_space == 1) {
		// screen space - chips hold a constant pixel size.
		// FRAGCOORD is already in pixels; SCREEN_PIXEL_SIZE is
		// canvas_item only and does not exist here.
		p = vec3(FRAGCOORD.xy * 0.01, 0.0);
	} else {
		// model space - chips stay locked to the mesh
		p = model_pos;
	}

	float n = texture(noise_tex, p * chip_scale + chip_offset).r;

	// push toward the extremes so the break is a bitten edge
	// rather than a soft fade
	n = clamp((n - 0.5) * contrast + 0.5, 0.0, 1.0);

	if (n < erode) {
		discard;
	}

	ALBEDO = ink;
	}
}
