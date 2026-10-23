shader_type spatial;
render_mode unshaded, cull_disabled;

// Il vetro del monitor 3D: mostra DAL VIVO la texture del SubViewport dell'OS (player.gd).
// Una ViewportTexture non ha mipmap: l'OS (1440x1080) sul monitor occupa ~200-400 px e
// con un solo campione per pixel le righe sottili del desktop fanno moire' ("scanalature").
// Qui ogni pixel fa la media di 4x4 campioni sparsi sull'impronta del pixel nella texture
// (dFdx/dFdy delle UV): e' il lavoro delle mipmap, ma sulla GPU e senza copiare niente.
// Da vicino (entrando nel PC) l'impronta e' piu' piccola di un texel e resta un normale
// filtro bilineare.

uniform sampler2D os_tex : source_color, filter_linear, repeat_disable;

void fragment() {
	vec2 du = dFdx(UV);
	vec2 dv = dFdy(UV);
	vec3 somma = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		for (int j = 0; j < 4; j++) {
			vec2 o = du * ((float(i) + 0.5) / 4.0 - 0.5) + dv * ((float(j) + 0.5) / 4.0 - 0.5);
			somma += texture(os_tex, UV + o).rgb;
		}
	}
	ALBEDO = somma / 16.0;
}
