extends SceneTree

# Test unitario (headless) del lettore MIDI (scripts/os/midi.gd) e del sintetizzatore
# (scripts/os/midi_synth.gd): un MIDI costruito qui byte per byte (tempi noti) e le
# melodie vere di web/audio/ (generate da tools/web/media.py).
#   & $godot --headless --path $proj -s res://tests/midi_test.gd

const AUDIO := "res://web/audio/"

var _fails: Array = []

func _initialize() -> void:
	# 1. un MIDI fatto a mano: 96 tick per quarto, 120 bpm, poi il tempo raddoppia.
	# Nota 60 da 0 a 96 (0.5 s), cambio di tempo a 96 (0.25 s al quarto), nota 64
	# da 96 a 192 in RUNNING STATUS (0.25 s), nota di batteria sul canale 10.
	var trk := PackedByteArray()
	trk.append_array([0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20])     # 500000 us
	trk.append_array([0x00, 0xC0, 0x50])                             # program 80
	trk.append_array([0x00, 0x90, 60, 100])
	trk.append_array([0x60, 0x80, 60, 0])
	trk.append_array([0x00, 0xFF, 0x51, 0x03, 0x03, 0xD0, 0x90])     # 250000 us
	trk.append_array([0x00, 0x90, 64, 80])
	trk.append_array([0x60, 64, 0])                                  # running status, vel 0 = off
	trk.append_array([0x00, 0x99, 42, 127, 0x10, 0x89, 42, 0])     # charleston, 16 tick
	trk.append_array([0x00, 0xFF, 0x2F, 0x00])
	var mid := "MThd".to_ascii_buffer()
	mid.append_array([0, 0, 0, 6, 0, 0, 0, 1, 0, 96])
	mid.append_array("MTrk".to_ascii_buffer())
	mid.append_array([0, 0, (trk.size() >> 8) & 0xFF, trk.size() & 0xFF])
	mid.append_array(trk)
	var s := Midi.leggi(mid)
	var note: Array = s.get("note", [])
	_si("note_3", note.size() == 3, str(note))
	if note.size() == 3:
		_vicino("nota1_t", note[0]["t"], 0.0)
		_vicino("nota1_d", note[0]["d"], 0.5)
		_si("nota1_prog", int(note[0]["prog"]) == 80, str(note[0]))
		_vicino("nota2_t", note[1]["t"], 0.5)
		_vicino("nota2_d", note[1]["d"], 0.25)       # col tempo nuovo
		_si("nota2_running", int(note[1]["nota"]) == 64, str(note[1]))
		_si("batteria", int(note[2]["can"]) == Midi.CANALE_BATTERIA, str(note[2]))
	_vicino("durata", s.get("durata", 0.0), 0.75 + 16.0 / 96.0 * 0.25)
	_si("non_midi", Midi.leggi("non sono un midi".to_utf8_buffer()).is_empty(), "")
	_si("troncato_non_esplode", Midi.leggi(mid.slice(0, 30)) is Dictionary, "")

	# 2. le melodie vere: si leggono, durano il giusto, suonano
	var jack := Midi.leggi(FileAccess.get_file_as_bytes(AUDIO + "jack.mid"))
	_si("jack_note", (jack.get("note", []) as Array).size() == 236, str((jack.get("note", []) as Array).size()))
	# 8 battute da 4 quarti a 126 bpm
	_vicino("jack_durata", jack.get("durata", 0.0), 32.0 * 60.0 / 126.0, 0.05)
	for f in DirAccess.get_files_at(AUDIO):
		if f.get_extension() == "mid":
			_si("legge_" + f, not Midi.leggi(FileAccess.get_file_as_bytes(AUDIO + f)).is_empty(), "")

	# 3. il render: suono vero (non silenzio), nei limiti, della lunghezza giusta
	var buf := MidiSynth.render(s)
	_si("render_lungo", buf.size() >= int(0.75 * MidiSynth.FREQ), str(buf.size()))
	var picco := 0.0
	var energia := 0.0
	for x in buf:
		picco = maxf(picco, absf(x))
		energia += x * x
	_si("render_suona", sqrt(energia / buf.size()) > 0.01, "rms %f" % sqrt(energia / buf.size()))
	_si("render_limitato", picco <= 1.0, "picco %f" % picco)
	# dopo l'ultima nota e il suo rilascio: silenzio
	_si("render_coda_muta", absf(buf[buf.size() - 1]) < 0.01, str(buf[buf.size() - 1]))

	# 4. lo stream: PCM 16 bit, in loop se richiesto, in cache
	var st := MidiSynth.stream_da_file(AUDIO + "valzer.mid", true)
	_si("stream", st != null and st.format == AudioStreamWAV.FORMAT_16_BITS, str(st))
	if st != null:
		_si("stream_loop", st.loop_mode == AudioStreamWAV.LOOP_FORWARD and st.loop_end == st.data.size() / 2, "")
	_si("in_cache", MidiSynth.pronto(AUDIO + "valzer.mid"), "")
	_si("stream_no_loop", MidiSynth.stream_in_cache(AUDIO + "valzer.mid", false).loop_mode == AudioStreamWAV.LOOP_DISABLED, "")
	_si("file_mancante", MidiSynth.stream_da_file(AUDIO + "non_ce.mid", false) == null, "")

	if _fails.is_empty():
		print("RISULTATO: PASS (tutti i test superati)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)

func _si(nome: String, cond: bool, info: String) -> void:
	if cond:
		print("PASS  " + nome)
	else:
		print("FAIL  %s  %s" % [nome, info])
		_fails.append(nome)

func _vicino(nome: String, got, want: float, tol := 0.001) -> void:
	_si(nome, absf(float(got) - want) <= tol, "atteso %f, ottenuto %s" % [want, got])
