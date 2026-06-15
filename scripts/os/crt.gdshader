shader_type canvas_item;

// CRT semplice e PIATTO (niente curvatura del monitor).
// Effetti: scanline, maschera fosfori RGB, leggera aberrazione cromatica e vignettatura.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.20;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.12;
uniform float aberration : hint_range(0.0, 4.0) = 0.5;     // in pixel
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.20;
uniform float brightness : hint_range(0.5, 2.0) = 1.22;
uniform vec2 screen_size = vec2(1440.0, 1080.0);

void fragment() {
	vec2 uv = UV;

	// --- leggera aberrazione cromatica ---
	float ab = aberration / screen_size.x;
	vec3 col;
	col.r = texture(TEXTURE, uv + vec2(ab, 0.0)).r;
	col.g = texture(TEXTURE, uv).g;
	col.b = texture(TEXTURE, uv - vec2(ab, 0.0)).b;

	// --- scanline orizzontali ---
	float scan = 0.5 + 0.5 * sin(uv.y * screen_size.y * 3.14159);
	col *= mix(1.0, scan, scanline_strength);

	// --- maschera fosfori RGB (aperture grille) sui pixel reali: niente moire ---
	vec3 mask = vec3(1.0 - mask_strength);
	int m = int(mod(FRAGCOORD.x, 3.0));
	if (m == 0) {
		mask.r = 1.0;
	} else if (m == 1) {
		mask.g = 1.0;
	} else {
		mask.b = 1.0;
	}
	col *= mask;

	// --- vignettatura tenue (bordi piatti, nessuna curvatura) ---
	vec2 d = uv - 0.5;
	float vig = 1.0 - vignette_strength * dot(d, d) * 2.0;
	col *= clamp(vig, 0.0, 1.0);

	// --- compensazione luminosita' ---
	col *= brightness;

	COLOR = vec4(col, 1.0);
}
