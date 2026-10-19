// paper_scan.gdshader -- written by wc2_godot_export.py (copied by astrid_godot_export.py). The watercolour scan, MULTIPLIED
// over the frame with its contrast stretched about its own mean, so the paper keeps the
// scheme's colour on average and the fibre texture comes through. Grey only: the scan
// cannot tint the paper.
shader_type canvas_item;
render_mode blend_mul;

uniform float contrast : hint_range(0.0, 12.0) = 4.0;
// the scan's own mean grey (measured); the multiplier is 1.0 there
uniform float scan_mean : hint_range(0.0, 1.0) = 0.8435;

void fragment() {
	float g = dot(texture(TEXTURE, UV).rgb, vec3(0.2126, 0.7152, 0.0722));
	float m = clamp(1.0 + (g - scan_mean) * contrast, 0.0, 1.0);
	COLOR = vec4(vec3(m), 1.0);
}
