extends RefCounted
## Collezione degli scheletri, pergamene e squadra della run.
## Tutto è salvato in user://progressi.cfg, insieme alle ricerche.
##
##   [collezione]  id_unità = rango (0 = non posseduta, 1..MAX_RANK)
##   [pergamene]   numero = pergamene da aprire, senza_epiche = aperture senza epiche/leggendarie
##   [squadra]     unita = le 4 unità scelte per la prossima run
##
## Regole delle pergamene (valori in game_data.gd):
##   - rarità estratta con RARITY_ODDS; ogni PITY_EVERY aperture un'epica o leggendaria è garantita
##   - finché la collezione non è completa esce sempre un'unità che non hai
##   - a collezione completa i doppioni alzano il rango (+10% vita e danno per rango)

const Data := preload("res://scripts/game_data.gd")
const SAVE_PATH := "user://progressi.cfg"
const SQUAD_SIZE := 4
const RARITY_ORDER := ["comune", "raro", "epico", "leggendario"]


static func load_state() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var owned := {}
	if not cfg.has_section("collezione"):
		# prima partita con le pergamene: unità di base e qualche pergamena in regalo
		for k in Data.STARTING_UNITS:
			owned[k] = 1
		var first := {"owned": owned, "scrolls": Data.STARTING_SCROLLS, "pity": 0,
			"squad": Data.STARTING_UNITS.duplicate()}
		save_state(first)
		return first
	for k in Data.ALLY_ORDER:
		var r := int(cfg.get_value("collezione", k, 0))
		if r > 0:
			owned[k] = r
	for k in Data.STARTING_UNITS:
		if not owned.has(k):
			owned[k] = 1
	var squad: Array = []
	for k in cfg.get_value("squadra", "unita", Data.STARTING_UNITS.duplicate()):
		if owned.has(k) and not k in squad and squad.size() < SQUAD_SIZE:
			squad.append(k)
	if squad.is_empty():
		squad = Data.STARTING_UNITS.duplicate()
	return {
		"owned": owned,
		"scrolls": int(cfg.get_value("pergamene", "numero", 0)),
		"pity": int(cfg.get_value("pergamene", "senza_epiche", 0)),
		"squad": squad,
	}


static func save_state(st: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # conserva ricerche, punti e record
	for k in Data.ALLY_ORDER:
		cfg.set_value("collezione", k, int(st["owned"].get(k, 0)))
	cfg.set_value("pergamene", "numero", st["scrolls"])
	cfg.set_value("pergamene", "senza_epiche", st["pity"])
	cfg.set_value("squadra", "unita", st["squad"])
	cfg.save(SAVE_PATH)


static func add_scrolls(n: int) -> void:
	if n <= 0:
		return
	var st := load_state()
	st["scrolls"] += n
	save_state(st)


## Moltiplicatore di vita e danno dato dal rango.
static func rank_mult(rank: int) -> float:
	return 1.0 + Data.RANK_BONUS * float(maxi(1, rank) - 1)


static func owned_count(st: Dictionary) -> int:
	return st["owned"].size()


## Apre una pergamena. Restituisce {kind, rank, new, rarity} oppure {} se non ce ne sono.
static func open_scroll(st: Dictionary) -> Dictionary:
	if st["scrolls"] <= 0:
		return {}
	st["scrolls"] -= 1
	st["pity"] += 1
	var rarity := _roll_rarity(st["pity"] >= Data.PITY_EVERY)
	if rarity == "epico" or rarity == "leggendario":
		st["pity"] = 0
	var missing: Array = Data.ALLY_ORDER.filter(func(k): return not st["owned"].has(k))
	var pick := ""
	if not missing.is_empty():
		# sempre un'unità nuova: della rarità estratta, o della più vicina che ti manca
		for r in _nearest_rarities(rarity):
			var pool: Array = missing.filter(func(k): return Data.UNITS[k]["rarity"] == r)
			if not pool.is_empty():
				pick = pool.pick_random()
				break
	else:
		var pool: Array = Data.ALLY_ORDER.filter(func(k): return Data.UNITS[k]["rarity"] == rarity)
		pick = pool.pick_random()
	var is_new: bool = not st["owned"].has(pick)
	st["owned"][pick] = 1 if is_new else mini(Data.MAX_RANK, st["owned"][pick] + 1)
	save_state(st)
	return {"kind": pick, "rank": st["owned"][pick], "new": is_new, "rarity": Data.UNITS[pick]["rarity"]}


static func _roll_rarity(guaranteed_epic: bool) -> String:
	var odds: Dictionary = Data.RARITY_ODDS.duplicate()
	if guaranteed_epic:
		odds = {"epico": Data.RARITY_ODDS["epico"], "leggendario": Data.RARITY_ODDS["leggendario"]}
	var total := 0.0
	for r in odds:
		total += odds[r]
	var x := randf() * total
	for r in RARITY_ORDER:
		if odds.has(r):
			x -= odds[r]
			if x <= 0.0:
				return r
	return "comune"


static func _nearest_rarities(r: String) -> Array:
	var i := RARITY_ORDER.find(r)
	var order := RARITY_ORDER.duplicate()
	order.sort_custom(func(a, b):
		var da := absi(RARITY_ORDER.find(a) - i)
		var db := absi(RARITY_ORDER.find(b) - i)
		return da < db or (da == db and RARITY_ORDER.find(a) > RARITY_ORDER.find(b)))
	return order
