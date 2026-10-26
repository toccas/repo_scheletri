extends Node2D
## Scena EVOCAZIONE (segnaposto): per ora solo il pulsante BACK per tornare al menu.
## Disegnata in pixel art a scala_pixel (320x180 pixel dell'arte).

const PixelFont := preload("res://scripts/pixel_font.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

@export_range(2, 6) var scala_pixel := 4

const C0 := Color("141414")
const C1 := Color("242424")
const C2 := Color("343434")
const C3 := Color("4a4a4a")
const C4 := Color("707070")
const C5 := Color("acacac")
const C6 := Color("ececec")

var t := 0.0
var fade := 1.0
var leaving := false
var back_rect := Rect2()
var hot := false


func _process(delta: float) -> void:
	t += delta
	if leaving:
		fade = minf(1.0, fade + delta * 3.0)
		if fade >= 1.0:
			get_tree().change_scene_to_file(MENU_SCENE)
			return
	else:
		fade = maxf(0.0, fade - delta * 3.0)
	var m := get_global_mouse_position() / scala_pixel
	hot = back_rect.grow(2).has_point(m)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hot else Input.CURSOR_ARROW)
	queue_redraw()


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hot:
		leaving = true
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER]:
		leaving = true


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scala_pixel)
	var art := (vp / scala_pixel).floor()
	draw_rect(Rect2(Vector2.ZERO, art), C0)
	# vortice al centro
	var c := Vector2(art.x / 2.0, 82)
	for y in range(-40, 41):
		for x in range(-40, 41):
			var r := Vector2(x, y * 1.2).length()
			if r > 40:
				continue
			var a := atan2(y, x)
			var v := sin(a * 3.0 + r * 0.35 - t * 2.0) * 0.5 + 0.5
			v *= 1.0 - r / 40.0
			if v > 0.6:
				draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), C5 if v > 0.75 else C3)
			elif v > 0.35:
				draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), C2)
	PixelFont.draw_centered(self, "EVOCAZIONE", c.x, 20, 2.0, C6, C0)
	PixelFont.draw_centered(self, "IN COSTRUZIONE", c.x, 136, 1.0, C4)
	PixelFont.draw_centered(self, "QUI EVOCHERAI NUOVI SCHELETRI", c.x, 148, 1.0, C3)
	# BACK in basso a sinistra (stesso stile del menu)
	var label := "< BACK"
	var size := Vector2(PixelFont.text_width(label, 1.0) + 10, 13)
	var r := Rect2(Vector2(8, art.y - 8 - size.y), size)
	back_rect = r
	if hot:
		draw_rect(r.grow(2), C6)
	draw_rect(r.grow(1), C0)
	draw_rect(Rect2(r.position + Vector2(2, -3), Vector2(size.x, 3)), Color("8a8a8c"))
	draw_rect(Rect2(r.position + Vector2(size.x, -1), Vector2(2, size.y)), C2)
	draw_rect(r, Color("707070") if hot else Color("5e5e60"))
	draw_rect(Rect2(r.position, Vector2(size.x, 1)), C4)
	PixelFont.draw_text(self, label, r.position + Vector2(6, 4), 1.0, C0)
	PixelFont.draw_text(self, label, r.position + Vector2(5, 3), 1.0, C6 if hot else C5)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, art), Color(C0, fade))
