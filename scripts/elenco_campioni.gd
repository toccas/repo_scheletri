class_name ElencoCampioni
extends Resource
## L'ELENCO DEI CAMPIONI DEGLI EROI, uno per ondata (vedi campione.gd).
## Aggiungi, togli o cambia l'ondata di un campione da qui o dal suo file.

@export var campioni: Array[Campione] = []
## Modalità infinita: dopo l'ultimo campione ricominciano dal primo (e la vita
## e i danni continuano a crescere con l'ondata).
@export var ricomincia_dopo_l_ultimo := true


## Il campione di quell'ondata (null se non c'è).
func per_ondata(w: int) -> Campione:
	var ultima := 0
	for c in campioni:
		if c == null:
			continue
		if c.ondata == w:
			return c
		ultima = maxi(ultima, c.ondata)
	if not ricomincia_dopo_l_ultimo or ultima <= 0 or w <= ultima:
		return null
	var k := w % ultima
	if k == 0:
		k = ultima
	for c in campioni:
		if c != null and c.ondata == k:
			return c
	return null
