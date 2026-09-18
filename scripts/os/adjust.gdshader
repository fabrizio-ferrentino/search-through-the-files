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
uniform float detail = 0.0;           //  0..1, "Nitidezza": passa-banda (0 = spento)

// Conversioni sRGB <-> lineare. Servono perche' il 2D di Godot campiona la texture in
// spazio LINEARE, mentre la foto (e l'occhio del giocatore) stanno in sRGB: regolando in
// lineare i cursori non fanno quello che sembrano fare, e le zone scure si schiacciano nel
// primo 3% della corsa del cursore — il codice nascosto li' diventava impossibile da tirare
// fuori. Qui si lavora nello spazio in cui l'immagine si VEDE.
vec3 lin_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 srgb_to_lin(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// MISURATO (17/09/2026): i valori che si leggono dal SubViewport di composizione stanno
// nello STESSO spazio dei byte del file -- scostamento 0.0000-0.0069 di luminanza sulle 6
// foto (le due con scarto sono quelle che la generazione sfoca, quindi lo scarto E' la
// sfocatura). L'ipotesi "lineare" sbagliava di 0.20-0.29, cioe' e' esclusa. Quindi un
// gemello su CPU del passa-banda NON deve applicare gamma extra, e le costanti che
// confrontano misure sul file con misure sulla composizione sono nello stesso spazio.
// Misurati anche i LIVELLI DISTINTI della scritta dentro i tratti: 14 su 13.7 livelli, 21
// su 20.7, 26 su 25.7 -- circa uno per livello, quindi il bersaglio a 8 bit non perde
// nulla e use_hdr_2d non serve.

// Direzioni per i prelievi in cerchio (8 raggi).
const vec2 RAGGI[8] = vec2[8](
	vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
	vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

// Luminanza di un prelievo, in spazio percepito. La texture va passata come PARAMETRO: in
// Godot le variabili predefinite (TEXTURE, UV...) non sono accessibili dentro una funzione.
// Le UV vanno CLAMPATE: fuori bordo si leggerebbe nero e comparirebbe una cornice chiara.
float luma_at(sampler2D tex, vec2 uv, vec2 px) {
	vec3 t = texture(tex, clamp(uv, px * 0.5, vec2(1.0) - px * 0.5)).rgb;
	return pow(max(dot(t, vec3(0.299, 0.587, 0.114)), 0.0), 1.0 / 2.2);
}

void fragment() {
	// base = texture * modulate: vale sia per la foto (TEXTURE = immagine) sia per
	// il Label (TEXTURE = atlante del font, COLOR = colore del testo).
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec3 c = lin_to_srgb(base.rgb);

	// "Nitidezza": PASSA-BANDA alla larghezza dei tratti della scritta (~3-5 px di
	// composizione). E' l'unico controllo NON puntuale, quindi il solo che può separare la
	// scritta dal dettaglio della foto per DIMENSIONE invece che per intensita': tutti gli
	// altri cursori amplificano scritta e dettaglio nella stessa misura, e su una foto piena
	// di grana la scritta resterebbe sepolta a qualunque valore.
	// Differenza fra una sfocatura FINE (~1.2 px: spegne grana e gradino a 8 bit) e una
	// LARGA (~7 px: via la struttura della foto). Forma "piatta" (0.5 + banda): la forma a
	// maschera di contrasto taglierebbe una delle due polarita' dei tratti sui fondi
	// scuri o chiari.
	if (detail > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE;          // un pixel della COMPOSIZIONE, non dello schermo
		float fine = luma_at(TEXTURE, UV, px) * 0.5;
		for (int i = 0; i < 8; i += 2) {
			fine += luma_at(TEXTURE, UV + RAGGI[i] * px, px) * 0.125;
		}
		// TRE anelli e non due: con soli 3.5 e 7 px la sfocatura larga aveva peso ZERO fra
		// 1 e 3.5 px, cioe' un buco proprio dove stanno i tratti (larghi 2.2-2.5 px di
		// composizione -- misurati col font vero, il commento sopra diceva 3-5 px e
		// sbagliava), e la sua risposta in frequenza non era monotona. I pesi sono
		// r*exp(-r^2/2*sigma^2) con sigma ~4 px, normalizzati a 0.8 cosi' col 0.2 di "fine"
		// il totale fa 1. Il gemello su CPU di questo kernel sta in OSContent.bp_shader_at:
		// se si cambiano raggi o pesi qui, si cambiano ANCHE la'.
		float larga = fine * 0.2;
		for (int i = 0; i < 8; i++) {
			larga += luma_at(TEXTURE, UV + RAGGI[i] * 1.8 * px, px) * 0.02879
					+ luma_at(TEXTURE, UV + RAGGI[i] * 3.8 * px, px) * 0.04283
					+ luma_at(TEXTURE, UV + RAGGI[i] * 6.8 * px, px) * 0.02838;
		}
		float banda = (fine - larga) * (detail * 60.0);
		c = mix(c, vec3(0.5 + banda), smoothstep(0.0, 0.25, detail));
	}

	// livelli: rimappa [nero, bianco] -> [0, 1]
	c = (c - black_point) / max(white_point - black_point, 0.001);
	// luminosita'
	c += brightness;
	// contrasto attorno al grigio medio
	c = (c - 0.5) * contrast + 0.5;
	// saturazione attorno alla luminanza
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	COLOR = vec4(srgb_to_lin(clamp(c, vec3(0.0), vec3(1.0))), base.a);
}
