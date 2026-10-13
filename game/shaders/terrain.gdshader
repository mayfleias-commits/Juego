shader_type spatial;
// Terreno del cráter: color por vértice con brillo de nieve barato.
render_mode cull_back, specular_disabled;
uniform float sparkle : hint_range(0.0, 1.0) = 0.5;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n = hash(floor(v_world.xz * 2.0));
	c += vec3(0.06) * (n - 0.5);
	float s = step(0.985, hash(floor(v_world.xz * 6.0) + floor(TIME * 0.5))) * sparkle;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	EMISSION = vec3(0.6, 0.7, 0.9) * s * 0.4;
}
