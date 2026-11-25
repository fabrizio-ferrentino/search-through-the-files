extends Node

# Il seme scelto nel menu (proprietario, 25/11/2026: "settare dei seed, cosi da rigiocare
# la stessa partita"). Controlla che:
#   1 "Avvia" apra la scelta (partita a caso / col seme); il campo accetti solo cifre e
#     "Gioca" resti spento senza un seme valido (vuoto, 0, fuori misura);
#   2 lo stesso seme ridia la STESSA partita (chiavi, siti, disco) e un altro seme no;
#   3 "Gioca" faccia partire la partita col seme scritto.
#   & $godot --headless --path $proj res://tests/seme_menu_test.tscn

var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	# Avvia apre la scelta, non parte subito
	menu._on_start_pressed()
	await get_tree().process_frame
	var scelta: NuovaPartitaScreen = menu.nuova
	_check("AVVIA_APRE_LA_SCELTA", scelta != null and is_instance_valid(scelta) and menu.button_type == null,
			"schermata %s, partenza %s" % [str(scelta), str(menu.button_type)])
	var campo: LineEdit = scelta.campo
	var spento_vuoto: bool = scelta.gioca_seme.disabled
	campo.text = "12a3-4 5"
	campo.text_changed.emit(campo.text)
	var pulito := campo.text
	var scelto: int = scelta.seme_scritto()
	var acceso: bool = not scelta.gioca_seme.disabled
	campo.text = "0"
	var zero: int = scelta.seme_scritto()
	campo.text = "9999999999"
	var troppo: int = scelta.seme_scritto()
	_check("CAMPO_SOLO_CIFRE", pulito == "12345" and scelto == 12345 and zero == 0 and troppo == 0
			and spento_vuoto and acceso, "'%s' -> %d, zero %d, troppo %d, Gioca spento a vuoto %s, acceso %s"
			% [pulito, scelto, zero, troppo, str(spento_vuoto), str(acceso)])

	var a := _partita(4242)
	var b := _partita(4242)
	var c := _partita(4243)
	_check("STESSO_SEME_STESSA_PARTITA", a == b and a != c, "%s / %s / %s" % [a, b, c])

	campo.text = "777"
	campo.text_changed.emit(campo.text)
	scelta.gioca_seme.pressed.emit()
	_check("AVVIA_USA_IL_SEME", GameManager.run_seed == 777, "seme della partita %d" % GameManager.run_seed)
	GameManager.finish_run()

	if _fails.is_empty():
		print("RISULTATO: PASS (il seme scelto ridà la stessa partita)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Quello che rende una partita quella: le chiavi, i siti della serata, il disco.
func _partita(seme: int) -> String:
	GameManager.start_new_run(seme)
	return "%s|%s|%s" % [str(GameManager.keys), str(WebRuntime.sites()), JSON.stringify(_nomi(VFS.get_root()))]

func _nomi(n: Dictionary) -> Array:
	var out: Array = [str(n.get("name", ""))]
	for c in n.get("children", []):
		if c is Dictionary:
			out.append_array(_nomi(c))
	return out

func _check(nome: String, ok: bool, perche: String) -> void:
	print(("  ok  " if ok else "  NO  ") + nome + ("" if ok else ": " + perche))
	if not ok:
		_fails.append(nome)
