// tail_flake.gdshader -- copied by astrid_godot_export.py (Blender repo, godot_export\tail_shed\). Re-export rewrites it.
// Astrid's tuft sheds little torn paper triangles (21 Oct 2026). One particle = one flake, evaluated in CLOSED FORM
// from its spawn data (the same model as Blender's 'TAIL SHED' preview, rig\tools\tail\tail_ik_build.py):
//   paper drag: the velocity relaxes over `tau` to a slow fall `v_fall`; a sideways flutter (amp, omega, phase);
//   tumbling (spin); each flake lives a random time in `life_range` and shrinks to nothing over its last `shrink`
//   seconds, in mid-air (Orion, 21 Oct 2026: "Flakes can disappear. They don't have to land or stay on the page").
// Spawn: a random point of the box (box_min..box_max, in the emitter's = TAIL_12 bone's space, Blender units) when the
// one-shot burst restarts; velocity = inherit_vel + a random sideways spread + an upward kick (per strength).
// All world values in METRES (tail_shed.gd converts Blender units).
shader_type particles;
render_mode disable_force, disable_velocity;

uniform vec3 inherit_vel = vec3(0.0);
uniform vec2 kick = vec2(0.05, 0.14);
uniform float spread = 0.145;
uniform float tau = 0.3;
uniform float v_fall = 0.5;
uniform vec2 life_range = vec2(1.0, 1.4);
uniform float shrink = 0.3;
uniform vec3 box_min = vec3(-0.12, -0.4, -0.8);
uniform vec3 box_max = vec3(0.12, 1.4, 0.8);
uniform vec2 size_range = vec2(0.02, 0.045);
uniform vec2 amp_range = vec2(0.011, 0.032);
uniform vec2 omega_range = vec2(5.0, 9.0);
uniform vec2 spin_range = vec2(4.0, 11.0);
uniform uint burst_seed = 1u;
// flakes in this burst (the rest of the emitter's `amount` stay inactive)
uniform int count = 24;

float rnd(inout uint s) {
	s = s * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	w = (w >> 22u) ^ w;
	return float(w) / 4294967295.0;
}

mat3 euler_xyz(vec3 r) {   // Blender's XYZ Euler: R = Rz * Ry * Rx
	float cx = cos(r.x), sx = sin(r.x), cy = cos(r.y), sy = sin(r.y), cz = cos(r.z), sz = sin(r.z);
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cx, sx), vec3(0.0, -sx, cx));
	mat3 ry = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	mat3 rz = mat3(vec3(cz, sz, 0.0), vec3(-sz, cz, 0.0), vec3(0.0, 0.0, 1.0));
	return rz * ry * rx;
}

void start() {
	if (int(INDEX) >= count) {
		ACTIVE = false;
	}
	uint s = uint(INDEX) * 9781u + burst_seed * 6271u + RANDOM_SEED * 13u + 17u;
	vec3 lb = mix(box_min, box_max, vec3(rnd(s), rnd(s), rnd(s)));
	vec3 p0 = (EMISSION_TRANSFORM * vec4(lb, 1.0)).xyz;
	float a = rnd(s) * TAU;
	vec3 v0 = inherit_vel + vec3(cos(a), 0.0, sin(a)) * rnd(s) * spread;
	v0.y += mix(kick.x, kick.y, rnd(s));
	float da = rnd(s) * TAU;
	USERDATA1 = vec4(p0, mix(life_range.x, life_range.y, rnd(s)));     // spawn, this flake's life
	USERDATA2 = vec4(v0, rnd(s) * TAU);
	USERDATA3 = vec4(cos(da), sin(da), mix(amp_range.x, amp_range.y, rnd(s)), mix(omega_range.x, omega_range.y, rnd(s)));
	USERDATA4 = vec4(rnd(s) * TAU, rnd(s) * TAU, rnd(s) * TAU, 0.0);
	vec3 sg = sign(vec3(rnd(s), rnd(s), rnd(s)) - 0.5);
	vec3 wr = vec3(mix(spin_range.x, spin_range.y, rnd(s)), mix(spin_range.x, spin_range.y, rnd(s)),
			mix(spin_range.x, spin_range.y, rnd(s))) * sg;
	float sz = mix(size_range.x, size_range.y, rnd(s));
	USERDATA5 = vec4(wr, sz);
	USERDATA6 = vec4(sz * mix(0.6, 1.3, rnd(s)), 0.0, 0.0, 0.0);
	CUSTOM = vec4(0.0, 0.0, rnd(s), 0.0);       // x = age (s), z = where on the scan (draw shader)
	TRANSFORM = mat4(vec4(0.0), vec4(0.0), vec4(0.0), vec4(p0, 1.0));
}

void process() {
	CUSTOM.x += DELTA;
	float t = CUSTOM.x;
	float life = USERDATA1.w;
	float tc = max(t, 0.0);
	float te = tau * (1.0 - exp(-tc / tau));
	vec3 v0 = USERDATA2.xyz;
	float ph = USERDATA2.w;
	vec3 dir = vec3(USERDATA3.x, 0.0, USERDATA3.y);
	vec3 pos = USERDATA1.xyz + v0 * te + dir * USERDATA3.z * (sin(USERDATA3.w * tc + ph) - sin(ph));
	pos.y += v_fall * te - v_fall * tc;
	vec3 rot = USERDATA4.xyz + USERDATA5.xyz * tc;     // tumbling all the way
	mat3 R = euler_xyz(rot);
	float sc = clamp((life - t) / shrink, 0.0, 1.0);
	TRANSFORM = mat4(vec4(R[0] * USERDATA5.w * sc, 0.0), vec4(R[1] * sc, 0.0), vec4(R[2] * USERDATA6.x * sc, 0.0),
			vec4(pos, 1.0));
	if (t > life) {
		ACTIVE = false;
	}
}
