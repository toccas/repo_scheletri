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
const UNITS := {
	"soldato": {
		"ally_name": "Soldato scheletro", "enemy_name": "Soldato umano",
		"count": 4, "hp": 60.0, "dmg": 6.0, "range": 3.0, "cooldown": 0.9,
		"speed": 24.0, "melee": true, "splash": 0.0, "radius": 4.0, "xp": 1,
	},
	"arciere": {
		"ally_name": "Arciere scheletro", "enemy_name": "Arciere umano",
		"count": 3, "hp": 30.0, "dmg": 6.0, "range": 56.0, "cooldown": 1.1,
		"speed": 20.0, "melee": false, "splash": 0.0, "radius": 4.0, "xp": 1,
	},
	"gigante": {
		"ally_name": "Scheletro gigante", "enemy_name": "Umano gigante",
		"count": 1, "hp": 260.0, "dmg": 14.0, "range": 4.0, "cooldown": 1.5,
		"speed": 15.0, "melee": true, "splash": 0.0, "radius": 7.0, "xp": 4,
	},
	"mago": {
		"ally_name": "Scheletro mago", "enemy_name": "Mago umano",
		"count": 2, "hp": 25.0, "dmg": 14.0, "range": 64.0, "cooldown": 1.8,
		"speed": 18.0, "melee": false, "splash": 12.0, "radius": 4.0, "xp": 2,
	},
}

const UNIT_ORDER := ["soldato", "arciere", "gigante", "mago"]

## Abilità del necromante. La potenza scala con l'attacco del necromante.
## L'area curativa cura solo le unità alleate: la torre non si cura mai.
const ABILITIES := {
	"palla_di_fuoco": {
		"name": "Palla di fuoco", "key": "1", "radius": 24.0, "power": 60.0,
		"cooldown": 12.0, "color": Color(1.0, 1.0, 1.0),
	},
	"area_curativa": {
		"name": "Area curativa", "key": "2", "radius": 36.0, "power": 40.0,
		"cooldown": 15.0, "color": Color(0.67, 0.67, 0.67),
	},
	"saetta": {
		"name": "Saetta", "key": "3", "radius": 10.0, "power": 140.0,
		"cooldown": 8.0, "color": Color(0.92, 0.92, 0.92),
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
