shader_type spatial;
// Copos de nieve animados por completo en la GPU: una sola llamada de dibujo.
// Cada instancia es un quad; su posición sale del índice y de un desplazamiento que la CPU
// integra cuadro a cuadro (así, si cambian la caída o el viento, la nevada no salta),
// envolviendo una caja que sigue a la cámara.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform vec3 center = vec3(0.0);
uniform vec3 box = vec3(120.0, 60.0, 120.0);
// Desplazamiento acumulado (m) por viento (x, z) y caída (y), ya envuelto en la caja.
uniform vec3 offset = vec3(0.0);
// Fase del bamboleo (rad), también integrada en la CPU.
uniform float wobble = 0.0;
uniform float flake_size = 0.18;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;

varying float v_alpha;

float h1(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 r = vec3(h1(id * 1.13), h1(id * 2.71 + 3.1), h1(id * 7.31 + 1.7));
	vec3 p;
	p.y = fract(r.y + offset.y / box.y) * box.y;
	p.x = fract(r.x + offset.x / box.x + sin(wobble + id) * 0.002) * box.x;
	p.z = fract(r.z + offset.z / box.z) * box.z;
	// Anclado al mundo y envuelto alrededor de la cámara (no "nada" al moverla).
	vec3 world;
	world.x = center.x - box.x * 0.5 + mod(p.x - center.x + box.x * 0.5, box.x);
	world.z = center.z - box.z * 0.5 + mod(p.z - center.z + box.z * 0.5, box.z);
	world.y = p.y;
	// billboard
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	float s = flake_size * (0.6 + r.x * 0.8);
	vec3 v = world + (cam_r * VERTEX.x + cam_u * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v, 1.0);
	v_alpha = opacity * smoothstep(0.0, 4.0, p.y) * smoothstep(box.y, box.y - 6.0, p.y);
}

void fragment() {
	float d = length(UV - vec2(0.5));
	float a = smoothstep(0.5, 0.15, d) * v_alpha;
	ALBEDO = vec3(0.95, 0.97, 1.0);
	ALPHA = a;
}
