shader_type spatial;
// Edificios y modelos: color por vértice, nieve en techos, ventanas emisivas de noche,
// recorte de obra en construcción y resaltado de selección.
// COLOR.a: 1 = material normal, 0.5 = ventana (brilla de noche), 0.1 = núcleo siempre encendido.
// INSTANCE_CUSTOM (MultiMesh): r = altura de corte de obra (m), g = selección, b = activo (luces).
render_mode cull_back, specular_disabled;

uniform bool use_instance = true;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.7;
uniform vec3 glow_color : source_color = vec3(1.0, 0.62, 0.28);

varying vec3 v_wn;
varying float v_y;
varying vec4 v_custom;

void vertex() {
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_y = VERTEX.y;
	v_custom = use_instance ? INSTANCE_CUSTOM : vec4(999.0, 0.0, 1.0, 0.0);
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
	// Nieve en superficies orientadas hacia arriba (no en ventanas ni núcleos)
	float up = smoothstep(0.55, 0.9, v_wn.y) * step(0.6, tag);
	base = mix(base, vec3(0.9, 0.94, 1.0), up * snow_amount);
	ALBEDO = base;
	ROUGHNESS = 0.9;
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
