extends Node2D

var button_type = null

var opzioni: OptionsScreen = null    # la schermata Opzioni, se aperta

func _ready() -> void:
	GameManager.applica_video_salvato()   # schermo intero / V-Sync / finestra scelti nelle Opzioni
	_etichette()

# I tre pulsanti del menu sono scritti nella SCENA (li ha messi il proprietario in
# editor): le etichette si assegnano qui, da locale/ui.csv, cosi' la scena non va
# toccata e il menu segue la lingua come il resto del gioco. Il titolo no: il nome
# del gioco non si traduce. Si richiama dopo un cambio di lingua nelle Opzioni,
# altrimenti i pulsanti resterebbero nella lingua di prima finche' non si riapre il menu.
func _etichette() -> void:
	$button_manager/Start.text = tr("UI_START")
	$button_manager/Option.text = tr("UI_OPTIONS")
	$button_manager/Quit.text = tr("UI_QUIT")

func _on_start_pressed() -> void:
	if _in_partenza():
		return                        # un secondo clic rifarebbe il run (seme e disco nuovi)
	button_type = "start"
	_blocca_pulsanti()
	GameManager.start_new_run()   # nuovo run: seme, stato PC azzerato e filesystem fresco
	$Fade_transition.show()
	$Fade_transition/fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")

# IMPOSTAZIONI: apre la schermata (scripts/options_screen.gd): lingua, video e, da li',
# i riconoscimenti. Prima questo pulsante era disabilitato nella scena e il suo
# callback chiudeva il gioco -- un pulsante "Opzioni" che spegne tutto e' peggio di uno
# spento, quindi finche' non c'era niente da mostrare era giusto lasciarlo grigio.
func _on_option_pressed() -> void:
	if _in_partenza():
		return
	if opzioni != null and is_instance_valid(opzioni):
		return                       # gia' aperta: il doppio clic non ne apre due
	opzioni = OptionsScreen.new()
	opzioni.lingua_cambiata.connect(_etichette)
	add_child(opzioni)

func _on_quit_pressed() -> void:
	if _in_partenza():
		return
	get_tree().quit()

# Dopo "Avvia", per il secondo della dissolvenza, il menu e' gia' lasciato: prima i pulsanti
# restavano vivi (proprietario, 23/10/2026: "mentre c'e' il fade posso comunque cliccare gli
# altri pulsanti") e si potevano aprire le Impostazioni o chiudere il gioco a meta' caricamento.
# Il velo nero non puo' fermare i clic: Fade_transition e' mouse_filter IGNORE apposta, perche'
# la stessa scena serve nella stanza, dove non deve rubare il cursore.
func _in_partenza() -> bool:
	return button_type == "start"

# I pulsanti smettono di ascoltare mouse e tastiera, ma NON si spengono (disabled): diventerebbero
# grigi per il secondo della dissolvenza, e sembrerebbe un difetto.
func _blocca_pulsanti() -> void:
	for b in $button_manager.get_children():
		if b is Button:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.focus_mode = Control.FOCUS_NONE
			b.release_focus()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	#elif button_type == "option":
		#get_tree().change_scene_to_file("res://main.tscn")
