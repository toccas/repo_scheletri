@tool
extends RefCounted
## Albero delle ricerche: dati dei nodi e salvataggio dei progressi.
##
## Per aggiungere o cambiare una ricerca modifica NODES:
##   name      nome mostrato
##   desc      descrizione (l'effetto per livello)
##   branch    ramo: 0 Necromante, 1 Evocazioni, 2 Arcano
##   pos       posizione nella griglia della schermata (colonna, riga)
##   costs     costo in punti di ogni livello (il numero di livelli è la lunghezza)
##   requires  [id, livello minimo] della ricerca da sbloccare prima (o [] se nessuna)
##   effect    tipo di bonus (vedi bonuses() e main.gd: _apply_research)
##   value     valore del bonus per ogni livello
##   icon      angolo in alto a sinistra dell'icona 16x16 in assets/sprites.png
##
## Le unità NON si sbloccano più da qui: si trovano aprendo le pergamene nel
## portale (vedi collezione.gd). Qui ci sono solo potenziamenti, anche per ruolo
## (corpo a corpo, a distanza, magia), e le tre abilità del necromante.
## Effetti per ruolo: "hp_<ruolo>" e "dmg_<ruolo>" (vedi main.gd: role_mult).

const SAVE_PATH := "user://progressi.cfg"

const BRANCHES := [
	{"name": "NECROMANTE", "cols": [0, 1]},
	{"name": "EVOCAZIONI", "cols": [3, 4]},
	{"name": "ARCANO", "cols": [6, 7]},
]

const NODES := {
	# --- Necromante ---------------------------------------------------------
	"mura": {
		"name": "Mura rinforzate", "desc": "Vita della torre +20 per livello.",
		"branch": 0, "pos": Vector2i(0, 0), "costs": [4, 6, 9, 12, 16], "requires": [],
		"effect": "tower_hp", "value": 20.0, "icon": Vector2(16, 48),
	},
	"furia": {
		"name": "Furia oscura", "desc": "Danno del necromante +10% per livello.",
		"branch": 0, "pos": Vector2i(1, 0), "costs": [5, 8, 12, 16, 22], "requires": [],
		"effect": "necro_dmg", "value": 0.10, "icon": Vector2(64, 32),
	},
	"occhio": {
		"name": "Occhio della notte", "desc": "Gittata del necromante +10% per livello.",
		"branch": 0, "pos": Vector2i(0, 1), "costs": [6, 10, 15], "requires": ["mura", 1],
		"effect": "necro_range", "value": 0.10, "icon": Vector2(48, 64),
	},
	"rito": {
		"name": "Rito rapido", "desc": "Velocità d'attacco del necromante +8% per livello.",
		"branch": 0, "pos": Vector2i(1, 1), "costs": [8, 12, 18], "requires": ["furia", 1],
		"effect": "necro_rate", "value": 0.08, "icon": Vector2(48, 80),
	},
	"saggezza": {
		"name": "Saggezza proibita", "desc": "Esperienza guadagnata +10% per livello: sali di livello prima.",
		"branch": 0, "pos": Vector2i(1, 2), "costs": [6, 10, 15], "requires": ["rito", 1],
		"effect": "xp", "value": 0.10, "icon": Vector2(64, 64),
	},
	# --- Evocazioni ---------------------------------------------------------
	"lame": {
		"name": "Lame d'osso", "desc": "Danno delle unità scheletro +10% per livello.",
		"branch": 1, "pos": Vector2i(3, 0), "costs": [5, 8, 12, 16, 22], "requires": [],
		"effect": "ally_dmg", "value": 0.10, "icon": Vector2(96, 64),
	},
	"ossa": {
		"name": "Ossa robuste", "desc": "Vita delle unità scheletro +10% per livello.",
		"branch": 1, "pos": Vector2i(4, 0), "costs": [5, 8, 12, 16, 22], "requires": [],
		"effect": "ally_hp", "value": 0.10, "icon": Vector2(80, 64),
	},
	"disciplina": {
		"name": "Disciplina d'osso", "desc": "Vita delle unità corpo a corpo +12% per livello.",
		"branch": 1, "pos": Vector2i(3, 1), "costs": [6, 10, 15], "requires": ["lame", 1],
		"effect": "hp_corpo", "value": 0.12, "icon": Vector2(0, 0),
	},
	"mira": {
		"name": "Mira spettrale", "desc": "Danno delle unità a distanza +12% per livello.",
		"branch": 1, "pos": Vector2i(3, 2), "costs": [8, 12, 18], "requires": ["disciplina", 1],
		"effect": "dmg_distanza", "value": 0.12, "icon": Vector2(32, 0),
	},
	"occulto": {
		"name": "Arti occulte", "desc": "Danno delle unità magiche +12% per livello.",
		"branch": 1, "pos": Vector2i(4, 1), "costs": [8, 12, 18], "requires": ["ossa", 1],
		"effect": "dmg_magia", "value": 0.12, "icon": Vector2(64, 0),
	},
	"legione": {
		"name": "Legione", "desc": "Squadre schierabili a inizio partita +1 per livello.",
		"branch": 1, "pos": Vector2i(4, 2), "costs": [25, 40], "requires": ["occulto", 1],
		"effect": "deploy", "value": 1.0, "icon": Vector2(112, 64),
	},
	# --- Arcano -------------------------------------------------------------
	"palla": {
		"name": "Palla di fuoco", "desc": "Sblocca l'abilità Palla di fuoco: danni alti in un'area media.",
		"branch": 2, "pos": Vector2i(6, 0), "costs": [8], "requires": [],
		"effect": "unlock_palla_di_fuoco", "value": 1.0, "icon": Vector2(48, 48),
	},
	"cura": {
		"name": "Area curativa", "desc": "Sblocca l'abilità Area curativa: cura gli scheletri in un'area ampia.",
		"branch": 2, "pos": Vector2i(7, 0), "costs": [8], "requires": [],
		"effect": "unlock_area_curativa", "value": 1.0, "icon": Vector2(80, 48),
	},
	"saetta": {
		"name": "Saetta", "desc": "Sblocca l'abilità Saetta: danni altissimi in un'area piccola.",
		"branch": 2, "pos": Vector2i(6, 1), "costs": [14], "requires": ["palla", 1],
		"effect": "unlock_saetta", "value": 1.0, "icon": Vector2(64, 48),
	},
	"potere": {
		"name": "Potere arcano", "desc": "Potenza delle abilità +15% per livello.",
		"branch": 2, "pos": Vector2i(6, 2), "costs": [10, 16, 24], "requires": ["saetta", 1],
		"effect": "ability_power", "value": 0.15, "icon": Vector2(112, 48),
	},
	"concentrazione": {
		"name": "Concentrazione", "desc": "Tempo di ricarica delle abilità -10% per livello.",
		"branch": 2, "pos": Vector2i(7, 1), "costs": [10, 16, 24], "requires": ["cura", 1],
		"effect": "ability_cd", "value": 0.10, "icon": Vector2(96, 48),
	},
}


# --- Salvataggio -------------------------------------------------------------

## Ricerche tolte (sblocco delle unità) e il loro costo, per rimborsare i vecchi salvataggi.
const OLD_UNLOCKS := {"arcieri": 6, "maghi": 12, "giganti": 14}

## Stato salvato: {"points": int, "best": int, "levels": {id: livello}}
static func load_state() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # se il file non esiste ancora parte tutto da zero
	var levels := {}
	for id in NODES:
		levels[id] = int(cfg.get_value("ricerche", id, 0))
	# vecchi salvataggi: gli sblocchi delle unità non esistono più, restituisco i punti
	var refund := 0
	for old in OLD_UNLOCKS:
		if int(cfg.get_value("ricerche", old, 0)) > 0:
			refund += OLD_UNLOCKS[old]
			cfg.set_value("ricerche", old, 0)
	if refund > 0:
		cfg.set_value("progressi", "punti", int(cfg.get_value("progressi", "punti", 0)) + refund)
		cfg.save(SAVE_PATH)
	return {
		"points": int(cfg.get_value("progressi", "punti", 0)),
		"best": int(cfg.get_value("progressi", "record_ondata", 0)),
		"levels": levels,
	}


static func save_state(st: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # conserva le altre voci (record, ecc.)
	cfg.set_value("progressi", "punti", st["points"])
	for id in st["levels"]:
		cfg.set_value("ricerche", id, st["levels"][id])
	cfg.save(SAVE_PATH)


# --- Regole ------------------------------------------------------------------

static func level(st: Dictionary, id: String) -> int:
	return st["levels"].get(id, 0)


static func max_level(id: String) -> int:
	return NODES[id]["costs"].size()


## Costo del prossimo livello, oppure -1 se la ricerca è al massimo.
static func next_cost(st: Dictionary, id: String) -> int:
	var lv := level(st, id)
	var costs: Array = NODES[id]["costs"]
	return costs[lv] if lv < costs.size() else -1


static func requirements_met(st: Dictionary, id: String) -> bool:
	var req: Array = NODES[id]["requires"]
	return req.is_empty() or level(st, req[0]) >= req[1]


static func can_buy(st: Dictionary, id: String) -> bool:
	var cost := next_cost(st, id)
	return cost >= 0 and requirements_met(st, id) and st["points"] >= cost


static func buy(st: Dictionary, id: String) -> bool:
	if not can_buy(st, id):
		return false
	st["points"] -= next_cost(st, id)
	st["levels"][id] = level(st, id) + 1
	save_state(st)
	return true


## Restituisce tutti i punti spesi e azzera le ricerche.
static func refund_all(st: Dictionary) -> void:
	for id in NODES:
		var costs: Array = NODES[id]["costs"]
		for i in level(st, id):
			st["points"] += costs[i]
		st["levels"][id] = 0
	save_state(st)


## Somma dei bonus di tutte le ricerche fatte: {effect: valore totale}.
static func bonuses(levels: Dictionary) -> Dictionary:
	var b := {}
	for id in NODES:
		var lv: int = levels.get(id, 0)
		if lv > 0:
			var n: Dictionary = NODES[id]
			b[n["effect"]] = b.get(n["effect"], 0.0) + n["value"] * lv
	return b
