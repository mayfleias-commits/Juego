shader_type spatial;
// Edificios y modelos: color por vértice, nieve en techos, ventanas emisivas de noche,
// recorte de obra en construcción y resaltado de selección.
// COLOR.a: 1 = material normal, 0.5 = ventana (brilla de noche), 0.1 = núcleo siempre encendido.
// INSTANCE_CUSTOM (MultiMesh): r = altura de corte de obra (m), g = selección, b = activo (luces).
render_mode cull_back;

uniform bool use_instance = true;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.7;
uniform vec3 glow_color : source_color = vec3(1.0, 0.62, 0.28);
// 0 = barato (celular): sin detalle procedural ni brillos; 1 = semirrealista (PC)
uniform int quality = 1;

varying vec3 v_wn;
varying float v_y;
varying vec4 v_custom;
varying vec3 v_wpos;
varying float v_mat;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(17.1, 113.7, 271.3))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i), n100 = hash3(i + vec3(1,0,0)), n010 = hash3(i + vec3(0,1,0)), n110 = hash3(i + vec3(1,1,0));
	float n001 = hash3(i + vec3(0,0,1)), n101 = hash3(i + vec3(1,0,1)), n011 = hash3(i + vec3(0,1,1)), n111 = hash3(i + vec3(1,1,1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void vertex() {
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_y = VERTEX.y;
	v_custom = use_instance ? INSTANCE_CUSTOM : vec4(999.0, 0.0, 1.0, 0.0);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_mat = UV.x;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float tag = COLOR.a;
	float cut = v_custom.r;
	if (v_y > cut) {
		discard;
	}
	float building = step(cut, 900.0); // 1 si está en obra
	// Andamio: tono madera claro cerca del borde de corte
	float edge = building * (1.0 - smoothstep(0.0, 0.6, cut - v_y));
	base = mix(base, vec3(0.72, 0.58, 0.36), edge * 0.8);
	// Materiales (PBR simplificado)
	int m = int(v_mat + 0.5);
	float rough = 0.9;
	float metal = 0.0;
	float spec = 0.3;
	if (quality > 0) {
		if (m == 1) { // metal oxidado
			float n = noise3(v_wpos * 1.7);
			base = mix(base, vec3(0.36, 0.19, 0.1), smoothstep(0.35, 0.8, n) * 0.55);
			metal = mix(0.65, 0.2, n);
			rough = mix(0.35, 0.85, n);
		} else if (m == 2) { // hielo
			rough = 0.12; spec = 0.9;
			base += vec3(0.04, 0.06, 0.08) * noise3(v_wpos * 3.0);
		} else if (m == 3) { // piedra
			float n = noise3(v_wpos * 2.3) * 0.6 + noise3(v_wpos * 7.0) * 0.4;
			base *= 0.82 + 0.32 * n;
			rough = 0.95;
		} else if (m == 4) { // madera (vetas)
			float g = sin((v_wpos.x + v_wpos.z) * 6.0 + v_wpos.y * 18.0 + noise3(v_wpos * 2.0) * 6.0);
			base *= 0.9 + 0.12 * g;
			rough = 0.78;
		} else if (m == 6) {
			rough = 0.95; spec = 0.1;
		}
	} else {
		spec = 0.0;
	}
	// Nieve en superficies orientadas hacia arriba (no en ventanas ni núcleos)
	float up = smoothstep(0.55, 0.9, v_wn.y) * step(0.6, tag);
	float snow_k = up * snow_amount;
	if (quality > 0) {
		snow_k *= smoothstep(0.15, 0.45, noise3(v_wpos * 1.3) + snow_amount * 0.5);
	}
	base = mix(base, vec3(0.9, 0.94, 1.0), snow_k);
	ALBEDO = base;
	ROUGHNESS = mix(rough, 0.65, snow_k);
	METALLIC = metal * (1.0 - snow_k);
	SPECULAR = spec;
	vec3 em = vec3(0.0);
	if (tag < 0.75 && tag > 0.6) {
		// vidrio de invernadero: brillo verdoso tenue
		em = vec3(0.35, 0.6, 0.45) * (0.08 + 0.35 * night) * v_custom.b;
	} else if (tag <= 0.6 && tag > 0.25) {
		em = glow_color * (0.25 + 1.6 * night) * v_custom.b;
	} else if (tag <= 0.25) {
		em = base * 2.5;
	}
	em += vec3(0.25, 0.65, 1.0) * v_custom.g * 0.55;
	EMISSION = em;
}
