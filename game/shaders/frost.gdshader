shader_type canvas_item;
// Viñeta de escarcha que crece con el frío. quality 0 = solo degradado (celular).
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform int quality = 2;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.5, 1.0));
	float edge = smoothstep(0.45 - intensity * 0.25, 0.85, r);
	float n = 0.0;
	if (quality > 0) {
		n = noise(uv * 18.0) * 0.6 + noise(uv * 55.0) * 0.4;
		if (quality > 1) {
			n = n * 0.7 + noise(uv * 140.0) * 0.3;
		}
	}
	float a = clamp(edge * (0.6 + n * 0.8), 0.0, 1.0) * intensity;
	COLOR = vec4(mix(vec3(0.75, 0.88, 1.0), vec3(1.0), n * 0.5), a * 0.85);
}
