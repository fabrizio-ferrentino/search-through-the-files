class_name Midi
extends RefCounted

# ============================================================
# Lettore di file MIDI (Standard MIDI File, tipo 0 e 1) per la musica delle pagine
# web: <bgsound src="tema.mid">. Godot non suona i MIDI, quindi qui il file diventa
# una lista di NOTE in secondi, e MidiSynth le trasforma in suono.
# Modulo puro (nessun nodo): i test lo provano headless (tests/midi_test.gd).
#
# Si tiene solo cio' che serve a una melodia d'epoca: note (on/off, velocity),
# cambi di strumento (program change) e cambi di tempo. Il canale 10 (indice 9)
# e' la batteria, come nel General MIDI.
# ============================================================

const CANALE_BATTERIA := 9

# Legge un file .mid. Restituisce {"note": [...], "durata": secondi} oppure {} se
# il file non e' un MIDI leggibile. Ogni nota: {t, d, nota, vel (0..1), can, prog},
# ordinate per tempo d'inizio.
static func leggi(dati: PackedByteArray) -> Dictionary:
	if dati.size() < 14 or dati.slice(0, 4).get_string_from_ascii() != "MThd":
		return {}
	var lun_testa := _u32(dati, 4)
	var tracce := _u16(dati, 10)
	var divisione := _u16(dati, 12)
	if divisione & 0x8000 or divisione == 0:
		return {}                                    # tempo SMPTE: mai usato nelle pagine
	var i := 8 + lun_testa
	# tutti gli eventi di tutte le tracce, in tick assoluti: [tick, ordine, tipo, a, b, c]
	var eventi: Array = []
	var ordine := 0
	for _k in range(tracce):
		if i + 8 > dati.size() or dati.slice(i, i + 4).get_string_from_ascii() != "MTrk":
			break
		var lun := _u32(dati, i + 4)
		var fine := mini(i + 8 + lun, dati.size())
		var j := i + 8
		var tick := 0
		var stato := 0
		while j < fine:
			var vl := _varlen(dati, j)
			tick += vl[0]
			j = vl[1]
			if j >= fine:
				break
			var b := dati[j]
			if b == 0xFF:                            # meta evento
				var tipo := dati[j + 1]
				var ml := _varlen(dati, j + 2)
				var da: int = ml[1]
				if tipo == 0x51 and ml[0] == 3:
					var usq := (dati[da] << 16) | (dati[da + 1] << 8) | dati[da + 2]
					eventi.append([tick, ordine, "tempo", usq, 0, 0])
				elif tipo == 0x2F:
					break
				j = da + int(ml[0])
				ordine += 1
				continue
			if b == 0xF0 or b == 0xF7:                # sysex: si salta
				var sl := _varlen(dati, j + 1)
				j = int(sl[1]) + int(sl[0])
				continue
			if b & 0x80:
				stato = b
				j += 1
			# altrimenti "running status": vale l'ultimo stato
			var cmd := stato & 0xF0
			var can := stato & 0x0F
			match cmd:
				0x80, 0x90:
					var nota := dati[j]
					var vel := dati[j + 1]
					j += 2
					var acceso := cmd == 0x90 and vel > 0
					eventi.append([tick, ordine, "on" if acceso else "off", can, nota, vel])
				0xC0:
					eventi.append([tick, ordine, "prog", can, dati[j], 0])
					j += 1
				0xD0:
					j += 1
				0xA0, 0xB0, 0xE0:
					j += 2
				_:
					break                            # byte senza senso: traccia finita
			ordine += 1
		i += 8 + lun
	eventi.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	# dai tick ai secondi, seguendo i cambi di tempo
	var usq_corrente := 500000.0                    # 120 bpm se il file non dice niente
	var tick_prec := 0
	var sec := 0.0
	var prog := PackedInt32Array()
	prog.resize(16)
	prog.fill(0)
	var aperte: Dictionary = {}                      # (can*128+nota) -> indice in note
	var note: Array = []
	for e in eventi:
		var t: int = e[0]
		sec += float(t - tick_prec) * usq_corrente / 1000000.0 / float(divisione)
		tick_prec = t
		match str(e[2]):
			"tempo":
				usq_corrente = float(e[3])
			"prog":
				prog[int(e[3])] = int(e[4])
			"on":
				var chiave: int = int(e[3]) * 128 + int(e[4])
				_chiudi(note, aperte, chiave, sec)
				aperte[chiave] = note.size()
				note.append({"t": sec, "d": 0.0, "nota": int(e[4]), "vel": float(e[5]) / 127.0,
						"can": int(e[3]), "prog": prog[int(e[3])]})
			"off":
				_chiudi(note, aperte, int(e[3]) * 128 + int(e[4]), sec)
	for chiave in aperte.keys():
		_chiudi(note, aperte, int(chiave), sec)
	var durata := sec
	for n in note:
		durata = maxf(durata, float(n["t"]) + float(n["d"]))
	return {"note": note, "durata": durata}

static func _chiudi(note: Array, aperte: Dictionary, chiave: int, sec: float) -> void:
	if not aperte.has(chiave):
		return
	var n: Dictionary = note[int(aperte[chiave])]
	n["d"] = maxf(0.02, sec - float(n["t"]))
	aperte.erase(chiave)

# Numero a lunghezza variabile: [valore, indice dopo].
static func _varlen(d: PackedByteArray, i: int) -> Array:
	var v := 0
	for _k in range(4):
		if i >= d.size():
			break
		var b := d[i]
		i += 1
		v = (v << 7) | (b & 0x7F)
		if not (b & 0x80):
			break
	return [v, i]

static func _u16(d: PackedByteArray, i: int) -> int:
	return (d[i] << 8) | d[i + 1]

static func _u32(d: PackedByteArray, i: int) -> int:
	return (d[i] << 24) | (d[i + 1] << 16) | (d[i + 2] << 8) | d[i + 3]
