shader_type canvas_item;

// Il GUASTO della cartella segreta (17/10/2026). Uno shader suo, e non glitch.gdshader,
// perche' quello e' anche l'AVVISO del regista delle minacce (a tutto schermo, cresce col
// pericolo) e il jumpscare: se questo gli somigliasse, il giocatore non distinguerebbe
// piu' "c'e' qualcuno nel corridoio" da "la cartella fa paura". Qui niente neve e niente
// strappi a tutto schermo: guasti di un PC dell'epoca, e solo ATTORNO AL DIALOGO.
//
// Il rettangolo che porta lo shader e' il dialogo ALLARGATO di un margine (vedi
// SecretGlitch.MARGINE): serve spazio fuori dal dialogo per la scia. "pannello" dice
// dov'e' il dialogo dentro quel rettangolo. Tutto si legge dallo schermo SOTTO
// (hint_screen_texture) e lo si rimescola: un pixel mostra sempre un pixel vero del
// dialogo, preso dal posto sbagliato -- e' questo che lo fa sembrare un guasto e non un
// filtro.
//
// Cosa sa fare (le intensita' le pilota SecretGlitch, a raffiche):
//  - fondo:   righe sottili che saltano di qualche pixel, sempre e di rado (segnale
//             instabile: il dialogo non e' mai del tutto sano);
//  - strappo: bande di altezza IRREGOLARE (spesso sottili, a volte spesse) che scorrono
//             in orizzontale e si RIAVVOLGONO dentro il dialogo, come uno scarto nella
//             memoria video; con un filo di separazione dei colori;
//  - blocchi: tessere 16x16 corrotte -- copiate da un altro punto del dialogo, con la
//             tavolozza sbagliata, o piene di un colore a 16 colori;
//  - scia:    la "sala degli specchi" del Win95 bloccato: copie del dialogo a scalini,
//             fuori dal suo bordo, la piu' recente sopra;
//  - palette: tutto nella tavolozza rossa, a pochi livelli (il RIFIUTO).

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 dimensione = vec2(740.0, 644.0);              // pixel di questo rettangolo
uniform vec4 pannello = vec4(140.0, 140.0, 460.0, 364.0);  // il dialogo: x, y, larg, alt
uniform float fondo : hint_range(0.0, 4.0) = 1.0;
uniform float strappo : hint_range(0.0, 1.0) = 0.0;
uniform float blocchi : hint_range(0.0, 1.0) = 0.0;
uniform float scia : hint_range(0.0, 1.0) = 0.0;
uniform vec2 passo_scia = vec2(14.0, 9.0);                 // di quanto si sposta ogni copia
uniform float palette : hint_range(0.0, 1.0) = 0.0;
uniform float seme = 0.0;                                  // cambia a scatti durante la raffica

float caso(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

bool dentro(vec2 p, vec4 r) {
	return p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w;
}

void fragment() {
	vec2 qui = UV * dimensione;
	vec2 p = qui;
	bool colpito = dentro(p, pannello);

	// --- scia: fuori dal dialogo, la copia piu' recente che passa di qui ---
	if (!colpito && scia > 0.0) {
		float n = ceil(scia * 7.0);
		for (int k = 1; k <= 7; k++) {
			if (float(k) > n) {
				break;
			}
			vec2 q = qui - passo_scia * float(k);
			if (dentro(q, pannello)) {
				p = q;
				colpito = true;
				break;
			}
		}
	}

	if (!colpito) {
		COLOR = vec4(0.0);    // fuori dal dialogo e senza scia: lascia vedere sotto
	} else {
		vec2 rel = p - pannello.xy;
		float fot = floor(TIME * 30.0);
		float sep = 0.0;

		// --- fondo: una riga di 2 px che salta, di rado ---
		float riga = floor(rel.y / 2.0);
		if (caso(vec2(riga, fot)) > 1.0 - 0.0015 * fondo) {
			rel.x = mod(rel.x - (caso(vec2(riga, fot + 3.0)) - 0.5) * 16.0, pannello.z);
		}

		// --- strappo: in ogni cella di 36 righe, una banda di altezza a caso ---
		if (strappo > 0.0) {
			float cella = floor(rel.y / 36.0);
			float a = caso(vec2(cella, seme));
			float alto = mix(2.0, 36.0, a * a);
			float inizio = floor(caso(vec2(cella, seme + 3.1)) * (36.0 - alto));
			float y_in = rel.y - cella * 36.0;
			if (y_in >= inizio && y_in < inizio + alto
					&& caso(vec2(cella, seme + 7.7)) < strappo * 0.9) {
				float dx = (caso(vec2(cella, seme + 1.3)) - 0.5) * 180.0 * strappo;
				rel.x = mod(rel.x - dx, pannello.z);
				sep = 3.0;
			}
		}

		// --- blocchi 16x16 ---
		float tipo = -1.0;
		vec2 b = floor(rel / 16.0);
		if (blocchi > 0.0 && caso(b + seme) < blocchi * 0.28) {
			float t = caso(b + seme + 11.0);
			if (t < 0.5) {
				// la tessera sbagliata: viene da un altro punto del dialogo
				vec2 altro = floor(vec2(caso(b + seme + 2.0), caso(b + seme + 4.0))
						* pannello.zw / 16.0) * 16.0;
				rel = altro + mod(rel, 16.0);
			} else if (t < 0.85) {
				tipo = 1.0;
			} else {
				tipo = 2.0;
			}
		}

		vec2 src = pannello.xy + rel;
		vec2 off = (src - qui) * SCREEN_PIXEL_SIZE;
		vec2 s = vec2(sep, 0.0) * SCREEN_PIXEL_SIZE;
		vec3 col;
		col.r = texture(screen_tex, SCREEN_UV + off + s).r;
		col.g = texture(screen_tex, SCREEN_UV + off).g;
		col.b = texture(screen_tex, SCREEN_UV + off - s).b;

		if (tipo == 1.0) {
			// tavolozza sbagliata: canali scambiati e pochi livelli
			col = floor(col.brg * 3.0 + 0.5) / 3.0;
		} else if (tipo == 2.0) {
			// un colore pieno della tavolozza a 16 colori
			float c = caso(b + seme + 21.0);
			if (c < 0.25) {
				col = vec3(0.0, 0.5, 0.5);
			} else if (c < 0.5) {
				col = vec3(0.5, 0.0, 0.5);
			} else if (c < 0.75) {
				col = vec3(0.5, 0.0, 0.0);
			} else {
				col = vec3(0.0);
			}
		}

		// --- tavolozza rossa: il rifiuto ---
		// rosso SCURO: col bianco dei campi a l*1.1 il rosso saturava e veniva rosa
		// salmone (visto nel provino), che non fa paura; cosi' il bianco va a sangue
		// e il nero del testo resta nero, quindi i codici si leggono ancora
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 rosso = floor(vec3(l * 0.78, l * 0.05, l * 0.04) * 5.0 + 0.5) / 5.0;
		col = mix(col, rosso, palette);

		COLOR = vec4(col, 1.0);
	}
}
