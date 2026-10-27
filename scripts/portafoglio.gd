extends RefCounted
## Monete d'osso, pacchetto VIP e acquisti del negozio.
## Salvati in user://progressi.cfg, sezione [negozio]:
##   monete       monete d'osso possedute
##   vip          true se hai il pacchetto VIP (sblocca la velocità x3)
##   acquistati   id degli oggetti comprati una sola volta
##   dev_infiniti fondi infiniti del dev tool (vale solo nelle build di prova)
##
## Le monete si guadagnano giocando (vedi MONETE_PER_ONDATA in game_data.gd).

const Collezione := preload("res://scripts/collezione.gd")
const SAVE_PATH := "user://progressi.cfg"
const DEV_TOOL := "res://scripts/dev_tool.gd"


static func load_state() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return {
		"monete": int(cfg.get_value("negozio", "monete", 0)),
		"vip": bool(cfg.get_value("negozio", "vip", false)),
		"acquistati": Array(cfg.get_value("negozio", "acquistati", [])),
		"dev_infiniti": bool(cfg.get_value("negozio", "dev_infiniti", false)),
	}


static func save_state(st: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # conserva ricerche, collezione, pergamene, record
	cfg.set_value("negozio", "monete", st["monete"])
	cfg.set_value("negozio", "vip", st["vip"])
	cfg.set_value("negozio", "acquistati", st["acquistati"])
	cfg.set_value("negozio", "dev_infiniti", st["dev_infiniti"])
	cfg.save(SAVE_PATH)


## Fondi infiniti attivi? Solo nelle build di prova (editor ed export di debug).
static func infinite(st: Dictionary) -> bool:
	return OS.is_debug_build() and bool(st["dev_infiniti"])


static func has_vip() -> bool:
	return bool(load_state()["vip"])


static func add_monete(n: int) -> void:
	if n <= 0:
		return
	var st := load_state()
	st["monete"] += n
	save_state(st)


static func owned(st: Dictionary, item: OggettoNegozio) -> bool:
	if item.una_sola_volta and item.id != "" and item.id in st["acquistati"]:
		return true
	return item.sblocca_vip and item.una_sola_volta and bool(st["vip"])


## Si può comprare? "" = sì, altrimenti il motivo.
static func why_not(st: Dictionary, item: OggettoNegozio) -> String:
	if owned(st, item):
		return "Lo hai già."
	if item.valuta == OggettoNegozio.Valuta.EURO:
		if OS.is_debug_build():
			return ""  # nelle build di prova l'acquisto viene simulato
		return "I pagamenti con soldi veri arriveranno più avanti."
	var have: int = st["monete"]
	if not infinite(st) and have < int(item.prezzo):
		return "Ti mancano %d monete d'osso." % (int(item.prezzo) - have)
	return ""


## Compra l'oggetto: paga e consegna. Restituisce il messaggio da mostrare.
static func buy(st: Dictionary, item: OggettoNegozio) -> String:
	var err := why_not(st, item)
	if err != "":
		return err
	if item.valuta == OggettoNegozio.Valuta.MONETE_D_OSSO and not infinite(st):
		st["monete"] -= int(item.prezzo)
	var got: Array = []
	if item.monete > 0:
		st["monete"] += item.monete
		got.append("%d monete d'osso" % item.monete)
	if item.sblocca_vip:
		st["vip"] = true
		got.append("la velocità x3")
	if item.una_sola_volta and item.id != "" and not item.id in st["acquistati"]:
		st["acquistati"].append(item.id)
	save_state(st)
	if item.pergamene > 0:
		Collezione.add_scrolls(item.pergamene)
		got.append("%d %s" % [item.pergamene, "pergamena" if item.pergamene == 1 else "pergamene"])
	var what: String = item.nome if got.is_empty() else ", ".join(got)
	var msg := "Hai ottenuto " + what + "!"
	if item.valuta == OggettoNegozio.Valuta.EURO:
		msg += "  (acquisto simulato: build di prova)"
	return msg


static func set_dev_infinite(on: bool) -> void:
	var st := load_state()
	st["dev_infiniti"] = on
	save_state(st)


## Mette il dev tool nella radice del gioco (resta attivo cambiando scena).
## Nelle build finali (senza debug) non fa niente.
static func install_dev_tool(tree: SceneTree) -> void:
	if not OS.is_debug_build() or tree == null or tree.root.has_node("DevTool"):
		return
	var dt: Node = load(DEV_TOOL).new()
	dt.name = "DevTool"
	tree.root.add_child.call_deferred(dt)
