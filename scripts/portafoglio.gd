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
const Lingua := preload("res://scripts/lingua.gd")
const Necromanti := preload("res://scripts/necromanti.gd")
const SAVE_PATH := "user://progressi.cfg"
const DEV_TOOL := "res://scripts/dev_tool.gd"
## Impostazioni del giocatore che non sono progressi (per ora: dev tool sbloccato).
const CFG_IMPOSTAZIONI := "user://impostazioni.cfg"

static var _dev_sbloccato := -1  # -1 = ancora da leggere


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


## Fondi infiniti attivi? Solo con il dev tool (build di prova, oppure sbloccato
## con il codice nelle Impostazioni).
static func infinite(st: Dictionary) -> bool:
	return dev_attivo() and bool(st["dev_infiniti"])


## Dev tool disponibile: nelle build di prova (editor ed export di debug) sempre,
## nelle build finali solo dopo il codice sviluppatore nelle Impostazioni.
static func dev_attivo() -> bool:
	return OS.is_debug_build() or dev_sbloccato()


## true se il codice sviluppatore è stato inserito (mostra il tasto DEV in alto a destra).
static func dev_sbloccato() -> bool:
	if _dev_sbloccato < 0:
		var cfg := ConfigFile.new()
		cfg.load(CFG_IMPOSTAZIONI)
		_dev_sbloccato = 1 if bool(cfg.get_value("dev", "sbloccato", false)) else 0
	return _dev_sbloccato == 1


## Sblocca (true) o toglie (false) il dev tool e salva la scelta.
static func sblocca_dev(on: bool, tree: SceneTree) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_IMPOSTAZIONI)
	cfg.set_value("dev", "sbloccato", on)
	cfg.save(CFG_IMPOSTAZIONI)
	_dev_sbloccato = 1 if on else 0
	if tree == null:
		return
	if on:
		install_dev_tool(tree)
	elif not OS.is_debug_build():
		var dt := tree.root.get_node_or_null("DevTool")
		if dt != null:
			if dt.has_method("chiudi_pannello"):
				dt.chiudi_pannello()
			dt.queue_free()


static func has_vip() -> bool:
	return bool(load_state()["vip"])


static func add_monete(n: int) -> void:
	if n <= 0:
		return
	var st := load_state()
	st["monete"] += n
	save_state(st)


static func owned(st: Dictionary, item: OggettoNegozio) -> bool:
	if item.necromante != "" and Necromanti.possiede(item.necromante):
		return true
	if item.una_sola_volta and item.id != "" and item.id in st["acquistati"]:
		return true
	return item.sblocca_vip and item.una_sola_volta and bool(st["vip"])


## Si può comprare? "" = sì, altrimenti il motivo.
static func why_not(st: Dictionary, item: OggettoNegozio) -> String:
	if owned(st, item):
		return Lingua.t("Lo hai già.")
	if item.valuta == OggettoNegozio.Valuta.EURO:
		if OS.is_debug_build():
			return ""  # nelle build di prova l'acquisto viene simulato
		return Lingua.t("I pagamenti con soldi veri arriveranno più avanti.")
	var have: int = st["monete"]
	if not infinite(st) and have < int(item.prezzo):
		return Lingua.t("Ti mancano %d monete d'osso.") % (int(item.prezzo) - have)
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
		got.append(Lingua.t("%d monete d'osso") % item.monete)
	if item.sblocca_vip:
		st["vip"] = true
		got.append(Lingua.t("la velocità x3"))
	if item.una_sola_volta and item.id != "" and not item.id in st["acquistati"]:
		st["acquistati"].append(item.id)
	save_state(st)
	if item.necromante != "":
		Necromanti.sblocca(item.necromante)
		var n := Necromanti.per_id(item.necromante)
		got.append(Lingua.t(n.nome) if n != null else item.necromante)
	if item.pergamene > 0:
		Collezione.add_scrolls(item.pergamene)
		got.append((Lingua.t("%d pergamena") if item.pergamene == 1 else Lingua.t("%d pergamene")) % item.pergamene)
	var what: String = Lingua.t(item.nome) if got.is_empty() else ", ".join(got)
	var msg := Lingua.t("Hai ottenuto %s!") % what
	if item.valuta == OggettoNegozio.Valuta.EURO:
		msg += Lingua.t("  (acquisto simulato: build di prova)")
	return msg


static func set_dev_infinite(on: bool) -> void:
	var st := load_state()
	st["dev_infiniti"] = on
	save_state(st)


## Mette il dev tool nella radice del gioco (resta attivo cambiando scena).
## Nelle build finali (senza debug) solo se è stato sbloccato con il codice.
static func install_dev_tool(tree: SceneTree) -> void:
	if not dev_attivo() or tree == null or tree.root.has_node("DevTool"):
		return
	var dt: Node = load(DEV_TOOL).new()
	dt.name = "DevTool"
	tree.root.add_child.call_deferred(dt)
