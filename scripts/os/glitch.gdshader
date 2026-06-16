shader_type canvas_item;

// Glitch riusabile (base per la Milestone 5): legge lo schermo sotto l'elemento e
// lo "rompe". intensity 0 = quasi invisibile; 1 = forte. Pilotata da codice (raffiche).

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 20.0) = 7.0;     // px max di separazione RGB
uniform float slices : hint_range(1.0, 64.0) = 22.0;        // fette orizzontali
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.30;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.18;

float rand(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 18.0);   // tempo "a scatti" per un glitch digitale

	// --- displacement a fette orizzontali (datamosh / tear) ---
	float slice = floor(uv.y * slices);
	float seed = rand(vec2(slice, t));
	float shift = 0.0;
	if (seed > 1.0 - intensity * 0.8) {
		shift = (rand(vec2(slice, t + 1.0)) - 0.5) * 0.06 * intensity;
	}
	vec2 suv = vec2(clamp(uv.x + shift, 0.0, 1.0), uv.y);

	// --- separazione RGB (aberrazione cromatica) ---
	float ab = aberration * SCREEN_PIXEL_SIZE.x * intensity;
	float cr = texture(screen_tex, vec2(clamp(suv.x + ab, 0.0, 1.0), suv.y)).r;
	float cg = texture(screen_tex, suv).g;
	float cb = texture(screen_tex, vec2(clamp(suv.x - ab, 0.0, 1.0), suv.y)).b;
	vec3 col = vec3(cr, cg, cb);

	// --- scanline ---
	float row = uv.y / SCREEN_PIXEL_SIZE.y;            // riga in pixel
	float sl = 0.5 + 0.5 * sin(row * 3.14159);
	col *= 1.0 - scanline_strength * intensity * sl;

	// --- rumore sparso ---
	float nz = rand(uv + vec2(t, t * 0.7));
	float nmask = step(1.0 - noise_amount * intensity, nz);
	col = mix(col, vec3(nz), nmask);

	COLOR = vec4(col, 1.0);
}
