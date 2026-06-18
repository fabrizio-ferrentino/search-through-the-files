shader_type canvas_item;

// Regolazioni "da fotoritocco" applicate a un CanvasItem (la foto e, condividendo lo
// stesso materiale, la scritta-chiave sovrapposta): luminosita', contrasto,
// saturazione e livelli (punto nero / punto bianco). Coi valori di default e'
// l'identita'; e' regolando questi parametri che la scritta nascosta emerge.
// (M3 parte 3: puzzle dell'immagine. Riusabile come base per effetti futuri.)

uniform float brightness = 0.0;       // -1..1, aggiunta
uniform float contrast = 1.0;         //  0..4, attorno a 0.5
uniform float saturation = 1.0;       //  0..3
uniform float black_point = 0.0;      //  0..1, livelli: nuovo nero
uniform float white_point = 1.0;      //  0..1, livelli: nuovo bianco

void fragment() {
	// base = texture * modulate: vale sia per la foto (TEXTURE = immagine) sia per
	// il Label (TEXTURE = atlante del font, COLOR = colore del testo).
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec3 c = base.rgb;
	// livelli: rimappa [nero, bianco] -> [0, 1]
	c = (c - black_point) / max(white_point - black_point, 0.001);
	// luminosita'
	c += brightness;
	// contrasto attorno al grigio medio
	c = (c - 0.5) * contrast + 0.5;
	// saturazione attorno alla luminanza
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	COLOR = vec4(clamp(c, 0.0, 1.0), base.a);
}
