shader_type canvas_item;

// La media dei colori dello schermo dell'OS per la luce che il monitor getta nella stanza
// (player.gd, LuceSchermo). Disegnato in un SubViewport minuscolo (16x12): ogni pixel e' la
// media di 8x8 campioni della sua cella dell'OS. player.gd ne rilegge i 192 pixel in modo
// asincrono, senza fermare il frame (la vecchia get_image() dell'intero OS lo bloccava).

uniform sampler2D os_tex : filter_linear, repeat_disable;
uniform vec2 celle = vec2(16.0, 12.0);

void fragment() {
	vec2 cella = 1.0 / celle;
	vec2 inizio = floor(UV * celle) * cella;
	vec3 somma = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		for (int j = 0; j < 8; j++) {
			somma += texture(os_tex, inizio + cella * vec2((float(i) + 0.5) / 8.0, (float(j) + 0.5) / 8.0)).rgb;
		}
	}
	COLOR = vec4(somma / 64.0, 1.0);
}
