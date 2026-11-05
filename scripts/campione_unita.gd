extends "res://scripts/unit.gd"
## CAMPIONE DEGLI EROI in battaglia: un eroe unico con sprite grande, barra della vita
## in alto sullo schermo, mosse speciali e seconda fase. I dati (vita, danni, mosse)
## stanno nella sua risorsa Campione (campioni/<id>.tres), vedi campione.gd e mossa_campione.gd.

const SegnaleScript := preload("res://scripts/segnale.gd")
## Velocità della CARICA (pixel dell'arte al secondo).
const VEL_CARICA := 130.0
## Pausa minima tra due mosse.
const PAUSA_MOSSE := 1.2

var dati: Campione
var timers: Array[float] = []
var fase2 := false
var scudo_t := 0.0
var scudo_k := 0.0
var cast_t := 0.0  # sta usando una mossa (frame 2)
var pausa_t := 0.0
var carica_t := 0.0
var carica_danno := 0.0
var carica_stun := 0.0
var carica_colpiti: Array = []
var polvere_t := 0.0
var fn := 16  # lato di un frame della sprite


func setup_campione(c: Campione, hp_mult: float, dmg_mult: float) -> void:
	dati = c
	_load_stats(c.tipo_base)
	team = ENEMY
	is_boss = true
	max_hp = c.vita * hp_mult
	hp = max_hp
	base_dmg = c.danno * dmg_mult
	attack_range = c.gittata
	base_cooldown = c.cadenza
	base_speed = c.velocita
	melee = c.corpo_a_corpo
	radius = c.raggio
	splash = c.area
	xp_value = c.esperienza
	vola = c.volante
	timers.clear()
	for m in c.mosse:
		timers.append(m.primo_uso if m != null else 999.0)


func _ready() -> void:
	super._ready()
	if dati.sprite != null:
		fn = dati.sprite.get_height()
		sprite.texture = dati.sprite
		sprite.scale = Vector2.ONE
		sprite.offset = Vector2(-fn / 2.0, -fn + dati.spazio_sotto_i_piedi)
		_update_frame()


func _update_frame() -> void:
	if dati == null or dati.sprite == null:
		super._update_frame()
		return
	var f := 2 if cast_t > 0.0 or attack_anim > 0.08 or carica_t > 0.0 else frame
	sprite.region_rect = Rect2(f * fn, 0, fn, fn)


func muzzle_height() -> float:
	return dati.altezza_colpo if dati != null else 16.0


func accent() -> Color:
	return dati.colore if dati != null else super.accent()


func _rabbia() -> float:
	return dati.velocita_fase2 if fase2 else 1.0


func get_speed() -> float:
	return super.get_speed() * _rabbia()


func get_cooldown() -> float:
	return super.get_cooldown() / _rabbia()


func _process(delta: float) -> void:
	super._process(delta)
	if dead or dati == null:
		return
	if vola:  # in volo: sta più in alto e ondeggia
		sprite.position.y -= 6.0 + roundf(sin(Time.get_ticks_msec() / 300.0) * 2.0)
	_update_frame()
	if not game.is_running() or entering:
		return
	cast_t = maxf(0.0, cast_t - delta)
	scudo_t = maxf(0.0, scudo_t - delta)
	pausa_t = maxf(0.0, pausa_t - delta)
	if not fase2 and dati.soglia_fase2 > 0.0 and hp < max_hp * dati.soglia_fase2:
		fase2 = true
		game.campione_fase2(self)
	if stun_t > 0.0 or carica_t > 0.0:
		return
	for i in dati.mosse.size():
		var m: MossaCampione = dati.mosse[i]
		if m == null or (m.solo_fase2 and not fase2):
			continue
		timers[i] -= delta * _rabbia()
		if timers[i] <= 0.0 and pausa_t <= 0.0:
			if _usa(m):
				timers[i] = m.ricarica
				pausa_t = PAUSA_MOSSE
				cast_t = 0.5
				game.campione_mossa(self, m)
			else:
				timers[i] = 1.0  # niente bersagli: riprova tra poco
			break


func _enemy_update(delta: float) -> void:
	if carica_t > 0.0:
		_carica_update(delta)
		return
	super._enemy_update(delta)


func take_damage(amount: float, attacker = null) -> void:
	if scudo_t > 0.0 and not dead:
		amount *= 1.0 - scudo_k
		if randf() < 0.3:
			game.spawn_unit_fx(ground, "spark", muzzle_height(), 1.0, 0.2, accent())
	super.take_damage(amount, attacker)


func _die() -> void:
	if dead:
		return
	game.on_campione_sconfitto(self)
	super._die()


# --- Mosse ------------------------------------------------------------------------

func _scheletri_entro(centro: Vector2, r: float) -> Array:
	var out: Array = []
	for c in game.allies_root.get_children():
		if not c.dead and c.visible and not c.entering and c.ground.distance_to(centro) <= r + c.radius:
			out.append(c)
	return out


func _eroi_entro(r: float) -> Array:
	var out: Array = []
	for c in game.enemies_root.get_children():
		if not c.dead and c.ground.distance_to(ground) <= r + c.radius:
			out.append(c)
	return out


## Uno scheletro a tiro per le mosse a distanza (a caso tra i più vicini).
func _bersaglio():
	var vicini := _scheletri_entro(ground, maxf(attack_range * 1.6, 110.0))
	if vicini.is_empty():
		return null
	vicini.sort_custom(func(a, b) -> bool: return a.ground.distance_squared_to(ground) < b.ground.distance_squared_to(ground))
	return vicini[randi() % mini(3, vicini.size())]


func _segnale(g: Vector2, r: float, ritardo: float, fatto: Callable, forma: String = "cerchio", lunghezza: float = 0.0) -> void:
	var s := SegnaleScript.new()
	s.game = game
	s.forma = forma
	s.raggio = r
	s.lunghezza = lunghezza
	s.ritardo = ritardo
	s.colore = accent()
	s.fatto = fatto
	s.scale = Vector2.ONE * game.px
	s.position = game.to_screen(g)
	s.z_index = 1
	game.segnali_root.add_child(s)


func _colpisci_area(centro: Vector2, r: float, dmg: float, stun: float = 0.0) -> void:
	for c in _scheletri_entro(centro, r):
		c.take_damage(dmg, self)
		if stun > 0.0:
			c.stun_t = maxf(c.stun_t, stun)


func _usa(m: MossaCampione) -> bool:
	var dmg := get_dmg() * m.danno
	var col := accent()
	match m.tipo:
		MossaCampione.Tipo.GRIDO:
			for c in _eroi_entro(m.raggio):
				c.buff_t = maxf(c.buff_t, m.durata)
				c.buff_k = maxf(c.buff_k if c.buff_t > 0.0 else 0.0, m.potenza)
				c.buff_col = col
			game.spawn_ground_fx(ground, m.raggio, col, 0.6)
			game.spawn_ground_fx(ground, m.raggio * 0.6, col.lightened(0.3), 0.45)
		MossaCampione.Tipo.EVOCA:
			for i in m.numero:
				var off := Vector2(randf_range(4.0, 18.0), randf_range(-14.0, 14.0))
				game.spawn_enemy_at(m.evoca, ground + off)
		MossaCampione.Tipo.CURA:
			for c in _eroi_entro(m.raggio):
				c.heal(c.max_hp * m.potenza * (0.25 if c == self else 1.0))
			game.spawn_ground_fx(ground, m.raggio, col, 0.7, "heal")
		MossaCampione.Tipo.SCHIANTO:
			if _scheletri_entro(ground, m.raggio).is_empty():
				return false
			lunge = 6.0
			game.spawn_ground_fx(ground, m.raggio, col, 0.4)
			game.spawn_ground_fx(ground, m.raggio * 0.5, Color.WHITE, 0.3)
			_colpisci_area(ground, m.raggio, dmg, m.durata)
			game.shake(0.25, 1.5)
		MossaCampione.Tipo.ROGO:
			var t = _bersaglio()
			if t == null:
				return false
			game.add_zona_nemica(t.ground, m.raggio, dmg, m.durata, col)
		MossaCampione.Tipo.METEORA:
			var t = _bersaglio()
			if t == null:
				return false
			var g: Vector2 = t.ground
			_segnale(g, m.raggio, m.ritardo, func() -> void:
				game.spawn_ground_fx(g, m.raggio, col, 0.5, "fire")
				game.spawn_ground_fx(g, m.raggio * 1.2, Color.WHITE, 0.3)
				_colpisci_area(g, m.raggio, dmg)
				game.shake(0.3, 2.0))
		MossaCampione.Tipo.PIOGGIA:
			var t = _bersaglio()
			if t == null:
				return false
			var centro: Vector2 = t.ground
			for i in m.numero:
				var g := centro + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * m.raggio
				_segnale(g, 7.0, m.ritardo + i * 0.07, func() -> void:
					game.spawn_unit_fx(g, "spark", 2.0, -1.0, 0.25, col)
					_colpisci_area(g, 7.0, dmg))
		MossaCampione.Tipo.CARICA:
			if _scheletri_entro(ground + Vector2(-m.raggio * 0.5, 0), m.raggio * 0.6).is_empty():
				return false
			carica_t = m.raggio / VEL_CARICA
			carica_danno = dmg
			carica_stun = m.durata
			carica_colpiti.clear()
		MossaCampione.Tipo.SCUDO:
			scudo_t = m.durata
			scudo_k = clampf(m.potenza, 0.0, 0.95)
			game.spawn_ground_fx(ground, radius + 10.0, col, 0.5)
		MossaCampione.Tipo.LUCE:
			var colpiti := _scheletri_entro(ground, m.raggio)
			if colpiti.is_empty():
				return false
			for c in colpiti:
				c.stun_t = maxf(c.stun_t, m.durata)
				c.flash = 0.3
			game.spawn_ground_fx(ground, m.raggio, Color.WHITE, 0.6)
			game.spawn_ground_fx(ground, m.raggio * 0.7, col, 0.5)
			game.lampo_schermo(0.25)
		MossaCampione.Tipo.RESURREZIONE:
			var n: int = game.resuscita_eroi(ground, m.raggio, m.numero)
			if n == 0:
				for i in mini(2, m.numero):
					game.spawn_enemy_at(m.evoca, ground + Vector2(randf_range(4.0, 16.0), randf_range(-12.0, 12.0)))
		MossaCampione.Tipo.RAGGIO:
			if _scheletri_entro(ground + Vector2(-m.raggio * 0.5, 0), m.raggio * 0.55).is_empty():
				return false
			var g := ground
			var lungo := m.raggio
			_segnale(g, 7.0, m.ritardo, func() -> void:
				for c in game.allies_root.get_children():
					if not c.dead and c.visible and c.ground.x <= g.x and c.ground.x >= g.x - lungo and absf(c.ground.y - g.y) <= 7.0 + c.radius:
						c.take_damage(dmg, self)
				game.shake(0.2, 1.5), "linea", lungo)
		MossaCampione.Tipo.COLONNE:
			var vicini := _scheletri_entro(ground, 200.0)
			if vicini.is_empty():
				return false
			vicini.shuffle()
			for i in mini(m.numero, vicini.size()):
				var g: Vector2 = vicini[i].ground
				_segnale(g, m.raggio, m.ritardo + i * 0.15, func() -> void:
					game.spawn_ground_fx(g, m.raggio, col, 0.4, "bolt")
					_colpisci_area(g, m.raggio, dmg))
		MossaCampione.Tipo.TELETRASPORTO:
			var dest := ground + Vector2(-m.raggio, randf_range(-10.0, 10.0))
			dest.x = maxf(dest.x, 30.0)
			if not vola:
				dest = game.constrain(dest, radius)
			game.spawn_ground_fx(ground, 10.0, col, 0.4)
			ground = dest
			game.spawn_ground_fx(ground, 12.0, col, 0.5)
			sync_screen()
	return true


func _carica_update(delta: float) -> void:
	carica_t -= delta
	ground.x -= VEL_CARICA * delta
	polvere_t -= delta
	if polvere_t <= 0.0:
		polvere_t = 0.07
		game.spawn_ground_fx(ground + Vector2(radius, 0), 4.0, C_LIGHT, 0.3)
	for c in game.allies_root.get_children():
		if c.dead or not c.visible or c in carica_colpiti:
			continue
		if c.ground.distance_to(ground) <= radius + c.radius + 3.0:
			carica_colpiti.append(c)
			c.take_damage(carica_danno, self)
			c.stun_t = maxf(c.stun_t, carica_stun)
			c.knock = Vector2(-4, 0)
			if not c.is_static():
				c.ground.x -= 6.0
	if game.tower_distance(ground) <= attack_range + 4.0:
		carica_t = 0.0


# --- Grafica ------------------------------------------------------------------------

func _draw_bar() -> void:
	var top := -float(fn - dati.spazio_sotto_i_piedi) - (6.0 if vola else 0.0)
	# corona sopra la testa
	bar.draw_texture_rect_region(ATLAS, Rect2(-8, top - 12, 16, 16), Rect2(80, 32, 16, 16))
	if scudo_t > 0.0:  # bolla dello scudo
		var a := 0.35 + 0.25 * sin(Time.get_ticks_msec() / 80.0)
		var r := fn * 0.45
		bar.draw_arc(Vector2(0, top * 0.5), r, 0.0, TAU, 24, Color(accent(), a), 1.0)
		bar.draw_arc(Vector2(0, top * 0.5), r - 1.0, 0.0, TAU, 24, Color(1, 1, 1, a * 0.6), 1.0)
	if stun_t > 0.0:
		var k := fmod(Time.get_ticks_msec() / 150.0, 4.0)
		bar.draw_rect(Rect2(-6 + roundf(k) * 3.0, top - 2, 1, 1), C_WHITE)
		bar.draw_rect(Rect2(6 - roundf(k) * 3.0, top - 3, 1, 1), C_WHITE)
	if curse_t > 0.0:
		bar.draw_rect(Rect2(8, top, 3, 2), C_BLACK)
		bar.draw_rect(Rect2(8, top - 1, 3, 1), Data.accent("lich"))
