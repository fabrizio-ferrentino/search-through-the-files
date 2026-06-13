shader_type canvas_item;

// Effetto CRT: curvatura, scanline, vignettatura, aberrazione cromatica.
uniform float curvature : hint_range(2.0, 16.0) = 7.0;        // valore alto = schermo piu' piatto
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.35;
uniform float aberration : hint_range(0.0, 4.0) = 0.7;        // in pixel
uniform float brightness : hint_range(0.5, 2.0) = 1.12;
uniform vec2 screen_size = vec2(1440.0, 1080.0);

vec2 curve_uv(vec2 uv, float curve) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / curve;
	uv = uv + uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}

void fragment() {
	vec2 cuv = curve_uv(UV, curvature);

	// Fuori dai bordi dello schermo curvo -> nero
	if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float ab = aberration / screen_size.x;
		vec4 col;
		col.r = texture(TEXTURE, cuv + vec2(ab, 0.0)).r;
		col.g = texture(TEXTURE, cuv).g;
		col.b = texture(TEXTURE, cuv - vec2(ab, 0.0)).b;
		col.a = 1.0;

		// Scanline orizzontali
		float scan = sin(cuv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
		col.rgb *= mix(1.0, scan, scanline_strength);

		// Vignettatura
		vec2 v = cuv * (1.0 - cuv.yx);
		float vig = pow(v.x * v.y * 15.0, vignette_strength);
		col.rgb *= clamp(vig, 0.0, 1.0);

		col.rgb *= brightness;
		COLOR = col;
	}
}
