extends SceneTree

# Il riepilogo di fine partita (proprietario, 25/11/2026: "mostrare seed e tempo a fine
# partita e statistiche varie"). Controlla che:
#   1 riepilogo() porti il seme, il tempo in m:ss e ogni statistica contata;
#   2 una partita nuova azzeri statistiche e tempo;
#   3 ogni voce esista tradotta in tutte e due le lingue.
#   & $godot --headless --path $proj -s res://tests/statistiche_test.gd

var _fails: Array = []

func _initialize() -> void:
	var gm = root.get_node("GameManager")
	gm.start_new_run(1234)
	gm.tempo_partita = 125.4
	gm.conta("jester")
	gm.conta("jester")
	gm.conta("pagine")
	var r: String = gm.riepilogo()
	var righe := r.split("\n")
	var jester := TranslationServer.translate("STATS_JESTER") % 2
	var pagine := TranslationServer.translate("STATS_PAGES") % 1
	_check("RIEPILOGO", righe[0].contains("1234") and righe[1].contains("2:05")
			and jester in righe and pagine in righe and righe.size() == 2 + gm.STATISTICHE.size(), r)
	gm.start_new_run(99)
	_check("AZZERA", gm.statistiche.is_empty() and gm.tempo_partita == 0.0, str(gm.statistiche))
	var mancano: Array = []
	for k in ["STATS_SEED", "STATS_TIME"] + gm.STATISTICHE.map(func(x): return str(x[1])):
		var en := TranslationServer.get_translation_object("en").get_message(k)
		var it := TranslationServer.get_translation_object("it").get_message(k)
		if en == "" or it == "" or en == it:
			mancano.append(k)
	_check("LINGUE", mancano.is_empty(), str(mancano))
	gm.finish_run()
	if _fails.is_empty():
		print("RISULTATO: PASS (il riepilogo di fine partita e' giusto)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)

func _check(nome: String, ok: bool, perche: String) -> void:
	print(("  ok  " if ok else "  NO  ") + nome + ("" if ok else ": " + perche))
	if not ok:
		_fails.append(nome)
