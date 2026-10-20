extends Node2D
## Unità generica: scheletro alleato o umano nemico.
##
## La logica lavora in coordinate di TERRENO (`ground`), misurate in pixel
## dell'arte e relative all'angolo in alto a sinistra della griglia:
##   x = distanza lungo la corsia (0 = bordo sinistro, vicino alla torre)
##   y = profondità (0 = fila in fondo, cresce verso lo spettatore)
## game.to_screen() le converte in pixel dello schermo allineati alla griglia
## della pixel art; z_index ordina le unità per profondità.
##
## Grafica: sprite 16x16 dall'atlante assets/sprites.png, con i piedi
## nell'origine del nodo. Il nodo è scalato di game.px, quindi tutto ciò che
## viene disegnato qui (ombra, barra della vita) è in pixel dell'arte.

const Data := preload("res://scripts/game_data.gd")
const ATLAS := preload("res://assets/sprites.png")

const ALLY := 0
const ENEMY := 1
## Colonna dell'atlante per ogni tipo (ogni tipo ha 2 frame affiancati).
const ATLAS_COL := {"soldato": 0, "arciere": 2, "mago": 4, "gigante": 6}
const FRAME_TIME := 0.18
const MUZZLE := 9.0  # altezza in pixel da cui partono i proiettili

const C_BLACK := Color("141414")
const C_LIGHT := Color("acacac")
const C_WHITE := Color("ececec")
const ATTACK_ANIM := 0.24

## Shader per il lampo bianco quando l'unità viene colpita.
static var _flash_shader: Shader

var game  # riferimento al nodo Main
var team := ALLY
var kind := ""
var is_boss := false
var dead := false

var max_hp := 10.0
var hp := 10.0
var base_dmg := 1.0
var attack_range := 10.0
var base_cooldown := 1.0
var base_speed := 60.0
var melee := true
var splash := 0.0
var radius := 4.0
var xp_value := 1

var ground := Vector2.ZERO  # posizione sul terreno (vedi sopra)
var home := Vector2.ZERO  # posizione di guardia sul terreno (alleati)
var atk_timer := 0.0
var target = null
var retaliating := false  # corpo a corpo che insegue chi l'ha colpito
var flash := 0.0
var lunge := 0.0
var attack_anim := 0.0  # secondi rimasti dell'animazione d'attacco
var knock := Vector2.ZERO  # spinta visiva quando viene colpita (pixel dell'arte)
## Appena evocato: esce dalla porta della torre e marcia fino alla sua casella.
## In marcia non combatte (ma può essere colpito).
var entering := false
var enter_delay := 0.0  # attesa dentro la torre prima di uscire (escono uno alla volta)
const ENTER_SPEED := 75.0  # pixel dell'arte al secondo
var frame := 0
var frame_timer := 0.0

var sprite: Sprite2D
var bar: Node2D


func _load_stats(kind_name: String) -> void:
	var d: Dictionary = Data.UNITS[kind_name]
	kind = kind_name
	max_hp = d["hp"]
	base_dmg = d["dmg"]
	attack_range = d["range"]
	base_cooldown = d["cooldown"]
	base_speed = d["speed"]
	melee = d["melee"]
	splash = d["splash"]
	radius = d["radius"]
	xp_value = d["xp"]


## `stats` sostituisce le statistiche base (vedi main.gd: ally_stats, dall'Inspector).
func setup_ally(kind_name: String, hp_mult: float, stats: Dictionary = {}) -> void:
	_load_stats(kind_name)
	team = ALLY
	max_hp = stats.get("hp", max_hp)
	base_dmg = stats.get("dmg", base_dmg)
	base_cooldown = stats.get("cooldown", base_cooldown)
	attack_range = stats.get("range", attack_range)
	max_hp *= hp_mult
	hp = max_hp
	atk_timer = randf() * base_cooldown


func setup_enemy(kind_name: String, hp_mult: float, dmg_mult: float, boss: bool) -> void:
	_load_stats(kind_name)
	team = ENEMY
	is_boss = boss
	if boss:
		hp_mult *= Data.BOSS_HP_MULT
		dmg_mult *= Data.BOSS_DMG_MULT
		radius *= 1.6
		xp_value *= 10
		base_speed *= Data.BOSS_SPEED_MULT
	max_hp *= hp_mult
	hp = max_hp
	base_dmg *= dmg_mult


func get_dmg() -> float:
	if team == ALLY:
		return base_dmg * game.mods["ally_dmg"]
	return base_dmg * game.mods["enemy_dmg"]


func get_cooldown() -> float:
	if team == ALLY:
		return base_cooldown / game.mods["ally_rate"]
	return base_cooldown


func get_speed() -> float:
	if team == ENEMY:
		return base_speed * game.mods["enemy_speed"]
	return base_speed


## Altezza da terra (in pixel dell'arte) da cui partono e arrivano i proiettili.
func muzzle_height() -> float:
	return MUZZLE * (2.0 if is_boss else 1.0)


func _ready() -> void:
	scale = Vector2.ONE * game.px
	sprite = Sprite2D.new()
	sprite.texture = ATLAS
	sprite.centered = false
	sprite.offset = Vector2(-8, -16)  # piedi nell'origine
	sprite.region_enabled = true
	sprite.flip_h = team == ENEMY  # le sprite guardano a destra, gli umani a sinistra
	if is_boss:
		sprite.scale = Vector2(2, 2)
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = """shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}"""
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = _flash_shader
	add_child(sprite)
	bar = Node2D.new()
	bar.draw.connect(_draw_bar)
	add_child(bar)
	_update_frame()
	sync_screen()


func sync_screen() -> void:
	var base: Vector2 = game.to_screen(ground)
	position = base + (Vector2(lunge * _face(), 0) + knock).round() * game.px
	z_index = int(base.y)
	# chi sta uscendo dalla torre le passa davanti, anche salendo verso le file in fondo
	if entering:
		z_index = maxi(z_index, game.tower_node.z_index + 1)


func _face() -> float:
	return 1.0 if team == ALLY else -1.0


func _update_frame() -> void:
	sprite.region_rect = Rect2((ATLAS_COL[kind] + frame) * 16, team * 16, 16, 16)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash -= delta
	# colpita: lampo bianco pieno, poi sfuma
	sprite.material.set_shader_parameter("flash", clampf(flash / 0.18, 0.0, 1.0))
	lunge = move_toward(lunge, 0.0, delta * 20.0)
	knock = knock.move_toward(Vector2.ZERO, delta * 14.0)
	# attacco: il corpo a corpo fa un saltello in avanti (insieme all'affondo),
	# chi tira si abbassa un attimo; tutto a pixel interi per restare nitido
	if attack_anim > 0.0:
		attack_anim = maxf(0.0, attack_anim - delta)
		var k := sin(PI * (1.0 - attack_anim / ATTACK_ANIM))
		sprite.position.y = -roundf((3.0 if melee else -1.0) * k)
	else:
		sprite.position.y = 0.0
	bar.queue_redraw()
	if entering and not dead:
		_enter_update(delta)
		return
	if not game.is_running():
		sync_screen()
	if dead or not game.is_running():
		return
	atk_timer = maxf(0.0, atk_timer - delta)
	var before := ground
	if team == ALLY:
		_ally_update(delta)
	else:
		_enemy_update(delta)
	_separate(delta)
	ground.y = clampf(ground.y, radius, game.depth - 1.0)
	_animate_walk(ground.distance_squared_to(before) > 0.0001, delta)
	sync_screen()


func _animate_walk(moving: bool, delta: float) -> void:
	if moving:
		frame_timer += delta
		if frame_timer >= FRAME_TIME:
			frame_timer = 0.0
			frame = 1 - frame
			_update_frame()
	elif frame != 0:
		frame = 0
		_update_frame()


## Uscita dalla torre e marcia verso la casella. Funziona anche durante lo
## schieramento (quando la partita non è ancora iniziata); si ferma in pausa.
func _enter_update(delta: float) -> void:
	if game.paused or game.state == game.State.GAME_OVER or game.state == game.State.VICTORY:
		return
	if enter_delay > 0.0:
		enter_delay -= delta
		if enter_delay <= 0.0:
			visible = true
			game.spawn_ground_fx(ground, 5.0, C_WHITE, 0.3)  # sbuffo alla porta
		return
	ground = ground.move_toward(home, ENTER_SPEED * delta)
	_animate_walk(true, delta)
	if ground.distance_to(home) < 0.5:
		ground = home
		entering = false
		_animate_walk(false, delta)
	sync_screen()


# --- Comportamento ---------------------------------------------------------

func _is_valid(t) -> bool:
	return t != null and is_instance_valid(t) and not t.dead


func _in_range(other) -> bool:
	var d: float = ground.distance_to(other.ground)
	if melee:
		d -= other.radius + radius
	return d <= attack_range


func _ally_update(delta: float) -> void:
	# Il corpo a corpo esce dalla posizione di guardia per intercettare chi
	# passa nelle file vicine; le unità a distanza restano ferme e sparano.
	var aggro := 46.0 if melee else attack_range
	var center := home if melee else ground
	if not _is_valid(target):
		retaliating = false
	# chi sta contrattaccando insegue l'aggressore ovunque, finché non muore
	if not retaliating and (not _is_valid(target) or target.ground.distance_to(center) > aggro + 10.0):
		target = game.nearest_unit(game.enemies_root, center, aggro)
	if _is_valid(target):
		if _in_range(target):
			_attack(target)
		else:
			_move_toward(target.ground, delta)
	elif ground.distance_to(home) > 0.5:
		_move_toward(home, delta)


func _enemy_update(delta: float) -> void:
	# 1) scheletri vicini  2) la torre  3) avanza verso sinistra nella sua fila
	var engage := radius + 13.0 if melee else attack_range
	if not _is_valid(target) or ground.distance_to(target.ground) > engage + 7.0:
		target = game.nearest_unit(game.allies_root, ground, engage)
	if _is_valid(target):
		if _in_range(target):
			_attack(target)
		else:
			_move_toward(target.ground, delta)
		return
	var to_tower: float = game.tower_distance(ground) - (radius if melee else 0.0)
	if to_tower <= attack_range:
		_attack_tower()
		return
	ground.x -= get_speed() * delta
	# vicino alla torre i nemici convergono verso la sua base
	if to_tower < 40.0:
		ground.y = move_toward(ground.y, game.tower_base_y, get_speed() * delta * 0.7)


func _move_toward(p: Vector2, delta: float) -> void:
	ground = ground.move_toward(p, get_speed() * delta)


func _attack(t) -> void:
	if atk_timer > 0.0:
		return
	atk_timer = get_cooldown()
	attack_anim = ATTACK_ANIM
	if melee:
		lunge = 5.0
		var hit_h: float = t.muzzle_height()
		game.spawn_unit_fx(t.ground, "slash", hit_h, _face(), 0.2)
		game.spawn_unit_fx(t.ground, "spark", hit_h, _face(), 0.25)
		t.take_damage(get_dmg(), self)
	else:
		lunge = -1.5
		game.spawn_unit_fx(ground + Vector2(4 * _face(), 0), "spark", muzzle_height(), _face(), 0.15)
		game.spawn_projectile(team, ground, muzzle_height(), t, false, get_dmg(), splash, kind == "mago", "", self)


func _attack_tower() -> void:
	if atk_timer > 0.0:
		return
	atk_timer = get_cooldown()
	attack_anim = ATTACK_ANIM
	if melee:
		game.damage_tower(get_dmg())
		lunge = 5.0
		game.spawn_unit_fx(ground + Vector2(-radius - 2, 0), "slash", muzzle_height(), _face(), 0.2)
	else:
		game.spawn_projectile(team, ground, muzzle_height(), null, true, get_dmg(), 0.0, kind == "mago")


func _separate(delta: float) -> void:
	# Evita che le unità della stessa squadra si sovrappongano.
	for o in get_parent().get_children():
		if o == self or o.dead or not o.visible:
			continue
		var diff: Vector2 = ground - o.ground
		var min_d: float = radius + o.radius
		var dsq := diff.length_squared()
		if dsq < 0.0001:
			ground += Vector2(randf() - 0.5, randf() - 0.5) * 0.3
		elif dsq < min_d * min_d:
			var dd := sqrt(dsq)
			ground += diff / dd * (min_d - dd) * 0.5 * minf(1.0, delta * 10.0)


# --- Vita ------------------------------------------------------------------

## `attacker` è l'unità che ha inflitto il danno (null per abilità e necromante).
func take_damage(amount: float, attacker = null) -> void:
	if dead:
		return
	_on_attacked(attacker)
	hp -= amount
	flash = 0.18
	# piccola spinta all'indietro, lontano da chi ha colpito
	var away := -_face()
	if attacker != null and is_instance_valid(attacker):
		away = signf(ground.x - attacker.ground.x)
		if away == 0.0:
			away = -_face()
	knock = Vector2(away * (1.0 if is_boss else 2.5), 0)
	if hp <= 0.0:
		_die()


## Uno scheletro corpo a corpo colpito va verso chi lo sta attaccando.
## Se sta già combattendo un nemico a portata, finisce prima quello.
func _on_attacked(attacker) -> void:
	if team != ALLY or not melee or not _is_valid(attacker) or attacker.team == team:
		return
	if attacker == target:
		retaliating = true
		return
	if _is_valid(target) and _in_range(target):
		return
	target = attacker
	retaliating = true


func heal(amount: float) -> void:
	if not dead:
		hp = minf(max_hp, hp + amount)


func _die() -> void:
	dead = true
	game.spawn_ground_fx(ground, radius + 3.0, C_WHITE if team == ALLY else C_LIGHT, 0.3)
	if team == ENEMY:
		game.on_enemy_killed(self)
	else:
		game.on_ally_died(self)
	queue_free()


# --- Grafica (in pixel dell'arte) -------------------------------------------

func _draw() -> void:
	# ombra a pixel sotto i piedi
	var w := 8.0 if kind != "gigante" else 12.0
	if is_boss:
		w *= 2.0
	draw_rect(Rect2(-w / 2.0 + 1.0, -1, w - 2.0, 1), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-w / 2.0, 0, w, 1), Color(0, 0, 0, 0.45))


func _draw_bar() -> void:
	var size := 32.0 if is_boss else 16.0
	if is_boss:
		bar.draw_texture_rect_region(ATLAS, Rect2(-8, -size - 14, 16, 16), Rect2(80, 32, 16, 16))
	if hp >= max_hp:
		return
	var w := 12.0 if is_boss else 8.0
	var y := -size - (7.0 if is_boss else 3.0)
	bar.draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 3), C_BLACK)
	var fill := C_WHITE if team == ALLY else C_LIGHT
	bar.draw_rect(Rect2(-w / 2.0, y, roundf(w * clampf(hp / max_hp, 0.0, 1.0)), 1), fill)
