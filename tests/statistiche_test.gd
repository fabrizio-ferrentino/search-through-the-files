extends SceneTree

# Il riepilogo di fine partita (proprietario, 25/11/2026: "mostrare seed e tempo a fine
# partita e statistiche varie"). Controlla che:
#   1 riepilogo() porti il tempo in m:ss, le chiavi trovate (solo da morto) e ogni statistica,
#     senza il seme e senza i nomi dei nemici (26/11/2026);
#   2 scopri_in() segni trovata solo la chiave che compare scritta per intero;
#   3 il pulsante del seme mostri il seme e, cliccato, dica che e' copiato;
#   4 una partita nuova azzeri statistiche, chiavi trovate e tempo;
#   5 ogni voce esista tradotta in tutte e due le lingue.
#   & $godot --headless --path $proj -s res://tests/statistiche_test.gd

var _fails: Array = []

func _initialize() -> void:
	var gm = root.get_node("GameManager")
	gm.start_new_run(1234)
	gm.tempo_partita = 125.4
	gm.conta("evitate")
	gm.conta("evitate")
	gm.conta("pagine")
	gm.scopri_in("bla %s bla" % gm.key_label(2))
	gm.scopri_in("bla %s bla" % gm.key_code(3))          # il codice nudo, senza "3-": non basta
	var r: String = gm.riepilogo()
	var righe := r.split("
")
	var evitate := TranslationServer.translate("STATS_AVOIDED") % 2
	var pagine := TranslationServer.translate("STATS_PAGES") % 1
	var chiavi := TranslationServer.translate("STATS_KEYS") % [1, 4]
	_check("RIEPILOGO", righe[0].contains("2:05") and chiavi in righe and evitate in righe
			and pagine in righe and righe.size() == 2 + gm.STATISTICHE.size()
			and not r.contains("1234"), r)
	_check("TROVATE", gm.chiavi_trovate.keys() == [2], str(gm.chiavi_trovate))
	var rv: String = gm.riepilogo(true)
	_check("VITTORIA_SENZA_CHIAVI", not chiavi in rv.split("
")
			and rv.split("
").size() == 1 + gm.STATISTICHE.size(), rv)
	var b: Button = gm.pulsante_seme()
	var prima := b.text
	b.pressed.emit()
	_check("SEME", prima.contains("1234") and b.text.contains("1234") and b.text != prima,
			"%s -> %s" % [prima, b.text])
	b.free()
	gm.start_new_run(99)
	_check("AZZERA", gm.statistiche.is_empty() and gm.chiavi_trovate.is_empty()
			and gm.tempo_partita == 0.0, str(gm.statistiche))
	var mancano: Array = []
	for k in ["STATS_SEED", "STATS_SEED_COPIED", "STATS_TIME", "STATS_KEYS"] + gm.STATISTICHE.map(func(x): return str(x[1])):
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
