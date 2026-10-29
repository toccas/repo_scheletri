extends Node2D
## Resti di un'unità morta, disegnati a pixel (il nodo è scalato di game.px).
##
##   SCHELETRI: la sprite si sbriciola pixel per pixel (cadono dal basso verso
##   l'alto, come un mucchio d'ossa che crolla), la polvere sparisce e resta il
##   TESCHIO per terra. Gli spettri (banshee, cecchino) invece si dissolvono
##   verso l'alto senza lasciare niente.
##   EROI: il corpo crolla e diventa cenere grigia; per terra resta quello che
##   portavano: spada, arco, cappello del mago, elmo del gigante, corona del campione.
##
## Quando finisce l'ondata main.gd chiama sink(): teschi e armi affondano nel
## terreno con un piccolo sbuffo di polvere, poi il nodo si elimina.

const Data := preload("res://scripts/game_data.gd")

const GRAVITY := 160.0
const DUST_LIFE := 1.4  # quanto resta la polvere dopo essere caduta
const GHOSTS := ["banshee", "cecchino"]

# oggetti lasciati per terra: W ossa, L chiaro, M medio, D scuro, K nero, A/a accento
const SKULL := [".WWW.", "WWWWW", "WKWKW", ".WWW.", ".W.W."]
const ITEMS := {
	"soldato": [".....D.", "WLLLLDK", ".....D."],
	"arciere": [".DDDD.", "D....D", "LLLLLL"],
	"mago": ["..A..", ".AA..", ".AaA.", "aaaaa"],
	"gigante": [".MMMM.", "MLLLLM", "AAAAAA"],
	"boss": ["A.A.A", "AAAAA", "aAaAa"],
}
const GRAYS := {"W": Color("ececec"), "L": Color("acacac"), "M": Color("707070"), "D": Color("3a3a3a"), "K": Color("141414")}

static var _images := {}  # Texture2D -> Image (per leggere i pixel delle sprite)

var game
var team := 0
var ground := Vector2.ZERO
var bits: Array = []  # pixel che cadono: {p, v, c, delay, landed, land_t, rest_y}
var keep: Array = []  # pixel dell'oggetto che resta: {o, c}  (o = posizione relativa)
var keep_pos := Vector2.ZERO  # dove sta l'oggetto (si muove finché non tocca terra)
var keep_v := Vector2.ZERO
var keep_bounced := false
var ghost := false
var t := 0.0
var sinking := false
var sink_delay := 0.0
var sink_t := 0.0
var puffs: Array = []  # sbuffi di polvere quando affonda


## Prepara i resti copiando i pixel della sprite dell'unità `u`.
func setup(u) -> void:
	game = u.game
	team = u.team
	ground = u.ground
	ghost = team == 0 and u.kind in GHOSTS
	var spr: Sprite2D = u.sprite
	var img := _image(spr.texture)
	var reg: Rect2 = spr.region_rect
	var sc: float = spr.scale.x
	if img != null:
		for y in int(reg.size.y):
			for x in int(reg.size.x):
				var c := img.get_pixel(int(reg.position.x) + x, int(reg.position.y) + y)
				if c.a < 0.5:
					continue
				var lx := (reg.size.x - 1 - x if spr.flip_h else float(x)) - 8.0
				var ly := float(y) - 16.0
				var p := Vector2(lx, ly) * sc
				var b := {"p": p, "c": c, "landed": false, "land_t": 0.0}
				if ghost:
					b["v"] = Vector2(randf_range(-6, 6), randf_range(-26, -8))
					b["delay"] = randf() * 0.25
				else:
					# i pixel in basso crollano per primi, quelli in alto cadono sopra
					b["v"] = Vector2(randf_range(-9, 9) + lx * randf_range(0.4, 1.4), randf_range(-12, 4))
					b["delay"] = (-ly / 16.0) * 0.14 + randf() * 0.05
					b["rest_y"] = -float(randi_range(0, 2 if sc > 1.0 else 1))
					if team == 1:  # gli eroi diventano cenere
						b["c"] = c.lerp(Color(0.35, 0.35, 0.35), 0.35)
				bits.append(b)
	# l'oggetto che resta per terra
	var pattern: Array = []
	if team == 0 and not ghost:
		pattern = SKULL
	elif team == 1:
		pattern = ITEMS["boss"] if u.is_boss else ITEMS.get(u.kind, [])
	var acc: Color = Data.accent("gigante" if u.is_boss else u.kind, team)
	for yy in pattern.size():
		var row: String = pattern[yy]
		for xx in row.length():
			var ch := row[xx]
			if ch == ".":
				continue
			var col: Color = GRAYS.get(ch, acc)
			if ch == "A":
				col = acc
			elif ch == "a":
				col = acc.darkened(0.35)
			var o := Vector2(xx - int(row.length() / 2.0), yy - pattern.size())
			if team == 1:  # gli eroi guardano a sinistra
				o.x = -o.x
			keep.append({"o": o, "c": col})
	# parte all'altezza della testa (o delle mani) e cade rimbalzando
	keep_pos = Vector2(randf_range(-2.0, 2.0), -12.0 * sc)
	keep_v = Vector2(randf_range(-10, 10), -randf_range(10, 25))
	scale = Vector2.ONE * game.px
	position = game.to_screen(ground)
	z_index = int(position.y) - 2


static func _image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	if not _images.has(tex):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_images[tex] = img
	return _images[tex]


## A fine ondata: affonda nel terreno dopo `delay` secondi.
func sink(delay: float) -> void:
	sinking = true
	sink_delay = delay


func _process(delta: float) -> void:
	if game == null or game.paused:
		return
	t += delta
	for b in bits:
		if b["landed"]:
			b["land_t"] += delta
			continue
		if t < b["delay"]:
			continue
		if ghost:
			b["p"] += b["v"] * delta
			b["land_t"] += delta
			continue
		b["v"].y += GRAVITY * delta
		b["p"] += b["v"] * delta
		if b["p"].y >= b["rest_y"]:
			b["p"].y = b["rest_y"]
			b["landed"] = true
	bits = bits.filter(func(b: Dictionary) -> bool: return b["land_t"] < DUST_LIFE)
	if not keep.is_empty() and t > 0.05:
		if keep_pos.y < 0.0 or keep_v.y < 0.0:
			keep_v.y += GRAVITY * delta
			keep_pos += keep_v * delta
			if keep_pos.y >= 0.0:
				keep_pos.y = 0.0
				if not keep_bounced and keep_v.y > 20.0:
					keep_v = Vector2(keep_v.x * 0.4, -keep_v.y * 0.3)  # un rimbalzino
					keep_bounced = true
				else:
					keep_v = Vector2.ZERO
	if sinking:
		sink_delay -= delta
		if sink_delay <= 0.0:
			if sink_t == 0.0:
				for i in 6:
					puffs.append({"p": keep_pos + Vector2(randf_range(-4, 4), 0), "v": Vector2(randf_range(-8, 8), -randf_range(4, 12)), "life": 0.6})
			sink_t += delta
			if sink_t >= 1.1:
				queue_free()
				return
	for pf in puffs:
		pf["p"] += pf["v"] * delta
		pf["life"] -= delta
	puffs = puffs.filter(func(pf: Dictionary) -> bool: return pf["life"] > 0.0)
	if keep.is_empty() and bits.is_empty() and puffs.is_empty():
		queue_free()
		return
	position = game.to_screen(ground)
	z_index = int(position.y) - 2  # sul terreno: le unità che stanno qui ci passano sopra
	queue_redraw()


func _draw() -> void:
	for b in bits:
		if t < b["delay"]:  # ancora al suo posto: la sprite non è ancora crollata qui
			draw_rect(Rect2((b["p"] as Vector2).round(), Vector2.ONE), b["c"])
			continue
		var a := 1.0
		if ghost:
			a = clampf(1.0 - b["land_t"] / DUST_LIFE, 0.0, 1.0)
		elif b["landed"]:
			a = clampf(1.0 - b["land_t"] / DUST_LIFE, 0.0, 1.0)
		var c: Color = b["c"]
		draw_rect(Rect2((b["p"] as Vector2).round(), Vector2.ONE), Color(c, c.a * a))
	if keep.is_empty():
		return
	# affondamento: l'oggetto scende sotto la linea del terreno e sparisce
	var k := clampf(sink_t / 1.0, 0.0, 1.0)
	var down := roundf(k * 6.0)
	var base := keep_pos.round()
	if k > 0.0:
		var w := 8.0 + 2.0 * sin(k * PI)
		draw_rect(Rect2(base.x - w / 2.0, base.y - 1.0, w, 2.0), Color(0, 0, 0, 0.4 * sin(k * PI)))
	for px in keep:
		var p: Vector2 = base + px["o"] + Vector2(0, down)
		if p.y > 0.0:
			continue  # già sotto terra
		var c: Color = px["c"]
		draw_rect(Rect2(p, Vector2.ONE), Color(c, 1.0 - k * 0.3))
	for pf in puffs:
		draw_rect(Rect2((pf["p"] as Vector2).round(), Vector2.ONE), Color(0.6, 0.6, 0.6, clampf(pf["life"] / 0.6, 0.0, 1.0) * 0.8))
