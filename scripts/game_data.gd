extends RefCounted
## Dati di bilanciamento del gioco.
## Tutti i numeri del tuning stanno qui: cambiali e riavvia la scena.

## Le distanze (gittate, raggi, velocità) sono in PIXEL DELL'ARTE:
## una casella di 2x2 tile misura 32 pixel. Così il bilanciamento resta
## uguale anche se cambi la scala dei pixel o le dimensioni della griglia.

## Statistiche base delle unità. Alleati (scheletri) e nemici (umani)
## condividono le stesse tipologie, come nel documento di design.
## - count:    quanti scheletri evoca una carta (solo alleati)
## - range:    per il corpo a corpo è la distanza dal bordo del bersaglio,
##             per le unità a distanza è la distanza dal centro
## - splash:   raggio dell'esplosione dei proiettili (0 = bersaglio singolo)
## - xp:       esperienza data al necromante quando l'unità nemica muore
## Campi in più (solo per gli scheletri):
## - role:     ruolo per le ricerche: "corpo", "distanza", "magia", "supporto"
## - rarity:   "base" (le hai da subito), "comune", "raro", "epico", "leggendario"
## - special:  abilità speciale (vedi unit.gd), "" se nessuna
## - sheet/sx: in quale atlante sta la sprite ("base" = sprites.png, colonna sx;
##             "nuove" = unita_scheletri.png, indice sx: 4 unità per riga, 2 frame)
## - desc:     descrizione mostrata in preparazione ed evocazione
const UNITS := {
	"soldato": {
		"ally_name": "Soldato scheletro", "enemy_name": "Soldato umano",
		"count": 4, "hp": 60.0, "dmg": 6.0, "range": 3.0, "cooldown": 0.9,
		"speed": 24.0, "melee": true, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "corpo", "rarity": "base", "special": "", "sheet": "base", "sx": 0,
		"desc": "Fanteria di base: tanti, economici, tengono la linea.",
	},
	"arciere": {
		"ally_name": "Arciere scheletro", "enemy_name": "Arciere umano",
		"count": 3, "hp": 30.0, "dmg": 6.0, "range": 56.0, "cooldown": 1.1,
		"speed": 20.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "distanza", "rarity": "base", "special": "", "sheet": "base", "sx": 2,
		"desc": "Tira frecce da lontano. Fragile: proteggilo.",
	},
	"gigante": {
		"ally_name": "Scheletro gigante", "enemy_name": "Umano gigante",
		"count": 1, "hp": 260.0, "dmg": 14.0, "range": 4.0, "cooldown": 1.5,
		"speed": 15.0, "melee": true, "splash": 0.0, "radius": 7.0, "xp": 4,
		"role": "corpo", "rarity": "base", "special": "", "sheet": "base", "sx": 6,
		"desc": "Un muro di ossa con tanta vita e colpi pesanti.",
	},
	"mago": {
		"ally_name": "Scheletro mago", "enemy_name": "Mago umano",
		"count": 2, "hp": 25.0, "dmg": 14.0, "range": 64.0, "cooldown": 1.8,
		"speed": 18.0, "melee": false, "splash": 12.0, "radius": 4.0, "xp": 2,
		"role": "magia", "rarity": "base", "special": "", "sheet": "base", "sx": 4,
		"desc": "Sfere magiche che esplodono e colpiscono un'area.",
	},
	# --- Unità da evocare con le pergamene (solo scheletri) --------------------
	"lanciere": {
		"ally_name": "Lanciere", "count": 3, "hp": 55.0, "dmg": 7.0, "range": 9.0, "cooldown": 1.0,
		"speed": 22.0, "melee": true, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "corpo", "rarity": "comune", "special": "trafiggi", "sheet": "nuove", "sx": 0,
		"desc": "Colpisce da più lontano e trafigge anche il nemico dietro (60%).",
	},
	"berserker": {
		"ally_name": "Berserker", "count": 2, "hp": 70.0, "dmg": 8.0, "range": 3.0, "cooldown": 0.8,
		"speed": 28.0, "melee": true, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "corpo", "rarity": "comune", "special": "furia", "sheet": "nuove", "sx": 1,
		"desc": "Più è ferito, più colpisce forte e veloce (fino al doppio).",
	},
	"cavaliere": {
		"ally_name": "Cavaliere scheletro", "count": 1, "hp": 150.0, "dmg": 16.0, "range": 4.0, "cooldown": 1.3,
		"speed": 42.0, "melee": true, "splash": 0.0, "radius": 6.0, "xp": 1,
		"role": "corpo", "rarity": "raro", "special": "carica", "sheet": "nuove", "sx": 2,
		"desc": "Carica da lontano: il primo colpo dopo una corsa fa danno doppio.",
	},
	"scudiero": {
		"ally_name": "Scudiero", "count": 2, "hp": 150.0, "dmg": 3.0, "range": 3.0, "cooldown": 1.2,
		"speed": 18.0, "melee": true, "splash": 0.0, "radius": 5.0, "xp": 1,
		"role": "corpo", "rarity": "comune", "special": "provoca", "sheet": "nuove", "sx": 3,
		"desc": "Attira su di sé i nemici vicini e subisce il 30% di danni in meno.",
	},
	"balestriere": {
		"ally_name": "Balestriere", "count": 2, "hp": 35.0, "dmg": 14.0, "range": 70.0, "cooldown": 2.0,
		"speed": 20.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "distanza", "rarity": "comune", "special": "trapassa", "sheet": "nuove", "sx": 4,
		"desc": "Dardi pesanti: un secondo dardo colpisce il nemico dietro (60%).",
	},
	"catapulta": {
		"ally_name": "Catapulta d'ossa", "count": 1, "hp": 60.0, "dmg": 24.0, "range": 120.0, "cooldown": 3.2,
		"speed": 0.0, "melee": false, "splash": 18.0, "radius": 6.0, "xp": 1,
		"role": "distanza", "rarity": "raro", "special": "catapulta", "sheet": "nuove", "sx": 5,
		"desc": "Lancia teschi lontanissimo con danno ad area, ma non colpisce chi è troppo vicino.",
	},
	"cecchino": {
		"ally_name": "Cecchino spettrale", "count": 1, "hp": 30.0, "dmg": 34.0, "range": 160.0, "cooldown": 2.6,
		"speed": 20.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "distanza", "rarity": "epico", "special": "cecchino", "sheet": "nuove", "sx": 6,
		"desc": "Gittata enorme: mira sempre il nemico con più vita.",
	},
	"negromante": {
		"ally_name": "Negromante minore", "count": 1, "hp": 40.0, "dmg": 6.0, "range": 60.0, "cooldown": 1.6,
		"speed": 18.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "magia", "rarity": "epico", "special": "rianima", "sheet": "nuove", "sx": 7,
		"desc": "Quando un nemico muore vicino a lui, lo rialza come scheletro per 14 secondi (max 3).",
	},
	"peste": {
		"ally_name": "Stregone della peste", "count": 1, "hp": 45.0, "dmg": 4.0, "range": 60.0, "cooldown": 2.4,
		"speed": 18.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "magia", "rarity": "epico", "special": "peste", "sheet": "nuove", "sx": 8,
		"desc": "Lascia nubi di peste che avvelenano e rallentano i nemici.",
	},
	"lich": {
		"ally_name": "Lich", "count": 1, "hp": 80.0, "dmg": 18.0, "range": 72.0, "cooldown": 1.8,
		"speed": 18.0, "melee": false, "splash": 10.0, "radius": 4.0, "xp": 1,
		"role": "magia", "rarity": "leggendario", "special": "maledici", "sheet": "nuove", "sx": 9,
		"desc": "Magie ad area che maledicono: i nemici colpiti subiscono +30% danni da tutti.",
	},
	"banshee": {
		"ally_name": "Banshee", "count": 1, "hp": 50.0, "dmg": 6.0, "range": 40.0, "cooldown": 4.0,
		"speed": 20.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
		"role": "magia", "rarity": "epico", "special": "urlo", "sheet": "nuove", "sx": 10,
		"desc": "Un urlo che ferisce e stordisce per un attimo tutti i nemici vicini.",
	},
	"totem": {
		"ally_name": "Totem d'ossa", "count": 1, "hp": 90.0, "dmg": 0.0, "range": 0.0, "cooldown": 2.0,
		"speed": 0.0, "melee": true, "splash": 0.0, "radius": 5.0, "xp": 1,
		"role": "supporto", "rarity": "raro", "special": "aura", "sheet": "nuove", "sx": 11,
		"desc": "Non attacca: gli scheletri vicini fanno +25% danni e attaccano più veloce.",
	},
	"golem": {
		"ally_name": "Golem di ossa", "count": 1, "hp": 520.0, "dmg": 22.0, "range": 5.0, "cooldown": 1.8,
		"speed": 12.0, "melee": true, "splash": 0.0, "radius": 9.0, "xp": 1,
		"role": "corpo", "rarity": "leggendario", "special": "schianto", "sheet": "nuove", "sx": 12,
		"desc": "Enorme. Ogni colpo fa tremare il terreno e ferisce anche chi è attorno.",
	},
	"mietitore": {
		"ally_name": "Mietitore", "count": 1, "hp": 110.0, "dmg": 20.0, "range": 6.0, "cooldown": 1.2,
		"speed": 30.0, "melee": true, "splash": 0.0, "radius": 5.0, "xp": 1,
		"role": "corpo", "rarity": "leggendario", "special": "falce", "sheet": "nuove", "sx": 13,
		"desc": "La falce colpisce tutti i vicini e finisce all'istante chi ha meno del 20% di vita.",
	},
	"muro": {
		"ally_name": "Muro d'ossa", "count": 1, "hp": 420.0, "dmg": 0.0, "range": 0.0, "cooldown": 1.0,
		"speed": 0.0, "melee": true, "splash": 0.0, "radius": 8.0, "xp": 1,
		"role": "supporto", "rarity": "raro", "special": "muro", "sheet": "nuove", "sx": 14,
		"desc": "Una barricata: non attacca, ma i nemici vicini devono abbatterla per passare.",
	},
	"carcassa": {
		"ally_name": "Carcassa esplosiva", "count": 2, "hp": 30.0, "dmg": 45.0, "range": 3.0, "cooldown": 1.0,
		"speed": 36.0, "melee": true, "splash": 20.0, "radius": 4.0, "xp": 1,
		"role": "corpo", "rarity": "raro", "special": "esplodi", "sheet": "nuove", "sx": 15,
		"desc": "Corre contro i nemici ed esplode, colpendo un'area. Rinasce a fine ondata.",
	},
}

## Tipi dei nemici (gli umani usano solo questi).
const UNIT_ORDER := ["soldato", "arciere", "gigante", "mago"]
## Tutti gli scheletri, nell'ordine della collezione.
const ALLY_ORDER := ["soldato", "arciere", "mago", "gigante",
	"lanciere", "scudiero", "balestriere", "berserker",
	"cavaliere", "catapulta", "totem", "muro", "carcassa",
	"negromante", "peste", "banshee", "cecchino",
	"lich", "golem", "mietitore"]
const STARTING_UNITS := ["soldato", "arciere", "mago", "gigante"]

const ROLE_NAMES := {"corpo": "Corpo a corpo", "distanza": "A distanza", "magia": "Magia", "supporto": "Supporto"}
const RARITY_NAMES := {"base": "Base", "comune": "Comune", "raro": "Raro", "epico": "Epico", "leggendario": "Leggendario"}
## Probabilità di ogni rarità quando apri una pergamena.
const RARITY_ODDS := {"comune": 0.50, "raro": 0.30, "epico": 0.15, "leggendario": 0.05}
## Ogni quante pergamene un'unità epica o leggendaria è garantita.
const PITY_EVERY := 10
## Ogni quante ondate superate si guadagna una pergamena.
const WAVES_PER_SCROLL := 10
## Monete d'osso guadagnate per ogni ondata superata (si spendono nel NEGOZIO).
const MONETE_PER_ONDATA := 2
## Monete d'osso in più se resisti a tutte le 100 ondate.
const MONETE_VITTORIA := 300
## Pergamene in regalo alla prima partita (per provare subito l'evocazione).
const STARTING_SCROLLS := 3
## Rango massimo di un'unità (i doppioni lo alzano): +10% vita e danno per rango.
const MAX_RANK := 5
const RANK_BONUS := 0.10

const SHEET_BASE := preload("res://assets/sprites.png")
const SHEET_NEW := preload("res://assets/unita_scheletri.png")


## Atlante e rettangolo del frame (0 o 1) di uno scheletro.
static func ally_texture(kind: String) -> Texture2D:
	return SHEET_NEW if UNITS[kind]["sheet"] == "nuove" else SHEET_BASE


static func ally_region(kind: String, frame: int = 0) -> Rect2:
	var d: Dictionary = UNITS[kind]
	if d["sheet"] == "nuove":
		var i: int = d["sx"]
		return Rect2((i % 4) * 32 + frame * 16, (i / 4) * 16, 16, 16)
	return Rect2((d["sx"] + frame) * 16, 0, 16, 16)

## COLORE D'ACCENTO di ogni unità: è l'unico elemento colorato della sprite
## (il resto è in scala di grigi) e colora anche i suoi proiettili e i suoi effetti.
## Se cambi un colore qui, per coerenza ridisegna anche quel pixel nella sprite.
const ACCENTI := {
	"soldato": Color("d64034"),     # sciarpa rossa
	"arciere": Color("68be4c"),     # cappellino verde
	"mago": Color("5292ec"),        # sfera blu sul bastone
	"gigante": Color("96643a"),     # clava di legno
	"lanciere": Color("ec8a30"),    # pennone arancio
	"berserker": Color("d64034"),   # asce insanguinate
	"cavaliere": Color("f0ce52"),   # elmo d'oro
	"scudiero": Color("5292ec"),    # scudo blu
	"balestriere": Color("40b0a0"), # cappuccio verde acqua
	"catapulta": Color("ec8a30"),   # teschi in fiamme
	"cecchino": Color("f0ce52"),    # occhi gialli
	"negromante": Color("de62b6"),  # stola magenta
	"peste": Color("b6d640"),       # fumo velenoso
	"lich": Color("68be4c"),        # fuoco verde
	"banshee": Color("78e2ea"),     # corpo spettrale
	"totem": Color("d64034"),       # palo dipinto di rosso
	"golem": Color("ec8a30"),       # nucleo ardente
	"mietitore": Color("ce96f6"),   # occhi lilla
	"muro": Color("68be4c"),        # muschio
	"carcassa": Color("ec8a30"),    # miccia accesa
}
## Accenti degli eroi nemici (stesse tipologie, altri colori).
const ACCENTI_NEMICI := {
	"soldato": Color("5292ec"),     # tunica blu
	"arciere": Color("96643a"),     # cappuccio di cuoio
	"mago": Color("d64034"),        # cappello rosso (magia di fuoco)
	"gigante": Color("f0ce52"),     # elmo con la fascia d'oro
}
## Viola della veste del necromante (colpi della torre).
const ACCENTO_NECROMANTE := Color("9c5ccc")


static func accent(kind: String, team: int = 0) -> Color:
	var d: Dictionary = ACCENTI if team == 0 else ACCENTI_NEMICI
	return d.get(kind, Color("acacac"))


## Abilità del necromante. La potenza scala con l'attacco del necromante.
## L'area curativa cura solo le unità alleate: la torre non si cura mai.
const ABILITIES := {
	"palla_di_fuoco": {
		"name": "Palla di fuoco", "key": "1", "radius": 24.0, "power": 60.0,
		"cooldown": 12.0, "color": Color("ec8a30"),
	},
	"area_curativa": {
		"name": "Area curativa", "key": "2", "radius": 36.0, "power": 40.0,
		"cooldown": 15.0, "color": Color("68be4c"),
	},
	"saetta": {
		"name": "Saetta", "key": "3", "radius": 10.0, "power": 140.0,
		"cooldown": 8.0, "color": Color("5292ec"),
	},
}

const ABILITY_ORDER := ["palla_di_fuoco", "area_curativa", "saetta"]

## Necromante / torre
const TOWER_HP := 100.0
const NECRO_DMG := 15.0
const NECRO_COOLDOWN := 0.8
const NECRO_RANGE := 88.0
## Frazione di danno che la torre subisce da frecce e magie (le mura reggono).
const TOWER_RANGED_TAKEN := 0.5

## Ondate
const FINAL_WAVE := 100
const BOSS_EVERY := 10
## Il boss è un umano gigante potenziato.
const BOSS_HP_MULT := 2.5
const BOSS_DMG_MULT := 1.2
const BOSS_SPEED_MULT := 0.7


## Moltiplicatore della vita dei nemici in base all'ondata.
static func enemy_hp_mult(wave: int) -> float:
	var w := float(wave - 1)
	return 1.0 + 0.12 * w + 0.002 * w * w


## Moltiplicatore dei danni dei nemici in base all'ondata.
static func enemy_dmg_mult(wave: int) -> float:
	return 1.0 + 0.05 * float(wave - 1)


## Esperienza necessaria per passare dal livello indicato al successivo.
static func xp_to_next(level: int) -> int:
	return 4 + level * 3


## Composizione di un'ondata: lista di {kind, boss}.
static func build_wave(wave: int) -> Array:
	var queue: Array = []
	var count := mini(3 + int(wave * 1.3), 60)
	for i in count:
		var r := randf()
		var kind := "soldato"
		if wave >= 3 and r < 0.30:
			kind = "arciere"
		if wave >= 7 and r < 0.12:
			kind = "mago"
		if wave >= 12 and r > 0.95:
			kind = "gigante"
		queue.append({"kind": kind, "boss": false})
	if wave % BOSS_EVERY == 0:
		queue.append({"kind": "gigante", "boss": true})
	return queue
