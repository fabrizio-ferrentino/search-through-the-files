class_name WebEffetti
extends RefCounted

# ============================================================
# Gli effetti animati delle pagine web: <marquee> e <blink>, che HtmlBB compila
# in [marquee ...] e [blink]. Sono RichTextEffect installati sulla PageView (e,
# FERMI, sul gemello che disegna la maschera del testo: vedi page_view.gd -- un
# tag che il gemello non conosce finirebbe stampato e cambierebbe l'impaginato).
# ============================================================

# Gli effetti da installare su un RichTextLabel. fermo = true: riconoscono il tag
# ma non muovono niente (il gemello della maschera deve impaginare uguale).
static func tutti(fermo := false) -> Array:
	var m := Marquee.new()
	m.fermo = fermo
	var b := Blink.new()
	b.fermo = fermo
	return [m, b]


# [marquee w=<largo> len=<testo> v=<px/s> dir=l|r mode=s|a]: la riga intera scorre.
# Tutti i caratteri ricevono lo STESSO spostamento, quindi il testo si muove come un
# blocco: entra da destra, esce a sinistra e ricomincia (mode=s), oppure rimbalza
# fra i due bordi (mode=a, behavior="alternate"). Fuori dal riquadro (largo w) i
# caratteri si nascondono, come il ritaglio di un marquee vero.
class Marquee extends RichTextEffect:
	var bbcode := "marquee"
	var fermo := false

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		if fermo:
			return true
		var w: float = float(fx.env.get("w", 600))
		var lun: float = float(fx.env.get("len", 200))
		var v: float = float(fx.env.get("v", 70))
		var t: float = fx.elapsed_time * v
		var dx := 0.0
		if str(fx.env.get("mode", "s")) == "a":
			# avanti e indietro fra il bordo sinistro e quello destro
			var corsa := maxf(1.0, w - lun)
			var p := fposmod(t, corsa * 2.0)
			dx = p if p <= corsa else corsa * 2.0 - p
		elif str(fx.env.get("dir", "l")) == "r":
			dx = fposmod(t, w + lun) - lun
		else:
			dx = w - fposmod(t, w + lun)
		fx.offset = Vector2(dx, 0.0)
		# come in un browser il testo si vede solo DENTRO il riquadro del marquee: entra
		# dal bordo destro e sparisce a quello sinistro, invece di sbordare fino alla barra.
		# L'engine non dice dove sta il carattere: lo si stima dalla sua posizione nel testo.
		var n: float = maxf(1.0, float(fx.env.get("n", 1)))
		var x := float(fx.relative_index) * lun / n + dx
		if x < 0.0 or x > w - lun / n:
			fx.visible = false
		return true


# [blink]: acceso e spento, come Netscape (un po' piu' acceso che spento).
class Blink extends RichTextEffect:
	var bbcode := "blink"
	var fermo := false

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		if fermo:
			return true
		if fposmod(fx.elapsed_time, 1.0) >= 0.6:
			fx.color.a = 0.0
		return true
