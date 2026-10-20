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
const ATLAS := preload("res://assets/sprites.png")

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
var unlocked_units: Array = ["soldato"]
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
var picker: PanelContainer  # scelta dell'unità, accanto alla casella cliccata
var picker_box: VBoxContainer
var picker_slot := -1
var picker_hover := ""  # unità sotto il mouse nella scelta (per l'anteprima della gittata)
var pause_overlay: Control
var pause_button: Button
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
	if tower_marker:
		var base := (tower_marker.position / px).round()
		wall_x = base.x + TOWER_W / 2.0 - origin.x
		tower_base_y = base.y - origin.y
	if origin.x + lane_len + SPAWN_W > art_size.x or origin.y + depth > art_size.y:
		push_warning("La griglia esce dallo schermo: spostala o riducila dall'Inspector.")


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
	unlocked_units = ["soldato"]
	for k in Data.UNIT_ORDER:
		if b.has("unlock_" + k):
			unlocked_units.append(k)
	unlocked_abilities = []
	for k in Data.ABILITY_ORDER:
		if b.has("unlock_" + k):
			unlocked_abilities.append(k)
	ability_cd_mult = maxf(0.3, 1.0 - b.get("ability_cd", 0.0))
	ability_power_mult = 1.0 + b.get("ability_power", 0.0)


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
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.text = ""
	if is_running():
		for k in ability_cd:
			ability_cd[k] = maxf(0.0, ability_cd[k] - delta)
		_process_waves(delta)
		_process_necro(delta)
		if autotest:
			_autotest_cast()
	_update_hud()
	queue_redraw()
	tower_node.queue_redraw()


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
	else:
		next_wave_timer -= delta
		if next_wave_timer <= 0.0:
			_start_wave(wave + 1)


func _start_wave(n: int) -> void:
	wave = n
	spawn_queue = Data.build_wave(n)
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
	return Vector2(wall_x - TOWER_W / 2.0 + 6.0, tower_base_y)


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
		var col: int = UnitScript.ATLAS_COL[kind]
		var img := ATLAS.get_image().get_region(Rect2i(col * 16, 0, 16, 16))
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
func ally_stats(kind: String) -> Dictionary:
	var st := {
		"hp": get(kind + "_vita"),
		"dmg": get(kind + "_attacco"),
		"cooldown": 1.0 / maxf(0.01, get(kind + "_velocita_attacco")),
	}
	if not Data.UNITS[kind]["melee"]:
		st["range"] = get(kind + "_gittata")
	return st


func is_ranged(kind: String) -> bool:
	return kind != "" and not Data.UNITS[kind]["melee"]


## Gittata in caselle, per i testi.
func _range_cells(kind: String) -> String:
	return ("%.1f" % (ally_stats(kind)["range"] / cell)).replace(".", ",")


## Scelta dell'unità da evocare, aperta accanto alla casella cliccata così la
## mappa resta visibile. Passando il mouse su un'unità a distanza si vede la
## sua gittata disegnata sulla griglia.
func _open_unit_picker(idx: int) -> void:
	picker_slot = idx
	picker_hover = ""
	for c in picker_box.get_children():
		picker_box.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "Evoca un'unità   (%d / %d)" % [deployed_count(), max_deploy]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker_box.add_child(title)
	for k in unlocked_units:
		var d: Dictionary = Data.UNITS[k]
		var btn := Button.new()
		btn.text = "%s  (x%d)" % [d["ally_name"], d["count"]]
		if is_ranged(k):
			btn.text += "  ·  gittata %s caselle" % _range_cells(k)
		btn.icon = unit_icon(k)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(400, 56)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_pick_unit.bind(idx, k))
		btn.mouse_entered.connect(func(): picker_hover = k)
		btn.mouse_exited.connect(func(): if picker_hover == k: picker_hover = "")
		picker_box.add_child(btn)
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.custom_minimum_size = Vector2(380, 40)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_close_picker)
	picker_box.add_child(cancel)
	picker.show()
	picker.reset_size()
	# a destra della casella, o a sinistra se non c'è spazio; sempre dentro lo schermo
	var vp := get_viewport_rect().size
	var cell_rect := Rect2(to_screen(slots[idx]["center"] - Vector2.ONE * cell / 2.0), Vector2.ONE * cell * px)
	var size := picker.size
	var pos := Vector2(cell_rect.end.x + 12, cell_rect.get_center().y - size.y / 2.0)
	if pos.x + size.x > vp.x - 8:
		pos.x = cell_rect.position.x - 12 - size.x
	pos.y = clampf(pos.y, UI_TOP + 8, vp.y - size.y - 8)
	pos.x = clampf(pos.x, 8, vp.x - size.x - 8)
	picker.position = pos


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
		{"text": "Attacco necromante +25%", "fn": func(): necro_dmg *= 1.25},
		{"text": "Velocità d'attacco necromante +20%", "fn": func(): necro_cooldown /= 1.2},
		{"text": "Vita torre +25 (massima e attuale)", "fn": func():
			tower_max_hp += 25.0
			tower_hp += 25.0},
		{"text": "Attacco unità +20%", "fn": func(): mods["ally_dmg"] *= 1.2},
		{"text": "Velocità d'attacco unità +15%", "fn": func(): mods["ally_rate"] *= 1.15},
		{"text": "Vita unità +20%", "fn": func(): _scale_hp(allies_root, "ally_hp", 1.2)},
		{"text": "Nemici: velocità -10%", "fn": func(): mods["enemy_speed"] *= 0.9},
		{"text": "Nemici: vita -10%", "fn": func(): _scale_hp(enemies_root, "enemy_hp", 0.9)},
		{"text": "Nemici: attacco -10%", "fn": func(): mods["enemy_dmg"] *= 0.9},
	]
	if free_slot_count() > 0:
		for k in unlocked_units:
			var d: Dictionary = Data.UNITS[k]
			pool.append({"text": "Evoca: %s (x%d)" % [d["ally_name"], d["count"]], "summon": k})
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
	var buttons := []
	for o in opts:
		buttons.append([o["text"], _choose_level_up.bind(o), unit_icon(o["summon"]) if o.has("summon") else null])
	_show_modal("Livello %d!" % necro_level, "Scegli un potenziamento", buttons)


func _choose_level_up(o: Dictionary) -> void:
	_close_modal()
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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_close_picker()  # un clic fuori dalla scelta la chiude (destro sempre)
		elif not picker.get_global_rect().has_point(event.position):
			_close_picker()
		return
	if not (event is InputEventMouseButton and event.pressed) or modal.visible:
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
			if idx >= 0 and slots[idx]["kind"] == "" and deployed_count() < max_deploy:
				_open_unit_picker(idx)
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
	_show_modal(title, body, [
		["Nuova partita", _restart_game],
		["Torna al menu", _go_to_menu],
	])


# --- Autotest (solo da riga di comando: godot -- --autotest) -------------------

func _start_autotest() -> void:
	autotest = true
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

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, UI_TOP)
	var top_style := _box(C0, C3, 12)
	top_style.set_border_width_all(0)
	top_style.border_width_bottom = 3
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", top_style)
	ui_root.add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)

	wave_label = Label.new()
	wave_label.custom_minimum_size = Vector2(150, 0)
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 22)
	row.add_child(wave_label)

	var tbox := VBoxContainer.new()
	tbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tower_label = Label.new()
	tower_bar = _make_bar(C6)
	tbox.add_child(tower_label)
	tbox.add_child(tower_bar)
	row.add_child(tbox)

	var lbox := VBoxContainer.new()
	lbox.alignment = BoxContainer.ALIGNMENT_CENTER
	level_label = Label.new()
	xp_bar = _make_bar(C4)
	lbox.add_child(level_label)
	lbox.add_child(xp_bar)
	row.add_child(lbox)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	for k in Data.ABILITY_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select_ability.bind(k))
		row.add_child(b)
		ability_buttons[k] = b

	speed_button = Button.new()
	speed_button.custom_minimum_size = Vector2(96, 52)
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.pressed.connect(_cycle_speed)
	row.add_child(speed_button)

	pause_button = Button.new()
	pause_button.text = "Pausa\n[Esc]"
	pause_button.custom_minimum_size = Vector2(76, 52)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(toggle_pause)
	row.add_child(pause_button)

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
	hint_label.offset_top = UI_TOP + 12
	hint_label.offset_bottom = UI_TOP + 42
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

	picker = PanelContainer.new()
	picker.add_theme_stylebox_override("panel", _box(C0, C6, 14))
	ui_root.add_child(picker)
	picker_box = VBoxContainer.new()
	picker_box.add_theme_constant_override("separation", 8)
	picker.add_child(picker_box)
	picker.hide()

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
	wave_label.text = "Ondata %d / %d" % [wave, Data.FINAL_WAVE]
	tower_label.text = "Torre  %d / %d" % [ceili(tower_hp), int(tower_max_hp)]
	tower_bar.max_value = tower_max_hp
	tower_bar.value = tower_hp
	level_label.text = "Necromante liv. %d" % necro_level
	xp_bar.max_value = necro_xp_next
	xp_bar.value = necro_xp
	speed_button.text = "Velocità\nx%d" % int(Engine.time_scale)
	for k in ability_buttons:
		var a: Dictionary = Data.ABILITIES[k]
		var b: Button = ability_buttons[k]
		var cd: float = ability_cd[k]
		var status := "pronta" if cd <= 0.0 else "%.0fs" % ceilf(cd)
		if selected_ability == k:
			status = "mira..."
		var locked: bool = not k in unlocked_abilities
		if locked:
			status = "bloccata"
		b.text = "%s [%s]\n%s" % [a["name"], a["key"], status]
		b.disabled = locked or not is_running() or cd > 0.0


# --- Disegno del campo (pixel art, coordinate in pixel dell'arte) ---------------

## Contorno di 1 pixel dell'arte, allineato alla griglia.
func _px_outline(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), col)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), col)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), col)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var w := art_size.x
	var horizon := origin.y - 6.0

	# cielo a bande e luna
	var bands := [C0, C1, C2]
	for i in bands.size():
		var y0 := floorf(horizon * i / bands.size())
		draw_rect(Rect2(0, y0, w, ceilf(horizon / bands.size()) + 1.0), bands[i])
	var moon := Vector2(w - 40, maxf(ceilf(float(UI_TOP) / px) + 12.0, horizon - 34.0))
	for y in range(-6, 7):
		var half := floori(sqrt(36.0 - y * y))
		draw_rect(Rect2(moon.x - half, moon.y + y, half * 2 + 1, 1), C5)
	draw_rect(Rect2(moon.x - 3, moon.y - 2, 2, 2), C4)
	draw_rect(Rect2(moon.x + 2, moon.y + 2, 2, 1), C4)

	# montagne lontane a gradini
	for x in int(w):
		var hgt := 10.0 + 8.0 * absf(sin(x * 0.031)) + 5.0 * absf(sin(x * 0.083 + 1.3))
		draw_rect(Rect2(x, horizon - floorf(hgt), 1, floorf(hgt)), C3 if hgt > 17.0 else C2)

	# terreno attorno al campo
	var ty := horizon
	while ty < art_size.y:
		var tx := 0.0
		while tx < w:
			draw_texture_rect_region(ATLAS, Rect2(tx, ty, TILE, TILE), R_DIRT, Color(0.7, 0.7, 0.7))
			tx += TILE
		ty += TILE

	# griglia di schieramento: ogni casella è fatta di tile d'erba 16x16
	var placing := (state == State.DEPLOY and deployed_count() < max_deploy) or state == State.PLACING
	for i in slots.size():
		var s: Dictionary = slots[i]
		var c: Vector2i = s["cell"]
		var tint := Color.WHITE if (c.x + c.y) % 2 == 0 else Color(0.86, 0.86, 0.86)
		for ty2 in tile_per_casella:
			for tx2 in tile_per_casella:
				var region := R_GRASS_A if (tx2 + ty2 + c.x * 3 + c.y) % 3 != 0 else R_GRASS_B
				var dst := Rect2(origin + Vector2(c.x * cell + tx2 * TILE, c.y * cell + ty2 * TILE), Vector2(TILE, TILE))
				draw_texture_rect_region(ATLAS, dst, region, tint)
		var rect := Rect2(origin + Vector2(c.x * cell, c.y * cell), Vector2(cell, cell))
		if s["kind"] != "":
			draw_rect(rect, Color(C6, 0.12))
			# icona della squadra solo mentre scegli dove schierare
			if state == State.DEPLOY or state == State.PLACING:
				_draw_cell_badge(rect, s["kind"])
		elif placing and i == hover_slot:
			draw_rect(rect, Color(C6, 0.2))
			_px_outline(self, rect, C6)
	# linee della griglia
	for r in rows + 1:
		draw_rect(Rect2(origin + Vector2(0, r * cell), Vector2(lane_len, 1)), Color(C0, 0.45))
	for c in cols + 1:
		draw_rect(Rect2(origin + Vector2(c * cell, 0), Vector2(1, depth)), Color(C0, 0.45))
	if placing:
		_px_outline(self, Rect2(origin - Vector2.ONE, Vector2(lane_len + 2, depth + 2)), C5)

	# striscia di spawn
	var sy := 0.0
	while sy < depth:
		draw_texture_rect_region(ATLAS, Rect2(origin + Vector2(lane_len, sy), Vector2(SPAWN_W, minf(TILE, depth - sy))),
			Rect2(R_SPAWN.position, Vector2(TILE, minf(TILE, depth - sy))))
		sy += TILE
	draw_rect(Rect2(origin + Vector2(lane_len, 0), Vector2(1, depth)), C5)

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
	var col: int = UnitScript.ATLAS_COL[kind]
	var top := 3 if kind in ["soldato", "arciere"] else 0  # mago e gigante hanno cappello/testa più in alto
	var p := rect.position + Vector2(2, 2)
	draw_rect(Rect2(p - Vector2.ONE, Vector2(10, 10)), Color(C0, 0.8))
	draw_texture_rect_region(ATLAS, Rect2(p, Vector2(8, 8)), Rect2(col * 16 + 4, top, 8, 8))


## Il mouse è sopra la torre (o sul necromante in cima)?
func _hovering_tower() -> bool:
	if picker.visible or modal.visible or paused or selected_ability != "":
		return false
	var m := get_global_mouse_position() / px
	var base := origin + Vector2(wall_x, tower_base_y)
	return Rect2(base - Vector2(TOWER_W, TOWER_H + 14), Vector2(TOWER_W, TOWER_H + 14)).has_point(m)


## Cosa mostrare come anteprima della gittata: [centro sul terreno, gittata] o [].
##  1) l'unità sotto il mouse nella scelta da evocare
##  2) l'unità da piazzare dopo un'evocazione del level-up, sulla casella libera sotto il mouse
##  3) una squadra a distanza già schierata sotto il mouse
func _range_preview() -> Array:
	if picker.visible:
		if picker_slot >= 0 and is_ranged(picker_hover):
			return [slots[picker_slot]["center"], ally_stats(picker_hover)["range"]]
		return []
	if modal.visible or paused or selected_ability != "" or hover_slot < 0:
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
func _draw_tower() -> void:
	var t := tower_node
	t.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	var base := origin + Vector2(wall_x, tower_base_y)  # angolo in basso a destra
	var pos := base - Vector2(TOWER_W, TOWER_H)
	# ombra a pixel
	t.draw_rect(Rect2(pos.x - 3, base.y - 1, TOWER_W + 8, 2), Color(0, 0, 0, 0.45))
	t.draw_rect(Rect2(pos.x - 1, base.y + 1, TOWER_W + 4, 1), Color(0, 0, 0, 0.35))
	t.draw_texture_rect_region(ATLAS, Rect2(pos, Vector2(TOWER_W, TOWER_H)), R_TOWER)
	if tower_flash > 0.0 and int(tower_flash * 40.0) % 2 == 0:
		t.draw_rect(Rect2(pos + Vector2(0, 8), Vector2(TOWER_W, TOWER_H - 8)), Color(C6, 0.35))
	# il necromante in piedi tra i merli
	t.draw_texture_rect_region(ATLAS, Rect2(pos + Vector2(TOWER_W / 2.0 - 8, -12), Vector2(16, 16)), R_NECRO)
	if necro_flash > 0.0:
		var orb := pos + Vector2(TOWER_W / 2.0 - 8 + 14, -12 + 2)  # punta del bastone
		var r := 1.0 + roundf(necro_flash * 15.0)
		t.draw_rect(Rect2(orb - Vector2(r, 0), Vector2(r * 2 + 1, 1)), C6)
		t.draw_rect(Rect2(orb - Vector2(0, r), Vector2(1, r * 2 + 1)), C6)
		t.draw_rect(Rect2(orb - Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1))
