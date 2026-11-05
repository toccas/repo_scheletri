class_name RamiUnita
extends Resource
## I RAMI DI SPECIALIZZAZIONE di un'unità: due scelte al rango 3 e due al rango 5.
## Un file per unità in specializzazioni/<unità>.tres (es. specializzazioni/arciere.tres):
## doppio clic per aprirlo nell'Inspector e cambiare nomi, colori e numeri.
## Il giocatore sceglie in preparazione (stella sulla carta dell'unità).

## Id dell'unità (come in game_data.gd), es. "arciere".
@export var unita := ""
@export_group("Rango 3")
@export var rango_3_a: Specializzazione
@export var rango_3_b: Specializzazione
@export_group("Rango 5")
@export var rango_5_a: Specializzazione
@export var rango_5_b: Specializzazione


func opzioni(rango: int) -> Array[Specializzazione]:
	var out: Array[Specializzazione] = []
	for s in ([rango_3_a, rango_3_b] if rango == 3 else [rango_5_a, rango_5_b]):
		if s != null:
			out.append(s)
	return out
