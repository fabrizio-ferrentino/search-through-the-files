shader_type canvas_item;

// CRT PIATTO: niente curvatura, per scelta. La curvatura SPOSTA i pixel, e il mouse
// (player.gd lo inoltra all'OS in linea retta) non cadrebbe piu' dove lo si vede.
// Tutto quello che c'e' qui sotto cambia la LUCE di un pixel, mai la sua posizione:
// anche gli angoli arrotondati e l'ombra del bordo scuriscono, non deformano.
//
// DUE UNITA' DI MISURA, ed e' il motivo della riscrittura (17/10/2026):
//  - cio' che sta SUL VETRO (scanline, maschera dei fosfori) si conta in pixel VERI
//    dello schermo (FRAGCOORD), a periodo INTERO. Prima le scanline si contavano in
//    pixel dell'OS (uv.y * 1080), ma l'OS non arriva mai 1:1 sullo schermo: nella
//    finestra di default (1280x720) il periodo voluto era 1,33 pixel e quello disegnato
//    4 -- 180 righe grosse invece di 540 sottili -- e a 1886x1061 (finestra
//    ingrandita) l'escursione riga per riga oscillava fra 0,005 e 0,085: bande di
//    moire' che scorrono, cioe' scanline che spariscono e ricompaiono a strisce.
//    Misurato con tests/crt_look_check.tscn. La maschera era gia' fatta cosi'.
//  - cio' che sta NELL'IMMAGINE (convergenza, angoli, ombra del bordo) si conta
//    in pixel dell'OS (screen_size), cosi' resta uguale a qualunque risoluzione.
//
// Solo cose che un monitor VGA dell'epoca aveva davvero. Niente rumore, niente banda
// che scorre: quelli sono del televisore e della telecamera, e un'immagine che si muove
// da sola renderebbe anche inaffidabili i confronti fra due fotogrammi dei test.
//
// NIENTE ALONE (halation), provato e misurato il 17/10/2026: il chiaro che sborda
// dentro il testo scuro alzava il nero delle lettere su fondo bianco da 0,195 a 0,260
// (contrasto 0,792 -> 0,740 a 1280x720). E' fisicamente giusto, ma colpisce proprio
// il testo nero su bianco del Blocco note e delle pagine web, cioe' dove si leggono le
// chiavi; e a un valore abbastanza basso da non costare leggibilita' non si vedeva.
// Stessa sorte per la CONVERGENZA CHE CRESCE VERSO I BORDI: rosso e blu spostati di
// ~1 px negli angoli sporcano le lettere scure proprio dove stanno menu e barre del
// titolo (menu nero su grigio 0,589 -> 0,572; spenta torna 0,610). Resta quella
// uniforme, mezzo pixel ovunque, che c'era gia'.

// --- scanline (sul vetro) ---
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.30;
// quante righe "del tubo" sullo schermo: il periodo in pixel veri e' altezza/righe
// arrotondato a un INTERO (mai sotto 2), ed e' l'intero che impedisce il moire'
uniform float scanline_righe : hint_range(120.0, 720.0) = 360.0;
// sul chiaro il fascio si allarga e riempie lo spazio fra le righe, come sul tubo
// vero: le pagine bianche restano piene e il testo nero sopra non viene rigato
uniform float scanline_chiaro : hint_range(0.0, 1.0) = 0.6;

// --- maschera dei fosfori RGB (sul vetro) ---
uniform float mask_strength : hint_range(0.0, 1.0) = 0.12;

// --- convergenza: i tre fasci non coincidono del tutto ---
uniform float aberration : hint_range(0.0, 4.0) = 0.5;     // in pixel dell'OS

// --- il tubo e la cornice ---
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.20;
uniform float angolo_raggio : hint_range(0.0, 60.0) = 18.0;  // in pixel dell'OS
uniform float bordo_ombra : hint_range(0.0, 40.0) = 10.0;    // in pixel dell'OS

uniform float brightness : hint_range(0.5, 2.0) = 1.22;
uniform vec2 screen_size = vec2(1440.0, 1080.0);

void fragment() {
	vec2 uv = UV;
	vec2 d = uv - 0.5;
	vec2 px = 1.0 / screen_size;

	// --- convergenza ---
	vec2 ab = vec2(aberration, 0.0) * px;
	vec3 col;
	col.r = texture(TEXTURE, uv + ab).r;
	col.g = texture(TEXTURE, uv).g;
	col.b = texture(TEXTURE, uv - ab).b;

	// --- scanline: un fascio gaussiano per riga del tubo, periodo intero in pixel veri ---
	float alto = 1.0 / SCREEN_PIXEL_SIZE.y;
	float periodo = max(2.0, floor(alto / scanline_righe + 0.5));
	float riga = mod(floor(FRAGCOORD.y), periodo);
	// centro del fascio spostato di mezzo pixel in su: con periodo 2 le due righe
	// sarebbero simmetriche rispetto al centro e uscirebbero uguali (niente riga)
	float dc = riga - (periodo - 2.0) * 0.5;
	float sigma = periodo * 0.3;
	float fascio = exp(-dc * dc / (2.0 * sigma * sigma));
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(1.0, fascio, scanline_strength * (1.0 - scanline_chiaro * luma));

	// --- maschera fosfori RGB (aperture grille) sui pixel reali: niente moire' ---
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

	// --- vignettatura: il tubo e' piu' debole verso i bordi ---
	float vig = 1.0 - vignette_strength * dot(d, d) * 2.0;
	col *= clamp(vig, 0.0, 1.0);

	col *= brightness;

	// --- la cornice: angoli arrotondati e l'ombra dove il vetro entra nel mobile ---
	// distanza (in pixel dell'OS) dal bordo di un rettangolo dagli angoli tondi: < 0 dentro
	vec2 p = uv * screen_size;
	vec2 meta = screen_size * 0.5;
	vec2 q = abs(p - meta) - (meta - vec2(angolo_raggio));
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - angolo_raggio;
	float dentro = clamp(0.5 - sd, 0.0, 1.0);    // un pixel di antialias sull'arco
	float ombra = mix(0.55, 1.0, smoothstep(0.0, max(bordo_ombra, 0.001), -sd));
	col *= dentro * ombra;

	COLOR = vec4(col, 1.0);
}
