class_name MidiSynth
extends RefCounted

# ============================================================
# Il "sintetizzatore della scheda audio" che suona i MIDI delle pagine: le note di
# Midi.leggi diventano un AudioStreamWAV (PCM 16 bit mono). Il timbro e' quello
# economico delle schede del 1997 -- onde quadre, triangoli, denti di sega con un
# inviluppo semplice, batteria fatta di rumore -- perche' e' cosi' che il web di
# allora suonava sugli altoparlanti di plastica di un PC di casa.
#
# La canzone si "registra" tutta in una volta (render) invece di essere generata
# fotogramma per fotogramma: costa un paio di secondi di calcolo, che il browser fa
# in un thread (WorkerThreadPool) mentre la pagina arriva -- come il MIDI d'epoca,
# che partiva sempre un attimo dopo la pagina. Il risultato resta in cache: tornando
# sulla pagina la musica riparte subito.
# ============================================================

const FREQ := 22050                 # mono 22 kHz: la qualita' "radio" di allora
const VOCE := 0.16                  # volume di una voce a velocity piena
const RILASCIO := 0.12              # coda della nota dopo il note-off (s)
const DURATA_MAX := 120.0           # oltre si tronca: nessuna pagina ne ha bisogno

static var _pcm: Dictionary = {}    # percorso -> PackedByteArray (vuoto = file illeggibile)
static var _lavori: Dictionary = {} # percorso -> id del lavoro in WorkerThreadPool

# Fa preparare la canzone in un thread, se non c'e' gia' (o non e' gia' in lavorazione).
# Chi aspetta guarda pronto(): nessun callback verso nodi che intanto possono sparire.
static func prepara(path: String) -> void:
	if _pcm.has(path) or _lavori.has(path):
		return
	_lavori[path] = WorkerThreadPool.add_task(_rendi.bind(path), false, "midi")

# Vero quando il render e' finito (anche se il file si e' rivelato illeggibile).
static func pronto(path: String) -> bool:
	return _pcm.has(path)

# Il suono di un file gia' renderizzato; null se non e' pronto o non e' un MIDI.
static func stream_in_cache(path: String, loop: bool) -> AudioStreamWAV:
	var pcm: PackedByteArray = _pcm.get(path, PackedByteArray())
	if pcm.is_empty():
		return null
	return stream_da_pcm(pcm, loop)

# Render sincrono, con cache (i test; e il thread lo usa per fare il lavoro).
static func stream_da_file(path: String, loop: bool) -> AudioStreamWAV:
	if not _pcm.has(path):
		_pcm[path] = pcm_da_file(path)
	return stream_in_cache(path, loop)

# Legge e renderizza un .mid (lento). PackedByteArray vuoto se il file non si legge.
static func pcm_da_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var canzone := Midi.leggi(FileAccess.get_file_as_bytes(path))
	if canzone.is_empty():
		return PackedByteArray()
	return a_pcm16(render(canzone))

# Nel thread: il lavoro lento, poi la consegna sul thread principale (la cache non si
# tocca da due thread).
static func _rendi(path: String) -> void:
	var pcm := pcm_da_file(path)
	_consegna.call_deferred(path, pcm)

static func _consegna(path: String, pcm: PackedByteArray) -> void:
	if _lavori.has(path):
		WorkerThreadPool.wait_for_task_completion(int(_lavori[path]))
		_lavori.erase(path)
	_pcm[path] = pcm

static func stream_da_pcm(pcm: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = FREQ
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = pcm.size() / 2
	return s

# ---------------- render ----------------

# Tutta la canzone in campioni (-1..1). Ogni nota si somma nel buffer per la sua
# durata piu' il rilascio; poi un filtro passa-basso leggero ammorbidisce le onde
# quadre (gli altoparlanti di allora non arrivavano agli acuti) e si limita.
static func render(canzone: Dictionary) -> PackedFloat32Array:
	var durata: float = minf(float(canzone.get("durata", 0.0)), DURATA_MAX)
	var n := int(ceilf((durata + RILASCIO) * FREQ)) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	var rumore := RandomNumberGenerator.new()
	rumore.seed = 1999                              # la batteria suona uguale ogni volta
	for nota in canzone.get("note", []):
		var t0 := int(float(nota["t"]) * FREQ)
		if t0 >= n:
			continue
		if int(nota["can"]) == Midi.CANALE_BATTERIA:
			_batteria(buf, t0, int(nota["nota"]), float(nota["vel"]), rumore)
		else:
			_tono(buf, t0, float(nota["d"]), int(nota["nota"]), float(nota["vel"]), int(nota["prog"]))
	# passa-basso a un polo + limitatore morbido
	var y := 0.0
	for k in range(n):
		y += 0.45 * (buf[k] - y)
		buf[k] = clampf(y * (1.5 - 0.5 * y * y) if absf(y) < 1.0 else signf(y), -1.0, 1.0)
	return buf

# Le famiglie General MIDI (program / 8) -> onda e inviluppo.
# onda: 0 quadra, 1 triangolo, 2 dente di sega, 3 seno, 4 impulso stretto
static func _timbro(prog: int) -> Dictionary:
	match prog / 8:
		0: return {"onda": 4, "a": 0.005, "dec": 0.6, "sus": 0.25}     # pianoforti
		1: return {"onda": 3, "a": 0.002, "dec": 0.35, "sus": 0.0}     # campanelli
		2: return {"onda": 0, "a": 0.01, "dec": 0.1, "sus": 0.8}       # organi
		3: return {"onda": 1, "a": 0.003, "dec": 0.4, "sus": 0.15}     # chitarre
		4: return {"onda": 1, "a": 0.005, "dec": 0.2, "sus": 0.7}      # bassi
		5, 6: return {"onda": 2, "a": 0.08, "dec": 0.3, "sus": 0.7}    # archi, cori
		7: return {"onda": 2, "a": 0.03, "dec": 0.2, "sus": 0.75}      # ottoni
		8, 9: return {"onda": 0, "a": 0.03, "dec": 0.2, "sus": 0.7}    # ance, flauti
		10: return {"onda": 0, "a": 0.005, "dec": 0.1, "sus": 0.8}     # synth lead
		11: return {"onda": 1, "a": 0.4, "dec": 0.5, "sus": 0.8}       # pad
	return {"onda": 1, "a": 0.01, "dec": 0.3, "sus": 0.5}

static func _tono(buf: PackedFloat32Array, t0: int, dur: float, nota: int, vel: float, prog: int) -> void:
	var tb := _timbro(prog)
	var onda: int = tb["onda"]
	var att: float = tb["a"]
	var dec: float = tb["dec"]
	var sus: float = tb["sus"]
	var f := 440.0 * pow(2.0, float(nota - 69) / 12.0)
	var passo := f / float(FREQ)
	var amp := VOCE * vel
	# i bassi suonano piu' forte, gli acuti piu' piano: altrimenti le quadre fischiano
	if nota < 48:
		amp *= 1.3
	elif nota > 84:
		amp *= 0.6
	var fine_nota := int(dur * FREQ)
	var lung := mini(fine_nota + int(RILASCIO * FREQ), buf.size() - t0)
	var fase := 0.0
	var livello_rilascio := 0.0
	for k in range(lung):
		var t := float(k) / FREQ
		var env := 0.0
		if k < fine_nota:
			if t < att:
				env = t / att
			else:
				env = sus + (1.0 - sus) * exp(-(t - att) / maxf(dec, 0.001))
			livello_rilascio = env
		else:
			env = livello_rilascio * (1.0 - float(k - fine_nota) / (RILASCIO * FREQ))
		var s := 0.0
		match onda:
			0: s = 1.0 if fase < 0.5 else -1.0
			1: s = 4.0 * absf(fase - 0.5) - 1.0
			2: s = 2.0 * fase - 1.0
			3: s = sin(fase * TAU)
			4: s = 1.0 if fase < 0.25 else -0.6
		buf[t0 + k] += s * env * amp
		fase += passo
		if fase >= 1.0:
			fase -= 1.0

# Batteria General MIDI, approssimata: cassa = seno che scende, rullante = rumore
# piu' un tono, piatti e charleston = rumore con code di lunghezze diverse.
static func _batteria(buf: PackedFloat32Array, t0: int, nota: int, vel: float, rng: RandomNumberGenerator) -> void:
	var amp := VOCE * vel * 1.4
	var dur := 0.08
	var tipo := "hat"
	match nota:
		35, 36:
			tipo = "cassa"
			dur = 0.18
		38, 40, 37, 39:
			tipo = "rullante"
			dur = 0.16
		42, 44:
			dur = 0.05
		46:
			dur = 0.25
		49, 57, 51, 59, 52, 55:
			tipo = "piatto"
			dur = 0.8
		41, 43, 45, 47, 48, 50:
			tipo = "tom"
			dur = 0.2
	var lung := mini(int(dur * FREQ), buf.size() - t0)
	var fase := 0.0
	for k in range(lung):
		var t := float(k) / FREQ
		var env := exp(-t / (dur * 0.3))
		var s := 0.0
		match tipo:
			"cassa":
				fase += (150.0 * exp(-t * 25.0) + 45.0) / FREQ
				s = sin(fase * TAU) * 1.4
			"tom":
				fase += (220.0 - float(50 - nota) * 12.0) * (1.0 - t * 2.0) / FREQ
				s = sin(fase * TAU)
			"rullante":
				fase += 190.0 / FREQ
				s = rng.randf_range(-1.0, 1.0) * 0.7 + sin(fase * TAU) * 0.4
			"piatto":
				s = rng.randf_range(-1.0, 1.0) * 0.5
			_:
				s = rng.randf_range(-1.0, 1.0) * 0.45
		buf[t0 + k] += s * env * amp

# Campioni -1..1 -> PCM 16 bit little-endian (il formato di AudioStreamWAV).
static func a_pcm16(buf: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	for k in range(buf.size()):
		out.encode_s16(k * 2, int(clampf(buf[k], -1.0, 1.0) * 32000.0))
	return out
