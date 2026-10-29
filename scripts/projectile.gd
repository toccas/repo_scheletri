extends Node2D
## Proiettile (frecce, magie, colpi del necromante), disegnato a pixel.
## Si muove sul terreno (`ground`) con un'altezza che passa gradualmente da
## quella di partenza a quella del bersaglio: in vista laterale parte dalle
## mani di chi spara (o dalla cima della torre) e arriva sul corpo.
## Se il bersaglio muore prima dell'impatto, il proiettile arriva all'ultima
## posizione nota: con splash esplode comunque, altrimenti si disperde.

const Data := preload("res://scripts/game_data.gd")
const Suoni := preload("res://scripts/suoni.gd")

const C_BLACK := Color("141414")
const C_MID := Color("707070")
const C_LIGHT := Color("acacac")
const C_WHITE := Color("ececec")

var game
var team := 0
var shooter = null  # chi ha tirato (per il contrattacco)
var target = null
var to_tower := false
var dmg := 1.0
var splash := 0.0
var look := "arrow"  # "arrow", "magic" o "necro"
var speed := 140.0  # pixel dell'arte al secondo
## Colore d'accento di chi ha tirato (impennaggio delle frecce, alone delle magie).
var tint := Color("acacac")

var ground := Vector2.ZERO
var height := 0.0
var start_height := 0.0
var dest := Vector2.ZERO
var dest_height := 9.0
var total := 1.0
var trail: Array = []  # ultime posizioni a schermo, per la scia


func _ready() -> void:
	scale = Vector2.ONE * game.px
	_update_dest()
	total = maxf(1.0, ground.distance_to(dest))
	_sync()


func _update_dest() -> void:
	if to_tower:
		dest = Vector2(game.wall_x - 12.0, game.tower_base_y)  # verso la base della torre
		dest_height = 24.0
	elif target != null and is_instance_valid(target) and not target.dead:
		dest = target.ground
		dest_height = target.muzzle_height()


func _process(delta: float) -> void:
	if not game.is_running():
		return
	_update_dest()
	var step := speed * delta
	if ground.distance_to(dest) <= step:
		_hit()
		return
	var dir_x := signf(dest.x - ground.x)
	ground = ground.move_toward(dest, step)
	var k := clampf(1.0 - ground.distance_to(dest) / total, 0.0, 1.0)
	height = lerpf(start_height, dest_height, k)
	if dir_x != 0.0:
		scale.x = game.px * dir_x  # la freccia punta dove va
	_sync()


func _sync() -> void:
	var base: Vector2 = game.to_screen(ground)
	position = base - Vector2(0, roundf(height) * game.px)
	trail.push_front(position)  # trail[0] è la posizione attuale
	if trail.size() > 5:
		trail.pop_back()
	z_index = int(base.y) + 1


func _hit() -> void:
	Suoni.play("impatto", 0.8 if splash > 0.0 else 1.0, -2.0 if look == "necro" else 0.0)
	if to_tower:
		game.damage_tower(dmg * Data.TOWER_RANGED_TAKEN)
	elif splash > 0.0:
		game.damage_area(dest, splash, dmg, 1 - team, shooter)
		game.spawn_ground_fx(dest, splash, tint if look != "arrow" else C_LIGHT, 0.25)
	elif target != null and is_instance_valid(target) and not target.dead:
		game.spawn_unit_fx(target.ground, "spark", dest_height, signf(dest.x - ground.x + 0.01), 0.22,
			tint if look != "arrow" else C_WHITE)
		target.take_damage(dmg, shooter)
	if to_tower:
		game.spawn_unit_fx(dest, "spark", dest_height, -1.0, 0.25)
	queue_free()


func _draw() -> void:
	# scia: puntini sempre più deboli nelle posizioni precedenti
	for i in range(1, trail.size()):
		var lp: Vector2 = (trail[i] - position) / scale
		var a := 0.55 * (1.0 - float(i) / trail.size())
		var col := tint if look != "arrow" else C_LIGHT
		draw_rect(Rect2(lp.round(), Vector2.ONE * (2.0 if look == "magic" and i == 1 else 1.0)), Color(col, a))
	match look:
		"arrow":
			draw_rect(Rect2(-3, 0, 4, 1), C_LIGHT)
			draw_rect(Rect2(1, 0, 1, 1), C_WHITE)
			draw_rect(Rect2(-4, -1, 1, 1), tint)  # impennaggio del colore dell'arciere
			draw_rect(Rect2(-4, 1, 1, 1), tint)
		"magic":
			draw_rect(Rect2(-2, -2, 4, 4), Color(tint, 0.45))
			draw_rect(Rect2(-1, -1, 2, 2), C_WHITE)
			draw_rect(Rect2(-3, 0, 2, 1), tint)
		"necro":
			draw_rect(Rect2(-2, -2, 5, 5), Color(tint, 0.4))
			draw_rect(Rect2(-1, -1, 3, 3), tint.darkened(0.3))
			draw_rect(Rect2(0, 0, 1, 1), C_WHITE)
			draw_rect(Rect2(-3, 0, 2, 1), tint)
