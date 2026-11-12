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
## Grafica: sprite 16x16 dall'atlante assets/sprites.png (le unità delle
## pergamene da assets/unita_scheletri.png), con i piedi nell'origine del nodo.
##
## ABILITÀ SPECIALI (campo "special" in game_data.gd):
##   trafiggi  colpisce anche il nemico dietro (60%)      furia     più ferito = più forte
##   carica    dopo una corsa il colpo fa danno doppio     provoca   attira i nemici, -30% danni subiti
##   trapassa  secondo dardo sul nemico dietro (60%)       catapulta lontanissimo, area, non tira da vicino
##                                                                   né a chi vola
##   cecchino  mira il nemico con più vita                 rianima   i nemici morti vicino tornano scheletri
##   peste     nubi che avvelenano e rallentano            maledici  i colpiti subiscono +30% danni
##   urlo      ferisce e stordisce chi è vicino            aura      +25% danni e velocità ai vicini
##   schianto  colpi ad area                               falce     colpisce i vicini, finisce i feriti
##   muro      barricata che attira i nemici               esplodi   esplode sui nemici (rinasce a fine ondata)
##   volo      vola su tutto il campo e piomba sui nemici   raggio    raggio continuo che brucia sempre di più
##             (gli eroi corpo a corpo non lo colpiscono)             finché colpisce lo stesso bersaglio
##   cura      (scheletri ed eroi) cura il compagno più ferito a portata; se nessuno è ferito combatte
##
## SPECIALIZZAZIONI (rango 3 e 5, vedi specializzazione.gd): `spec` contiene gli effetti
## sommati dei rami scelti; vita/danno/cadenza/gittata/area sono già nelle statistiche,
## qui si applicano gli effetti dei colpi, la difesa, le aure e il nuovo colore.
##
## Il nodo è scalato di game.px, quindi tutto ciò che
## viene disegnato qui (ombra, barra della vita) è in pixel dell'arte.

const Data := preload("res://scripts/game_data.gd")
const ATLAS := preload("res://assets/sprites.png")
const Suoni := preload("res://scripts/suoni.gd")
const RestiScript := preload("res://scripts/resti.gd")
## Suono degli attacchi speciali: [nome, tono] (gli altri: spada / freccia / magia).
const SPECIAL_SOUNDS := {
	"schianto": ["spada", 0.65], "falce": ["spada", 0.8], "carica": ["spada", 0.9],
	"catapulta": ["freccia", 0.55], "cecchino": ["freccia", 1.25], "trapassa": ["freccia", 0.9],
	"urlo": ["magia", 0.55], "rianima": ["necromante", 1.3], "peste": ["magia", 0.8],
	"maledici": ["necromante", 1.1], "esplodi": ["palla_di_fuoco", 1.2], "cura": ["magia", 1.3],
}

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
var special := ""
var role := "corpo"
var rank := 1
# stati: rallentato, stordito, maledetto (secondi rimasti)
var slow_t := 0.0
var slow_k := 0.0
var stun_t := 0.0
var curse_t := 0.0
var curse_k := 0.3  # maledetto: danni in più subiti (0.3 = +30%; la Strega maledice più forte)
var gelo_t := 0.0  # congelato dal Lich: azzurro e fermo (lo stordimento fa il resto)
var life_left := -1.0  # scheletri rianimati: spariscono quando arriva a 0
var summoner = null  # chi ha rianimato questo scheletro
var run_dist := 0.0  # carica: strada percorsa dall'ultimo colpo
var pulse_t := 0.0  # aura del totem: ogni tanto un'onda visiva
var shot_t := 0.0  # catapulta: secondi in cui mostra il braccio scattato (frame 1)
## Effetti delle specializzazioni (vuoto = nessuna). Vedi Specializzazioni.effetti().
var spec: Dictionary = {}
var spec_col := Color(0, 0, 0, 0)  # nuovo colore d'accento (trasparente = quello normale)
var _in_effetto := false  # esplosioni e catene non generano altre esplosioni e catene
var aura_t := 0.0
# fuoco / veleno delle specializzazioni (danno nel tempo) e colore del rallentamento
var dot_t := 0.0
var dot_dps := 0.0
var dot_col := Color(1, 0.5, 0.2)
var dot_necro := false  # il veleno viene dal necromante (Strega)
## L'ultimo danno è arrivato dal necromante (torre, magie, suo veleno)? Il Signore delle
## Ossa rialza solo gli eroi uccisi da lui, non quelli finiti dagli scheletri.
var ultimo_necro := false
var slow_col := Color(0, 0, 0, 0)
## Eroi spronati da un campione (GRIDO): +buff_k danni, più veloci, per buff_t secondi.
var buff_t := 0.0
var buff_k := 0.0
var buff_col := Color(1, 1, 1)
## Vola sopra acqua, crepacci e ostacoli (l'arcangelo).
var vola := false
## EROE VOLANTE: vola dritto verso la torre, in alto. Il corpo a corpo non lo
## raggiunge: lo colpiscono solo le unità a distanza, la torre e le magie.
var in_volo := false
const ALTEZZA_VOLO := 12.0
var volo_fase := 0.0
## Livello della squadra (potenziamento: un'evocazione uguale sopra la squadra).
var squad_lv := 1
## Pteroscheletro: distanza (dalla sua casella) entro cui va a cercare i nemici.
const VOLO_RAGGIO_CACCIA := 72.0
## Torre infernale: i danni del raggio crescono di RAGGIO_CRESCITA volte al secondo
## sullo stesso bersaglio, fino a RAGGIO_MAX volte i danni di partenza.
const RAGGIO_CRESCITA := 2.0
const RAGGIO_MAX := 8.0
var raggio_t := 0.0  # secondi sullo stesso bersaglio
var raggio_tick := 0.0
var raggio_suono := 0.0

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
	special = d.get("special", "")
	role = d.get("role", "corpo")


## `stats` sostituisce le statistiche base (vedi main.gd: ally_stats, dall'Inspector).
func setup_ally(kind_name: String, hp_mult: float, stats: Dictionary = {}) -> void:
	_load_stats(kind_name)
	team = ALLY
	max_hp = stats.get("hp", max_hp)
	base_dmg = stats.get("dmg", base_dmg)
	base_cooldown = stats.get("cooldown", base_cooldown)
	attack_range = stats.get("range", attack_range)
	base_speed = stats.get("speed", base_speed)
	splash = stats.get("splash", splash)
	rank = stats.get("rank", 1)
	spec = stats.get("spec", {})
	if int(spec.get("attive", 0)) == 0:
		spec = {}
	spec_col = spec.get("colore", Color(0, 0, 0, 0))
	max_hp *= hp_mult
	hp = max_hp
	atk_timer = randf() * base_cooldown
	if special == "volo":  # pteroscheletro
		in_volo = true
		vola = true
		volo_fase = randf() * TAU


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
	if kind_name == "volante":
		in_volo = true
		vola = true
		volo_fase = randf() * TAU


func get_dmg() -> float:
	if team == ALLY:
		var d: float = base_dmg * game.mods["ally_dmg"] * game.role_mult(role, "dmg") * game.aura_bonus(self)
		if special == "furia":
			d *= 1.0 + (1.0 - clampf(hp / max_hp, 0.0, 1.0)) * sp("potenza_speciale", 1.0)
		return d
	return base_dmg * game.mods["enemy_dmg"] * (1.0 + buff_k if buff_t > 0.0 else 1.0)


func get_cooldown() -> float:
	if team == ALLY:
		var cd: float = base_cooldown / game.mods["ally_rate"] / game.aura_bonus(self)
		if special == "furia":
			cd /= 1.0 + (1.0 - clampf(hp / max_hp, 0.0, 1.0)) * sp("potenza_speciale", 1.0)
		return cd
	return base_cooldown / (1.0 + buff_k * 0.5 if buff_t > 0.0 else 1.0)


## Valore di un effetto delle specializzazioni (`def` se l'unità non ne ha).
func sp(k: String, def: float = 0.0) -> float:
	return float(spec.get(k, def)) if not spec.is_empty() else def


func get_speed() -> float:
	var sp := base_speed * (1.0 - slow_k if slow_t > 0.0 else 1.0)
	if team == ENEMY:
		return sp * game.mods["enemy_speed"] * (1.0 + buff_k * 0.5 if buff_t > 0.0 else 1.0)
	return sp


## Unità che non si muovono (catapulta, totem, muro).
func is_static() -> bool:
	return base_speed <= 0.0


## Altezza da terra (in pixel dell'arte) da cui partono e arrivano i proiettili.
func muzzle_height() -> float:
	return MUZZLE * (2.0 if is_boss else 1.0) + (ALTEZZA_VOLO if in_volo else 0.0)


func _ready() -> void:
	scale = Vector2.ONE * game.px
	sprite = Sprite2D.new()
	sprite.texture = Data.ally_texture(kind) if team == ALLY else ATLAS
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
// specializzazione: i pixel colorati della sprite prendono il nuovo colore
uniform float swap = 0.0;
uniform vec4 to_col : source_color = vec4(1.0);
uniform float from_luma = 0.5;
varying vec4 modulate_col;
void vertex() {
	modulate_col = COLOR;  // colore del nodo (modulate): stati come gelo e fuoco
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (swap > 0.5) {
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		if (mx - mn > 0.12) {
			float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			c.rgb = clamp(to_col.rgb * (l / max(from_luma, 0.05)), 0.0, 1.0);
		}
	}
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a) * modulate_col;
}"""
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = _flash_shader
	if team == ENEMY and game.tex_nemici != null:
		sprite.texture = game.tex_nemici
		_update_frame()
	if in_volo and team == ENEMY:
		sprite.texture = game.tex_volante
		_update_frame()
	if kind == "guaritore" and team == ENEMY:
		sprite.texture = game.tex_guaritore
		_update_frame()
	if spec_col.a > 0.0:
		var base_col := Data.accent(kind, team)
		sprite.material.set_shader_parameter("swap", 1.0)
		sprite.material.set_shader_parameter("to_col", spec_col)
		sprite.material.set_shader_parameter("from_luma", base_col.r * 0.299 + base_col.g * 0.587 + base_col.b * 0.114)
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
	if team == ALLY:
		sprite.region_rect = Data.ally_region(kind, frame)
	elif in_volo or kind == "guaritore":  # striscia 32x16 con 2 frame (volanti, guaritori)
		sprite.region_rect = Rect2(frame * 16, 0, 16, 16)
	else:
		# eroi del bioma (elfi, vichinghi...): la loro striscia ha una riga sola
		var y := 0 if sprite.texture != ATLAS else team * 16
		sprite.region_rect = Rect2((ATLAS_COL[kind] + frame) * 16, y, 16, 16)


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
	if in_volo:  # in alto, ondeggia
		sprite.position.y -= ALTEZZA_VOLO + roundf(sin(Time.get_ticks_msec() / 260.0 + volo_fase) * 1.5)
	bar.queue_redraw()
	if special == "raggio":
		queue_redraw()  # il raggio si ridisegna a ogni frame
	if entering and not dead:
		_enter_update(delta)
		return
	if not game.is_running():
		sync_screen()
	if dead or not game.is_running():
		return
	slow_t = maxf(0.0, slow_t - delta)
	curse_t = maxf(0.0, curse_t - delta)
	gelo_t = maxf(0.0, gelo_t - delta)
	buff_t = maxf(0.0, buff_t - delta)
	_tinta_stati()
	if dot_t > 0.0:  # fuoco / veleno delle specializzazioni
		dot_t -= delta
		ultimo_necro = dot_necro
		poison(dot_dps * delta)
		if dead:
			return
	if not spec.is_empty():
		_spec_update(delta)
	if life_left > 0.0:
		life_left -= delta
		if life_left <= 0.0:
			_die()
			return
	if stun_t > 0.0:  # stordito: non si muove e non attacca
		stun_t -= delta
		sync_screen()
		return
	if special == "aura":
		pulse_t -= delta
		if pulse_t <= 0.0:
			pulse_t = 2.0
			game.spawn_ground_fx(ground, game.AURA_RADIUS * sp("area", 1.0), accent(), 0.6)
	atk_timer = maxf(0.0, atk_timer - delta)
	var before := ground
	if team == ALLY:
		_ally_update(delta)
	else:
		_enemy_update(delta)
	_separate(delta)
	if not vola:
		ground = game.constrain(ground, radius)  # corsie e ostacoli del livello
	ground.y = clampf(ground.y, radius, game.depth - 1.0)
	_animate_walk(ground.distance_squared_to(before) > 0.0001, delta)
	sync_screen()


func _animate_walk(moving: bool, delta: float) -> void:
	if shot_t > 0.0:  # la catapulta ha appena tirato: braccio in alto, coppa vuota
		shot_t -= delta
		if frame != 1:
			frame = 1
			_update_frame()
		return
	if moving or in_volo or special == "raggio":  # ali che sbattono, fiamme che tremano
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
	if special == "aura" or special == "muro":
		return  # non attaccano: restano dove li hai messi
	if special == "cura" and _cura_update():
		return
	if special == "raggio":
		_raggio_update(delta)
		return
	if in_volo:
		_volo_update(delta)
		return
	if not melee and special in ["cecchino", "catapulta"]:
		if not _is_valid(target) or not _in_range(target) or (special == "catapulta" and ground.distance_to(target.ground) < CATAPULT_MIN):
			target = _special_target()
		if _is_valid(target):
			_attack(target)
		return
	# Il corpo a corpo esce dalla posizione di guardia per intercettare chi
	# passa nelle file vicine; le unità a distanza restano ferme e sparano.
	var aggro := 46.0 if melee else attack_range
	if special == "carica":
		aggro = 90.0
	var center := home if melee else ground
	if not _is_valid(target):
		retaliating = false
	elif melee and not game.same_lane(ground, target.ground):
		target = null  # è in un'altra corsia: non si può raggiungere
		retaliating = false
	# chi sta contrattaccando insegue l'aggressore ovunque, finché non muore
	if not retaliating and (not _is_valid(target) or target.ground.distance_to(center) > aggro + 10.0):
		target = game.nearest_unit(game.enemies_root, center, aggro, melee)
	if _is_valid(target):
		if _in_range(target):
			_attack(target)
		else:
			_move_toward(target.ground, delta)
	elif ground.distance_to(home) > 0.5:
		_move_toward(home, delta)


## Pteroscheletro: caccia i nemici di qualsiasi corsia (anche i volanti) attorno alla sua
## casella, volando sopra canali e ostacoli; senza nemici torna a volteggiare sulla casella.
func _volo_update(delta: float) -> void:
	if not _is_valid(target) or target.ground.distance_to(home) > VOLO_RAGGIO_CACCIA + 12.0:
		target = game.nearest_unit(game.enemies_root, home, VOLO_RAGGIO_CACCIA, false)
	if _is_valid(target):
		if _in_range(target):
			_attack(target)
		else:
			_move_toward(target.ground, delta)
	elif ground.distance_to(home) > 0.5:
		_move_toward(home, delta)


## Torre infernale: un raggio continuo sul nemico più vicino; più resta sullo stesso
## bersaglio più fa male. Cambiando bersaglio si riparte da capo.
func _raggio_update(delta: float) -> void:
	if not _is_valid(target) or ground.distance_to(target.ground) > attack_range + target.radius:
		var nuovo = game.nearest_unit(game.enemies_root, ground, attack_range, false)
		if nuovo != target:
			raggio_t = 0.0
		target = nuovo
	if not _is_valid(target):
		raggio_t = 0.0
		return
	raggio_t += delta
	raggio_tick -= delta
	if raggio_tick <= 0.0:
		raggio_tick = 0.1
		var k := minf(1.0 + RAGGIO_CRESCITA * sp("potenza_speciale", 1.0) * raggio_t, RAGGIO_MAX)
		target.take_damage(get_dmg() * k * 0.1, self)
	raggio_suono -= delta
	if raggio_suono <= 0.0:
		raggio_suono = 0.45
		Suoni.play("palla_di_fuoco", 1.5 + minf(raggio_t, 4.0) * 0.12, -14.0)


## Moltiplicatore attuale del raggio (per il disegno).
func raggio_k() -> float:
	return minf(1.0 + RAGGIO_CRESCITA * sp("potenza_speciale", 1.0) * raggio_t, RAGGIO_MAX)


func _enemy_update(delta: float) -> void:
	if in_volo:  # dritto verso la torre, sopra scheletri e ostacoli
		if game.tower_distance(ground) - radius <= attack_range:
			_attack_tower()
		else:
			ground = ground.move_toward(Vector2(game.wall_x, game.tower_base_y), get_speed() * delta)
		return
	if special == "cura" and _cura_update():
		return  # si ferma a curare
	# 1) scheletri vicini (prima chi provoca: scudieri e muri)  2) la torre  3) avanza verso sinistra
	var engage := radius + 13.0 if melee else attack_range
	var taunter = game.nearest_taunter(ground, engage + 22.0)
	if taunter != null:
		target = taunter
	elif not _is_valid(target) or ground.distance_to(target.ground) > engage + 7.0:
		target = game.nearest_unit(game.allies_root, ground, engage, melee)
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
	ground += _passo(Vector2(-get_speed() * delta, 0.0))  # gira attorno agli ostacoli
	# vicino alla torre i nemici convergono verso la sua base
	if to_tower < 40.0:
		ground.y = move_toward(ground.y, game.tower_base_y, get_speed() * delta * 0.7)


## Guaritori (scheletri ed eroi): se un compagno a portata è ferito restano fermi e
## curano il più ferito (in proporzione alla vita); true = sta curando.
func _cura_update() -> bool:
	var amici: Node = game.allies_root if team == ALLY else game.enemies_root
	var t = _piu_ferito(amici, [])
	if t == null:
		return false
	if atk_timer <= 0.0:
		atk_timer = get_cooldown()
		attack_anim = ATTACK_ANIM
		lunge = -1.0
		var forza := potenza_cura()
		_lancia_cura(t, forza)
		var curati: Array = [t]
		for _i in int(sp("curati_extra")):  # specializzazione: cura anche altri feriti
			var altro = _piu_ferito(amici, curati)
			if altro == null:
				break
			curati.append(altro)
			_lancia_cura(altro, forza * 0.7)
	return true


## Il compagno a portata con meno vita in proporzione (null se nessuno è ferito).
func _piu_ferito(amici: Node, esclusi: Array):
	var best = null
	var best_k := 0.98
	for c in amici.get_children():
		if c.dead or not c.visible or c.entering or c.hp >= c.max_hp - 0.5 or c in esclusi:
			continue
		if ground.distance_to(c.ground) > attack_range + c.radius:
			continue
		var k: float = c.hp / c.max_hp
		if k < best_k:
			best_k = k
			best = c
	return best


## Vita ridata da un colpo di cura: cresce con la vita dell'unità (ranghi, ricerche,
## livello della squadra; per gli eroi l'ondata) e con la potenza delle specializzazioni.
func potenza_cura() -> float:
	var d: Dictionary = Data.UNITS[kind]
	var k := max_hp / maxf(1.0, float(d["hp"]))
	return float(d.get("cura", 0.0)) * k * sp("potenza_speciale", 1.0)


func _lancia_cura(t, forza: float) -> void:
	game.spawn_projectile(team, ground, muzzle_height(), t, false, forza, 0.0, true, "cura", self)
	Suoni.play("magia", 1.35 if team == ALLY else 1.2, -4.0)


func _move_toward(p: Vector2, delta: float) -> void:
	if team == ALLY and is_static():
		return
	var before := ground
	ground += _passo(ground.move_toward(p, get_speed() * delta) - ground)
	run_dist += ground.distance_to(before)


## Passo che evita gli ostacoli del livello (chi vola ci passa sopra).
func _passo(step: Vector2) -> Vector2:
	return step if vola else game.aggira(ground, step, radius)


const CATAPULT_MIN := 30.0


## Bersaglio delle unità a distanza speciali: il cecchino sceglie chi ha più
## vita, la catapulta il più vicino oltre la distanza minima.
func _special_target():
	var best = null
	var best_v := -1.0
	for c in game.enemies_root.get_children():
		if c.dead or not c.visible:
			continue
		var d := ground.distance_to(c.ground)
		if d > attack_range:
			continue
		if special == "catapulta":
			if d < CATAPULT_MIN or c.in_volo:  # non mira chi vola
				continue
			if best == null or d < best_v:
				best = c
				best_v = d
		elif c.hp > best_v:
			best = c
			best_v = c.hp
	return best


## Il nemico più vicino a `t` (escluso), entro `dist`, che sta dietro di lui.
func _enemy_behind(t, dist: float):
	var best = null
	var best_d := dist
	for c in game.enemies_root.get_children():
		if c == t or c.dead or not c.visible or c.ground.x < t.ground.x - 1.0:
			continue
		var d: float = c.ground.distance_to(t.ground)
		if d <= best_d:
			best_d = d
			best = c
	return best


func _attack(t) -> void:
	if atk_timer > 0.0:
		return
	atk_timer = get_cooldown()
	attack_anim = ATTACK_ANIM
	_attack_sound()
	if team == ALLY and special != "":
		_special_attack(t)
	else:
		_basic_attack(t)
	# specializzazione: colpisce anche altri nemici (altri proiettili o fendente)
	var n := int(sp("colpi_extra"))
	if team == ALLY and n > 0 and not special in ["esplodi", "urlo", "schianto", "falce"]:
		var k := sp("danno_colpi_extra", 0.6)
		for e in _altri_bersagli(t, n):
			if special != "":
				_special_attack(e, k)
			else:
				_basic_attack(e, k)


func _basic_attack(t, k: float = 1.0) -> void:
	if melee:
		lunge = 5.0
		var hit_h: float = t.muzzle_height()
		game.spawn_unit_fx(t.ground, "slash", hit_h, _face(), 0.2, accent() if spec_col.a > 0.0 else C_WHITE)
		game.spawn_unit_fx(t.ground, "spark", hit_h, _face(), 0.25)
		t.take_damage(get_dmg() * k, self)
	else:
		lunge = -1.5
		game.spawn_unit_fx(ground + Vector2(4 * _face(), 0), "spark", muzzle_height(), _face(), 0.15)
		game.spawn_projectile(team, ground, muzzle_height(), t, false, get_dmg() * k, splash, kind == "mago" or special == "cura", "", self)


## Altri `n` nemici vicini per i colpi extra (a distanza: entro la gittata; corpo a corpo: attorno al bersaglio).
func _altri_bersagli(t, n: int) -> Array:
	var c_list: Array = []
	for c in game.enemies_root.get_children():
		if c == t or c.dead or not c.visible:
			continue
		if melee:
			if c.ground.distance_to(t.ground) > 14.0 + c.radius or not game.same_lane(c.ground, t.ground):
				continue
		else:
			var d: float = ground.distance_to(c.ground)
			if d > attack_range or (special == "catapulta" and (d < CATAPULT_MIN or c.in_volo)):
				continue
		c_list.append(c)
	c_list.sort_custom(func(a, b) -> bool: return a.ground.distance_squared_to(t.ground) < b.ground.distance_squared_to(t.ground))
	return c_list.slice(0, n)


## Attacchi delle unità con un'abilità speciale (`k` = parte del danno, per i colpi extra).
func _special_attack(t, k: float = 1.0) -> void:
	var dmg := get_dmg() * k
	var hit_h: float = t.muzzle_height()
	var pk := sp("potenza_speciale", 1.0)  # specializzazione: abilità più forte
	var ak := sp("area", 1.0)
	match special:
		"trafiggi", "provoca", "furia", "carica":
			lunge = 5.0
			if special == "carica" and run_dist >= 24.0:
				dmg *= 1.0 + pk
				lunge = 8.0
				game.spawn_ground_fx(t.ground, 8.0, accent(), 0.3)
			run_dist = 0.0
			game.spawn_unit_fx(t.ground, "slash", hit_h, _face(), 0.2)
			t.take_damage(dmg, self)
			if special == "trafiggi":
				var b = _enemy_behind(t, 14.0)
				if b != null:
					game.spawn_unit_fx(b.ground, "spark", b.muzzle_height(), _face(), 0.2)
					b.take_damage(dmg * minf(1.0, 0.6 * pk), self)
		"schianto":
			lunge = 4.0
			game.spawn_ground_fx(t.ground, 14.0 * ak, accent(), 0.35)
			t.take_damage(dmg, self)
			for c in game.enemies_root.get_children():
				if c != t and not c.dead and c.ground.distance_to(t.ground) <= 14.0 * ak + c.radius:
					c.take_damage(dmg * minf(1.0, 0.6 * pk), self)
		"falce":
			lunge = 6.0
			game.spawn_unit_fx(t.ground, "slash", hit_h, _face(), 0.25)
			for c in game.enemies_root.get_children():
				if c.dead or c.ground.distance_to(t.ground) > 11.0 * ak + c.radius:
					continue
				if not c.is_boss and c.hp / c.max_hp < 0.2 * pk:
					game.spawn_unit_fx(c.ground, "spark", c.muzzle_height(), _face(), 0.3)
					c.take_damage(c.hp + 1.0, self)  # esecuzione
				else:
					c.take_damage(dmg if c == t else dmg * 0.6, self)
		"esplodi":
			game.spawn_ground_fx(ground, splash, accent(), 0.6, "fire")
			game.damage_area(ground, splash, dmg, ENEMY, self)
			_die()
		"trapassa":
			lunge = -1.5
			game.spawn_projectile(team, ground, muzzle_height(), t, false, dmg, 0.0, false, "", self)
			var b = _enemy_behind(t, 18.0)
			if b != null:
				game.spawn_projectile(team, ground, muzzle_height(), b, false, dmg * minf(1.0, 0.6 * pk), 0.0, false, "", self)
		"catapulta":
			lunge = -2.0
			shot_t = 0.7
			game.spawn_projectile(team, ground, muzzle_height() + 4.0, t, false, dmg, splash, true, "", self)
		"cecchino":
			lunge = -1.5
			game.spawn_unit_fx(ground + Vector2(4 * _face(), 0), "spark", muzzle_height(), _face(), 0.15)
			game.spawn_projectile(team, ground, muzzle_height(), t, false, dmg, 0.0, false, "", self)
		"cura":  # nessuno da curare: un colpo magico debole
			lunge = -1.0
			game.spawn_projectile(team, ground, muzzle_height(), t, false, dmg, 0.0, true, "", self)
		"rianima":
			lunge = -1.0
			game.spawn_projectile(team, ground, muzzle_height(), t, false, dmg, 0.0, true, "", self)
		"peste":
			lunge = -1.0
			game.spawn_projectile(team, ground, muzzle_height(), t, false, dmg, 0.0, true, "", self)
			game.add_plague_cloud(t.ground, dmg * 1.5 * pk, rank, 16.0 * ak, maxf(0.3, sp("rallenta")), sp("maledici"))
		"maledici":
			lunge = -1.0
			game.spawn_projectile(team, ground, muzzle_height(), t, false, dmg, splash, true, "", self)
			for c in game.enemies_root.get_children():
				if not c.dead and c.ground.distance_to(t.ground) <= splash + c.radius:
					c.curse_t = maxf(c.curse_t, 4.0 * pk)
		"urlo":
			lunge = -1.0
			game.spawn_ground_fx(ground, attack_range, accent(), 0.5)
			game.spawn_ground_fx(ground, attack_range * 0.6, accent().lightened(0.4), 0.4)
			for c in game.enemies_root.get_children():
				if not c.dead and c.ground.distance_to(ground) <= attack_range + c.radius:
					c.take_damage(dmg, self)
					c.stun_t = maxf(c.stun_t, 1.2 * pk * (0.5 if c.is_boss else 1.0))
		_:
			t.take_damage(dmg, self)


func _attack_tower() -> void:
	if atk_timer > 0.0:
		return
	atk_timer = get_cooldown()
	attack_anim = ATTACK_ANIM
	_attack_sound()
	if melee:
		game.damage_tower(get_dmg())
		lunge = 5.0
		game.spawn_unit_fx(ground + Vector2(-radius - 2, 0), "slash", muzzle_height(), _face(), 0.2)
	else:
		game.spawn_projectile(team, ground, muzzle_height(), null, true, get_dmg(), 0.0, kind == "mago" or special == "cura", "", self)


func _separate(delta: float) -> void:
	# Evita che le unità della stessa squadra si sovrappongano.
	if team == ALLY and is_static():
		return  # catapulta, totem e muro non si spostano
	for o in get_parent().get_children():
		if o == self or o.dead or not o.visible or o.in_volo != in_volo:
			continue  # chi vola non spinge chi cammina
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
	var att_ok: bool = attacker != null and is_instance_valid(attacker) and not attacker.dead
	if in_volo and att_ok and attacker.team != team and attacker.melee and not attacker.in_volo:
		return  # spade e asce non arrivano fin lassù
	if in_volo and attacker != null and is_instance_valid(attacker) and attacker.special == "catapulta" and attacker.team != team:
		return  # i teschi della catapulta volano a parabola e ricadono a terra: chi vola non lo prendono
	ultimo_necro = game.colpo_necro
	if team == ALLY and not spec.is_empty():  # difese delle specializzazioni
		if sp("schiva") > 0.0 and randf() < sp("schiva"):
			game.spawn_unit_fx(ground, "spark", muzzle_height(), -_face(), 0.2, C_WHITE)
			return
		amount *= 1.0 - sp("riduzione_danni")
		if sp("spine") > 0.0 and att_ok and attacker.melee and attacker.team != team:
			attacker.take_damage(amount * sp("spine"), null)
	var dal_ramo: bool = att_ok and attacker.team == ALLY and team == ENEMY and not attacker.spec.is_empty()
	if dal_ramo:
		amount = attacker._modifica_colpo(self, amount)
	_on_attacked(attacker)
	if curse_t > 0.0:
		amount *= 1.0 + curse_k
	if gelo_t > 0.0 and game.schegge > 0.0:
		amount *= 1.0 + game.schegge
	if att_ok and team == ENEMY and attacker.team == ALLY:
		game.on_ally_hit(self, amount)
	if team == ALLY and special == "provoca":
		amount *= 0.7
	hp -= amount
	if dal_ramo:
		attacker._dopo_colpo(self, amount)
	if dead:
		return  # già finito da un effetto (esplosione, catena)
	flash = 0.18
	# piccola spinta all'indietro, lontano da chi ha colpito
	var away := -_face()
	if attacker != null and is_instance_valid(attacker):
		away = signf(ground.x - attacker.ground.x)
		if away == 0.0:
			away = -_face()
	knock = Vector2(away * (1.0 if is_boss else 2.5), 0)
	if att_ok and attacker.special == "raggio":  # il raggio brucia senza spingere
		knock = Vector2.ZERO
		flash = 0.06
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


## Danno nel tempo (peste): niente lampo né spinta.
func poison(amount: float) -> void:
	if dead:
		return
	hp -= amount * (1.0 + curse_k if curse_t > 0.0 else 1.0)
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if not dead:
		hp = minf(max_hp, hp + amount)


func _attack_sound() -> void:
	var big := 0.8 if is_boss or kind in ["gigante", "golem"] else 1.0
	if team == ALLY and SPECIAL_SOUNDS.has(special):
		var sp: Array = SPECIAL_SOUNDS[special]
		Suoni.play(sp[0], sp[1] * big, -2.0)
	elif melee:
		Suoni.play("spada", big * (1.1 if team == ALLY else 0.95))
	elif kind == "mago" or role == "magia" or special == "cura":
		Suoni.play("magia", 1.0 if team == ALLY else 0.85)
	else:
		Suoni.play("freccia", 1.0 if team == ALLY else 0.9)


## Colore d'accento dell'unità (lo stesso dell'elemento colorato della sprite).
func accent() -> Color:
	if spec_col.a > 0.0:
		return spec_col
	if team == ENEMY and game != null and game.colori_nemici.has(kind):
		return game.colori_nemici[kind]
	return Data.accent(kind, team)


# --- Specializzazioni ---------------------------------------------------------

## Prima del danno: critico, bonus contro i campioni, esecuzione.
func _modifica_colpo(v, amount: float) -> float:
	if sp("critico") > 0.0 and randf() < sp("critico"):
		amount *= sp("danno_critico", 2.0)
		game.spawn_unit_fx(v.ground, "spark", v.muzzle_height() + 2.0, _face(), 0.3, accent().lightened(0.3))
	if v.is_boss:
		amount *= sp("danno_campioni", 1.0)
	elif sp("esecuzione") > 0.0 and (v.hp - amount) / v.max_hp < sp("esecuzione"):
		amount = v.hp + 1.0
		game.spawn_unit_fx(v.ground, "slash", v.muzzle_height(), _face(), 0.3, accent())
	return amount


## Dopo il danno: fuoco, gelo, stordimento, maledizione, rubavita, spinta, esplosione, catena.
func _dopo_colpo(v, amount: float) -> void:
	var col := accent()
	if sp("danno_nel_tempo") > 0.0:
		v.dot_dps = maxf(v.dot_dps if v.dot_t > 0.0 else 0.0, amount * sp("danno_nel_tempo"))
		v.dot_t = maxf(v.dot_t, sp("durata_danno_nel_tempo", 3.0))
		v.dot_col = col
	if sp("rallenta") > 0.0:
		v.slow_k = maxf(v.slow_k if v.slow_t > 0.0 else 0.0, sp("rallenta"))
		v.slow_t = maxf(v.slow_t, sp("durata_rallenta", 2.0))
		v.slow_col = col
	if sp("stordisci") > 0.0 and randf() < sp("stordisci"):
		v.stun_t = maxf(v.stun_t, sp("durata_stordisci", 0.8) * (0.5 if v.is_boss else 1.0))
	if sp("maledici") > 0.0:
		v.curse_t = maxf(v.curse_t, sp("maledici"))
	if sp("rubavita") > 0.0 and not dead:
		heal(amount * sp("rubavita"))
	if sp("respingi") > 0.0 and not v.is_boss and not v.dead:
		v.ground.x += sp("respingi")
		v.knock = Vector2(4, 0)
	if _in_effetto:
		return
	_in_effetto = true
	if sp("esplosione") > 0.0:
		var r := sp("esplosione")
		game.spawn_ground_fx(v.ground, r, col, 0.3, "fire" if col.r > col.b else "ring")
		for c in game.enemies_root.get_children():
			if c != v and not c.dead and c.ground.distance_to(v.ground) <= r + c.radius:
				c.take_damage(amount * sp("danno_esplosione", 0.5), self)
	var n := int(sp("catena"))
	if n > 0:
		var prev = v
		var colpiti: Array = [v]
		for i in n:
			var best = null
			var best_d := 44.0
			for c in game.enemies_root.get_children():
				if c.dead or not c.visible or c in colpiti:
					continue
				var d: float = c.ground.distance_to(prev.ground)
				if d < best_d:
					best_d = d
					best = c
			if best == null:
				break
			game.spawn_zap(prev.ground, prev.muzzle_height(), best.ground, best.muzzle_height(), col)
			best.take_damage(amount * sp("danno_catena", 0.6), self)
			colpiti.append(best)
			prev = best
	_in_effetto = false


## Rigenerazione e aure delle specializzazioni.
func _spec_update(delta: float) -> void:
	if sp("rigenera") > 0.0 and hp < max_hp:
		heal(max_hp * sp("rigenera") * delta)
	if sp("aura_cura") <= 0.0 and sp("aura_rallenta") <= 0.0:
		return
	aura_t -= delta
	if aura_t > 0.0:
		return
	aura_t = 1.0
	var r: float = game.AURA_RADIUS * sp("area", 1.0)
	if sp("aura_cura") > 0.0:
		var curati := false
		for c in game.allies_root.get_children():
			if not c.dead and c.visible and c.hp < c.max_hp and c.ground.distance_to(ground) <= r:
				c.heal(c.max_hp * sp("aura_cura"))
				curati = true
		if curati:
			game.spawn_ground_fx(ground, r * 0.5, accent(), 0.6, "heal")
	if sp("aura_rallenta") > 0.0:
		for c in game.enemies_root.get_children():
			if not c.dead and c.ground.distance_to(ground) <= r + c.radius:
				c.slow_k = maxf(c.slow_k if c.slow_t > 0.0 else 0.0, sp("aura_rallenta"))
				c.slow_t = maxf(c.slow_t, 1.2)
				c.slow_col = accent()
		game.spawn_ground_fx(ground, r, Color(accent(), 0.5), 0.5)


## Colore dei nemici rallentati dal gelo o in fiamme / avvelenati.
func _tinta_stati() -> void:
	var tinta := Color.WHITE
	if slow_t <= 0.0:
		slow_col.a = 0.0
	if gelo_t > 0.0:  # congelato: blocco di ghiaccio azzurro
		tinta = Color.WHITE.lerp(Color("78e2ea"), 0.75)
	elif slow_t > 0.0 and slow_col.a > 0.0:
		tinta = Color.WHITE.lerp(slow_col, 0.55)
	elif dot_t > 0.0:
		tinta = Color.WHITE.lerp(dot_col, 0.3 + 0.15 * sin(Time.get_ticks_msec() / 90.0))
	elif buff_t > 0.0:  # spronato da un campione
		tinta = Color.WHITE.lerp(buff_col, 0.35 + 0.1 * sin(Time.get_ticks_msec() / 120.0))
	sprite.modulate = Color(tinta, sprite.modulate.a)


func _die() -> void:
	if dead:
		return
	dead = true
	if team == ALLY and sp("esplode_alla_morte") > 0.0 and visible:
		var r := sp("esplode_alla_morte")
		game.spawn_ground_fx(ground, r, accent(), 0.5, "fire")
		game.damage_area(ground, r, maxf(base_dmg, 10.0) * 2.0, ENEMY, null)
	game.spawn_ground_fx(ground, radius + 2.0, C_WHITE if team == ALLY else C_LIGHT, 0.25)
	Suoni.play("morte_scheletro" if team == ALLY else "morte_eroe", 0.75 if is_boss or kind in ["gigante", "golem"] else 1.0)
	if visible:  # si sbriciola lasciando il teschio (o l'arma, per gli eroi)
		var r := RestiScript.new()
		r.setup(self)
		game.add_remains(r)
	if team == ENEMY:
		game.on_enemy_killed(self)
	else:
		game.on_ally_died(self)
	queue_free()


# --- Grafica (in pixel dell'arte) -------------------------------------------

func _draw() -> void:
	if special == "raggio" and team == ALLY:
		_draw_raggio()
	# ombra a pixel sotto i piedi
	var w := 8.0 if not kind in ["gigante", "golem", "muro", "cavaliere", "catapulta", "infernale"] else 12.0
	if is_boss:
		w *= 2.0
	draw_rect(Rect2(-w / 2.0 + 1.0, -1, w - 2.0, 1), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-w / 2.0, 0, w, 1), Color(0, 0, 0, 0.45))


## Il raggio della torre infernale: dalla fiamma in cima al bersaglio, sempre più spesso
## e chiaro man mano che i danni crescono.
func _draw_raggio() -> void:
	if dead or not _is_valid(target) or raggio_t <= 0.0 or not game.is_running():
		return
	var da := Vector2(0, -15)
	var a: Vector2 = (game.to_screen(target.ground) - position) / game.px + Vector2(0, -target.muzzle_height())
	var k := (raggio_k() - 1.0) / (RAGGIO_MAX - 1.0)  # 0 all'inizio, 1 al massimo
	var col := accent()
	var tremito := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 40.0)
	var spessore := 1.0 + roundf(k * 2.0)
	var dir := (a - da)
	var n := int(dir.length())
	for i in n:  # a pixel interi, così resta nitido
		var p := (da + dir * (float(i) / maxf(1.0, float(n)))).round()
		draw_rect(Rect2(p - Vector2(spessore, spessore) * 0.5, Vector2(spessore, spessore)), Color(col, 0.55 + 0.35 * tremito))
		if k > 0.4 and i % 2 == 0:
			draw_rect(Rect2(p, Vector2.ONE), Color(C_WHITE, 0.5 + 0.5 * k))
	# fiammata sul bersaglio
	var r := 1.0 + roundf(k * 2.0 + tremito)
	draw_rect(Rect2(a.round() - Vector2(r, r), Vector2(r * 2.0 + 1.0, r * 2.0 + 1.0)), Color(col, 0.5))
	draw_rect(Rect2(a.round(), Vector2.ONE), C_WHITE)


func _draw_bar() -> void:
	var size := (32.0 if is_boss else 16.0) + (ALTEZZA_VOLO if in_volo else 0.0)
	if squad_lv > 1 and team == ALLY:  # gradi del potenziamento sopra la testa
		for k in squad_lv - 1:
			var gy := -size - 6.0 - k * 2.0
			bar.draw_rect(Rect2(-2, gy - 1.0, 5, 3), C_BLACK)
			bar.draw_rect(Rect2(-1, gy, 3, 1), accent())
	if curse_t > 0.0:  # teschietto della maledizione sopra la testa
		bar.draw_rect(Rect2(-1, -size - 7, 3, 2), C_BLACK)
		bar.draw_rect(Rect2(-1, -size - 8, 3, 1), Data.accent("lich"))  # fuoco verde del lich
	if stun_t > 0.0:  # stelline dello stordimento
		var a := fmod(Time.get_ticks_msec() / 150.0, 4.0)
		bar.draw_rect(Rect2(-4 + roundf(a) * 2.0, -size - 5, 1, 1), C_WHITE)
		bar.draw_rect(Rect2(4 - roundf(a) * 2.0, -size - 6, 1, 1), C_WHITE)
	if life_left > 0.0 and life_left < 3.0 and int(life_left * 6.0) % 2 == 0:
		sprite.modulate.a = 0.5  # lo scheletro rianimato sta per sparire
	elif life_left > 0.0:
		sprite.modulate.a = 0.85
	if is_boss:
		bar.draw_texture_rect_region(ATLAS, Rect2(-8, -size - 14, 16, 16), Rect2(80, 32, 16, 16))
	if hp >= max_hp:
		return
	var w := 12.0 if is_boss else 8.0
	var y := -size - (7.0 if is_boss else 3.0)
	bar.draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 3), C_BLACK)
	var fill := C_WHITE if team == ALLY else C_LIGHT
	bar.draw_rect(Rect2(-w / 2.0, y, roundf(w * clampf(hp / max_hp, 0.0, 1.0)), 1), fill)
