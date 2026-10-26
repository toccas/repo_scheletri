extends Node2D
## Gestore della partita: mappa, ondate, torre del necromante, level-up,
## abilità, interfaccia e salvataggio dei punti per l'albero dei progressi.
##
## MAPPA (dal documento di design): una corsia vista di lato.
##   - a sinistra la torre del necromante, che i nemici cercano di raggiungere
##   - al centro la griglia di schieramento: il giocatore può evocare le unità
##     in qualsiasi casella. Colonne e file si scelgono dall'Inspector.
##   - a destra la striscia di spawn: i nemici compaiono in un punto qualsiasi
##     e avanzano verso sinistra, senza un percorso prestabilito
##
## PIXEL ART: tutta la grafica è in tile da 16x16 (assets/sprites.png) in
## scala di grigi. Ogni pixel dell'arte diventa un quadrato di `px` x `px`
## pixel sullo schermo, e tutte le posizioni sono allineate a quella griglia.
##
## COORDINATE: la logica di gioco usa coordinate di TERRENO in pixel
## dell'arte, relative all'angolo in alto a sinistra della griglia:
##   x = distanza lungo la corsia, y = profondità (0 = fila in fondo)

const Data := preload("res://scripts/game_data.gd")
const Research := preload("res://scripts/research_data.gd")
const UnitScript := preload("res://scripts/unit.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const Pietra := preload("res://scripts/ui_pietra.gd")
const Collezione := preload("res://scripts/collezione.gd")
const AURA_RADIUS := 40.0  # raggio dell'aura del totem
const RAISE_RADIUS := 60.0  # il negromante minore rianima i nemici morti entro questa distanza
const RAISE_MAX := 3
const RAISE_LIFE := 14.0
const ATLAS := preload("res://assets/sprites.png")
# grafica 3D del campo (generata da make_campo_art.py, stesso stile del menu)
const TEX_SKY := preload("res://assets/campo/cielo.png")
const TEX_GROUND := preload("res://assets/campo/terreno.png")
const TEX_TILES := preload("res://assets/campo/lastre.png")
const TEX_TOWER := preload("res://assets/campo/torre.png")
const TEX_TOWER_MERLI := preload("res://assets/campo/torre_merli.png")
const TEX_PILLAR := preload("res://assets/campo/pilastro.png")

enum State { DEPLOY, PLAYING, LEVEL_UP, PLACING, GAME_OVER, VICTORY }

@export_group("Griglia di schieramento")
## Lunghezza della griglia: numero di caselle lungo la corsia.
@export_range(1, 20) var colonne := 9
## Larghezza della griglia: numero di file in profondità.
@export_range(1, 10) var file := 4
## Lato di una casella, in tile da 16x16 pixel.
@export_range(1, 4) var tile_per_casella := 2
@export_group("Schermo")
## Quanti pixel dello schermo per ogni pixel dell'arte. Se la mappa non entra
## nello schermo, il gioco usa automaticamente la scala più grande che entra.
@export_range(1, 6) var scala_pixel := 3
@export_group("Interfaccia")
## Il tuo tema (.tres). Se lo lasci vuoto si usa il tema in scala di grigi.
@export var tema_ui: Theme

@export_group("Torre del necromante", "torre_")
## Attiva: la torre si mette da sola sul bordo sinistro della griglia (anche se
## cambi colonne, file, dimensione delle caselle o sposti la griglia) e il
## segnaposto "Torre" la segue nell'editor. Disattiva: la posizioni tu con il
## segnaposto "Torre" (la base resta comunque dentro il campo).
@export var torre_attaccata_alla_griglia := true
## Su quale fila sta la torre quando è attaccata alla griglia
## (0 = quella in fondo, -1 = quella davanti).
@export_range(-1, 9) var torre_fila := -1
## Fin dove spara il necromante, misurato dal lato destro della torre, in pixel
## dell'arte (32 = una casella). La ricerca "Occhio della notte" la aumenta.
@export_range(8, 600, 1) var torre_gittata: float = Data.NECRO_RANGE

## STATISTICHE DEGLI SCHELETRI. I valori di partenza vengono da game_data.gd.
## Le ricerche e i potenziamenti del level-up si applicano sopra questi valori.
## La velocità d'attacco è in attacchi al secondo; la gittata in pixel
## dell'arte (una casella misura 32).
@export_group("Soldato scheletro", "soldato_")
@export_range(1, 2000, 1) var soldato_vita: float = Data.UNITS["soldato"]["hp"]
@export_range(0, 500, 0.5) var soldato_attacco: float = Data.UNITS["soldato"]["dmg"]
## Attacchi al secondo.
@export_range(0.1, 10, 0.01) var soldato_velocita_attacco: float = 1.0 / Data.UNITS["soldato"]["cooldown"]
@export_group("Arciere scheletro", "arciere_")
@export_range(1, 2000, 1) var arciere_vita: float = Data.UNITS["arciere"]["hp"]
@export_range(0, 500, 0.5) var arciere_attacco: float = Data.UNITS["arciere"]["dmg"]
## Attacchi al secondo.
@export_range(0.1, 10, 0.01) var arciere_velocita_attacco: float = 1.0 / Data.UNITS["arciere"]["cooldown"]
## Distanza massima di tiro, in pixel dell'arte (32 = una casella).
@export_range(8, 400, 1) var arciere_gittata: float = Data.UNITS["arciere"]["range"]
@export_group("Scheletro mago", "mago_")
@export_range(1, 2000, 1) var mago_vita: float = Data.UNITS["mago"]["hp"]
@export_range(0, 500, 0.5) var mago_attacco: float = Data.UNITS["mago"]["dmg"]
## Attacchi al secondo.
@export_range(0.1, 10, 0.01) var mago_velocita_attacco: float = 1.0 / Data.UNITS["mago"]["cooldown"]
## Distanza massima di tiro, in pixel dell'arte (32 = una casella).
@export_range(8, 400, 1) var mago_gittata: float = Data.UNITS["mago"]["range"]
@export_group("Scheletro gigante", "gigante_")
@export_range(1, 5000, 1) var gigante_vita: float = Data.UNITS["gigante"]["hp"]
@export_range(0, 500, 0.5) var gigante_attacco: float = Data.UNITS["gigante"]["dmg"]
## Attacchi al secondo.
@export_range(0.1, 10, 0.01) var gigante_velocita_attacco: float = 1.0 / Data.UNITS["gigante"]["cooldown"]

## POSIZIONI: nella scena ci sono due nodi figli da spostare nell'editor
## (trascinandoli nella vista 2D o dal loro Transform nell'Inspector):
##   Griglia  -> angolo in alto a sinistra della griglia di schieramento
##   Torre    -> centro della base della torre
## Se uno dei due manca, la sua posizione viene calcolata in automatico.

# --- Misure in pixel dell'arte ---------------------------------------------
const TILE := 16
const TOWER_W := 48
const TOWER_H := 96
const SPAWN_W := 16
const LEFT_MARGIN := 6
const WALL_X := -4.0  # i nemici colpiscono la torre quando arrivano qui
const UI_TOP := 72  # pixel dello schermo occupati dalla barra in alto
const HINT_SPACE := 48  # spazio per i messaggi sotto la barra
const UI_BOTTOM := 96  # spazio per il pulsante "Inizia ondate"
const MAX_DEPLOY := 3  # squadre schierabili senza ricerche (vedi "Legione")
const SAVE_PATH := "user://progressi.cfg"

# Regioni dell'atlante
const R_GRASS_A := Rect2(0, 32, 16, 16)
const R_GRASS_B := Rect2(16, 32, 16, 16)
const R_DIRT := Rect2(32, 32, 16, 16)
const R_SPAWN := Rect2(48, 32, 16, 16)
const R_NECRO := Rect2(64, 32, 16, 16)
const R_TOWER := Rect2(0, 48, 48, 96)
# torre 3D: l'immagine ha 30 pixel in più sopra (torretta) e 3 di margine
const TOWER_IMG_OFFSET := Vector2(-3, -30)
const TOWER_WINDOWS := [Vector2(6, 20), Vector2(26, 20), Vector2(6, 46), Vector2(26, 46)]
const TOWER_DOOR_X := 18.0  # centro del portone, dal bordo sinistro della torre
const NECRO_FEET := Vector2(24, 9)  # dove sta il necromante sul tetto
# atlante lastre.png
const R_SLABS := [Rect2(0, 0, 16, 16), Rect2(16, 0, 16, 16), Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16), Rect2(64, 0, 16, 16), Rect2(80, 0, 16, 16)]
const R_FACE := [Rect2(0, 16, 16, 16), Rect2(16, 16, 16, 16), Rect2(32, 16, 16, 16)]
const R_WALL_OK := Rect2(48, 16, 16, 16)
const R_WALL_BROKEN := Rect2(64, 16, 16, 16)
const R_WALL_SKULL := Rect2(80, 16, 16, 16)
const R_WALL_TORCH := Rect2(96, 16, 16, 16)
const R_PROPS_SMALL := [Rect2(0, 32, 16, 16), Rect2(16, 32, 16, 16), Rect2(32, 32, 16, 16), Rect2(48, 32, 16, 16),
	Rect2(64, 32, 16, 16), Rect2(80, 32, 16, 16), Rect2(96, 32, 16, 16), Rect2(112, 32, 16, 16)]
const R_PROPS_TALL := [Rect2(0, 48, 16, 32), Rect2(16, 48, 16, 32), Rect2(32, 48, 16, 32)]
const FACE_H := 7  # spessore visibile del bordo davanti del campo
# icone 16x16 in sprites.png
const R_IC_FIRE := Rect2(48, 48, 16, 16)
const R_IC_BOLT := Rect2(64, 48, 16, 16)
const R_IC_HEAL := Rect2(80, 48, 16, 16)
const R_IC_HOURGLASS := Rect2(96, 48, 16, 16)
const R_IC_STAR := Rect2(112, 48, 16, 16)
const R_IC_EYE := Rect2(48, 64, 16, 16)
const R_IC_HEART := Rect2(80, 64, 16, 16)
const R_IC_SWORD := Rect2(96, 64, 16, 16)
const R_IC_FAST := Rect2(48, 80, 16, 16)
const ABILITY_ICONS := {"palla_di_fuoco": R_IC_FIRE, "area_curativa": R_IC_HEAL, "saetta": R_IC_BOLT}
# crepe della torre (coordinate nel rettangolo della torre), una lista per livello di danno
const TOWER_CRACKS := [
	[[Vector2(9, 15), Vector2(9, 19), Vector2(11, 19), Vector2(11, 24), Vector2(10, 24), Vector2(10, 28)],
	 [Vector2(28, 62), Vector2(28, 66), Vector2(30, 66), Vector2(30, 71)]],
	[[Vector2(10, 28), Vector2(10, 33), Vector2(12, 33), Vector2(12, 38)],
	 [Vector2(22, 34), Vector2(22, 38), Vector2(20, 38), Vector2(20, 44), Vector2(21, 44), Vector2(21, 49)],
	 [Vector2(33, 16), Vector2(33, 22), Vector2(31, 22), Vector2(31, 26)]],
	[[Vector2(3, 58), Vector2(3, 63), Vector2(5, 63), Vector2(5, 69), Vector2(4, 69), Vector2(4, 74)],
	 [Vector2(30, 71), Vector2(30, 77), Vector2(32, 77), Vector2(32, 84)],
	 [Vector2(15, 50), Vector2(15, 55), Vector2(17, 55), Vector2(17, 58)],
	 [Vector2(21, 49), Vector2(21, 54), Vector2(24, 54), Vector2(24, 60)]],
]
const SKY_FIRES := [Vector2(268, 9), Vector2(318, 7), Vector2(372, 10), Vector2(402, 6)]

# Scala di grigi
const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

var px := 3
var cell := 32
var cols := 9
var rows := 4
var depth := 128.0
var lane_len := 288.0
var wall_x := WALL_X
var origin := Vector2.ZERO  # angolo in alto a sinistra della griglia, in pixel dell'arte
var art_size := Vector2.ZERO  # schermo in pixel dell'arte
var tower_base_y := 0.0  # profondità (terreno) della base della torre

var state: int = State.DEPLOY
var slots: Array = []  # una per casella: {cell, center, kind, units}
var hover_slot := -1

var allies_root: Node2D
var enemies_root: Node2D
var projectiles_root: Node2D
var fx_root: Node2D
var tower_node: Node2D
var tower_flash := 0.0
var necro_flash := 0.0  # bagliore del bastone quando il necromante spara
var _icon_cache := {}
var ambient_node: Node2D  # animazioni dello sfondo (sopra il terreno, sotto le unità)
var front_node: Node2D  # cose davanti alle unità (pilastro crollato del portale)
var amb_t := 0.0
var horizon := 0.0
var props: Array = []  # oggetti decorativi: {r, pos}
var wall_tiles: Array = []  # muretto dietro il campo: {r, x}
var stars: Array = []
var bats: Array = []
var marchers: Array = []  # eroi lontani che marciano verso il portale
var embers: Array = []

var tower_max_hp := Data.TOWER_HP
var tower_hp := Data.TOWER_HP

var necro_level := 1
var necro_xp := 0.0
var necro_xp_next := Data.xp_to_next(1)
var necro_dmg := Data.NECRO_DMG
var necro_cooldown := Data.NECRO_COOLDOWN
var necro_range := Data.NECRO_RANGE
var necro_timer := 0.0

## Moltiplicatori dei buff/debuff scelti durante la run.
var mods := {
	"ally_dmg": 1.0, "ally_rate": 1.0, "ally_hp": 1.0,
	"enemy_dmg": 1.0, "enemy_speed": 1.0, "enemy_hp": 1.0,
}

var wave := 0
var spawn_queue: Array = []
var spawn_timer := 0.0
var wave_running := false
var next_wave_timer := 0.0
var kills := 0

var ability_cd := {}
var selected_ability := ""
var pending_levelups := 0
var pending_summon := ""
var autotest := false

# Effetti dell'albero delle ricerche (vedi _apply_research)
var max_deploy := MAX_DEPLOY
var unlocked_units: Array = ["soldato"]  # la squadra della run (scelta in preparazione)
var unit_ranks := {}  # rango di ogni unità della collezione
var role_bonus := {}  # bonus delle ricerche per ruolo: {"dmg_corpo": 0.12, ...}
var clouds: Array = []  # nubi di peste: {p, t, dps}
var scrolls_earned := 0
var unlocked_abilities: Array = []
var xp_mult := 1.0
var ability_cd_mult := 1.0
var ability_power_mult := 1.0

# Interfaccia
var ui: CanvasLayer
var ui_root: Control
var wave_label: Label
var tower_label: Label
var tower_bar: ProgressBar
var level_label: Label
var xp_bar: ProgressBar
var hint_label: Label
var hint_timer := 0.0
var start_button: Button
var speed_button: Button
var ability_buttons := {}
var modal: PanelContainer
var modal_box: VBoxContainer
var picker: Control  # scelta dell'unità: lapidi attorno alla casella cliccata
var picker_tip: Control  # scheda con le statistiche dell'unità sotto il mouse
var ui_font: Font
var wave_banner: Control  # stendardo con l'ondata e i nemici, accanto al portale
var spell_row: Control  # fila degli incantesimi in basso
var spell_slots := {}
var levelup: Control  # scelta del level-up: tre lapidi
var levelup_opts: Array = []
var next_queue: Array = []  # composizione della prossima ondata (per lo stendardo)
var next_queue_wave := 0
var smoke: Array = []  # fumo della torre danneggiata
var picker_slot := -1
var picker_hover := ""  # unità sotto il mouse nella scelta (per l'anteprima della gittata)
var pause_overlay: Control
var pause_button: Button
var soul_orb: Control  # sfera d'anima del necromante (livello + esperienza)
var orb_flash := 0.0  # bagliore quando il necromante sale di livello
var orb_level := 1
var paused := false


func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0
	_compute_layout()
	_apply_research()
	for r in rows:
		for c in cols:
			slots.append({
				"cell": Vector2i(c, r),
				"center": Vector2((c + 0.5) * cell, (r + 0.5) * cell),
				"kind": "", "units": [],
			})
	tower_node = Node2D.new()
	tower_node.name = "tower"
	tower_node.z_index = int(to_screen(Vector2(0, tower_base_y)).y)
	tower_node.draw.connect(_draw_tower)
	add_child(tower_node)
	ambient_node = Node2D.new()
	ambient_node.name = "ambient"
	ambient_node.z_index = 1
	ambient_node.draw.connect(_draw_ambient)
	add_child(ambient_node)
	front_node = Node2D.new()
	front_node.name = "front"
	front_node.z_index = 2000
	front_node.draw.connect(_draw_front)
	add_child(front_node)
	_setup_scenery()
	for n in ["enemies", "allies", "projectiles", "fx"]:
		var node := Node2D.new()
		node.name = n
		add_child(node)
	enemies_root = $enemies
	allies_root = $allies
	projectiles_root = $projectiles
	fx_root = $fx
	for k in Data.ABILITY_ORDER:
		ability_cd[k] = 0.0
	next_queue = Data.build_wave(1)
	next_queue_wave = 1
	_build_ui()
	_show_deploy_hint()
	if "--autotest" in OS.get_cmdline_user_args():
		_start_autotest()


# --- Layout, proiezione e griglia --------------------------------------------

## Calcola scala dei pixel e posizione della griglia a partire dai valori
## dell'Inspector, centrando torre + griglia + spawn nello schermo.
func _compute_layout() -> void:
	cols = colonne
	rows = file
	cell = TILE * tile_per_casella
	lane_len = cols * cell
	depth = rows * cell
	tower_base_y = depth - cell * 0.5
	wall_x = WALL_X
	var vp := get_viewport_rect().size
	var need_w := LEFT_MARGIN + TOWER_W + 4 + int(lane_len) + SPAWN_W + 4
	px = scala_pixel
	while px > 1:
		var aw := floori(vp.x / px)
		var ah := floori(vp.y / px) - ceili(float(UI_TOP + HINT_SPACE + UI_BOTTOM) / px)
		if need_w <= aw and depth <= ah:
			break
		px -= 1
	if px < scala_pixel:
		push_warning("Griglia %dx%d troppo grande per la scala %d: uso la scala %d." % [cols, rows, scala_pixel, px])
	art_size = Vector2(floori(vp.x / px), floori(vp.y / px))
	var top := ceili(float(UI_TOP + HINT_SPACE) / px)
	var bottom := ceili(float(UI_BOTTOM) / px)
	origin.x = LEFT_MARGIN + TOWER_W + 4 + maxi(0, floori((art_size.x - need_w) / 2.0))
	origin.y = top + maxi(0, floori((art_size.y - top - bottom - depth) / 2.0))
	# la cima della torre (con il necromante) non deve finire sotto la barra
	var tower_top := origin.y + tower_base_y - TOWER_H - 14.0
	var min_top := ceilf(float(UI_TOP) / px) + 2.0
	if tower_top < min_top:
		origin.y += min_top - tower_top
	# posizioni scelte nell'editor (allineate alla griglia dei pixel)
	var grid_marker := get_node_or_null("Griglia") as Node2D
	if grid_marker:
		origin = (grid_marker.position / px).round()
	var tower_marker := get_node_or_null("Torre") as Node2D
	if torre_attaccata_alla_griglia or tower_marker == null:
		wall_x = WALL_X
		tower_base_y = tower_row_base(torre_fila, rows, cell)
	else:
		var base := (tower_marker.position / px).round()
		wall_x = base.x + TOWER_W / 2.0 - origin.x
		# la torre deve poggiare sul campo, sennò i nemici non possono raggiungerla
		tower_base_y = clampf(base.y - origin.y, cell * 0.5, depth)
	_fit_on_screen()


## Se il campo (o la torre) esce dallo schermo, sposta la griglia quanto basta.
## Succede quando cambi colonne/file/caselle senza spostare il segnaposto "Griglia".
func _fit_on_screen() -> void:
	var before := origin
	var tower_left := wall_x - TOWER_W
	var min_x := maxf(2.0, 2.0 - tower_left)
	var max_x := art_size.x - lane_len - SPAWN_W - 2.0
	origin.x = clampf(origin.x, min_x, maxf(min_x, max_x))
	# la cima della torre (torretta compresa) non deve finire sotto la barra in alto
	var min_y := ceilf(float(UI_TOP) / px) + 2.0 - (tower_base_y - TOWER_H + TOWER_IMG_OFFSET.y)
	min_y = maxf(min_y, ceilf(float(UI_TOP) / px) + 14.0)
	# il bordo davanti del campo deve restare dentro lo schermo
	var max_y := art_size.y - depth - FACE_H - 2.0
	origin.y = maxf(origin.y, min_y)
	origin.y = minf(origin.y, maxf(max_y, ceilf(float(UI_TOP) / px)))
	origin = origin.round()
	if origin != before:
		push_warning("Il campo non entrava nello schermo: l'ho spostato di %s pixel. Sposta il segnaposto \"Griglia\" (o riduci colonne/file) per sistemarlo." % str((origin - before) * px))
	if origin.x + lane_len + SPAWN_W > art_size.x or origin.y + depth > art_size.y:
		push_warning("La griglia è troppo grande per lo schermo: riduci colonne, file o caselle dall'Inspector.")


## Legge l'albero delle ricerche e applica i bonus a questa partita.
## L'autotest normale sblocca tutto senza bonus (per misurare il bilanciamento
## di base); con --fresh simula un giocatore che non ha ancora fatto ricerche.
func _apply_research() -> void:
	var args := OS.get_cmdline_user_args()
	var levels: Dictionary = {} if "--autotest" in args else Research.load_state()["levels"]
	var b := Research.bonuses(levels)
	if "--autotest" in args and not "--fresh" in args:
		for k in ["unlock_arciere", "unlock_mago", "unlock_gigante",
				"unlock_palla_di_fuoco", "unlock_area_curativa", "unlock_saetta"]:
			b[k] = 1.0
	tower_max_hp += b.get("tower_hp", 0.0)
	tower_hp = tower_max_hp
	necro_dmg *= 1.0 + b.get("necro_dmg", 0.0)
	necro_cooldown /= 1.0 + b.get("necro_rate", 0.0)
	necro_range = torre_gittata * (1.0 + b.get("necro_range", 0.0))
	xp_mult = 1.0 + b.get("xp", 0.0)
	mods["ally_dmg"] *= 1.0 + b.get("ally_dmg", 0.0)
	mods["ally_hp"] *= 1.0 + b.get("ally_hp", 0.0)
	max_deploy = MAX_DEPLOY + int(b.get("deploy", 0.0))
	# squadra della run: le 4 unità scelte nella preparazione (collezione salvata)
	var col := Collezione.load_state()
	unit_ranks = col["owned"]
	unlocked_units = col["squad"].duplicate()
	if "--autotest" in args:
		unlocked_units = Data.STARTING_UNITS.duplicate()
		unit_ranks = {}
		for a in args:
			if a.begins_with("--squadra="):
				unlocked_units = Array(a.substr(10).split(","))
	for k in b:
		if k.begins_with("dmg_") or k.begins_with("hp_"):
			role_bonus[k] = b[k]
	print("[squadra] unità della run: ", unlocked_units)
	unlocked_abilities = []
	for k in Data.ABILITY_ORDER:
		if b.has("unlock_" + k):
			unlocked_abilities.append(k)
	ability_cd_mult = maxf(0.3, 1.0 - b.get("ability_cd", 0.0))
	ability_power_mult = 1.0 + b.get("ability_power", 0.0)


## Profondità della base della torre quando è attaccata alla griglia
## (usata anche dal segnaposto nell'editor).
static func tower_row_base(fila: int, n_rows: int, cell_size: int) -> float:
	var r := n_rows - 1 if fila < 0 else clampi(fila, 0, n_rows - 1)
	return (r + 0.5) * cell_size


func to_screen(g: Vector2) -> Vector2:
	return (origin + g.round()) * px


func to_ground(s: Vector2) -> Vector2:
	return s / px - origin


## Distanza di un punto del terreno dalla torre (i nemici attaccano a distanza 0).
func tower_distance(g: Vector2) -> float:
	return g.x - wall_x


func slot_index(c: int, r: int) -> int:
	return clampi(r, 0, rows - 1) * cols + clampi(c, 0, cols - 1)


func slot_at_screen(p: Vector2) -> int:
	var g := to_ground(p)
	var c := floori(g.x / cell)
	var r := floori(g.y / cell)
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return -1
	return r * cols + c


func deployed_count() -> int:
	var n := 0
	for s in slots:
		if s["kind"] != "":
			n += 1
	return n


func free_slot_count() -> int:
	return slots.size() - deployed_count()


# --- Ciclo di gioco ----------------------------------------------------------

func is_running() -> bool:
	return state == State.PLAYING and not paused


func _process(delta: float) -> void:
	hover_slot = slot_at_screen(get_global_mouse_position())
	if tower_flash > 0.0:
		tower_flash -= delta
	necro_flash = maxf(0.0, necro_flash - delta)
	orb_flash = maxf(0.0, orb_flash - delta * 1.5)
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.text = ""
	if is_running():
		for k in ability_cd:
			ability_cd[k] = maxf(0.0, ability_cd[k] - delta)
		_process_waves(delta)
		_process_necro(delta)
		_update_clouds(delta)
		if autotest:
			_autotest_cast()
	_update_hud()
	_update_ambient(delta)
	queue_redraw()
	tower_node.queue_redraw()
	ambient_node.queue_redraw()


func _process_waves(delta: float) -> void:
	if wave_running:
		if not spawn_queue.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_enemy(spawn_queue.pop_front())
				spawn_timer = maxf(0.25, 0.8 - wave * 0.006)
		elif _alive_count(enemies_root) == 0:
			wave_running = false
			if wave >= Data.FINAL_WAVE:
				_end_run(true)
				return
			next_wave_timer = 3.0
			_revive_squads()
			set_hint("Ondata %d superata! Il necromante rianima i caduti." % wave, 2.5)
			if wave % Data.WAVES_PER_SCROLL == 0:
				scrolls_earned += 1
				if not autotest:
					Collezione.add_scrolls(1)
				set_hint("Ondata %d superata: hai ottenuto una PERGAMENA! Aprila nel portale." % wave, 4.0)
	else:
		next_wave_timer -= delta
		if next_wave_timer <= 0.0:
			_start_wave(wave + 1)


func _start_wave(n: int) -> void:
	wave = n
	spawn_queue = next_queue.duplicate() if next_queue_wave == n else Data.build_wave(n)
	next_queue = Data.build_wave(n + 1)
	next_queue_wave = n + 1
	spawn_timer = 0.0
	wave_running = true
	if n % Data.BOSS_EVERY == 0:
		set_hint("Ondata %d: arriva un campione degli eroi!" % n, 3.0)
	else:
		set_hint("Ondata %d" % n, 1.5)
	if autotest and n % 5 == 0:
		print("[autotest] ondata %d | torre %.0f/%.0f | livello %d | uccisioni %d | scheletri vivi %d" % [
			n, tower_hp, tower_max_hp, necro_level, kills, _alive_count(allies_root)])


func _spawn_enemy(entry: Dictionary) -> void:
	var u := UnitScript.new()
	u.game = self
	var hp_mult: float = Data.enemy_hp_mult(wave) * mods["enemy_hp"]
	u.setup_enemy(entry["kind"], hp_mult, Data.enemy_dmg_mult(wave), entry["boss"])
	# punto qualsiasi della striscia di spawn
	u.ground = Vector2(lane_len + randf_range(3.0, SPAWN_W - 3.0), randf_range(5.0, depth - 2.0))
	enemies_root.add_child(u)


func _process_necro(delta: float) -> void:
	necro_timer -= delta
	if necro_timer > 0.0:
		return
	var t = nearest_to_tower(enemies_root, necro_range)
	if t != null:
		spawn_projectile(0, Vector2(wall_x - TOWER_W / 2.0, tower_base_y), TOWER_H + 6.0, t, false, necro_dmg, 0.0, false, "necro")
		necro_flash = 0.2
		necro_timer = necro_cooldown


# --- Servizi usati da unità e proiettili --------------------------------------

func _alive_count(root: Node) -> int:
	var n := 0
	for c in root.get_children():
		if not c.dead:
			n += 1
	return n


## Punto del terreno davanti alla porta della torre, da cui escono gli scheletri.
func tower_door() -> Vector2:
	return Vector2(wall_x - TOWER_W + TOWER_DOOR_X, tower_base_y)


func nearest_unit(root: Node, from: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for c in root.get_children():
		if c.dead or not c.visible:  # chi è ancora dentro la torre non si può colpire
			continue
		var d := from.distance_to(c.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


func nearest_to_tower(root: Node, max_dist: float):
	var best = null
	var best_d := max_dist
	for c in root.get_children():
		if c.dead:
			continue
		var d := tower_distance(c.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


func damage_area(center: Vector2, area_radius: float, amount: float, target_team: int, attacker = null) -> void:
	var root := enemies_root if target_team == 1 else allies_root
	for c in root.get_children():
		if not c.dead and center.distance_to(c.ground) <= area_radius + c.radius:
			c.take_damage(amount, attacker)


func spawn_projectile(team: int, from: Vector2, from_height: float, target, to_tower: bool,
		dmg: float, splash: float, magic: bool, look_override: String = "", shooter = null) -> void:
	var p := ProjectileScript.new()
	p.game = self
	p.team = team
	p.shooter = shooter
	p.target = target
	p.to_tower = to_tower
	p.dmg = dmg
	p.splash = splash
	p.look = look_override if look_override != "" else ("magic" if magic else "arrow")
	p.ground = from
	p.height = from_height
	p.start_height = from_height
	projectiles_root.add_child(p)


## Effetto sul corpo di un'unità (fendenti, scintille): `lift` è l'altezza da terra
## in pixel dell'arte, `dir` il verso (1 = verso destra).
func spawn_unit_fx(g: Vector2, kind: String, lift: float, dir: float = 1.0, life: float = 0.2) -> void:
	var f := FxScript.new()
	f.kind = kind
	f.color = C6
	f.life = life
	f.dir = 1.0 if dir >= 0.0 else -1.0
	f.scale = Vector2.ONE * px
	f.position = to_screen(g) - Vector2(0, roundf(lift) * px)
	f.z_index = 3000
	fx_root.add_child(f)


## Icona in pixel art di uno scheletro (primo frame dell'atlante, ingrandito senza sfocare).
func unit_icon(kind: String, size: int = 48) -> Texture2D:
	var key := "%s_%d" % [kind, size]
	if not _icon_cache.has(key):
		var img := Data.ally_texture(kind).get_image().get_region(Rect2i(Data.ally_region(kind)))
		img.resize(size, size, Image.INTERPOLATE_NEAREST)
		_icon_cache[key] = ImageTexture.create_from_image(img)
	return _icon_cache[key]


## Effetto disegnato sul terreno (onde, fulmini).
func spawn_ground_fx(g: Vector2, fx_radius: float, color: Color, life: float, kind: String = "ring") -> void:
	var f := FxScript.new()
	f.kind = kind
	f.radius = fx_radius
	f.color = color
	f.life = life
	f.scale = Vector2.ONE * px
	f.position = to_screen(g)
	f.z_index = 3000
	fx_root.add_child(f)


func damage_tower(amount: float) -> void:
	if state != State.PLAYING:
		return
	tower_hp -= amount
	tower_flash = 0.15
	if tower_hp <= 0.0:
		tower_hp = 0.0
		_end_run(false)


func on_enemy_killed(u) -> void:
	kills += 1
	_try_raise(u)
	necro_xp += u.xp_value * xp_mult
	while necro_xp >= necro_xp_next:
		necro_xp -= necro_xp_next
		necro_level += 1
		necro_xp_next = Data.xp_to_next(necro_level)
		pending_levelups += 1
	if pending_levelups > 0 and state == State.PLAYING:
		call_deferred("_open_level_up")


## La casella resta occupata anche se la squadra muore tutta:
## a fine ondata viene rianimata (vedi _revive_squads).
func on_ally_died(u) -> void:
	for s in slots:
		if u in s["units"]:
			s["units"].erase(u)


# --- Schieramento ------------------------------------------------------------

func _spawn_squad(idx: int, kind: String) -> void:
	var s: Dictionary = slots[idx]
	s["kind"] = kind
	s["units"] = []
	var n: int = Data.UNITS[kind]["count"]
	var spread := cell * 0.22
	for i in n:
		var u := UnitScript.new()
		u.game = self
		u.setup_ally(kind, mods["ally_hp"], ally_stats(kind))
		var off := Vector2.ZERO if n == 1 else Vector2.from_angle(TAU * i / n - PI / 2.0) * spread
		u.home = s["center"] + off
		# escono dalla porta della torre uno dopo l'altro e marciano fino alla casella
		u.ground = tower_door() + Vector2(0, randf_range(0.0, 2.0))
		u.entering = true
		u.enter_delay = 0.05 + i * 0.22
		u.visible = false
		allies_root.add_child(u)
		s["units"].append(u)
	spawn_ground_fx(s["center"], cell * 0.45, C6, 0.45)


## A fine ondata ogni squadra torna al completo e a piena vita.
## Cura solo gli scheletri: la torre non si cura mai.
func _revive_squads() -> void:
	for i in slots.size():
		var kind: String = slots[i]["kind"]
		if kind == "":
			continue
		var full: bool = slots[i]["units"].size() == Data.UNITS[kind]["count"]
		if full:
			for u in slots[i]["units"]:
				u.hp = u.max_hp
		else:
			_remove_squad(i)
			_spawn_squad(i, kind)


func _remove_squad(idx: int) -> void:
	var s: Dictionary = slots[idx]
	for u in s["units"]:
		u.queue_free()
	s["units"] = []
	s["kind"] = ""


## Statistiche base di uno scheletro, prese dall'Inspector del nodo Main.
## Le quattro unità di base usano i valori dell'Inspector; le altre quelli di
## game_data.gd. Il rango (doppioni delle pergamene) aumenta vita e danno.
func ally_stats(kind: String) -> Dictionary:
	var d: Dictionary = Data.UNITS[kind]
	var st := {"hp": d["hp"], "dmg": d["dmg"], "cooldown": d["cooldown"], "range": d["range"]}
	if get(kind + "_vita") != null:
		st["hp"] = get(kind + "_vita")
		st["dmg"] = get(kind + "_attacco")
		st["cooldown"] = 1.0 / maxf(0.01, get(kind + "_velocita_attacco"))
		if not d["melee"]:
			st["range"] = get(kind + "_gittata")
	var rank: int = unit_ranks.get(kind, 1)
	var rm := Collezione.rank_mult(rank)
	st["hp"] *= rm * (1.0 + role_bonus.get("hp_" + d["role"], 0.0))
	st["dmg"] *= rm
	st["rank"] = rank
	return st


## Bonus delle ricerche per ruolo (es. role_mult("distanza", "dmg")).
func role_mult(role: String, stat: String) -> float:
	return 1.0 + role_bonus.get(stat + "_" + role, 0.0)


## +25% danni e velocità d'attacco vicino a un totem d'ossa.
func aura_bonus(u) -> float:
	if u.special == "aura":
		return 1.0
	for c in allies_root.get_children():
		if c.special == "aura" and not c.dead and c.visible and c.ground.distance_to(u.ground) <= AURA_RADIUS:
			return 1.25
	return 1.0


## Lo scheletro che provoca (scudiero, muro d'ossa) più vicino, entro `dist`.
func nearest_taunter(from: Vector2, dist: float):
	var best = null
	var best_d := dist
	for c in allies_root.get_children():
		if c.dead or not c.visible or c.entering or not (c.special == "provoca" or c.special == "muro"):
			continue
		var d := from.distance_to(c.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


## Nube di peste: avvelena (danno nel tempo) e rallenta i nemici dentro.
func add_plague_cloud(g: Vector2, dps: float, _rank: int = 1) -> void:
	clouds.append({"p": g, "t": 3.0, "dps": dps})


func _update_clouds(delta: float) -> void:
	for cl in clouds:
		cl["t"] -= delta
		for c in enemies_root.get_children():
			if not c.dead and c.ground.distance_to(cl["p"]) <= 16.0 + c.radius:
				c.poison(cl["dps"] * delta)
				c.slow_t = 0.4
				c.slow_k = 0.3
	clouds = clouds.filter(func(cl): return cl["t"] > 0.0)


## Il negromante minore rialza come scheletro un nemico morto vicino a lui.
func _try_raise(dead_enemy) -> void:
	for n in allies_root.get_children():
		if n.special != "rianima" or n.dead or n.ground.distance_to(dead_enemy.ground) > RAISE_RADIUS:
			continue
		var active := 0
		for m in allies_root.get_children():
			if m.summoner == n and not m.dead:
				active += 1
		if active >= RAISE_MAX:
			continue
		var u := UnitScript.new()
		u.game = self
		u.setup_ally("soldato", mods["ally_hp"] * 0.6, ally_stats("soldato"))
		u.ground = dead_enemy.ground
		u.home = dead_enemy.ground
		u.life_left = RAISE_LIFE
		u.summoner = n
		allies_root.add_child(u)
		spawn_ground_fx(u.ground, 6.0, C6, 0.4)
		spawn_unit_fx(u.ground, "spark", 6.0, 1.0, 0.3)
		return


func is_ranged(kind: String) -> bool:
	return kind != "" and not Data.UNITS[kind]["melee"]


## Gittata in caselle, per i testi.
func _range_cells(kind: String) -> String:
	return ("%.1f" % (ally_stats(kind)["range"] / cell)).replace(".", ",")


## Scelta dell'unità da evocare: una lapide per unità attorno alla casella
## cliccata, così la mappa resta visibile. Passando il mouse su una lapide si
## vedono le statistiche e, per le unità a distanza, la gittata sulla griglia.
## Tasti 1-4 per scegliere al volo. Le unità non ancora ricercate sono incatenate.
func _open_unit_picker(idx: int) -> void:
	picker_slot = idx
	picker_hover = ""
	for c in picker.get_children():
		if c != picker_tip:
			picker.remove_child(c)
			c.queue_free()
	var vp := get_viewport_rect().size
	var cell_rect := Rect2(to_screen(slots[idx]["center"] - Vector2.ONE * cell / 2.0), Vector2.ONE * cell * px)
	var size := Vector2(94, 104)
	var c := cell_rect.get_center()
	var gap := 6.0
	var spots := [
		Vector2(c.x - size.x / 2.0, cell_rect.position.y - size.y - gap),  # sopra
		Vector2(cell_rect.end.x + gap, c.y - size.y / 2.0),  # destra
		Vector2(c.x - size.x / 2.0, cell_rect.end.y + gap),  # sotto
		Vector2(cell_rect.position.x - size.x - gap, c.y - size.y / 2.0),  # sinistra
	]
	for i in unlocked_units.size():
		var k: String = unlocked_units[i]
		var p: Vector2 = spots[i % spots.size()]
		p.x = clampf(p.x, 8.0, vp.x - size.x - 8.0)
		p.y = clampf(p.y, UI_TOP + 8.0, vp.y - size.y - 8.0)
		var b := _flat_button()
		b.position = p.round()
		b.size = size
		b.disabled = not k in unlocked_units
		b.mouse_entered.connect(func():
			picker_hover = k
			picker.queue_redraw())
		b.mouse_exited.connect(func():
			if picker_hover == k:
				picker_hover = ""
			picker.queue_redraw())
		b.pressed.connect(_pick_unit.bind(idx, k))
		b.draw.connect(_draw_unit_tomb.bind(b, k, i))
		b.set_meta("kind", k)
		picker.add_child(b)
	picker.move_child(picker_tip, -1)
	picker.show()


func _flat_button() -> Button:
	var b := Button.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _draw_unit_tomb(b: Button, k: String, i: int) -> void:
	var locked := not k in unlocked_units
	var hot := picker_hover == k and not locked
	var r := Rect2(Vector2(0, -4 if hot else 0), b.size)
	Pietra.tomb(b, r, Color("8a8a8a") if hot else (C3 if locked else C4), hot)
	b.draw_texture_rect_region(Data.ally_texture(k), Rect2(Vector2(r.get_center().x - 24, r.position.y + 10), Vector2(48, 48)),
		Data.ally_region(k), Color(1, 1, 1, 0.35 if locked else 1.0))
	var label := k.to_upper()
	var fs := 16 if ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= r.size.x - 10 else 12
	Pietra.text_c(b, ui_font, r.get_center().x, r.position.y + 60 + (16 - fs) / 2, label, fs, C5 if locked else C6)
	Pietra.text_c(b, ui_font, r.get_center().x, r.position.y + 79, "ricerca" if locked else "[%d]" % (i + 1), 16, C1, false)
	if locked:  # catene incrociate e lucchetto
		var a := r.position + Vector2(10, 14)
		var z := r.position + Vector2(r.size.x - 10, 54)
		b.draw_line(a, z, C1, 6.0)
		b.draw_line(Vector2(z.x, a.y), Vector2(a.x, z.y), C1, 6.0)
		var lk := Vector2(r.get_center().x, r.position.y + 34)
		b.draw_rect(Rect2(lk + Vector2(-9, -6), Vector2(18, 15)), C0)
		b.draw_rect(Rect2(lk + Vector2(-6, -3), Vector2(12, 9)), C5)


## Scheda con le statistiche dell'unità sotto il mouse, accanto alla sua lapide.
func _draw_picker_tip() -> void:
	if picker_hover == "":
		return
	var tomb: Control = null
	for c in picker.get_children():
		if c.has_meta("kind") and c.get_meta("kind") == picker_hover:
			tomb = c
	if tomb == null:
		return
	var d: Dictionary = Data.UNITS[picker_hover]
	var lines: Array = ["%s x%d" % [d["ally_name"].to_upper(), d["count"]]]
	if picker_hover in unlocked_units:
		var st := ally_stats(picker_hover)
		var l2 := "Vita %d" % int(st["hp"])
		if st["dmg"] > 0.0:
			l2 += " · Attacco %d" % int(st["dmg"])
		if st["rank"] > 1:
			l2 += " · rango %d" % st["rank"]
		lines.append(l2)
		var l3: String = Data.ROLE_NAMES.get(d["role"], "")
		if is_ranged(picker_hover):
			l3 += " · gittata %d" % int(st["range"])
		lines.append(l3)
	else:
		lines.append("Sbloccalo nell'albero")
		lines.append("delle ricerche")
	var w := 0.0
	for l in lines:
		w = maxf(w, ui_font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var size := Vector2(w + 28, lines.size() * 24 + 18)
	var vp := get_viewport_rect().size
	var pos := Vector2(tomb.position.x + tomb.size.x + 10, tomb.position.y)
	if pos.x + size.x > vp.x - 8:
		pos.x = tomb.position.x - size.x - 10
	pos.y = clampf(pos.y, UI_TOP + 8.0, vp.y - size.y - 8.0)
	var r := Rect2(pos, size)
	picker_tip.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.5))
	picker_tip.draw_rect(r, C5)
	picker_tip.draw_rect(r.grow(-3), C1)
	for i in lines.size():
		Pietra.text(picker_tip, ui_font, r.position + Vector2(14, 10 + i * 24), lines[i], 16, C6 if i == 0 else C5)


func _close_picker() -> void:
	picker.hide()
	picker_slot = -1
	picker_hover = ""


func _pick_unit(idx: int, kind: String) -> void:
	_close_picker()
	_spawn_squad(idx, kind)
	_show_deploy_hint()


func _show_deploy_hint() -> void:
	var n := deployed_count()
	if n < max_deploy:
		set_hint("Clicca una casella della griglia per evocare un'unità (%d/%d). Tasto destro per rimuoverla." % [n, max_deploy])
	else:
		set_hint("Schieramento completo: premi \"Inizia ondate\".")
	if start_button:
		start_button.disabled = n == 0


func _on_start_pressed() -> void:
	if state != State.DEPLOY or deployed_count() == 0:
		return
	state = State.PLAYING
	start_button.hide()
	next_wave_timer = 1.0
	set_hint("Arrivano gli eroi!", 2.0)


# --- Level-up ----------------------------------------------------------------

func _level_up_options() -> Array:
	var pool := [
		{"title": "Furia oscura", "icon": R_IC_STAR, "text": "Attacco necromante +25%", "fn": func(): necro_dmg *= 1.25},
		{"title": "Mano rapida", "icon": R_IC_HOURGLASS, "text": "Velocità d'attacco necromante +20%", "fn": func(): necro_cooldown /= 1.2},
		{"title": "Mura d'ossa", "icon": R_IC_HEART, "text": "Vita torre +25 (massima e attuale)", "fn": func():
			tower_max_hp += 25.0
			tower_hp += 25.0},
		{"title": "Lame affilate", "icon": R_IC_SWORD, "text": "Attacco unità +20%", "fn": func(): mods["ally_dmg"] *= 1.2},
		{"title": "Ossa leggere", "icon": R_IC_FAST, "text": "Velocità d'attacco unità +15%", "fn": func(): mods["ally_rate"] *= 1.15},
		{"title": "Ossa robuste", "icon": R_IC_HEAL, "text": "Vita unità +20%", "fn": func(): _scale_hp(allies_root, "ally_hp", 1.2)},
		{"title": "Nebbia gelida", "icon": R_IC_EYE, "text": "Nemici: velocità -10%", "fn": func(): mods["enemy_speed"] *= 0.9},
		{"title": "Peste", "icon": R_IC_EYE, "text": "Nemici: vita -10%", "fn": func(): _scale_hp(enemies_root, "enemy_hp", 0.9)},
		{"title": "Terrore", "icon": R_IC_EYE, "text": "Nemici: attacco -10%", "fn": func(): mods["enemy_dmg"] *= 0.9},
	]
	if free_slot_count() > 0:
		for k in unlocked_units:
			var d: Dictionary = Data.UNITS[k]
			pool.append({"title": "Evocazione", "text": "Evoca: %s (x%d)" % [d["ally_name"], d["count"]], "summon": k})
	return pool


func _scale_hp(root: Node, mod_key: String, factor: float) -> void:
	mods[mod_key] *= factor
	for u in root.get_children():
		u.max_hp *= factor
		u.hp *= factor


func _open_level_up() -> void:
	if pending_levelups <= 0 or state != State.PLAYING:
		return
	state = State.LEVEL_UP
	selected_ability = ""
	var opts := _level_up_options()
	opts.shuffle()
	opts = opts.slice(0, 3)
	if autotest:
		_choose_level_up(opts[0])
		return
	_show_level_up(opts)


## Tre lapidi che emergono dal terreno, sopra il campo oscurato.
func _show_level_up(opts: Array) -> void:
	levelup_opts = opts
	for c in levelup.get_children():
		levelup.remove_child(c)
		c.queue_free()
	var vp := get_viewport_rect().size
	var size := Vector2(280, 320)
	var gap := 48.0
	var x0 := roundf((vp.x - (size.x * opts.size() + gap * (opts.size() - 1))) / 2.0)
	for i in opts.size():
		var b := _flat_button()
		b.position = Vector2(x0 + i * (size.x + gap), 214)
		b.size = size
		b.pressed.connect(_choose_level_up.bind(opts[i]))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		b.draw.connect(_draw_levelup_card.bind(b, i))
		levelup.add_child(b)
	levelup.show()
	levelup.queue_redraw()


func _draw_levelup_bg() -> void:
	var vp := get_viewport_rect().size
	levelup.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.05, 0.05, 0.66))
	var br := Rect2(vp.x / 2.0 - 240, 45, 480, 124)
	Pietra.banner(levelup, br)
	Pietra.text_c(levelup, ui_font, vp.x / 2.0, 62, "IL NECROMANTE SALE", 24, C0, false)
	Pietra.text_c(levelup, ui_font, vp.x / 2.0, 94, "AL LIVELLO %d" % necro_level, 32, C0, false)
	# terra smossa ai piedi delle lapidi
	levelup.draw_rect(Rect2(150, 534, vp.x - 300, 18), C1)
	levelup.draw_rect(Rect2(150, 534, vp.x - 300, 3), C3)
	for i in 9:
		var x := 176.0 + i * 112.0 + (i % 3) * 17.0
		levelup.draw_rect(Rect2(x, 527 + (i % 2) * 2, 12 + (i % 3) * 3, 9), C3 if i % 2 else C4)
	Pietra.text_c(levelup, ui_font, vp.x / 2.0, 590, "Scegli un dono · tasti 1 2 3", 16, C5)


func _draw_levelup_card(b: Button, i: int) -> void:
	if i >= levelup_opts.size():
		return
	var o: Dictionary = levelup_opts[i]
	var hot := b.is_hovered()
	var r := Rect2(Vector2(0, -12 if hot else 0), b.size + Vector2(0, 12 if hot else 0))
	Pietra.tomb(b, r, C4 if hot else Color("5a5a5a"), hot, 6.0)
	var icon_rect := Rect2(Vector2(r.get_center().x - 48, r.position.y + 34), Vector2(96, 96))
	if o.has("summon"):
		b.draw_texture_rect_region(Data.ally_texture(o["summon"]), icon_rect, Data.ally_region(o["summon"]))
	else:
		b.draw_texture_rect_region(ATLAS, icon_rect, o["icon"])
	Pietra.text_c(b, ui_font, r.get_center().x, r.position.y + 150, String(o["title"]).to_upper(), 24, C6)
	Pietra.text_block(b, ui_font, Vector2(22, r.position.y + 192), r.size.x - 44, o["text"], 16, C6)
	Pietra.text_c(b, ui_font, r.get_center().x, r.end.y - 40, "[%d]" % (i + 1), 16, C1, false)


func _choose_level_up(o: Dictionary) -> void:
	if levelup:
		levelup.hide()
	pending_levelups -= 1
	if o.has("summon"):
		pending_summon = o["summon"]
		if autotest:
			_spawn_squad(_autotest_free_slot(), pending_summon)
			pending_summon = ""
		else:
			state = State.PLACING
			set_hint("Clicca una casella libera della griglia per evocare: %s" % Data.UNITS[pending_summon]["ally_name"])
			return
	else:
		o["fn"].call()
	_resume_after_choice()


func _resume_after_choice() -> void:
	state = State.PLAYING
	if pending_levelups > 0:
		_open_level_up()
	else:
		set_hint("", 0.0)


# --- Abilità -----------------------------------------------------------------

func _select_ability(key: String) -> void:
	if not is_running() or ability_cd[key] > 0.0:
		return
	if not key in unlocked_abilities:
		set_hint("%s non è ancora sbloccata: cercala nell'albero delle ricerche." % Data.ABILITIES[key]["name"], 2.5)
		return
	selected_ability = "" if selected_ability == key else key
	if selected_ability != "":
		set_hint("Clicca sul campo per lanciare %s (tasto destro: annulla)" % Data.ABILITIES[key]["name"])
	else:
		set_hint("", 0.0)


## `g` è il punto del terreno colpito.
func _cast(key: String, g: Vector2) -> void:
	var a: Dictionary = Data.ABILITIES[key]
	var power: float = a["power"] * necro_dmg / Data.NECRO_DMG * ability_power_mult
	ability_cd[key] = a["cooldown"] * ability_cd_mult
	selected_ability = ""
	set_hint("", 0.0)
	match key:
		"palla_di_fuoco":
			damage_area(g, a["radius"], power, 1)
			spawn_ground_fx(g, a["radius"], a["color"], 0.5)
		"saetta":
			damage_area(g, a["radius"], power, 1)
			spawn_ground_fx(g, a["radius"], a["color"], 0.35, "bolt")
		"area_curativa":
			for u in allies_root.get_children():
				if not u.dead and g.distance_to(u.ground) <= a["radius"]:
					u.heal(a["power"])
			spawn_ground_fx(g, a["radius"], a["color"], 0.6)


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		return
	if paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var num: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
		if levelup.visible and num >= 0 and num < levelup_opts.size():
			_choose_level_up(levelup_opts[num])
			return
		if picker.visible and num >= 0 and num < unlocked_units.size():
			_pick_unit(picker_slot, unlocked_units[num])
			return
		match event.keycode:
			KEY_1:
				_select_ability(Data.ABILITY_ORDER[0])
			KEY_2:
				_select_ability(Data.ABILITY_ORDER[1])
			KEY_3:
				_select_ability(Data.ABILITY_ORDER[2])
			KEY_SPACE:
				_cycle_speed()
		return
	if event is InputEventMouseButton and event.pressed and picker.visible:
		_close_picker()  # i clic sulle lapidi li prendono i pulsanti: qualsiasi altro clic chiude
		return
	if not (event is InputEventMouseButton and event.pressed) or modal.visible or levelup.visible:
		return
	var p := get_global_mouse_position()
	var idx := slot_at_screen(p)
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_ability != "":
			selected_ability = ""
			set_hint("", 0.0)
		elif state == State.DEPLOY and idx >= 0 and slots[idx]["kind"] != "":
			_remove_squad(idx)
			_show_deploy_hint()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	match state:
		State.DEPLOY:
			if idx >= 0 and slots[idx]["kind"] == "":
				if deployed_count() < max_deploy:
					_open_unit_picker(idx)
				else:
					set_hint("Puoi schierare %d squadre a inizio partita: togline una (tasto destro) per evocarne un'altra. Le altre arrivano col level-up." % max_deploy, 4.0)
		State.PLACING:
			if idx >= 0 and slots[idx]["kind"] == "":
				_spawn_squad(idx, pending_summon)
				pending_summon = ""
				_resume_after_choice()
		State.PLAYING:
			if selected_ability != "":
				_cast(selected_ability, to_ground(p))


func _cycle_speed() -> void:
	var next := Engine.time_scale + 1.0
	Engine.time_scale = 1.0 if next > 3.0 else next


# --- Fine partita e progressi --------------------------------------------------

func _end_run(won: bool) -> void:
	state = State.VICTORY if won else State.GAME_OVER
	selected_ability = ""
	Engine.time_scale = 1.0
	var cleared := wave if won else maxi(0, wave - 1)
	var earned := cleared + int(kills / 20.0) + (50 if won else 0)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # se non esiste ancora parte da zero
	var total: int = cfg.get_value("progressi", "punti", 0) + earned
	var best: int = maxi(cfg.get_value("progressi", "record_ondata", 0), wave)
	cfg.set_value("progressi", "punti", total)
	cfg.set_value("progressi", "record_ondata", best)
	cfg.save(SAVE_PATH)

	if autotest:
		print("[autotest] fine partita: %s all'ondata %d | livello %d | uccisioni %d | punti %d" % [
			"vittoria" if won else "sconfitta", wave, necro_level, kills, earned])
		get_tree().quit()
		return

	var title := "Hai resistito alle 100 ondate!" if won else "La torre è caduta"
	var body := "Ondata raggiunta: %d   ·   Nemici uccisi: %d\nPunti progresso guadagnati: %d   (totale: %d)\nRecord: ondata %d" % [
		wave, kills, earned, total, best]
	if scrolls_earned > 0:
		body += "\nPergamene ottenute: %d  ·  aprile nel portale del menu" % scrolls_earned
	_show_modal(title, body, [
		["Nuova partita", _restart_game],
		["Cambia squadra", func(): get_tree().change_scene_to_file("res://scenes/preparazione.tscn")],
		["Torna al menu", _go_to_menu],
	])


# --- Autotest (solo da riga di comando: godot -- --autotest) -------------------

func _start_autotest() -> void:
	autotest = true
	if Array(OS.get_cmdline_user_args()).any(func(x): return x.begins_with("--squadra=")):
		# prova di una squadra precisa: tutte e quattro le unità in campo
		var spots := [slot_index(2, 1), slot_index(1, 2), slot_index(1, 1), slot_index(2, 2)]
		for i in mini(4, unlocked_units.size()):
			_spawn_squad(spots[i], unlocked_units[i])
		_on_start_pressed()
		return
	_spawn_squad(slot_index(2, 1), "soldato")
	_spawn_squad(slot_index(1, 2), unlocked_units[1] if unlocked_units.size() > 1 else "soldato")
	_spawn_squad(slot_index(1, 1), unlocked_units[3] if unlocked_units.size() > 3 else "soldato")
	_on_start_pressed()


## Casella libera casuale nelle prime 4 colonne (o la prima libera).
func _autotest_free_slot() -> int:
	var choices := []
	for i in slots.size():
		if slots[i]["kind"] == "" and slots[i]["cell"].x <= 3:
			choices.append(i)
	if not choices.is_empty():
		return choices.pick_random()
	for i in slots.size():
		if slots[i]["kind"] == "":
			return i
	return 0


## Simula un giocatore semplice: lancia le abilità appena sono pronte.
func _autotest_cast() -> void:
	if state != State.PLAYING:
		return
	var t = nearest_to_tower(enemies_root, 999.0)
	if t != null:
		for k in ["saetta", "palla_di_fuoco"]:
			if k in unlocked_abilities and ability_cd[k] <= 0.0:
				_cast(k, t.ground)
				return
	if "area_curativa" in unlocked_abilities and ability_cd["area_curativa"] <= 0.0:
		for u in allies_root.get_children():
			if not u.dead and u.hp < u.max_hp * 0.5:
				_cast("area_curativa", u.ground)
				return


# --- Interfaccia (in scala di grigi) ------------------------------------------

func set_hint(text: String, duration: float = 0.0) -> void:
	if hint_label == null:
		return
	hint_label.text = text
	hint_timer = duration


func _box(bg: Color, border: Color, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(margin)
	return sb


func _make_theme() -> Theme:
	if tema_ui:
		return tema_ui
	var th := Theme.new()
	th.set_stylebox("normal", "Button", _box(C1, C4))
	th.set_stylebox("hover", "Button", _box(C2, C5))
	th.set_stylebox("pressed", "Button", _box(C0, C6))
	th.set_stylebox("disabled", "Button", _box(C0, C2))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C6)
	th.set_color("font_hover_color", "Button", C6)
	th.set_color("font_pressed_color", "Button", C6)
	th.set_color("font_disabled_color", "Button", C3)
	th.set_color("font_color", "Label", C6)
	return th


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C0
	bg.border_color = C3
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	ui.add_child(ui_root)

	ui_font = ui_root.get_theme_default_font()

	# velocità e pausa: due pietre in alto a destra (al posto della barra in alto)
	var vpw := get_viewport_rect().size.x
	speed_button = _flat_button()
	speed_button.position = Vector2(vpw - 16 - 56 - 8 - 64, 16)
	speed_button.size = Vector2(64, 56)
	speed_button.tooltip_text = "Velocità (Spazio)"
	speed_button.pressed.connect(_cycle_speed)
	speed_button.mouse_entered.connect(speed_button.queue_redraw)
	speed_button.mouse_exited.connect(speed_button.queue_redraw)
	speed_button.draw.connect(_draw_speed_button)
	ui_root.add_child(speed_button)
	pause_button = _flat_button()
	pause_button.position = Vector2(vpw - 16 - 56, 16)
	pause_button.size = Vector2(56, 56)
	pause_button.tooltip_text = "Pausa (Esc)"
	pause_button.pressed.connect(toggle_pause)
	pause_button.mouse_entered.connect(pause_button.queue_redraw)
	pause_button.mouse_exited.connect(pause_button.queue_redraw)
	pause_button.draw.connect(func():
		Pietra.stone(pause_button, Rect2(Vector2.ZERO, pause_button.size), C3, pause_button.is_hovered())
		pause_button.draw_rect(Rect2(19, 16, 6, 24), C6)
		pause_button.draw_rect(Rect2(31, 16, 6, 24), C6))
	ui_root.add_child(pause_button)

	# sfera d'anima sopra il necromante: livello ed esperienza
	soul_orb = Control.new()
	soul_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul_orb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	soul_orb.draw.connect(_draw_soul_orb)
	ui_root.add_child(soul_orb)

	# Pulsante grande in basso al centro, visibile solo durante lo schieramento.
	start_button = Button.new()
	start_button.text = "Inizia ondate"
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	start_button.offset_left = -130
	start_button.offset_right = 130
	start_button.offset_top = -80
	start_button.offset_bottom = -24
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	ui_root.add_child(start_button)

	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 22
	hint_label.offset_bottom = 52
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_outline_color", C0)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hint_label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(center)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", _box(C0, C6, 24))
	center.add_child(modal)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 10)
	modal.add_child(modal_box)
	modal.hide()

	# stendardo degli eroi accanto al portale: ondata e nemici in arrivo
	wave_banner = Control.new()
	wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bx := to_screen(Vector2(lane_len + SPAWN_W, 0)).x + 12.0
	wave_banner.position = Vector2(minf(bx, get_viewport_rect().size.x - 88.0), to_screen(Vector2.ZERO).y + 12.0)
	wave_banner.draw.connect(_draw_wave_banner)
	ui_root.add_child(wave_banner)

	# fila degli incantesimi in basso (si vede durante la battaglia)
	spell_row = Control.new()
	spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	spell_row.offset_left = -372
	spell_row.offset_right = 372
	spell_row.offset_top = -74
	spell_row.offset_bottom = -4
	spell_row.draw.connect(func(): Pietra.stone(spell_row, Rect2(Vector2.ZERO, spell_row.size), C3))
	ui_root.add_child(spell_row)
	for i in Data.ABILITY_ORDER.size():
		var k: String = Data.ABILITY_ORDER[i]
		var sb := _flat_button()
		sb.position = Vector2(12 + i * 242, 9)
		sb.size = Vector2(230, 52)
		sb.pressed.connect(_select_ability.bind(k))
		sb.mouse_entered.connect(sb.queue_redraw)
		sb.mouse_exited.connect(sb.queue_redraw)
		sb.draw.connect(_draw_spell_slot.bind(sb, k))
		spell_row.add_child(sb)
		spell_slots[k] = sb

	picker = Control.new()
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(picker)
	picker_tip = Control.new()
	picker_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker_tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker_tip.draw.connect(_draw_picker_tip)
	picker.add_child(picker_tip)
	picker.draw.connect(picker_tip.queue_redraw)
	picker.hide()

	levelup = Control.new()
	levelup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	levelup.mouse_filter = Control.MOUSE_FILTER_STOP
	levelup.draw.connect(_draw_levelup_bg)
	ui_root.add_child(levelup)
	levelup.hide()

	pause_overlay = _build_pause_overlay()
	ui_root.add_child(pause_overlay)

	_update_hud()


## Menu di pausa: copre tutto lo schermo e blocca i clic sul gioco sotto.
func _build_pause_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(C0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(C0, C6, 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	for opt in [
		["Riprendi", toggle_pause],
		["Ricomincia partita", _restart_game],
		["Torna al menu", _go_to_menu],
	]:
		var btn := Button.new()
		btn.text = opt[0]
		btn.custom_minimum_size = Vector2(360, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(opt[1])
		box.add_child(btn)
	overlay.hide()
	return overlay


func toggle_pause() -> void:
	# a partita finita la schermata di fine offre già le stesse scelte
	if state == State.GAME_OVER or state == State.VICTORY:
		return
	paused = not paused
	pause_overlay.visible = paused
	if paused:
		selected_ability = ""


func _restart_game() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _show_modal(title: String, body: String, options: Array) -> void:
	for c in modal_box.get_children():
		modal_box.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	modal_box.add_child(t)
	if body != "":
		var b := Label.new()
		b.text = body
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(440, 0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_box.add_child(b)
	for opt in options:
		var btn := Button.new()
		btn.text = opt[0]
		btn.custom_minimum_size = Vector2(440, 44)
		if opt.size() > 2 and opt[2] != null:
			btn.icon = opt[2]
			btn.custom_minimum_size.y = 56
		btn.pressed.connect(opt[1])
		modal_box.add_child(btn)
	modal.show()


func _close_modal() -> void:
	modal.hide()


func _update_hud() -> void:
	if necro_level != orb_level:
		orb_level = necro_level
		orb_flash = 1.0
	speed_button.queue_redraw()
	soul_orb.queue_redraw()
	spell_row.visible = state != State.DEPLOY and state != State.GAME_OVER and state != State.VICTORY
	for k in spell_slots:
		var b: Button = spell_slots[k]
		b.disabled = not k in unlocked_abilities or not is_running() or ability_cd[k] > 0.0
		b.queue_redraw()
	wave_banner.queue_redraw()


func _draw_speed_button() -> void:
	var b := speed_button
	Pietra.stone(b, Rect2(Vector2.ZERO, b.size), C3, b.is_hovered())
	b.draw_texture_rect_region(ATLAS, Rect2(Vector2(16, 4), Vector2(32, 32)), R_IC_FAST, Color(1, 1, 1, 0.5 + 0.5 * minf(1.0, Engine.time_scale - 1.0)))
	Pietra.text_c(b, ui_font, b.size.x / 2.0, 34, "x%d" % int(Engine.time_scale), 16, C6)


## Sfera d'anima sopra il necromante: si riempie con l'esperienza, dentro c'è il livello.
## Con il mouse sulla torre mostra anche la sua vita.
func _draw_soul_orb() -> void:
	var n := soul_orb
	var pos := origin + Vector2(wall_x, tower_base_y) - Vector2(TOWER_W, TOWER_H)
	var c := ((pos + Vector2(40, -24)) * px).round() + Vector2(1, 1)
	var r := 27.0
	var fill := clampf(necro_xp / maxf(1.0, necro_xp_next), 0.0, 1.0)
	var level_y := c.y + r - fill * 2.0 * r
	# cerchio a righe di 3 pixel (aspetto pixel art)
	for row in range(int(-r - 6), int(r + 6), 3):
		var y := c.y + row
		var half_out := floorf(sqrt(maxf(0.0, (r + 6) * (r + 6) - (row + 1.5) * (row + 1.5))) / 3.0) * 3.0
		var half_b := floorf(sqrt(maxf(0.0, (r + 3) * (r + 3) - (row + 1.5) * (row + 1.5))) / 3.0) * 3.0
		var half := floorf(sqrt(maxf(0.0, r * r - (row + 1.5) * (row + 1.5))) / 3.0) * 3.0
		if half_out > 0.0:
			n.draw_rect(Rect2(c.x - half_out, y, half_out * 2.0, 3), C3)
		if half_b > 0.0:
			n.draw_rect(Rect2(c.x - half_b, y, half_b * 2.0, 3), C0)
		if half > 0.0:
			var col := C1
			if y >= level_y:
				col = C4
			if absf(y - level_y) < 3.0 and fill > 0.0:
				col = C5
			n.draw_rect(Rect2(c.x - half, y, half * 2.0, 3), col)
	if orb_flash > 0.0:
		n.draw_circle(c, r + 8.0 + (1.0 - orb_flash) * 14.0, Color(1, 1, 1, 0.35 * orb_flash))
	Pietra.text_c(n, ui_font, c.x, c.y - 20, "LIV", 16, C6)
	Pietra.text_c(n, ui_font, c.x, c.y - 4, "%d" % necro_level, 24, C6)
	# filo d'anima verso il bastone del necromante
	var dots := [Vector2(-18, 33), Vector2(-24, 40), Vector2(-29, 47)]
	for i in dots.size():
		var a := 0.4 + 0.6 * absf(sin(amb_t * 3.0 - i * 0.9))
		n.draw_rect(Rect2((c + dots[i]).round(), Vector2(3, 3)), Color(C5, a))
	# vita della torre, solo con il mouse sopra
	if _hovering_tower():
		var label := "TORRE %d/%d" % [ceili(tower_hp), int(tower_max_hp)]
		var w := ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24
		var base := (origin + Vector2(wall_x, tower_base_y)) * px
		var box := Rect2(Vector2(base.x - TOWER_W * px / 2.0 - w / 2.0, base.y + 12), Vector2(w, 32))
		box.position.x = maxf(8.0, box.position.x)
		Pietra.stone(n, box, C3)
		Pietra.text(n, ui_font, box.position + Vector2(12, 8), label, 16, C6)


## Uno slot della fila degli incantesimi: icona, tasto, nome e ricarica.
func _draw_spell_slot(b: Button, k: String) -> void:
	var a: Dictionary = Data.ABILITIES[k]
	var r := Rect2(Vector2.ZERO, b.size)
	var cd: float = ability_cd[k]
	var locked: bool = not k in unlocked_abilities
	var ready := not locked and cd <= 0.0 and is_running()
	var aiming := selected_ability == k
	Pietra.stone(b, r, C4 if ready or aiming else C2, aiming or (ready and b.is_hovered()))
	var icon := Rect2(Vector2(6, 6), Vector2(40, 40))
	b.draw_texture_rect_region(ATLAS, icon, ABILITY_ICONS.get(k, R_IC_STAR), Color(1, 1, 1, 1.0 if ready or aiming else 0.4))
	Pietra.text(b, ui_font, Vector2(8, 4), a["key"], 16, C6 if ready else C5)
	if cd > 0.0 and not locked:
		Pietra.text_c(b, ui_font, icon.get_center().x, 16, "%d" % ceili(cd), 16, C6)
	Pietra.text(b, ui_font, Vector2(54, 7), String(a["name"]).to_upper(), 16, C6 if ready or aiming else C5)
	if locked:
		Pietra.text(b, ui_font, Vector2(54, 28), "bloccata", 16, C3, false)
		return
	var bar := Rect2(54, 32, r.size.x - 64, 8)
	b.draw_rect(bar, C1)
	var k_ready := 1.0 if cd <= 0.0 else 1.0 - cd / maxf(0.01, a["cooldown"] * ability_cd_mult)
	if aiming:
		k_ready = 1.0 if int(amb_t * 4.0) % 2 == 0 else 0.0
	b.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(k_ready, 0.0, 1.0)), bar.size.y)), C6 if ready or aiming else C4)


## Nemici dell'ondata in corso (rimasti) o della prossima: [[tipo, quanti, capo]].
func _wave_counts() -> Array:
	var counts := {}
	var src: Array = spawn_queue if wave_running else next_queue
	for e in src:
		var key: String = e["kind"] + ("!" if e["boss"] else "")
		counts[key] = counts.get(key, 0) + 1
	if wave_running:
		for u in enemies_root.get_children():
			if not u.dead:
				var key: String = u.kind + ("!" if u.is_boss else "")
				counts[key] = counts.get(key, 0) + 1
	var out := []
	for k in ["soldato", "arciere", "mago", "gigante", "soldato!", "arciere!", "mago!", "gigante!"]:
		if counts.has(k):
			out.append([k.trim_suffix("!"), counts[k], k.ends_with("!")])
	return out


## Stendardo degli eroi: numero dell'ondata e nemici (rimasti o in arrivo).
func _draw_wave_banner() -> void:
	var n := wave_banner
	var counts := _wave_counts()
	var w := 80.0
	var h := 74.0 + counts.size() * 36.0 + 28.0
	Pietra.banner(n, Rect2(Vector2.ZERO, Vector2(w, h)))
	var title := "ONDATA" if wave_running or wave == 0 else "PROSSIMA"
	var ts := 16 if ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= w - 8 else 12
	Pietra.text_c(n, ui_font, w / 2.0, 12, title, ts, C0, false)
	var num := wave if wave_running else wave + 1
	Pietra.text_c(n, ui_font, w / 2.0, 32, "%d" % mini(num, Data.FINAL_WAVE), 24, C0, false)
	Pietra.text_c(n, ui_font, w / 2.0, 56, "/ %d" % Data.FINAL_WAVE, 12, C2, false)
	for i in counts.size():
		var e: Array = counts[i]
		var y := 74.0 + i * 36.0
		var col: int = UnitScript.ATLAS_COL[e[0]]
		n.draw_texture_rect_region(ATLAS, Rect2(Vector2(6, y), Vector2(32, 32)), Rect2(col * 16, 16, 16, 16))
		if e[2]:  # corona del campione
			n.draw_rect(Rect2(14, y - 4, 16, 4), C0)
			n.draw_rect(Rect2(14, y - 8, 4, 4), C0)
			n.draw_rect(Rect2(20, y - 8, 4, 4), C0)
			n.draw_rect(Rect2(26, y - 8, 4, 4), C0)
		Pietra.text(n, ui_font, Vector2(42, y + 9), "x%d" % e[1], 16, C0, false)


# --- Disegno del campo (pixel art, coordinate in pixel dell'arte) ---------------

## Contorno di 1 pixel dell'arte, allineato alla griglia.
func _px_outline(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), col)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), col)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	_draw_scenery()

	# griglia di schieramento: lastre di pietra in rilievo (2x2 tile per casella)
	var placing := (state == State.DEPLOY and deployed_count() < max_deploy) or state == State.PLACING
	for i in slots.size():
		var s: Dictionary = slots[i]
		var c: Vector2i = s["cell"]
		var tint := Color.WHITE if (c.x + c.y) % 2 == 0 else Color(0.84, 0.84, 0.84)
		# più scuro in fondo, più chiaro davanti: aiuta la profondità
		tint = tint * (0.86 + 0.14 * float(c.y) / maxf(1.0, rows - 1.0))
		tint.a = 1.0
		for ty2 in tile_per_casella:
			for tx2 in tile_per_casella:
				var h := absi(c.x * 31 + c.y * 17 + c.x * c.y * 7) % R_SLABS.size()  # una pietra per casella
				var dst := Rect2(origin + Vector2(c.x * cell + tx2 * TILE, c.y * cell + ty2 * TILE), Vector2(TILE, TILE))
				draw_texture_rect_region(TEX_TILES, dst, R_SLABS[h], tint)
		var rect := Rect2(origin + Vector2(c.x * cell, c.y * cell), Vector2(cell, cell))
		_draw_bevel(self, rect)
		if s["kind"] != "":
			draw_rect(rect, Color(C6, 0.12))
			# icona della squadra solo mentre scegli dove schierare
			if state == State.DEPLOY or state == State.PLACING:
				_draw_cell_badge(rect, s["kind"])
		elif placing and i == hover_slot:
			draw_rect(rect, Color(C6, 0.2))
			_px_outline(self, rect, C6)
	if placing:
		_px_outline(self, Rect2(origin - Vector2.ONE, Vector2(lane_len + 2, depth + 2)), C5)

	# striscia di spawn: lastre in ombra (la nebbia è animata in _draw_ambient)
	var sy := 0.0
	while sy < depth:
		var hh := minf(TILE, depth - sy)
		var r0: Rect2 = R_SLABS[int(sy / TILE) % R_SLABS.size()]
		draw_texture_rect_region(TEX_TILES, Rect2(origin + Vector2(lane_len, sy), Vector2(SPAWN_W, hh)),
			Rect2(r0.position, Vector2(TILE, hh)), Color(0.5, 0.5, 0.5))
		_draw_bevel(self, Rect2(origin + Vector2(lane_len, sy), Vector2(SPAWN_W, hh)), 0.5)
		sy += TILE
	draw_rect(Rect2(origin + Vector2(lane_len, 0), Vector2(1, depth)), Color(C5, 0.6))

	# portata del necromante: con il mouse sulla torre si vede tutta l'area colpita
	if _hovering_tower():
		var x0 := origin.x + roundf(wall_x)
		var rw := roundf(necro_range)
		draw_rect(Rect2(x0, origin.y, rw, depth), Color(C6, 0.1))
		draw_rect(Rect2(x0 + rw, origin.y, 1, depth), C6)
		draw_rect(Rect2(x0 + rw - 1, origin.y, 1, depth), Color(C6, 0.35))
	elif state == State.DEPLOY:
		var nx := origin.x + roundf(wall_x + necro_range)
		var yy := 0.0
		while yy < depth:
			draw_rect(Rect2(nx, origin.y + yy, 1, 2), Color(C6, 0.7))
			yy += 4.0

	# anteprima della gittata delle unità a distanza
	var preview := _range_preview()
	if not preview.is_empty():
		_draw_range(preview[0], preview[1])

	# area dell'abilità selezionata
	if selected_ability != "":
		var ab: Dictionary = Data.ABILITIES[selected_ability]
		var g := to_ground(get_global_mouse_position()).round()
		FxScript.draw_pixel_circle(self, origin + g, ab["radius"], C6)


## Piccola icona (la testa dello scheletro) nell'angolo di una casella occupata.
func _draw_cell_badge(rect: Rect2, kind: String) -> void:
	var top := 3 if kind in ["soldato", "arciere"] else (0 if kind in ["mago", "gigante"] else 2)
	var src := Data.ally_region(kind)
	var p := rect.position + Vector2(2, 2)
	draw_rect(Rect2(p - Vector2.ONE, Vector2(10, 10)), Color(C0, 0.8))
	draw_texture_rect_region(Data.ally_texture(kind), Rect2(p, Vector2(8, 8)), Rect2(src.position + Vector2(4, top), Vector2(8, 8)))


## Il mouse è sopra la torre (o sul necromante in cima)?
func _hovering_tower() -> bool:
	if picker.visible or modal.visible or levelup.visible or paused or selected_ability != "":
		return false
	var m := get_global_mouse_position() / px
	var base := origin + Vector2(wall_x, tower_base_y)
	return Rect2(base - Vector2(TOWER_W, TOWER_H + 30), Vector2(TOWER_W + 6, TOWER_H + 30)).has_point(m)


## Cosa mostrare come anteprima della gittata: [centro sul terreno, gittata] o [].
##  1) l'unità sotto il mouse nella scelta da evocare
##  2) l'unità da piazzare dopo un'evocazione del level-up, sulla casella libera sotto il mouse
##  3) una squadra a distanza già schierata sotto il mouse
func _range_preview() -> Array:
	if picker.visible:
		if picker_slot >= 0 and is_ranged(picker_hover) and picker_hover in unlocked_units:
			return [slots[picker_slot]["center"], ally_stats(picker_hover)["range"]]
		return []
	if modal.visible or levelup.visible or paused or selected_ability != "" or hover_slot < 0:
		return []
	var s: Dictionary = slots[hover_slot]
	if state == State.PLACING and s["kind"] == "" and is_ranged(pending_summon):
		return [s["center"], ally_stats(pending_summon)["range"]]
	if is_ranged(s["kind"]) and state in [State.DEPLOY, State.PLACING, State.PLAYING]:
		return [s["center"], ally_stats(s["kind"])["range"]]
	return []


## Cerchio della gittata a pixel: riempimento leggero e bordo.
func _draw_range(center: Vector2, r: float) -> void:
	var c := origin + center.round()
	var ri := int(r)
	for y in range(-ri, ri + 1):
		var half := floorf(sqrt(r * r - y * y))
		draw_rect(Rect2(c.x - half, c.y + y, half * 2.0 + 1.0, 1), Color(C6, 0.1))
	FxScript.draw_pixel_circle(self, c, r, C6)
	FxScript.draw_pixel_circle(self, c, r - 1.0, Color(C6, 0.35))


## La torre è un nodo a parte con il suo z_index, così le unità nelle file
## davanti le passano davanti e quelle in fondo dietro.
## Ordine: torre, luci delle finestre, necromante, merli davanti (lo coprono dalle ginocchia in giù).
func _draw_tower() -> void:
	var t := tower_node
	t.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var base := origin + Vector2(wall_x, tower_base_y)  # angolo in basso a destra
	var pos := base - Vector2(TOWER_W, TOWER_H)
	# ombra verso destra (la luce viene da in alto a sinistra)
	for i in 5:
		t.draw_rect(Rect2(pos.x - 2 + i * 2, base.y - 1 + i, TOWER_W + 8 - i, 1), Color(0, 0, 0, 0.4 - i * 0.06))
	t.draw_texture(TEX_TOWER, pos + TOWER_IMG_OFFSET)
	if tower_flash > 0.0 and int(tower_flash * 40.0) % 2 == 0:
		t.draw_texture(TEX_TOWER, pos + TOWER_IMG_OFFSET, Color(4, 4, 4, 0.45))
	var dmg := tower_damage_level()
	# finestre che tremolano come candele (in fiamme quando la torre sta crollando)
	for wp in TOWER_WINDOWS:
		var k := 0.12 + 0.22 * absf(sin(amb_t * 3.1 + wp.x * 0.7 + wp.y))
		if dmg >= 3:
			k = 0.45 + 0.3 * absf(sin(amb_t * 11.0 + wp.x))
		t.draw_rect(Rect2(pos + wp + Vector2(0, 1), Vector2(4, 7)), Color(1, 1, 1, k))
		t.draw_rect(Rect2(pos + wp - Vector2(2, 1), Vector2(8, 11)), Color(1, 1, 1, k * 0.25))
	# crepe sempre più grandi
	for lvl in dmg:
		for crack in TOWER_CRACKS[lvl]:
			_draw_crack(t, pos, crack)
	if dmg >= 2:  # macerie alla base
		for rb in [Vector2(-2, 93), Vector2(3, 94), Vector2(37, 92), Vector2(42, 93), Vector2(40, 95)]:
			t.draw_rect(Rect2(pos + rb, Vector2(2, 2)), C4)
			t.draw_rect(Rect2(pos + rb + Vector2(0, 1), Vector2(2, 1)), C2)
	if dmg >= 3:  # stendardo strappato e fiamme dalle finestre
		t.draw_rect(Rect2(pos + Vector2(15, 26), Vector2(4, 9)), C0)
		t.draw_rect(Rect2(pos + Vector2(19, 30), Vector2(3, 5)), C0)
		for wp in TOWER_WINDOWS:
			var hgt := 2.0 + roundf(absf(sin(amb_t * 9.0 + wp.x + wp.y)) * 3.0)
			t.draw_rect(Rect2(pos + wp + Vector2(1, -hgt), Vector2(2, hgt)), C6)
			t.draw_rect(Rect2(pos + wp + Vector2(0, -1), Vector2(4, 2)), C5)
	# il necromante sul tetto, dietro i merli
	var necro := pos + NECRO_FEET - Vector2(8, 15)
	t.draw_texture_rect_region(ATLAS, Rect2(necro, Vector2(16, 16)), R_NECRO)
	t.draw_texture(TEX_TOWER_MERLI, pos + TOWER_IMG_OFFSET)
	if dmg >= 2:  # merli crollati
		for mx in ([24.0] if dmg == 2 else [24.0, 6.0]):
			t.draw_rect(Rect2(pos + Vector2(mx, 5), Vector2(4, 6)), C1)
			t.draw_rect(Rect2(pos + Vector2(mx, 10), Vector2(4, 1)), C3)
	for sm in smoke:
		var a: float = clampf(sm["life"] / sm["max"], 0.0, 1.0)
		var sz: float = sm["size"]
		t.draw_rect(Rect2((sm["p"] as Vector2).round(), Vector2(sz, sz)), Color(0.45, 0.45, 0.45, 0.55 * a))
	var orb := necro + Vector2(14, 2)  # punta del bastone
	var glow := 0.25 + 0.25 * absf(sin(amb_t * 2.2))
	t.draw_rect(Rect2(orb - Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1, glow))
	if necro_flash > 0.0:
		var r := 1.0 + roundf(necro_flash * 15.0)
		t.draw_rect(Rect2(orb - Vector2(r, 0), Vector2(r * 2 + 1, 1)), C6)
		t.draw_rect(Rect2(orb - Vector2(0, r), Vector2(1, r * 2 + 1)), C6)
		t.draw_rect(Rect2(orb - Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1))


## 0 = intatta, 1 = crepe (sotto 75%), 2 = crepe, macerie e fumo (sotto 50%),
## 3 = in fiamme (sotto 25%).
func tower_damage_level() -> int:
	var k := tower_hp / maxf(1.0, tower_max_hp)
	if k < 0.25:
		return 3
	if k < 0.5:
		return 2
	if k < 0.75:
		return 1
	return 0


## Crepa a gradini: segmenti orizzontali/verticali, scuri con un bordo chiaro.
func _draw_crack(ci: CanvasItem, pos: Vector2, pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pos + pts[i]
		var b: Vector2 = pos + pts[i + 1]
		var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x) + 1, absf(b.y - a.y) + 1))
		ci.draw_rect(Rect2(r.position + Vector2(1, 0), r.size), Color(1, 1, 1, 0.18))
		ci.draw_rect(r, C0)


# --- Scenario 3D (stesso stile del menu) ------------------------------------------

func _apron_x() -> float:
	## Bordo sinistro della pedana di pietra: un po' prima della torre.
	var tower_left := origin.x + wall_x - TOWER_W
	return origin.x - ceilf((origin.x - tower_left + 8.0) / TILE) * TILE


## Prepara le posizioni (fisse per tutta la partita) di oggetti, muretto e animazioni.
func _setup_scenery() -> void:
	horizon = origin.y - 24.0
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	var spawn_x := origin.x + lane_len
	var bottom := origin.y + depth + FACE_H
	var ax := _apron_x()
	var tower_rect := Rect2(origin + Vector2(wall_x - TOWER_W - 4, tower_base_y - TOWER_H - 30), Vector2(TOWER_W + 18, TOWER_H + 36))
	# muretto in rovina sul bordo dietro il campo
	wall_tiles.clear()
	var x := ax
	var i := 0
	while x < spawn_x:
		var r: Rect2 = R_WALL_OK
		var h := (i * 37 + 11) % 10
		if i % 4 == 2:
			r = R_WALL_TORCH
		elif h < 2:
			r = R_WALL_BROKEN
		elif h == 5:
			r = R_WALL_SKULL
		wall_tiles.append({"r": r, "x": x})
		x += TILE
		i += 1
	# oggetti: dietro il muretto, a sinistra della torre, davanti al campo, oltre il portale
	props.clear()
	var tries := 0
	while props.size() < 34 and tries < 600:
		tries += 1
		var p := Vector2(rnd.randi_range(-4, int(art_size.x) - 12), rnd.randi_range(int(horizon) + 10, int(art_size.y) + 8))
		var tall := rnd.randf() < 0.3
		var size := Vector2(16, 32 if tall else 16)
		var box := Rect2(p - Vector2(0, size.y), size)
		if box.intersects(Rect2(Vector2(ax - 2, origin.y - 12), Vector2(spawn_x + SPAWN_W - ax + 4, depth + FACE_H + 16))):
			continue  # niente sul campo (né sul muretto)
		if box.intersects(tower_rect):
			continue
		if p.y < origin.y and tall and rnd.randf() < 0.5:
			pass
		elif p.y < origin.y:
			tall = true  # dietro il muretto si vedono solo le cose alte
			size.y = 32
		var region: Rect2
		if tall:
			var k := rnd.randi_range(0, R_PROPS_TALL.size() - 1)
			if p.x > spawn_x - 40:
				k = 2  # stendardi degli eroi vicino al portale
			elif k == 2:
				k = rnd.randi_range(0, 1)
			region = R_PROPS_TALL[k]
		else:
			region = R_PROPS_SMALL[rnd.randi_range(0, R_PROPS_SMALL.size() - 1)]
		var ok := true
		for q in props:
			if absf(q["pos"].x - p.x) < 12 and absf(q["pos"].y - p.y) < 8:
				ok = false
				break
		if ok:
			props.append({"r": region, "pos": p, "flip": rnd.randf() < 0.5})
	props.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	# stelle solo dove nel panorama c'è cielo (non sulle montagne)
	stars.clear()
	var sky_img := TEX_SKY.get_image()
	var sky_top := horizon - TEX_SKY.get_height()
	for k in 200:
		if stars.size() >= 40:
			break
		var sp := Vector2(rnd.randi_range(0, int(art_size.x) - 1), rnd.randi_range(int(ceilf(float(UI_TOP) / px)), int(horizon) - 8))
		var ip := Vector2i(int(sp.x) % sky_img.get_width(), int(sp.y - sky_top))
		if ip.y < 0 or ip.y >= sky_img.get_height() or sky_img.get_pixelv(ip).v < 0.12:
			stars.append({"p": sp, "ph": rnd.randf() * TAU, "sp": rnd.randf_range(1.0, 3.0)})
	bats.clear()
	for k in 3:
		bats.append({"x": rnd.randf_range(0, art_size.x), "y": rnd.randf_range(horizon - 30, horizon - 10),
			"sp": rnd.randf_range(8, 15), "ph": rnd.randf() * TAU})
	marchers.clear()
	for k in 14:
		marchers.append(_new_marcher(rnd, true))


func _new_marcher(rnd: RandomNumberGenerator, anywhere: bool) -> Dictionary:
	var x := rnd.randf_range(-10, art_size.x) if anywhere else rnd.randf_range(-24, -4)
	return {"x": x, "y": rnd.randf_range(horizon + 3, origin.y - 13), "sp": rnd.randf_range(2.5, 5.0),
		"ph": rnd.randf() * TAU, "flag": rnd.randf() < 0.2}


func _update_ambient(delta: float) -> void:
	amb_t += delta
	for b in bats:
		b["x"] += b["sp"] * delta
		if b["x"] > art_size.x + 8:
			b["x"] = -8.0
			b["y"] = randf_range(horizon - 30, horizon - 10)
	var gate := origin.x + lane_len + 4.0
	for m in marchers:
		m["x"] += m["sp"] * delta
		if m["x"] > gate:  # entra nel portale: ne arriva un altro da sinistra
			var rnd := RandomNumberGenerator.new()
			rnd.randomize()
			var n := _new_marcher(rnd, false)
			m.merge(n, true)
	# scintille che salgono dalle torce
	if randf() < delta * 4.0 and not wall_tiles.is_empty():
		var torches := _torch_points()
		var tp: Vector2 = torches[randi() % torches.size()]
		embers.append({"p": tp + Vector2(0, -2), "v": Vector2(randf_range(-2, 2), randf_range(-10, -5)), "life": randf_range(0.6, 1.2)})
	for e in embers:
		e["p"] += e["v"] * delta
		e["life"] -= delta
	embers = embers.filter(func(e): return e["life"] > 0.0)
	# fumo dalla torre danneggiata
	var dmg := tower_damage_level()
	if dmg >= 2 and randf() < delta * (5.0 if dmg == 2 else 12.0):
		var top := origin + Vector2(wall_x, tower_base_y) - Vector2(TOWER_W, TOWER_H)
		var life := randf_range(1.5, 2.8)
		smoke.append({"p": top + Vector2(randf_range(14, 34), randf_range(2, 8)), "v": Vector2(randf_range(1, 5), randf_range(-9, -5)),
			"life": life, "max": life, "size": randf_range(2.0, 4.0) if dmg == 2 else randf_range(3.0, 5.0)})
	for sm in smoke:
		sm["p"] += sm["v"] * delta
		sm["size"] = minf(7.0, sm["size"] + delta * 1.2)
		sm["life"] -= delta
	smoke = smoke.filter(func(sm): return sm["life"] > 0.0)


## Punte delle fiamme di tutte le torce (muretto + pilastro del portale).
func _torch_points() -> Array:
	var pts := []
	for w in wall_tiles:
		if w["r"] == R_WALL_TORCH:
			pts.append(Vector2(w["x"] + 8, origin.y + 1 - TILE + 3))
	pts.append(Vector2(origin.x + lane_len + 8, origin.y + 2 - TEX_PILLAR.get_height() + 31))
	return pts


## Smusso di una lastra: spigolo chiaro in alto a sinistra, ombra in basso a destra.
func _draw_bevel(ci: CanvasItem, r: Rect2, k: float = 1.0) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.2 * k))
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(1, r.size.y - 2)), Color(1, 1, 1, 0.12 * k))
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 1, 1)), Color(0, 0, 0, 0.22 * k))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.5 * k))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 1), Vector2(1, r.size.y - 2)), Color(0, 0, 0, 0.42 * k))


func _draw_prop(ci: CanvasItem, pr: Dictionary) -> void:
	var r: Rect2 = pr["r"]
	var pos: Vector2 = pr["pos"] - Vector2(0, r.size.y)
	var dst := Rect2(pos, r.size)
	if pr["flip"]:
		dst = Rect2(pos + Vector2(r.size.x, 0), Vector2(-r.size.x, r.size.y))
	# più lontano = più scuro (foschia)
	var k := clampf(0.55 + 0.45 * (pr["pos"].y - horizon) / maxf(1.0, origin.y + depth - horizon), 0.55, 1.0)
	ci.draw_texture_rect_region(TEX_TILES, dst, r, Color(k, k, k))


## Cielo, terreno, oggetti, muretto e pedana di pietra (tutto dietro le unità).
func _draw_scenery() -> void:
	var w := art_size.x
	var sky_h := float(TEX_SKY.get_height())
	var sky_top := horizon - sky_h
	if sky_top > 0.0:
		draw_rect(Rect2(0, 0, w, sky_top + 1.0), C0)
	var x := 0.0
	while x < w:
		draw_texture(TEX_SKY, Vector2(x, sky_top))
		var gy := horizon
		draw_texture(TEX_GROUND, Vector2(x, gy))
		gy += TEX_GROUND.get_height()
		while gy < art_size.y:  # schermi molto alti: ripeti la parte davanti del terreno
			var hh := minf(120.0, art_size.y - gy)
			draw_texture_rect_region(TEX_GROUND, Rect2(x, gy, TEX_GROUND.get_width(), hh),
				Rect2(0, TEX_GROUND.get_height() - 120, TEX_GROUND.get_width(), hh))
			gy += hh
		x += TEX_GROUND.get_width()
	# oggetti dietro il muretto
	for pr in props:
		if pr["pos"].y < origin.y:
			_draw_prop(self, pr)
	var ax := _apron_x()
	var spawn_end := origin.x + lane_len + SPAWN_W
	# ombra del campo rialzato sul terreno davanti
	for i in 4:
		draw_rect(Rect2(ax + 2 + i, origin.y + depth + FACE_H + i, spawn_end - ax, 1), Color(0, 0, 0, 0.45 - i * 0.1))
	# faccia frontale del campo (spessore della pedana)
	var fx := ax
	var fi := 0
	while fx < spawn_end:
		var r: Rect2 = R_FACE[fi % R_FACE.size()]
		var ww := minf(TILE, spawn_end - fx)
		draw_texture_rect_region(TEX_TILES, Rect2(fx, origin.y + depth, ww, FACE_H), Rect2(r.position, Vector2(ww, FACE_H)))
		fx += TILE
		fi += 1
	# pedana di pietra sotto la torre (a sinistra della griglia)
	var py := 0.0
	while py < depth:
		var px2 := ax
		while px2 < origin.x:
			var h := absi(int(px2) * 13 + int(py) * 7) % R_SLABS.size()
			var hh := minf(TILE, depth - py)
			var ww := minf(TILE, origin.x - px2)
			draw_texture_rect_region(TEX_TILES, Rect2(px2, origin.y + py, ww, hh), Rect2(R_SLABS[h].position, Vector2(ww, hh)), Color(0.72, 0.72, 0.72))
			_draw_bevel(self, Rect2(px2, origin.y + py, ww, hh), 0.7)
			px2 += TILE
		py += TILE
	draw_rect(Rect2(ax, origin.y, 1, depth), Color(C0, 0.6))
	# muretto in rovina dietro il campo
	for wt in wall_tiles:
		draw_texture_rect_region(TEX_TILES, Rect2(wt["x"], origin.y + 1 - TILE, TILE, TILE), wt["r"])
	# pilastro del portale (dietro)
	draw_texture(TEX_PILLAR, Vector2(origin.x + lane_len, origin.y + 2 - TEX_PILLAR.get_height()))
	# oggetti davanti e ai lati
	for pr in props:
		if pr["pos"].y >= origin.y:
			_draw_prop(self, pr)
	# buio oltre il portale: da lì arrivano gli eroi
	var dark_x := spawn_end
	for y in range(int(horizon), int(art_size.y), 2):
		for xx in range(int(dark_x), int(w), 2):
			var k := (xx - dark_x) / maxf(1.0, w - dark_x)
			if fmod(xx * 0.5 + y * 0.75, 1.0) < 0.5 and k > 0.15:
				draw_rect(Rect2(xx, y, 2, 2), Color(0, 0, 0, 0.35 * k))


## Animazioni dello sfondo: stelle, pipistrelli, fuochi dell'accampamento, eroi
## lontani in marcia, torce, nebbia del portale.
func _draw_ambient() -> void:
	var n := ambient_node
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var t := amb_t
	for st in stars:
		var a := 0.25 + 0.55 * absf(sin(t * st["sp"] + st["ph"]))
		n.draw_rect(Rect2(st["p"], Vector2.ONE), Color(1, 1, 1, a))
	for b in bats:
		var flap := int(t * 10.0 + b["ph"]) % 2
		var p := Vector2(roundf(b["x"]), roundf(b["y"] + sin(t * 2.0 + b["ph"]) * 3.0))
		n.draw_rect(Rect2(p, Vector2(1, 1)), C0)
		n.draw_rect(Rect2(p + Vector2(-2, -flap), Vector2(2, 1)), C0)
		n.draw_rect(Rect2(p + Vector2(1, -flap), Vector2(2, 1)), C0)
	# fuochi dell'accampamento sulle colline
	for f in SKY_FIRES:
		var fp := Vector2(f.x, horizon - f.y)
		if fp.x >= art_size.x:
			continue
		var hgt := 1.0 + roundf(absf(sin(t * 8.0 + f.x)))
		n.draw_rect(Rect2(fp - Vector2(0, hgt), Vector2(1, hgt)), C6)
		n.draw_rect(Rect2(fp - Vector2(2, 3), Vector2(5, 4)), Color(1, 1, 1, 0.07 + 0.05 * absf(sin(t * 5.0 + f.x))))
	# nebbia bassa che scorre sull'orizzonte
	for i in 4:
		var fw := 70.0 + i * 20.0
		var fxp := fmod(t * (3.0 + i) + i * 140.0, art_size.x + fw) - fw
		n.draw_rect(Rect2(roundf(fxp), horizon + 1 + i * 2, fw, 2), Color(1, 1, 1, 0.05))
	# eroi lontani che marciano verso il portale
	for m in marchers:
		var mx := roundf(m["x"])
		var my := roundf(m["y"])
		var step := int(t * 6.0 + m["ph"]) % 2
		var col := Color(0.42, 0.42, 0.42)
		n.draw_rect(Rect2(mx, my - 3, 1, 2), col)
		n.draw_rect(Rect2(mx - (1 if step else 0), my - 1, 1, 1), col)
		n.draw_rect(Rect2(mx + (1 if step else 0), my - 1, 1, 1), col)
		n.draw_rect(Rect2(mx + 1, my - 5, 1, 4), Color(0.3, 0.3, 0.3))  # lancia
		if m["flag"]:
			n.draw_rect(Rect2(mx + 2, my - 5, 2, 2), Color(0.67, 0.67, 0.67))
	# torce
	for tp in _torch_points():
		var hgt := 2.0 + roundf(absf(sin(t * 9.0 + tp.x)) * 2.0)
		n.draw_rect(Rect2(tp.x, tp.y - hgt + 1, 1, hgt), C6)
		n.draw_rect(Rect2(tp.x - 1, tp.y, 3, 1), Color(1, 1, 1, 0.6))
		var k := 0.05 + 0.04 * absf(sin(t * 5.0 + tp.x))
		n.draw_rect(Rect2(tp.x - 5, tp.y - 5, 11, 11), Color(1, 1, 1, k))
		n.draw_rect(Rect2(tp.x - 3, tp.y - 3, 7, 7), Color(1, 1, 1, k))
	for e in embers:
		n.draw_rect(Rect2((e["p"] as Vector2).round(), Vector2.ONE), Color(1, 1, 1, clampf(e["life"], 0.0, 1.0)))
	# nubi di peste sul terreno
	for cl in clouds:
		var a: float = clampf(cl["t"], 0.0, 1.0)
		var cp: Vector2 = origin + (cl["p"] as Vector2).round()
		for yy in range(-6, 7, 2):
			for xx in range(-16, 17, 2):
				if Vector2(xx, yy * 2.4).length() > 16.0:
					continue
				var v := sin(xx * 0.5 + t * 3.0 + yy) * cos(yy * 0.7 - t * 2.0)
				if v > 0.1:
					n.draw_rect(Rect2(cp + Vector2(xx, yy), Vector2(2, 2)), Color(0.55, 0.55, 0.55, 0.45 * a))
	# nebbia che vortica nel portale degli eroi
	var sx := origin.x + lane_len
	for y in range(0, int(depth), 2):
		for xx in range(-4, SPAWN_W + 20, 2):
			var v := sin(xx * 0.35 + t * 1.7 + y * 0.12) * sin(y * 0.21 - t * 1.1 + xx * 0.05)
			if v > 0.35:
				var a := (v - 0.35) * (0.5 if xx < SPAWN_W + 4 else 0.25)
				n.draw_rect(Rect2(sx + xx, origin.y + y, 2, 2), Color(0.8, 0.8, 0.8, a))


## Davanti alle unità: il pilastro crollato del portale (in basso).
func _draw_front() -> void:
	var n := front_node
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var stump := 24.0
	var ph := float(TEX_PILLAR.get_height())
	var base := Vector2(origin.x + lane_len, origin.y + depth + FACE_H)
	n.draw_texture_rect_region(TEX_PILLAR, Rect2(base - Vector2(0, stump), Vector2(16, stump)),
		Rect2(0, ph - stump, 16, stump))
	n.draw_rect(Rect2(base.x + 3, base.y - stump, 10, 1), Color("8a8a8c"))
